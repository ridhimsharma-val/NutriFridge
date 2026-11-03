import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/app_image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/nutrition_data.dart';
import '../fridge/models/category_item.dart';
import 'models/ai_message.dart';
import 'services/ai_assistant_service.dart';

/// Full-featured, interactive AI Assistant screen for NutriFridge.
/// Acts as the single primary entry point for natural-language food addition,
/// meal logging with ingredient fridge deduction, and contextual nutrition Q&A.
class AiAssistantScreen extends StatefulWidget {
  final String? initialPrompt;

  const AiAssistantScreen({
    super.key,
    this.initialPrompt,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<AiChatMessage> _messages = [];
  bool _isSending = false;
  bool _isConfirmingInventory = false;
  String? _selectedImageBase64;
  String? _selectedImageMimeType;
  String? _selectedImageName;

  @override
  void initState() {
    super.initState();
    // Load session messages to ensure conversation is preserved across navigations
    if (AiAssistantService.sessionMessages.isEmpty) {
      AiAssistantService.resetSession();
    }
    _messages.addAll(AiAssistantService.sessionMessages);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSend(promptOverride: widget.initialPrompt);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncSession() {
    AiAssistantService.sessionMessages = List.from(_messages);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await AppImagePicker.pickImage(source: source);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      final mime = file.name.endsWith('.png') ? 'image/png' : 'image/jpeg';

      setState(() {
        _selectedImageBase64 = base64Str;
        _selectedImageMimeType = mime;
        _selectedImageName = file.name;
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _retryLastUserMessage() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        final text = _messages[i].text;
        _handleSend(promptOverride: text);
        break;
      }
    }
  }

  Future<void> _handleSend({String? promptOverride}) async {
    final text = (promptOverride ?? _textController.text).trim();
    if (text.isEmpty && _selectedImageBase64 == null) return;

    final userMessage = AiChatMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      attachedImageBase64: _selectedImageBase64,
    );

    final imageToSend = _selectedImageBase64;
    final mimeToSend = _selectedImageMimeType;

    setState(() {
      _messages.add(userMessage);
      _syncSession();
      _textController.clear();
      _selectedImageBase64 = null;
      _selectedImageMimeType = null;
      _selectedImageName = null;
      _isSending = true;
    });

    _scrollToBottom();

    // Call live n8n backend or intelligent local processing
    final response = await AiAssistantService.sendRequest(
      message: text,
      imageBase64: imageToSend,
      mimeType: mimeToSend,
      history: _messages,
    );

    if (!mounted) return;

    final String assistantText =
        (response['assistantMessage'] as String?) ?? 'Processed your request.';
    final String action = (response['action'] as String?) ?? 'assistant_reply';
    final bool requiresConfirmation = (response['requiresConfirmation'] as bool?) ?? false;
    bool needsClarification = (response['needsClarification'] as bool?) ?? false;
    String? clarifyingQuestion = response['clarifyingQuestion'] as String?;

    final List<Map<String, dynamic>> inventoryItems = [];
    if (response['inventoryItems'] is List) {
      for (final it in response['inventoryItems']) {
        if (it is Map) {
          inventoryItems.add(Map<String, dynamic>.from(it));
        }
      }
    }

    // If Gemini proposes items with missing or ambiguous quantity, ask for clarification
    if (action == 'add_inventory_items' && inventoryItems.isNotEmpty) {
      for (final it in inventoryItems) {
        final rawQty = it['quantity'];
        if (rawQty == null || (rawQty is num && rawQty <= 0) || (rawQty is String && rawQty.trim().isEmpty)) {
          needsClarification = true;
          final itemName = (it['name'] as String?) ?? 'food item';
          clarifyingQuestion =
              'How much $itemName would you like to add? Please specify the quantity and unit.';
          inventoryItems.clear();
          break;
        }
      }
    }

    Map<String, dynamic>? meal;
    if (response['meal'] is Map) {
      meal = Map<String, dynamic>.from(response['meal'] as Map);
    }

    final List<Map<String, dynamic>> suggestedDeductions = [];
    if (response['suggestedInventoryDeductions'] is List) {
      for (final d in response['suggestedInventoryDeductions']) {
        if (d is Map) {
          suggestedDeductions.add(Map<String, dynamic>.from(d));
        }
      }
    }

    // Pre-populate deduction selections for matched fridge items
    final Set<String> initialSelectedDeductions = {};
    if (meal != null && meal['ingredients'] is List) {
      for (final ing in meal['ingredients']) {
        if (ing is Map && ing['name'] != null) {
          final ingName = ing['name'] as String;
          final match = FridgeCategoryRepository.findItemByName(ingName);
          if (match != null || ing['matchedInventoryItemId'] != null) {
            initialSelectedDeductions.add(ingName);
          }
        }
      }
    }

    final assistantMessage = AiChatMessage(
      id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
      text: assistantText,
      isUser: false,
      timestamp: DateTime.now(),
      action: action,
      requiresConfirmation: requiresConfirmation,
      needsClarification: needsClarification,
      clarifyingQuestion: clarifyingQuestion,
      inventoryItems: inventoryItems,
      meal: meal,
      suggestedDeductions: suggestedDeductions,
      selectedDeductionIngredients: initialSelectedDeductions,
    );

    setState(() {
      _messages.add(assistantMessage);
      _syncSession();
      _isSending = false;
    });

    _scrollToBottom();
  }

  static num _parseQuantity(dynamic q) {
    if (q is num) return q;
    if (q is String) {
      final clean = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(q);
      if (clean != null) {
        return num.tryParse(clean.group(1)!) ?? 1;
      }
    }
    return 1;
  }

  static String _parseUnit(dynamic u) {
    if (u is String && u.trim().isNotEmpty) {
      return u.trim();
    }
    return 'piece';
  }

  static num _getStepForUnit(String unit, [num? currentVal]) {
    final u = unit.trim().toLowerCase();
    if (u == 'g' || u == 'gram' || u == 'grams') return 50;
    if (u == 'ml' || u == 'millilitre' || u == 'millilitres') return 50;
    if (u == 'kg' || u == 'kilogram' || u == 'kilograms') return 0.1;
    if (u == 'l' || u == 'litre' || u == 'litres' || u == 'liter' || u == 'liters') {
      if (currentVal != null && (currentVal % 0.5 != 0) && (currentVal % 0.25 == 0)) {
        return 0.25;
      }
      return 0.5;
    }
    return 1;
  }

  static num _getMinForUnit(String unit, [num? currentVal]) {
    final u = unit.trim().toLowerCase();
    if (u == 'g' || u == 'gram' || u == 'grams') return 50;
    if (u == 'ml' || u == 'millilitre' || u == 'millilitres') return 50;
    if (u == 'kg' || u == 'kilogram' || u == 'kilograms') return 0.1;
    if (u == 'l' || u == 'litre' || u == 'litres' || u == 'liter' || u == 'liters') {
      if (currentVal != null && currentVal > 0 && currentVal < 0.5) return currentVal;
      return 0.5;
    }
    return 1;
  }

  void _incrementProposedItem(AiChatMessage message, int itemIndex) {
    if (message.isConfirmed) return;
    final msgIdx = _messages.indexWhere((m) => m.id == message.id);
    if (msgIdx == -1) return;

    final updatedList = List<Map<String, dynamic>>.from(
      message.inventoryItems.map((it) => Map<String, dynamic>.from(it)),
    );
    if (itemIndex < 0 || itemIndex >= updatedList.length) return;

    final item = updatedList[itemIndex];
    final currentQty = _parseQuantity(item['quantity']);
    final unit = _parseUnit(item['unit']);
    final step = _getStepForUnit(unit, currentQty);

    num newQty = currentQty + step;
    if (step is double || currentQty is double) {
      newQty = double.parse(newQty.toStringAsFixed(2));
      if (newQty == newQty.roundToDouble()) {
        newQty = newQty.toInt();
      }
    } else {
      newQty = newQty.toInt();
    }

    item['quantity'] = newQty;
    updatedList[itemIndex] = item;

    setState(() {
      _messages[msgIdx] = _messages[msgIdx].copyWith(inventoryItems: updatedList);
      _syncSession();
    });
  }

  void _decrementProposedItem(AiChatMessage message, int itemIndex) {
    if (message.isConfirmed) return;
    final msgIdx = _messages.indexWhere((m) => m.id == message.id);
    if (msgIdx == -1) return;

    final updatedList = List<Map<String, dynamic>>.from(
      message.inventoryItems.map((it) => Map<String, dynamic>.from(it)),
    );
    if (itemIndex < 0 || itemIndex >= updatedList.length) return;

    final item = updatedList[itemIndex];
    final currentQty = _parseQuantity(item['quantity']);
    final unit = _parseUnit(item['unit']);
    final minVal = _getMinForUnit(unit, currentQty);
    final step = _getStepForUnit(unit, currentQty);

    if (currentQty <= minVal) {
      return;
    }

    num newQty = currentQty - step;
    if (newQty < minVal) {
      newQty = minVal;
    }

    if (step is double || currentQty is double) {
      newQty = double.parse(newQty.toStringAsFixed(2));
      if (newQty == newQty.roundToDouble()) {
        newQty = newQty.toInt();
      }
    } else {
      newQty = newQty.toInt();
    }

    item['quantity'] = newQty;
    updatedList[itemIndex] = item;

    setState(() {
      _messages[msgIdx] = _messages[msgIdx].copyWith(inventoryItems: updatedList);
      _syncSession();
    });
  }

  void _removeItemFromProposedAdditions(AiChatMessage message, int indexToRemove) {
    if (message.isConfirmed) return;
    final updatedList = List<Map<String, dynamic>>.from(message.inventoryItems);
    if (indexToRemove >= 0 && indexToRemove < updatedList.length) {
      updatedList.removeAt(indexToRemove);
    }
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(inventoryItems: updatedList);
        _syncSession();
      });
    }
  }

  void _toggleIngredientDeduction(AiChatMessage message, String ingredientName) {
    if (message.isConfirmed) return;
    final current = Set<String>.from(message.selectedDeductionIngredients);
    if (current.contains(ingredientName)) {
      current.remove(ingredientName);
    } else {
      current.add(ingredientName);
    }
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(selectedDeductionIngredients: current);
        _syncSession();
      });
    }
  }

  void _showEditMealDialog(AiChatMessage message) {
    if (message.isConfirmed || message.meal == null) return;
    final meal = Map<String, dynamic>.from(message.meal!);
    final nutrition = Map<String, dynamic>.from(meal['nutrition'] as Map? ?? {});

    final originalName = (meal['name'] as String? ?? 'Meal').trim();
    final nameController = TextEditingController(text: originalName);
    String mealType = (meal['mealType'] as String? ?? 'lunch').toLowerCase();

    // Prefill manual values only if user had manually entered them before; otherwise keep empty by default
    final bool hasPreviousManual = nutrition['isManual'] == true;
    final caloriesController = TextEditingController(
      text: hasPreviousManual && nutrition['calories'] != null ? '${nutrition['calories']}' : '',
    );
    final proteinController = TextEditingController(
      text: hasPreviousManual && nutrition['proteinG'] != null ? '${nutrition['proteinG']}' : '',
    );
    final carbsController = TextEditingController(
      text: hasPreviousManual && nutrition['carbsG'] != null ? '${nutrition['carbsG']}' : '',
    );
    final fatController = TextEditingController(
      text: hasPreviousManual && nutrition['fatG'] != null ? '${nutrition['fatG']}' : '',
    );

    bool isManualExpanded = false;
    bool isEstimating = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6DDD8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Edit Meal', style: AppTypography.cardTitle.copyWith(fontSize: 18)),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // A. Meal Name (Required)
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Meal Name *',
                        hintText: 'e.g. Grilled Chicken Salad',
                        filled: true,
                        fillColor: const Color(0xFFF7FAF8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.tealPrimary, width: 1.5),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // B. Nutrition calculation info section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F6F0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBE5D4)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.auto_awesome, size: 18, color: AppColors.tealPrimary),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NutriFridge AI will estimate the nutrition for your meal.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F5132),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'You can review the estimated values before logging.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF14532D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // C. Optional manual nutrition entry expandable trigger
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setDialogState(() {
                          isManualExpanded = !isManualExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isManualExpanded ? const Color(0xFFF7FAF8) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tune_rounded, size: 18, color: AppColors.tealPrimary),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enter nutrition manually',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Already know the nutrition values? Add them yourself.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isManualExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Expandable manual nutrition inputs
                    if (isManualExpanded)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBFDFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nutrition details (Optional)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: caloriesController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Calories (kcal)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: proteinController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Protein (g)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: carbsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Carbs (g)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: fatController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Fat (g)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB91C1C),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    // D. Primary Action: Save Meal
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tealPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isEstimating
                            ? null
                            : () async {
                                final enteredName = nameController.text.trim();
                                if (enteredName.isEmpty) {
                                  setDialogState(() {
                                    errorMessage = 'Meal name is required.';
                                  });
                                  return;
                                }

                                final cText = caloriesController.text.trim();
                                final pText = proteinController.text.trim();
                                final cbText = carbsController.text.trim();
                                final fText = fatController.text.trim();

                                final anyManual = cText.isNotEmpty || pText.isNotEmpty || cbText.isNotEmpty || fText.isNotEmpty;
                                final allManual = cText.isNotEmpty && pText.isNotEmpty && cbText.isNotEmpty && fText.isNotEmpty;

                                // Partial manual nutrition entry check
                                if (anyManual && !allManual) {
                                  setDialogState(() {
                                    errorMessage = 'Please enter all 4 nutrition values, or leave them empty for AI estimation.';
                                    if (!isManualExpanded) isManualExpanded = true;
                                  });
                                  return;
                                }

                                // Manual nutrition entry completely filled
                                if (allManual) {
                                  final cal = int.tryParse(cText);
                                  final prot = int.tryParse(pText);
                                  final carb = int.tryParse(cbText);
                                  final fat = int.tryParse(fText);

                                  if (cal == null || prot == null || carb == null || fat == null || cal < 0 || prot < 0 || carb < 0 || fat < 0) {
                                    setDialogState(() {
                                      errorMessage = 'Please enter valid non-negative numbers for nutrition.';
                                    });
                                    return;
                                  }

                                  nutrition['calories'] = cal;
                                  nutrition['proteinG'] = prot;
                                  nutrition['carbsG'] = carb;
                                  nutrition['fatG'] = fat;
                                  nutrition['isManual'] = true;
                                  nutrition['isEstimate'] = false;
                                  nutrition.remove('estimateNote');

                                  meal['name'] = enteredName;
                                  meal['mealType'] = mealType;
                                  meal['nutrition'] = nutrition;

                                  final idx = _messages.indexWhere((m) => m.id == message.id);
                                  if (idx != -1) {
                                    setState(() {
                                      _messages[idx] = _messages[idx].copyWith(meal: meal);
                                      _syncSession();
                                    });
                                  }
                                  Navigator.of(sheetContext).pop();
                                  return;
                                }

                                // Manual fields left empty -> Use AI Nutrition Estimation as default
                                final isNameUnchanged = enteredName.toLowerCase() == originalName.toLowerCase();
                                final hasExistingEstimate = nutrition['calories'] != null && nutrition['isManual'] != true;

                                if (isNameUnchanged && hasExistingEstimate) {
                                  // Reuse existing AI estimate
                                  nutrition['isManual'] = false;
                                  nutrition['isEstimate'] = true;
                                  meal['name'] = enteredName;
                                  meal['mealType'] = mealType;
                                  meal['nutrition'] = nutrition;

                                  final idx = _messages.indexWhere((m) => m.id == message.id);
                                  if (idx != -1) {
                                    setState(() {
                                      _messages[idx] = _messages[idx].copyWith(meal: meal);
                                      _syncSession();
                                    });
                                  }
                                  Navigator.of(sheetContext).pop();
                                  return;
                                }

                                // Meal name has changed -> fetch fresh AI nutrition estimate
                                setDialogState(() {
                                  isEstimating = true;
                                  errorMessage = null;
                                });

                                final estimate = await AiAssistantService.estimateMealNutrition(
                                  mealName: enteredName,
                                  mealType: mealType,
                                );

                                if (!mounted || !sheetContext.mounted) return;

                                if (estimate != null) {
                                  nutrition['calories'] = estimate['calories'];
                                  nutrition['proteinG'] = estimate['proteinG'];
                                  nutrition['carbsG'] = estimate['carbsG'];
                                  nutrition['fatG'] = estimate['fatG'];
                                  nutrition['isEstimate'] = true;
                                  nutrition['isManual'] = false;
                                  nutrition['estimateNote'] = estimate['estimateNote'];

                                  meal['name'] = enteredName;
                                  meal['mealType'] = mealType;
                                  meal['nutrition'] = nutrition;

                                  final idx = _messages.indexWhere((m) => m.id == message.id);
                                  if (idx != -1) {
                                    setState(() {
                                      _messages[idx] = _messages[idx].copyWith(meal: meal);
                                      _syncSession();
                                    });
                                  }
                                  Navigator.of(sheetContext).pop();
                                } else {
                                  setDialogState(() {
                                    isEstimating = false;
                                    errorMessage = 'Could not estimate nutrition for this meal. Please enter nutrition manually or try again.';
                                  });
                                }
                              },
                        child: isEstimating
                            ? const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Estimating nutrition...',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ],
                                ),
                              )
                            : const Text('Save Meal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmAddInventory(AiChatMessage message) {
    if (_isConfirmingInventory || message.isConfirmed || message.inventoryItems.isEmpty) return;

    setState(() {
      _isConfirmingInventory = true;
    });

    try {
      int addedCount = 0;
      final List<Map<String, dynamic>> successfullyAddedItems = [];

      for (final itemJson in message.inventoryItems) {
        final name = itemJson['name'] as String? ?? 'Food Item';
        final category = itemJson['category'] as String? ?? 'Others';
        final qty = _parseQuantity(itemJson['quantity']);
        final unit = _parseUnit(itemJson['unit']);
        final expiryDays = (itemJson['expiryDaysEstimate'] as num?)?.toInt() ?? 5;
        final imageAsset = itemJson['imageAsset'] as String?;

        FridgeCategoryRepository.addOrMergeItem(
          categoryName: category,
          name: name,
          quantity: qty,
          unit: unit,
          expiryDays: expiryDays,
          imageAsset: imageAsset,
        );
        addedCount++;
        successfullyAddedItems.add({
          'name': name,
          'quantity': qty,
          'unit': unit,
        });
      }

      if (addedCount == 0 || successfullyAddedItems.isEmpty) {
        // Do not display a success message if the inventory update fails
        return;
      }

      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        setState(() {
          _messages[index] = _messages[index].copyWith(isConfirmed: true);
          _syncSession();
        });
      }

      final successMessage = _generateAdditionSuccessMessage(successfullyAddedItems);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  successMessage,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.tealPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Error confirming food additions: $e');
      // Do not display a success message if the inventory update fails
    } finally {
      if (mounted) {
        setState(() {
          _isConfirmingInventory = false;
        });
      }
    }
  }

  static String _generateAdditionSuccessMessage(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 'Added to your fridge!';

    if (items.length == 1) {
      final item = items.first;
      final rawName = (item['name'] as String? ?? 'Item').trim();
      final qty = _parseQuantity(item['quantity']);
      final unit = _parseUnit(item['unit']);
      final normUnit = FridgeCategoryRepository.normalizeUnit(unit);

      // Countable item (pieces/items/etc.)
      if (normUnit == 'piece' || normUnit == 'item' || normUnit.isEmpty) {
        if (qty == 1) {
          final singular = _capitalizeFirst(_singularFoodName(rawName));
          return '$singular added to your fridge!';
        } else {
          final qtyStr = (qty is int || qty == qty.roundToDouble()) ? '${qty.toInt()}' : '$qty';
          final plural = _pluralizeFoodName(_singularFoodName(rawName)).toLowerCase();
          return '$qtyStr $plural added to your fridge!';
        }
      }

      // Quantity with measurement unit (e.g. 250 g paneer, 1 L milk)
      final formattedQty = FridgeCategoryRepository.formatQuantity(qty, unit);
      return '$formattedQty ${rawName.toLowerCase()} added to your fridge!';
    }

    if (items.length == 2) {
      final item1 = items[0];
      final item2 = items[1];
      final name1 = (item1['name'] as String? ?? 'Item 1').trim();
      final name2 = (item2['name'] as String? ?? 'Item 2').trim();
      final qty1 = _parseQuantity(item1['quantity']);
      final qty2 = _parseQuantity(item2['quantity']);
      final unit1 = FridgeCategoryRepository.normalizeUnit(_parseUnit(item1['unit']));
      final unit2 = FridgeCategoryRepository.normalizeUnit(_parseUnit(item2['unit']));

      String label1 = name1;
      if (unit1 == 'piece' || unit1 == 'item' || unit1.isEmpty) {
        label1 = qty1 > 1 ? _pluralizeFoodName(_singularFoodName(name1)) : _capitalizeFirst(_singularFoodName(name1));
      } else {
        label1 = _capitalizeFirst(name1);
      }

      String label2 = name2.toLowerCase();
      if (unit2 == 'piece' || unit2 == 'item' || unit2.isEmpty) {
        label2 = qty2 > 1 ? _pluralizeFoodName(_singularFoodName(name2)).toLowerCase() : _singularFoodName(name2).toLowerCase();
      }

      final combined = '$label1 and $label2';
      if (combined.length <= 36) {
        return '$combined added to your fridge!';
      }
    }

    // 3 or more items, or 2 items with very long names
    return '${items.length} items added to your fridge!';
  }

  static String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  static String _pluralizeFoodName(String name) {
    final trimmed = name.trim();
    final lower = trimmed.toLowerCase();
    if (lower.endsWith('s') || lower.endsWith('sh') || lower.endsWith('ch') || lower.endsWith('x') || lower.endsWith('z')) {
      if (lower.endsWith('s')) return trimmed;
      return '${trimmed}es';
    }
    if (lower.endsWith('y') && !lower.endsWith('ay') && !lower.endsWith('ey') && !lower.endsWith('oy') && !lower.endsWith('uy')) {
      return '${trimmed.substring(0, trimmed.length - 1)}ies';
    }
    if (lower == 'tomato') return '${trimmed}es';
    if (lower == 'potato') return '${trimmed}es';
    return '${trimmed}s';
  }

  static String _singularFoodName(String name) {
    final trimmed = name.trim();
    final lower = trimmed.toLowerCase();
    if (lower == 'grapes') return 'Grapes';
    if (lower == 'hummus') return 'Hummus';
    if (lower.endsWith('ies')) {
      return '${trimmed.substring(0, trimmed.length - 3)}y';
    }
    if (lower.endsWith('tomatoes')) {
      return trimmed.substring(0, trimmed.length - 2);
    }
    if (lower.endsWith('potatoes')) {
      return trimmed.substring(0, trimmed.length - 2);
    }
    if (lower.endsWith('es') && !lower.endsWith('ches') && !lower.endsWith('shes') && !lower.endsWith('xes')) {
      return trimmed.substring(0, trimmed.length - 2);
    }
    if (lower.endsWith('s') && !lower.endsWith('ss')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  void _confirmRemoveInventory(AiChatMessage message) {
    if (message.inventoryItems.isEmpty) return;

    int removedCount = 0;
    for (final itemJson in message.inventoryItems) {
      final name = itemJson['name'] as String? ?? '';
      final category = itemJson['category'] as String?;
      final id = itemJson['id'] as String? ?? itemJson['matchedInventoryItemId'] as String?;

      if (id != null && id.isNotEmpty) {
        FridgeCategoryRepository.removeItem(category ?? '', id);
        removedCount++;
      } else if (name.isNotEmpty) {
        if (FridgeCategoryRepository.removeItemByName(name)) {
          removedCount++;
        }
      }
    }

    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(isConfirmed: true);
        _syncSession();
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                removedCount > 0
                    ? 'Removed $removedCount items from your fridge inventory!'
                    : 'Removed requested items from your fridge.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmLogMeal(AiChatMessage message) {
    if (message.meal == null) return;

    final meal = message.meal!;
    final name = meal['name'] as String? ?? 'Logged Meal';
    final mealType = (meal['mealType'] as String? ?? 'Lunch').toLowerCase();
    final nutrition = meal['nutrition'] as Map? ?? {};

    final calories = (nutrition['calories'] as num?)?.toInt() ?? 0;
    final protein = (nutrition['proteinG'] as num? ?? nutrition['protein'] as num?)?.toInt() ?? 0;
    final carbs = (nutrition['carbsG'] as num? ?? nutrition['carbs'] as num?)?.toInt() ?? 0;
    final fat = (nutrition['fatG'] as num? ?? nutrition['fat'] as num?)?.toInt() ?? 0;

    final List<String> ingredients = [];
    if (meal['ingredients'] is List) {
      for (final ing in meal['ingredients']) {
        if (ing is Map && ing['name'] != null) {
          ingredients.add(ing['name'] as String);
        }
      }
    }

    final formattedType = mealType.isNotEmpty
        ? mealType[0].toUpperCase() + mealType.substring(1)
        : 'Lunch';

    // 1. Update MockDataRepository (nutrition totals, meal history, wellness)
    MockDataRepository.logMeal(
      mealType: formattedType,
      mealName: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      ingredients: ingredients,
    );

    // 2. Deduct ONLY the user-selected/confirmed fridge ingredients
    int deductedCount = 0;
    final selectedIngNames = message.selectedDeductionIngredients;

    for (final ingName in selectedIngNames) {
      if (FridgeCategoryRepository.removeItemByName(ingName)) {
        deductedCount++;
      }
    }

    // Mark confirmed
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(isConfirmed: true);
        _syncSession();
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                deductedCount > 0
                    ? 'Logged $name! +$calories kcal, and deducted $deductedCount ingredients from fridge.'
                    : 'Logged $name! +$calories kcal, +${protein}g protein.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.tealPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Messages timeline
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    return _buildMessageItem(_messages[index]);
                  } else {
                    return _buildTypingIndicator();
                  }
                },
              ),
            ),

            // Image attachment preview strip
            if (_selectedImageBase64 != null) _buildSelectedImagePreview(),

            // Bottom Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00796B), Color(0xFF004D40)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.kitchen_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NutriFridge AI',
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Primary Assistant & Food Logger',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 22),
          tooltip: 'Reset Conversation',
          onPressed: () {
            setState(() {
              AiAssistantService.resetSession();
              _messages.clear();
              _messages.addAll(AiAssistantService.sessionMessages);
            });
          },
        ),
      ],
    );
  }

  Widget _buildMessageItem(AiChatMessage message) {
    if (message.isUser) {
      return _buildUserBubble(message);
    } else {
      return _buildAssistantBubble(message);
    }
  }

  Widget _buildUserBubble(AiChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: AppColors.tealPrimary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealPrimary.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.attachedImageBase64 != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    base64Decode(message.attachedImageBase64!),
                    width: 160,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(AiChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Assistant Text
              Text(
                message.text,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // Embedded Action: Add Inventory Items
              if (message.action == 'add_inventory_items' &&
                  (message.inventoryItems.isNotEmpty || message.requiresConfirmation)) ...[
                const SizedBox(height: 14),
                _buildInventoryActionCard(message),
              ],

              // Embedded Action: Remove Inventory Items
              if ((message.action == 'remove_inventory_items' || message.action == 'remove_inventory_item') &&
                  message.inventoryItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildRemovalActionCard(message),
              ],

              // Embedded Action: Log Meal
              if (message.action == 'log_meal' && message.meal != null) ...[
                const SizedBox(height: 14),
                _buildMealLogActionCard(message),
              ],

              // Embedded Clarification Prompt
              if (message.needsClarification && message.clarifyingQuestion != null) ...[
                const SizedBox(height: 12),
                _buildClarificationCard(message.clarifyingQuestion!),
              ],

              // Embedded Error Retry Action
              if (message.action == 'error') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _retryLastUserMessage,
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.error),
                  label: const Text(
                    'Retry',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryActionCard(AiChatMessage message) {
    final hasItems = message.inventoryItems.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.kitchen_rounded, size: 16, color: AppColors.tealPrimary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Proposed Fridge Additions',
                  style: AppTypography.cardTitle.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!message.isConfirmed && hasItems)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Review & Confirm',
                    style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasItems)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8E2D9), width: 0.8),
              ),
              child: const Center(
                child: Text(
                  'All proposed items have been dismissed.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ),
            )
          else
            for (int i = 0; i < message.inventoryItems.length; i++) ...[
              Builder(
                builder: (context) {
                  final item = message.inventoryItems[i];
                  final name = item['name'] ?? 'Item';
                  final cat = item['category'] ?? 'Others';
                  final qty = _parseQuantity(item['quantity']);
                  final unit = _parseUnit(item['unit']);
                  final exp = (item['expiryDaysEstimate'] as num?)?.toInt() ?? 5;
                  final formattedQty = FridgeCategoryRepository.formatQuantity(qty, unit);
                  final minVal = _getMinForUnit(unit, qty);
                  final canDecrease = !message.isConfirmed && (qty > minVal);

                  return Container(
                    key: ValueKey('proposed_item_${name}_$i'),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE8E2D9), width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.tealPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    cat,
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF7ED),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Expires in $exp d',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (!message.isConfirmed) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                key: ValueKey('remove_proposed_${name}_$i'),
                                onTap: () => _removeItemFromProposedAdditions(message, i),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAF8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2EBE5), width: 0.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Quantity to add',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (message.isConfirmed)
                                Text(
                                  formattedQty,
                                  key: ValueKey('qty_text_${name}_$i'),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.tealPrimary,
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    // Minus Button
                                    Material(
                                      color: canDecrease ? Colors.white : const Color(0xFFF1F5F9),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(
                                          color: canDecrease ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: InkWell(
                                        key: ValueKey('decrease_proposed_${name}_$i'),
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: canDecrease ? () => _decrementProposedItem(message, i) : null,
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons.remove_rounded,
                                            size: 15,
                                            color: canDecrease ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Quantity display
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          formattedQty,
                                          key: ValueKey('qty_text_${name}_$i'),
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Plus Button
                                    Material(
                                      color: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 0.8),
                                      ),
                                      child: InkWell(
                                        key: ValueKey('increase_proposed_${name}_$i'),
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () => _incrementProposedItem(message, i),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4.0),
                                          child: Icon(
                                            Icons.add_rounded,
                                            size: 15,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: (message.isConfirmed || !hasItems || _isConfirmingInventory)
                  ? null
                  : () => _confirmAddInventory(message),
              icon: _isConfirmingInventory
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      message.isConfirmed ? Icons.check_circle_rounded : Icons.add_rounded,
                      size: 18,
                    ),
              label: Text(
                message.isConfirmed
                    ? 'Added to Fridge ✓'
                    : (_isConfirmingInventory ? 'Adding to Fridge...' : 'Add to Fridge'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: message.isConfirmed ? Colors.grey.shade400 : AppColors.tealPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemovalActionCard(AiChatMessage message) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Proposed Fridge Removals',
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF991B1B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...message.inventoryItems.map((item) {
            final name = item['name'] ?? 'Item';
            final cat = item['category'] ?? 'Others';
            final qty = item['quantity'] != null ? '${item['quantity']} ${item['unit'] ?? ''}'.trim() : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                  if (qty.isNotEmpty)
                    Text(
                      qty,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cat,
                      style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: message.isConfirmed ? null : () => _confirmRemoveInventory(message),
              icon: Icon(
                message.isConfirmed ? Icons.check_circle_rounded : Icons.delete_sweep_rounded,
                size: 18,
              ),
              label: Text(
                message.isConfirmed ? 'Removed from Fridge ✓' : 'Remove from Fridge',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: message.isConfirmed ? Colors.grey.shade400 : const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealLogActionCard(AiChatMessage message) {
    final meal = message.meal!;
    final name = meal['name'] as String? ?? 'Meal';
    final type = (meal['mealType'] as String? ?? 'lunch').toUpperCase();
    final nutrition = meal['nutrition'] as Map? ?? {};
    final cals = nutrition['calories'] ?? 0;
    final protein = nutrition['proteinG'] ?? 0;
    final carbs = nutrition['carbsG'] ?? 0;
    final fat = nutrition['fatG'] ?? 0;
    final isManual = nutrition['isManual'] == true;

    final List<dynamic> ingredients = (meal['ingredients'] is List) ? meal['ingredients'] as List : [];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE0B2), width: 1.2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: AppTypography.cardTitle.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!message.isConfirmed)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.tealPrimary),
                  tooltip: 'Edit Meal & Nutrition',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  onPressed: () => _showEditMealDialog(message),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isManual ? const Color(0xFFEFF6FF) : const Color(0xFFE8F6F0),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isManual ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isManual ? Icons.edit_note_rounded : Icons.auto_awesome,
                      size: 11,
                      color: isManual ? const Color(0xFF2563EB) : AppColors.tealPrimary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isManual ? 'Manual Entry' : 'AI Estimate',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isManual ? const Color(0xFF1D4ED8) : AppColors.tealPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.peachLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.peachPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildMacroMini('Calories', '$cals kcal', AppColors.tealPrimary)),
              Expanded(child: _buildMacroMini('Protein', '${protein}g', const Color(0xFF3B82F6))),
              Expanded(child: _buildMacroMini('Carbs', '${carbs}g', const Color(0xFFF59E0B))),
              Expanded(child: _buildMacroMini('Fat', '${fat}g', const Color(0xFFEC4899))),
            ],
          ),
          if (!isManual) ...[
            const SizedBox(height: 8),
            // Sizing uncertainty disclaimer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFD97706)),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Approximate nutrition • Actual values may vary',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Ingredients deduction section
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Ingredients & Fridge Deductions',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 2),
            const Text(
              'Select which ingredients came from your fridge inventory:',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final ing in ingredients) ...[
              if (ing is Map) ...[
                Builder(
                  builder: (context) {
                    final ingName = ing['name'] as String? ?? 'Ingredient';
                    final qtyStr = ing['quantity'] != null
                        ? '${ing['quantity']} ${ing['unit'] ?? ''}'.trim()
                        : '';
                    final matchedItem = FridgeCategoryRepository.findItemByName(ingName);
                    final isTracked = matchedItem != null;
                    final isSelected = message.selectedDeductionIngredients.contains(ingName);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isTracked
                            ? (isSelected ? const Color(0xFFF0FDF4) : Colors.white)
                            : const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isTracked
                              ? (isSelected ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0))
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isTracked) ...[
                            Checkbox(
                              value: isSelected,
                              onChanged: message.isConfirmed
                                  ? null
                                  : (_) => _toggleIngredientDeduction(message, ingName),
                              activeColor: AppColors.tealPrimary,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                          ] else ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.circle_outlined, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  qtyStr.isNotEmpty ? '$ingName ($qtyStr)' : ingName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                ),
                                if (isTracked)
                                  Text(
                                    'In fridge: ${matchedItem.quantity}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.tealPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                else
                                  const Text(
                                    'Pantry / External',
                                    style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          if (isTracked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isSelected ? 'Will deduct' : 'Keep',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? const Color(0xFF166534) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: message.isConfirmed ? null : () => _confirmLogMeal(message),
              icon: Icon(
                message.isConfirmed ? Icons.check_circle_rounded : Icons.restaurant_rounded,
                size: 18,
              ),
              label: Text(
                message.isConfirmed ? 'Logged to Today\'s Meals ✓' : 'Confirm & Log Meal',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: message.isConfirmed ? Colors.grey.shade400 : AppColors.peachPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroMini(String label, String value, Color color) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildClarificationCard(String question) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.help_outline_rounded, size: 15, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text(
                'Clarification Needed',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            question,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.tealPrimary),
              ),
              SizedBox(width: 10),
              Text(
                'NutriFridge AI is analyzing...',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(_selectedImageBase64!),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _selectedImageName ?? 'Attached image',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              setState(() {
                _selectedImageBase64 = null;
                _selectedImageMimeType = null;
                _selectedImageName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2EBE5), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Camera / Gallery Attachment Button
          PopupMenuButton<ImageSource>(
            icon: const Icon(Icons.camera_alt_outlined, color: AppColors.tealPrimary),
            tooltip: 'Attach Food Photo',
            onSelected: _pickImage,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ImageSource.camera,
                child: Row(
                  children: [
                    Icon(Icons.photo_camera_rounded, size: 20, color: AppColors.tealPrimary),
                    SizedBox(width: 10),
                    Text('Take Photo'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: ImageSource.gallery,
                child: Row(
                  children: [
                    Icon(Icons.photo_library_rounded, size: 20, color: AppColors.tealPrimary),
                    SizedBox(width: 10),
                    Text('Choose from Gallery'),
                  ],
                ),
              ),
            ],
          ),

          // Text Field
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _textController,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Ask anything, add food, or log meal...',
                  hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),

          // Send Button
          InkWell(
            onTap: _isSending ? null : () => _handleSend(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey.shade300 : AppColors.tealPrimary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
