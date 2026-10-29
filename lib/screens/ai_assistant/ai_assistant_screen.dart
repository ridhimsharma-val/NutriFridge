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
/// Supports natural-language inventory management, meal logging, and contextual Q&A.
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
  String? _selectedImageBase64;
  String? _selectedImageMimeType;
  String? _selectedImageName;

  static const List<String> _quickPrompts = [
    'Add 2 apples and 1 litre of milk to my fridge',
    'Remove milk and apples from my fridge',
    'I ate a paneer rice bowl for lunch',
    'What fruits do I have in my fridge?',
    'What can I cook using my available ingredients?',
  ];

  @override
  void initState() {
    super.initState();
    _seedInitialWelcome();
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

  void _seedInitialWelcome() {
    _messages.add(
      AiChatMessage(
        id: 'msg_welcome',
        text:
            'Hello! I am your NutriFridge AI assistant.\n\nYou can ask me to add groceries to your fridge, log what you ate, check your current perishables, or get cooking ideas.',
        isUser: false,
        timestamp: DateTime.now(),
        action: 'assistant_reply',
      ),
    );
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
      _textController.clear();
      _selectedImageBase64 = null;
      _selectedImageMimeType = null;
      _selectedImageName = null;
      _isSending = true;
    });

    _scrollToBottom();

    // Call live n8n backend
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
    final bool needsClarification = (response['needsClarification'] as bool?) ?? false;
    final String? clarifyingQuestion = response['clarifyingQuestion'] as String?;

    final List<Map<String, dynamic>> inventoryItems = [];
    if (response['inventoryItems'] is List) {
      for (final it in response['inventoryItems']) {
        if (it is Map) {
          inventoryItems.add(Map<String, dynamic>.from(it));
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
    );

    setState(() {
      _messages.add(assistantMessage);
      _isSending = false;
    });

    _scrollToBottom();
  }

  void _confirmAddInventory(AiChatMessage message) {
    if (message.inventoryItems.isEmpty) return;

    for (final itemJson in message.inventoryItems) {
      final name = itemJson['name'] as String? ?? 'Food Item';
      final category = itemJson['category'] as String? ?? 'Others';
      final quantity = itemJson['quantity'] != null
          ? '${itemJson['quantity']} ${itemJson['unit'] ?? ''}'.trim()
          : '1 item';
      final expiryDays = (itemJson['expiryDaysEstimate'] as num?)?.toInt() ?? 5;

      final newItem = CategoryFoodItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}_$name',
        name: name,
        quantity: quantity,
        expiryDays: expiryDays,
      );

      FridgeCategoryRepository.addItemToCategory(category, newItem);
    }

    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(isConfirmed: true);
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
                'Added ${message.inventoryItems.length} items to your fridge!',
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

    final calories = (nutrition['calories'] as num?)?.toInt() ?? 450;
    final protein = (nutrition['proteinG'] as num?)?.toInt() ?? 20;
    final carbs = (nutrition['carbsG'] as num?)?.toInt() ?? 50;
    final fat = (nutrition['fatG'] as num?)?.toInt() ?? 15;

    final List<String> ingredients = [];
    if (meal['ingredients'] is List) {
      for (final ing in meal['ingredients']) {
        if (ing is Map && ing['name'] != null) {
          ingredients.add(ing['name'] as String);
        }
      }
    }

    // Capitalize mealType
    final formattedType = mealType.isNotEmpty
        ? mealType[0].toUpperCase() + mealType.substring(1)
        : 'Lunch';

    MockDataRepository.logMeal(
      mealType: formattedType,
      mealName: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      ingredients: ingredients,
    );

    // Also deduct/remove matching ingredients from fridge inventory
    int deductedCount = 0;
    if (message.suggestedDeductions.isNotEmpty) {
      for (final deduction in message.suggestedDeductions) {
        final deductionName = deduction['name'] as String? ?? '';
        final deductionId = deduction['matchedInventoryItemId'] as String?;
        if (deductionId != null && deductionId.isNotEmpty) {
          FridgeCategoryRepository.removeItem('', deductionId);
          deductedCount++;
        } else if (deductionName.isNotEmpty) {
          if (FridgeCategoryRepository.removeItemByName(deductionName)) {
            deductedCount++;
          }
        }
      }
    } else {
      for (final ing in ingredients) {
        if (FridgeCategoryRepository.removeItemByName(ing)) {
          deductedCount++;
        }
      }
    }

    // Mark confirmed
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(isConfirmed: true);
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
            // Quick suggestions chips
            _buildQuickPromptsBar(),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2EBE5)),

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
                    child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'NutriFridge AI',
              style: AppTypography.cardTitle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
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
              _messages.clear();
              _seedInitialWelcome();
            });
          },
        ),
      ],
    );
  }

  Widget _buildQuickPromptsBar() {
    return Container(
      height: 48,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: _quickPrompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = _quickPrompts[index];
          return ActionChip(
            label: Text(
              prompt,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.tealPrimary),
            ),
            backgroundColor: AppColors.tealSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFC8E6C9), width: 1),
            ),
            onPressed: () => _handleSend(promptOverride: prompt),
          );
        },
      ),
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
              if (message.action == 'add_inventory_items' && message.inventoryItems.isNotEmpty) ...[
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryActionCard(AiChatMessage message) {
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
                  style: AppTypography.cardTitle.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
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
                      color: AppColors.tealPrimary,
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
                      color: AppColors.tealSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cat,
                      style: const TextStyle(fontSize: 10, color: AppColors.tealPrimary, fontWeight: FontWeight.w700),
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
              onPressed: message.isConfirmed ? null : () => _confirmAddInventory(message),
              icon: Icon(
                message.isConfirmed ? Icons.check_circle_rounded : Icons.add_rounded,
                size: 18,
              ),
              label: Text(
                message.isConfirmed ? 'Added to Fridge ✓' : 'Add to Fridge',
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
    final cals = nutrition['calories'] ?? 450;
    final protein = nutrition['proteinG'] ?? 20;
    final carbs = nutrition['carbsG'] ?? 50;
    final fat = nutrition['fatG'] ?? 15;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: AppTypography.cardTitle.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.peachLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  type,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.peachPrimary),
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
