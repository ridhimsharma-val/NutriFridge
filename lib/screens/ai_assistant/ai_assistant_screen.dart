import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/app_image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/nutrition_data.dart';
import '../../services/auth/auth_service.dart';
import '../../services/meals/models/meal_models.dart';
import '../fridge/models/category_item.dart';
import 'models/ai_message.dart';
import 'services/ai_assistant_service.dart';
import '../meal_detail/models/meal_ai_context.dart';
import '../../services/chillu/chillu_sound_controller.dart';
import '../../widgets/chillu/chillu_animation_controller.dart';
import '../../widgets/chillu/chillu_mascot.dart';

/// Full-featured, interactive AI Assistant screen for NutriFridge.
/// Acts as the single primary entry point for natural-language food addition,
/// meal logging with ingredient fridge deduction, and contextual nutrition Q&A.
class AiAssistantScreen extends StatefulWidget {
  final String? initialPrompt;
  final MealAiContext? mealContext;

  const AiAssistantScreen({
    super.key,
    this.initialPrompt,
    this.mealContext,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<AiChatMessage> _messages = [];
  bool _isSending = false;
  bool _isRecording = false;
  final FocusNode _inputFocusNode = FocusNode();
  bool _isConfirmingInventory = false;
  bool _isRemovingInventory = false;
  String? _selectedImageBase64;
  String? _selectedImageMimeType;
  String? _selectedImageName;
  String? _pendingQuickActionIntent;
  MealAiContext? _activeMealContext;
  bool _initialPromptDispatched = false;
  final ChilluAnimationController _chilluController = ChilluAnimationController();
  bool _showAudioDebugPanel = true;
  bool _audioDebugPanelCollapsed = false;

  @override
  void initState() {
    super.initState();
    // Load session messages to ensure conversation is preserved across navigations
    if (AiAssistantService.sessionMessages.isEmpty) {
      AiAssistantService.resetSession();
    }
    _pendingQuickActionIntent = AiAssistantService.activeQuickActionIntent;
    _messages.addAll(AiAssistantService.sessionMessages);

    _inputFocusNode.addListener(_onInputFocusOrTextChanged);
    _textController.addListener(_onInputFocusOrTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      _chilluController.greet();
      ChilluSoundController.instance.playEntryJump();
    });

    _activeMealContext = widget.mealContext ?? AiAssistantService.activeMealContext;
    if (widget.mealContext != null) {
      AiAssistantService.activeMealContext = widget.mealContext;
    }

    final promptToRun = widget.initialPrompt ??
        (_activeMealContext != null
            ? "I want to cook ${_activeMealContext!.mealTitle}. Please give me the complete recipe with ingredients from my fridge and step-by-step cooking instructions."
            : null);

    final isSameMealAlreadyInSession = _activeMealContext != null &&
        AiAssistantService.activeMealContextId == _activeMealContext!.mealId &&
        _messages.any((m) => m.isUser && m.text.contains(_activeMealContext!.mealTitle));

    if (promptToRun != null && promptToRun.isNotEmpty && !_initialPromptDispatched && !isSameMealAlreadyInSession) {
      _initialPromptDispatched = true;
      if (_activeMealContext != null) {
        AiAssistantService.activeMealContextId = _activeMealContext!.mealId;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSend(
          promptOverride: promptToRun,
          extraPayload: _activeMealContext != null
              ? {
                  'mealContext': _activeMealContext!.toJson(),
                  'actionHint': 'assistant',
                }
              : null,
        );
      });
    }
  }

  @override
  void dispose() {
    _inputFocusNode.removeListener(_onInputFocusOrTextChanged);
    _textController.removeListener(_onInputFocusOrTextChanged);
    _inputFocusNode.dispose();
    _chilluController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onInputFocusOrTextChanged() {
    if (_isSending || _isRecording) return;
    final hasNonWhitespace = _textController.text.trim().isNotEmpty;

    if (hasNonWhitespace) {
      // First non-whitespace character triggers Attentive; subsequent keystrokes maintain it without restarting
      if (_chilluController.state != ChilluState.attentive && _chilluController.state != ChilluState.thinking) {
        _chilluController.attentive();
        ChilluSoundController.instance.playAttentive();
      }
    } else {
      // When input message is cleared, return to Confused if latest response was an error, else return to Idle
      if (_chilluController.state == ChilluState.attentive) {
        final int lastAssistantIdx = _messages.lastIndexWhere((m) => !m.isUser);
        if (lastAssistantIdx != -1 && _messages[lastAssistantIdx].action == 'error') {
          _chilluController.confused(persistent: true);
        } else {
          _chilluController.idle();
        }
      }
    }
  }

  void _syncSession() {
    AiAssistantService.sessionMessages = List.from(_messages);
    AiAssistantService.activeQuickActionIntent = _pendingQuickActionIntent;
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

  void _handleVoiceInput() {
    if (_isSending) return;

    if (!_isRecording) {
      // Start actual voice recording session
      setState(() {
        _isRecording = true;
      });
      _chilluController.listening();
      ChilluSoundController.instance.playListening();
    } else {
      // End recording and transition to thinking as message processing begins
      setState(() {
        _isRecording = false;
      });
      _chilluController.think();

      final voicePrompt = _textController.text.trim().isNotEmpty
          ? _textController.text.trim()
          : "What can I cook with the ingredients in my fridge?";
      _textController.clear();
      _handleSend(promptOverride: voicePrompt);
    }
  }

  void _cancelVoiceRecording() {
    if (!_isRecording) return;
    setState(() {
      _isRecording = false;
    });
    if (_inputFocusNode.hasFocus || _textController.text.trim().isNotEmpty) {
      _chilluController.attentive();
    } else {
      _chilluController.idle();
    }
  }

  void _retryLastUserMessage() {
    if (_isSending) return;

    int lastUserIdx = -1;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        lastUserIdx = i;
        break;
      }
    }

    if (lastUserIdx == -1) return;

    final lastUserMsg = _messages[lastUserIdx];
    final text = lastUserMsg.text;
    final image = lastUserMsg.attachedImageBase64;

    // Remove any trailing assistant error message so user does not see duplicate error bubbles
    setState(() {
      if (_messages.isNotEmpty && !_messages.last.isUser) {
        _messages.removeLast();
      }
    });

    _handleSend(promptOverride: text, imageOverride: image, isRetry: true);
  }

  void _dismissErrorMessage(AiChatMessage message) {
    setState(() {
      _messages.remove(message);
    });
    _syncSession();

    final int lastAssistantIdx = _messages.lastIndexWhere((m) => !m.isUser);
    final bool latestIsStillError =
        lastAssistantIdx != -1 && _messages[lastAssistantIdx].action == 'error';

    if (!latestIsStillError && _chilluController.state == ChilluState.confused) {
      final returnState = (_inputFocusNode.hasFocus || _textController.text.trim().isNotEmpty)
          ? ChilluState.attentive
          : ChilluState.idle;
      if (returnState == ChilluState.attentive) {
        _chilluController.attentive();
      } else {
        _chilluController.idle();
      }
    }
  }

  Future<void> _handleSend({
    String? promptOverride,
    String? imageOverride,
    bool isRetry = false,
    Map<String, dynamic>? extraPayload,
  }) async {
    if (_isSending) return;

    final text = (promptOverride ?? _textController.text).trim();
    final imageToSend = imageOverride ?? _selectedImageBase64;
    final mimeToSend = _selectedImageMimeType;

    if (text.isEmpty && imageToSend == null) return;

    setState(() {
      _isSending = true;
      if (!isRetry) {
        final userMessage = AiChatMessage(
          id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
          attachedImageBase64: imageToSend,
        );
        _messages.add(userMessage);
        _textController.clear();
        _selectedImageBase64 = null;
        _selectedImageMimeType = null;
        _selectedImageName = null;
      }
      _syncSession();
    });

    _scrollToBottom();
    _chilluController.think();
    ChilluSoundController.instance.playThinking();

    final currentIntent = _pendingQuickActionIntent;

    // Resolve actionHint based on pending quick-action intent or active recipe context
    String resolvedActionHint = 'auto';
    if (extraPayload != null && extraPayload['actionHint'] is String) {
      resolvedActionHint = extraPayload['actionHint'] as String;
    } else if (currentIntent == 'log_meal') {
      resolvedActionHint = 'log_meal';
    } else if (currentIntent == 'add_groceries') {
      resolvedActionHint = 'add_food_multiple';
    } else if (currentIntent == 'recipe_ideas') {
      resolvedActionHint = 'meal_recommendation';
    } else if (_activeMealContext != null) {
      resolvedActionHint = 'assistant';
    }

    // Ensure cook_recipe is normalized to 'assistant' for n8n compatibility
    if (resolvedActionHint == 'cook_recipe' || resolvedActionHint == 'recipe_instructions') {
      resolvedActionHint = 'assistant';
    }

    final Map<String, dynamic> combinedPayload = {
      ...?extraPayload,
    };
    if (currentIntent != null) {
      combinedPayload['quickActionIntent'] = currentIntent;
    }
    if (_activeMealContext != null) {
      combinedPayload['mealContext'] = _activeMealContext!.toJson();
    }

    try {
      // Call live n8n backend or intelligent local processing
      final response = await AiAssistantService.sendRequest(
        message: text,
        imageBase64: imageToSend,
        mimeType: mimeToSend,
        actionHint: resolvedActionHint,
        history: _messages,
        extraPayload: combinedPayload.isNotEmpty ? combinedPayload : null,
      );

      if (!mounted) return;

      String assistantText =
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

      // If Gemini proposes removals with missing quantity or over-removal, ask for clarification
      if ((action == 'remove_inventory_items' || action == 'remove_inventory_item') && inventoryItems.isNotEmpty) {
        for (final it in inventoryItems) {
          final rawQty = it['quantity'];
          final itemName = (it['name'] as String?) ?? 'food item';

          // Check if removal quantity is unspecified or ambiguous (TEST 11)
          if (it['isFullRemoval'] != true &&
              (rawQty == null || (rawQty is num && rawQty <= 0) || (rawQty is String && rawQty.trim().isEmpty))) {
            needsClarification = true;
            clarifyingQuestion =
                'Would you like to remove all $itemName or a specific amount? Please specify the quantity and unit.';
            inventoryItems.clear();
            break;
          }

          // Check if removal exceeds available stock (TEST 3: Over-removal)
          final invItem = FridgeCategoryRepository.findItemByName(itemName);
          if (invItem != null && rawQty != null && it['isFullRemoval'] != true) {
            final qty = _parseQuantity(rawQty);
            final unit = _parseUnit(it['unit']);
            final check = FridgeCategoryRepository.checkDeduction(item: invItem, quantity: qty, unit: unit);
            if (check.status == DeductionStatus.overRemoval) {
              needsClarification = true;
              clarifyingQuestion =
                  'You only have ${invItem.quantity} in your fridge. Please adjust the quantity.';
              inventoryItems.clear();
              break;
            }
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

      // If the user requested recipe instructions / cooking flow, ensure the response contains complete steps
      if (_activeMealContext != null && _isFullRecipeRequest(text)) {
        final hasSteps = assistantText.contains('1.') ||
            assistantText.contains('Step 1') ||
            (assistantText.contains('Preparation') && assistantText.length > 250);

        if (!hasSteps) {
          String recipeMarkdown = _activeMealContext!.formattedRecipeMarkdown;

          // If the meal context didn't have steps, but Gemini returned structured meal steps:
          if ((_activeMealContext!.preparationSteps.isEmpty && _activeMealContext!.detailedSteps.isEmpty) &&
              meal != null &&
              meal['preparationSteps'] is List &&
              (meal['preparationSteps'] as List).isNotEmpty) {
            recipeMarkdown = MealAiContext.buildRecipeMarkdownFromMealMap(
              mealMap: meal,
              fallbackContext: _activeMealContext,
            );
          }

          final intro = assistantText.trim().isNotEmpty
              ? assistantText.trim()
              : 'Here is the complete recipe for ${_activeMealContext!.mealTitle} using ingredients from your fridge:';
          assistantText = '$intro\n\n$recipeMarkdown';
        }
      } else if (meal != null &&
          meal['preparationSteps'] is List &&
          (meal['preparationSteps'] as List).isNotEmpty &&
          _isFullRecipeRequest(text)) {
        final hasSteps = assistantText.contains('1.') ||
            assistantText.contains('Step 1') ||
            (assistantText.contains('Preparation') && assistantText.length > 250);

        if (!hasSteps) {
          final recipeMarkdown = MealAiContext.buildRecipeMarkdownFromMealMap(
            mealMap: meal,
          );
          final intro = assistantText.trim().isNotEmpty
              ? assistantText.trim()
              : 'Here is the complete recipe using ingredients from your fridge:';
          assistantText = '$intro\n\n$recipeMarkdown';
        }
      }

      final bool isAiError = _isAiResponseError(
        action: action,
        response: response,
        assistantText: assistantText,
      );

      final String effectiveAction = isAiError ? 'error' : action;

      final assistantMessage = AiChatMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        text: assistantText,
        isUser: false,
        timestamp: DateTime.now(),
        action: effectiveAction,
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
      });

      final returnState = (_inputFocusNode.hasFocus || _textController.text.trim().isNotEmpty)
          ? ChilluState.attentive
          : ChilluState.idle;

      if (isAiError) {
        // Trigger persistent Confused state when AI response fails
        _chilluController.confused(persistent: true);
        ChilluSoundController.instance.playConfused();
      } else if (meal != null ||
          action == 'meal_recommendation' ||
          action == 'recipe_ideas' ||
          (_activeMealContext != null && _isFullRecipeRequest(text)) ||
          assistantText.contains('Preparation') ||
          assistantText.contains('Step 1')) {
        _chilluController.excited(returnState: returnState);
        ChilluSoundController.instance.playExcited();
      } else {
        _chilluController.happy(returnState: returnState);
        ChilluSoundController.instance.playHappy();
      }
    } catch (e) {
      debugPrint('[AiAssistantScreen] Error processing send request: $e');
      _chilluController.confused(persistent: true);
      ChilluSoundController.instance.playConfused();
      if (mounted) {
        setState(() {
          _messages.add(AiChatMessage(
            id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
            text: 'Unable to reach NutriFridge AI. Please check your internet connection and tap retry.',
            isUser: false,
            timestamp: DateTime.now(),
            action: 'error',
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        _syncSession();
        _scrollToBottom();
      }
    }
  }

  /// Determines whether an AI response indicates a failure/error.
  bool _isAiResponseError({
    required String action,
    required Map<String, dynamic> response,
    required String assistantText,
  }) {
    if (action == 'error') return true;
    if (response['ok'] == false || response['success'] == false) return true;
    if (response['error'] != null && response['error'].toString().trim().isNotEmpty) return true;

    final lower = assistantText.toLowerCase().trim();
    if (lower.isEmpty) return true;

    if (lower.contains('no response from ai')) return true;
    if (lower.contains('timed out') || lower.contains('time out')) return true;
    if (lower.contains('failed to receive an ai response') || lower.contains('failed to get a response')) return true;
    if (lower.contains('service temporarily unavailable') || lower.contains('ai service unavailable') || lower.contains('service unavailable')) return true;
    if (lower.contains('response generation failed') || lower.contains('generation failed')) return true;
    if (lower.contains('unable to reach nutrifridge ai') || lower.contains('unable to reach ai')) return true;
    if (lower.contains('received an empty response')) return true;
    if (lower.contains('could not verify your session') || lower.contains('user not authenticated')) return true;

    return false;
  }

  bool _isFullRecipeRequest(String prompt) {
    final lower = prompt.toLowerCase();
    // Specific follow-up questions about ingredients or timings should NOT re-trigger full recipe
    final isSpecificQuestion = lower.startsWith('can i') ||
        lower.startsWith('could i') ||
        lower.startsWith('should i') ||
        lower.startsWith('what if') ||
        lower.startsWith('how long') ||
        lower.startsWith('what temperature') ||
        lower.startsWith('is it okay');

    if (isSpecificQuestion) return false;

    return lower.contains('complete recipe') ||
        lower.contains('give me the recipe') ||
        lower.contains('show me the recipe') ||
        lower.contains('full recipe') ||
        lower.contains('step-by-step') ||
        lower.contains('step by step') ||
        lower.contains('show steps') ||
        lower.contains('all steps') ||
        lower.contains('instructions') ||
        lower.contains('i want to cook') ||
        lower.contains('how to cook') ||
        lower.contains('how do i make');
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
                          borderSide: const BorderSide(color: AppColors.forestGreen, width: 1.5),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Optional manual nutrition entry expandable trigger
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
                            const Icon(Icons.tune_rounded, size: 18, color: AppColors.forestGreen),
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
                          backgroundColor: AppColors.forestGreen,
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

      _chilluController.itemAdded();
      ChilluSoundController.instance.playCelebrating();

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
          backgroundColor: AppColors.forestGreen,
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
          if (_pendingQuickActionIntent == 'add_groceries') {
            _pendingQuickActionIntent = null;
          }
        });
        _syncSession();
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
    if (message.inventoryItems.isEmpty || _isRemovingInventory || message.isConfirmed) return;

    // First validate for any over-removal
    for (final itemJson in message.inventoryItems) {
      if (itemJson['isFullRemoval'] == true) continue;
      final rawQty = itemJson['quantity'];
      if (rawQty != null) {
        final name = (itemJson['name'] as String?) ?? '';
        final invItem = FridgeCategoryRepository.findItemByName(name);
        if (invItem != null) {
          final qty = _parseQuantity(rawQty);
          final unit = _parseUnit(itemJson['unit']);
          final check = FridgeCategoryRepository.checkDeduction(item: invItem, quantity: qty, unit: unit);
          if (check.status == DeductionStatus.overRemoval) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(check.message),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            return;
          }
        }
      }
    }

    setState(() {
      _isRemovingInventory = true;
    });

    int removedCount = 0;
    int deductedCount = 0;
    final List<String> deductionMessages = [];

    for (final itemJson in message.inventoryItems) {
      final name = itemJson['name'] as String? ?? '';
      final category = itemJson['category'] as String?;
      final id = itemJson['id'] as String? ?? itemJson['matchedInventoryItemId'] as String?;
      final isFullRemoval = itemJson['isFullRemoval'] == true;
      final rawQty = itemJson['quantity'];

      if (isFullRemoval || rawQty == null) {
        // Full removal
        if (id != null && id.isNotEmpty) {
          FridgeCategoryRepository.removeItem(category ?? '', id);
          removedCount++;
        } else if (name.isNotEmpty) {
          if (FridgeCategoryRepository.removeItemByName(name)) {
            removedCount++;
          }
        }
      } else {
        // Partial deduction
        final qty = _parseQuantity(rawQty);
        final unit = _parseUnit(itemJson['unit']);
        final result = FridgeCategoryRepository.deductItemQuantity(
          itemId: id,
          categoryIdOrName: category,
          name: name.isNotEmpty ? name : null,
          quantity: qty,
          unit: unit,
        );

        if (result.isSuccess) {
          if (result.status == DeductionStatus.removed) {
            removedCount++;
          } else {
            deductedCount++;
          }
          deductionMessages.add(result.message);
        }
      }
    }

    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(isConfirmed: true);
        _isRemovingInventory = false;
        _syncSession();
      });
    } else {
      setState(() {
        _isRemovingInventory = false;
      });
    }

    String snackText;
    if (deductedCount > 0 && removedCount == 0) {
      snackText = deductionMessages.length == 1
          ? deductionMessages.first
          : 'Updated $deductedCount items in your fridge inventory!';
    } else if (removedCount > 0 && deductedCount == 0) {
      snackText = 'Removed $removedCount items from your fridge inventory!';
    } else if (deductedCount > 0 && removedCount > 0) {
      snackText = 'Updated $deductedCount and removed $removedCount items from your fridge!';
    } else {
      snackText = 'Removed requested items from your fridge.';
    }

    if (removedCount > 0 || deductedCount > 0) {
      _chilluController.itemAdded();
      ChilluSoundController.instance.playCelebrating();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                snackText,
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

  void _confirmLogMeal(AiChatMessage message) async {
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
    final List<MealIngredientDeduction> deductions = [];
    final selectedIngNames = message.selectedDeductionIngredients;

    if (meal['ingredients'] is List) {
      for (final ing in meal['ingredients']) {
        if (ing is Map && ing['name'] != null) {
          final ingName = (ing['name'] as String).trim();
          final rawQty = ing['quantity'] ?? ing['amount'];
          num? qty;
          if (rawQty != null) {
            qty = _parseQuantity(rawQty);
          }
          final rawUnitStr = ing['unit']?.toString().trim();
          final String? unit = (rawUnitStr != null && rawUnitStr.isNotEmpty) ? rawUnitStr : null;

          final formattedIng = (qty != null && unit != null)
              ? '$ingName ($qty $unit)'
              : (qty != null ? '$ingName ($qty)' : ingName);
          ingredients.add(formattedIng);

          final isSelected = selectedIngNames.contains(ingName);
          final matched = FridgeCategoryRepository.findItemByName(ingName);
          final isRealUuid = matched != null &&
              matched.id.isNotEmpty &&
              !matched.id.startsWith('item_') &&
              !matched.id.startsWith('food_') &&
              !matched.id.startsWith('dairy_');

          final effectiveUnit = unit ?? matched?.unit ?? 'pieces';
          final bool unitsCompatible = matched != null &&
              FridgeCategoryRepository.areUnitsCompatible(matched.unit, effectiveUnit);

          final doDeduct = isSelected && isRealUuid && qty != null && qty > 0 && unitsCompatible;

          deductions.add(MealIngredientDeduction(
            name: ingName,
            requiredQuantity: qty,
            requiredUnit: effectiveUnit,
            matchedFridgeItemId: doDeduct ? matched.id : null,
            deductQuantity: doDeduct ? qty : null,
            deductUnit: doDeduct ? effectiveUnit : null,
            doDeduct: doDeduct,
          ));
        }
      }
    }

    final formattedType = mealType.isNotEmpty
        ? mealType[0].toUpperCase() + mealType.substring(1)
        : 'Lunch';

    int deductedCount = 0;
    try {
      final result = await MockDataRepository.logMeal(
        mealType: formattedType,
        mealName: name,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        ingredients: ingredients,
        ingredientDeductions: deductions,
      );

      if (result != null) {
        deductedCount = result.deductionsApplied;
      }
    } catch (e) {
      debugPrint('[AiAssistantScreen] Meal logging error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log meal: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    // In offline / unauthenticated test mode, execute in-memory inventory deduction
    if (!AuthService.instance.isAuthenticated || AuthService.instance.currentUser == null) {
      final selectedIngNames = message.selectedDeductionIngredients;

      for (final ingName in selectedIngNames) {
        // Find ingredient details from meal['ingredients']
        Map<String, dynamic>? matchedIng;
        if (meal['ingredients'] is List) {
          for (final ing in meal['ingredients']) {
            if (ing is Map && (ing['name'] as String?)?.toLowerCase().trim() == ingName.toLowerCase().trim()) {
              matchedIng = Map<String, dynamic>.from(ing);
              break;
            }
          }
        }

        num? qty;
        String? unit;
        if (matchedIng != null) {
          final rawQty = matchedIng['quantity'] ?? matchedIng['amount'];
          if (rawQty != null) {
            qty = _parseQuantity(rawQty);
          }
          unit = _parseUnit(matchedIng['unit']);
        }

        if (qty != null && qty > 0) {
          final result = FridgeCategoryRepository.deductItemQuantityByName(
            name: ingName,
            quantity: qty,
            unit: unit,
          );
          if (result.isSuccess) {
            deductedCount++;
          }
        } else {
          if (FridgeCategoryRepository.removeItemByName(ingName)) {
            deductedCount++;
          }
        }
      }
    }

    // Mark confirmed
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1 && mounted) {
      setState(() {
        _messages[index] = _messages[index].copyWith(isConfirmed: true);
        if (_pendingQuickActionIntent == 'log_meal') {
          _pendingQuickActionIntent = null;
        }
        _syncSession();
      });
    }

    _chilluController.mealLogged();
    ChilluSoundController.instance.playCelebrating();

    if (mounted) {
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
          backgroundColor: AppColors.forestGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        ChilluSoundController.instance.unlockAudioContext();
      },
      child: Scaffold(
        backgroundColor: AppColors.warmCream,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              if (_showAudioDebugPanel) _buildDebugSoundPanel(),

              // Contextual meal indicator when opened from Meal Detail or active in session
            if (_activeMealContext != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.paleMint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFC8E6C9), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant_menu_rounded, size: 16, color: AppColors.primaryForest),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Discussing: ${_activeMealContext!.mealTitle}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryForest,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Recipe context active · ${_activeMealContext!.servingSize}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.freshGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Active Quick Action Context Banner (when quick-action clarification flow is active)
            if (_pendingQuickActionIntent != null && _activeMealContext == null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.paleMint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.freshGreen.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.forum_outlined, size: 14, color: AppColors.primaryForest),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getIntentBannerText(_pendingQuickActionIntent!),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryForest,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _pendingQuickActionIntent = null;
                          _syncSession();
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(Icons.close_rounded, size: 14, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

            // Messages timeline
            Expanded(
              child: Builder(
                builder: (context) {
                  final int lastAssistantIdx = _messages.lastIndexWhere((m) => !m.isUser);
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_isSending ? 1 : 0) + (_showWelcomeHero ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_showWelcomeHero) {
                        if (index == 0) {
                          return _buildWelcomeHero();
                        }
                        final msgIdx = index - 1;
                        if (msgIdx < _messages.length) {
                          final isLatestAssistant = msgIdx == lastAssistantIdx;
                          return _buildMessageItem(_messages[msgIdx], isLatestAssistant: isLatestAssistant);
                        } else {
                          return _buildTypingIndicator();
                        }
                      } else {
                        if (index < _messages.length) {
                          final isLatestAssistant = index == lastAssistantIdx;
                          return _buildMessageItem(_messages[index], isLatestAssistant: isLatestAssistant);
                        } else {
                          return _buildTypingIndicator();
                        }
                      }
                    },
                  );
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
    ),
  );
}

  bool get _showWelcomeHero => _messages.length <= 1 && _pendingQuickActionIntent == null;

  String _getIntentBannerText(String intent) {
    switch (intent) {
      case 'log_meal':
        return 'Context: Meal Logging';
      case 'add_groceries':
        return 'Context: Adding Groceries';
      case 'recipe_ideas':
        return 'Context: Recipe Ideas';
      default:
        return 'Context: Active Flow';
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.warmCream,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.neutralCharcoal),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: const Center(
              child: ChilluMascot(
                size: 32,
                showShadow: false,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chillu · AI Assistant',
              style: AppTypography.cardTitle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.neutralCharcoal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showAudioDebugPanel ? Icons.tune_rounded : Icons.tune_outlined,
            color: _showAudioDebugPanel ? AppColors.forestGreen : AppColors.textSecondary,
            size: 22,
          ),
          tooltip: _showAudioDebugPanel ? 'Hide Sound Panel' : 'Show Sound Panel',
          onPressed: () {
            setState(() {
              _showAudioDebugPanel = !_showAudioDebugPanel;
            });
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: ChilluSoundController.instance.soundEnabledNotifier,
          builder: (context, soundEnabled, _) {
            return IconButton(
              icon: Icon(
                soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: soundEnabled ? AppColors.forestGreen : AppColors.textSecondary,
                size: 22,
              ),
              tooltip: soundEnabled ? 'Mute Sound Effects' : 'Enable Sound Effects',
              onPressed: () => ChilluSoundController.instance.toggleSound(),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 22),
          tooltip: 'Reset Conversation',
          onPressed: () {
            setState(() {
              _pendingQuickActionIntent = null;
              AiAssistantService.resetSession();
              _messages.clear();
              _messages.addAll(AiAssistantService.sessionMessages);
            });
            _chilluController.greet();
            ChilluSoundController.instance.playEntryJump();
          },
        ),
      ],
    );
  }

  Widget _buildWelcomeHero() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        children: [
          ChilluMascot(
            controller: _chilluController,
            size: 110,
            onTap: () {
              _chilluController.greet();
              ChilluSoundController.instance.playHappy();
            },
          ),
          const SizedBox(height: 10),
          const Text(
            'Hi there! I am Chillu',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryForest,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "What's on your plate today?",
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.neutralCharcoal,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionPill('Log my meal'),
              _buildSuggestionPill('Add groceries'),
              _buildSuggestionPill('Recipe ideas'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionPill(String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleQuickActionTap(label),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.forestGreen,
            ),
          ),
        ),
      ),
    );
  }

  void _handleQuickActionTap(String actionLabel) {
    String clarifyingQuestion;
    String intent;
    switch (actionLabel) {
      case 'Log my meal':
        intent = 'log_meal';
        clarifyingQuestion =
            "What did you eat today? Tell me the meal name or upload a photo, and I'll help you log it with its nutritional information.";
        break;
      case 'Add groceries':
        intent = 'add_groceries';
        clarifyingQuestion =
            "What groceries would you like to add to your fridge? Tell me the items and quantities, or upload a grocery photo or receipt.";
        break;
      case 'Recipe ideas':
        intent = 'recipe_ideas';
        clarifyingQuestion =
            "What would you like to cook? Tell me the ingredients you want to use, or I can suggest recipes based on what's currently in your fridge.";
        break;
      default:
        intent = 'general';
        clarifyingQuestion = 'How can I help you today?';
    }

    final userMessage = AiChatMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      text: actionLabel,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final assistantMessage = AiChatMessage(
      id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch + 1}',
      text: clarifyingQuestion,
      isUser: false,
      timestamp: DateTime.now(),
      action: 'assistant_reply',
    );

    setState(() {
      _pendingQuickActionIntent = intent;
      _messages.add(userMessage);
      _messages.add(assistantMessage);
      _syncSession();
    });

    _chilluController.think();
    ChilluSoundController.instance.playThinking();
    _scrollToBottom();
  }

  Widget _buildMessageItem(AiChatMessage message, {bool isLatestAssistant = false}) {
    if (message.isUser) {
      return _buildUserBubble(message);
    } else {
      return _buildAssistantBubble(message, isLatest: isLatestAssistant);
    }
  }

  Widget _buildUserBubble(AiChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: const BoxDecoration(
            color: AppColors.forestGreen,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x18143D30),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.attachedImageBase64 != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.memory(
                      base64Decode(message.attachedImageBase64!),
                      width: 170,
                      height: 125,
                      fit: BoxFit.cover,
                    ),
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

  Widget _buildAssistantBubble(AiChatMessage message, {bool isLatest = false}) {
    final bool isMealMessage = message.meal != null || message.action == 'log_meal';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ChilluMascot(
              controller: isLatest ? _chilluController : null,
              disableAnimations: !isLatest,
              size: 46,
              showShadow: false,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
              decoration: BoxDecoration(
                color: isMealMessage ? const Color(0xFFFFFDF9) : AppColors.cardWhite,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: isMealMessage ? AppColors.peachBorder : const Color(0xFFE5ECE7),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
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
                      color: AppColors.neutralCharcoal,
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

              // Embedded Error Retry & Dismiss Actions
              if (message.action == 'error') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isSending ? null : _retryLastUserMessage,
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
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _isSending ? null : () => _dismissErrorMessage(message),
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.neutralMedium),
                      label: const Text(
                        'Dismiss',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.neutralMedium),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF9FAFB),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildInventoryActionCard(AiChatMessage message) {
    final hasItems = message.inventoryItems.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3E7D8), width: 1.2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                    color: const Color(0xFFE8F5EC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Review & Confirm',
                    style: TextStyle(fontSize: 10, color: AppColors.forestGreen, fontWeight: FontWeight.w700),
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
                      border: Border.all(color: const Color(0xFFE2EBE5), width: 0.8),
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
                                color: AppColors.forestGreen,
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
                                color: const Color(0xFFEAF5EE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Expires in $exp d',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF1B6A45), fontWeight: FontWeight.w600),
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
                                    color: AppColors.forestGreen,
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
                backgroundColor: message.isConfirmed ? const Color(0xFFCBD5E1) : AppColors.forestGreen,
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
              onPressed: (message.isConfirmed || _isRemovingInventory)
                  ? null
                  : () => _confirmRemoveInventory(message),
              icon: Icon(
                message.isConfirmed ? Icons.check_circle_rounded : Icons.delete_sweep_rounded,
                size: 18,
              ),
              label: Text(
                message.isConfirmed
                    ? 'Removed from Fridge ✓'
                    : (_isRemovingInventory ? 'Updating...' : 'Remove from Fridge'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: message.isConfirmed ? const Color(0xFFCBD5E1) : const Color(0xFFDC2626),
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
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.peachBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
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
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.forestGreen),
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
              if (isManual) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFBFDBFE),
                      width: 0.8,
                    ),
                  ),
                  child: const Text(
                    'Manual Entry',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
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
              Expanded(child: _buildMacroMini('Calories', '$cals kcal', AppColors.forestGreen)),
              Expanded(child: _buildMacroMini('Protein', '${protein}g', AppColors.sageAccent)),
              Expanded(child: _buildMacroMini('Carbs', '${carbs}g', AppColors.coralHighlight)),
              Expanded(child: _buildMacroMini('Fat', '${fat}g', AppColors.amberPrimary)),
            ],
          ),
          // Ingredients deduction section
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Ingredients & Fridge Deductions',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.neutralCharcoal),
            ),
            const SizedBox(height: 2),
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
                              activeColor: AppColors.forestGreen,
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
                                      color: AppColors.forestGreen,
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
                backgroundColor: message.isConfirmed ? const Color(0xFFCBD5E1) : AppColors.forestGreen,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEDE8E0), width: 0.8),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: color)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildClarificationCard(String question) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.peachLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.peachBorder, width: 1.0),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.help_outline_rounded, size: 15, color: AppColors.peachText),
              SizedBox(width: 6),
              Text(
                'Clarification Needed',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.peachText),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ChilluMascot(
              controller: _chilluController,
              size: 46,
              showShadow: false,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: const Color(0xFFE5ECE7),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Chillu is thinking...',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(
          top: BorderSide(color: Color(0xFFE8E5DF), width: 1),
          bottom: BorderSide(color: Color(0xFFE8E5DF), width: 0.8),
        ),
      ),
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
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.neutralCharcoal),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
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
        color: AppColors.cardWhite,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
        border: Border(top: BorderSide(color: Color(0xFFE8E5DF), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Camera / Gallery Attachment Button
            PopupMenuButton<ImageSource>(
              icon: const Icon(Icons.camera_alt_outlined, color: AppColors.forestGreen),
              tooltip: 'Attach Food Photo',
              onSelected: _pickImage,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: ImageSource.camera,
                  child: Row(
                    children: [
                      Icon(Icons.photo_camera_rounded, size: 20, color: AppColors.forestGreen),
                      SizedBox(width: 10),
                      Text('Take Photo'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: ImageSource.gallery,
                  child: Row(
                    children: [
                      Icon(Icons.photo_library_rounded, size: 20, color: AppColors.forestGreen),
                      SizedBox(width: 10),
                      Text('Choose from Gallery'),
                    ],
                  ),
                ),
              ],
            ),

            // Microphone Button (Voice Input)
            IconButton(
              icon: Icon(
                _isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                color: _isRecording ? AppColors.error : AppColors.forestGreen,
              ),
              tooltip: _isRecording ? 'Stop Recording & Send' : 'Voice Input',
              onPressed: _handleVoiceInput,
            ),

            if (_isRecording)
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                tooltip: 'Cancel Voice Recording',
                onPressed: _cancelVoiceRecording,
              ),

            // Text Field
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F1EA),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _isRecording ? AppColors.forestGreen : const Color(0xFFE8E5DF),
                    width: _isRecording ? 1.5 : 1,
                  ),
                ),
                child: TextField(
                  focusNode: _inputFocusNode,
                  controller: _textController,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14, color: AppColors.neutralCharcoal),
                  decoration: InputDecoration(
                    hintText: _isRecording
                        ? 'Listening to your voice... Tap mic to send'
                        : 'Ask anything, add food, or log meal...',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: _isRecording ? AppColors.forestGreen : const Color(0xFF9CA3AF),
                      fontWeight: _isRecording ? FontWeight.w600 : FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                  color: _isSending ? const Color(0xFFCBD5E1) : AppColors.forestGreen,
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
      ),
    );
  }

  /// Temporary debug sound test panel providing live diagnostics and 8 manual sound triggers.
  Widget _buildDebugSoundPanel() {
    return ValueListenableBuilder<ChilluAudioDiagnostics>(
      valueListenable: ChilluSoundController.instance.diagnosticsNotifier,
      builder: (context, diag, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: diag.lastError != null ? Colors.red.shade300 : AppColors.freshGreen.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header bar
              InkWell(
                onTap: () {
                  setState(() {
                    _audioDebugPanelCollapsed = !_audioDebugPanelCollapsed;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.audiotrack_rounded,
                        size: 20,
                        color: diag.isSoundEnabled ? AppColors.primaryForest : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Chillu Sound Test Panel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryForest,
                        ),
                      ),
                      const Spacer(),
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: diag.isAudioUnlocked ? AppColors.paleMint : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: diag.isAudioUnlocked ? AppColors.freshGreen : Colors.amber.shade400,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: diag.isAudioUnlocked ? AppColors.freshGreen : Colors.amber.shade700,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              diag.isAudioUnlocked ? 'Audio Unlocked' : 'Awaiting Tap',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: diag.isAudioUnlocked ? AppColors.primaryForest : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _audioDebugPanelCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                        size: 20,
                        color: AppColors.mutedText,
                      ),
                    ],
                  ),
                ),
              ),

              if (!_audioDebugPanelCollapsed) ...[
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Diagnostics readout row
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _buildDiagBadge('Assets', '${diag.loadedAssetsCount}/${diag.totalAssetsCount} cached', Icons.folder_zip_rounded),
                                const SizedBox(width: 6),
                                _buildDiagBadge('Player', diag.isPlayerInitialized ? 'Ready' : 'Init...', Icons.play_circle_outline_rounded),
                                const SizedBox(width: 6),
                                _buildDiagBadge('Mute', diag.isSoundEnabled ? 'ON' : 'OFF', Icons.volume_up_rounded),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Text(
                                  'Status: ',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                ),
                                Expanded(
                                  child: Text(
                                    diag.playbackStatus,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: diag.playbackStatus.startsWith('Error')
                                          ? Colors.red
                                          : (diag.playbackStatus.startsWith('Playing') ? AppColors.freshGreen : const Color(0xFF334155)),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (diag.lastError != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Error: ${diag.lastError}',
                                style: const TextStyle(fontSize: 10.5, color: Colors.red, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 8 Test Buttons Grid / Wrap
                      const Text(
                        'Trigger Sound & Animation Reaction:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildSoundTestButton(
                            label: '1. Entry Jump',
                            asset: ChilluSoundController.entryJumpAsset,
                            onTrigger: () {
                              ChilluSoundController.instance.testPlay(ChilluSoundController.entryJumpAsset);
                              _chilluController.greet();
                            },
                          ),
                          _buildSoundTestButton(
                            label: '2. Attentive',
                            asset: ChilluSoundController.attentiveAsset,
                            onTrigger: () {
                              ChilluSoundController.instance.testPlay(ChilluSoundController.attentiveAsset);
                              _chilluController.attentive();
                            },
                          ),
                          _buildSoundTestButton(
                            label: '3. Listening',
                            asset: ChilluSoundController.listeningAsset,
                            onTrigger: () {
                              ChilluSoundController.instance.testPlay(ChilluSoundController.listeningAsset);
                              _chilluController.listening();
                            },
                          ),
                          _buildSoundTestButton(
                            label: '4. Thinking',
                            asset: ChilluSoundController.thinkingAsset,
                            onTrigger: () {
                              ChilluSoundController.instance.testPlay(ChilluSoundController.thinkingAsset);
                              _chilluController.think();
                            },
                          ),
                          _buildSoundTestButton(
                            label: '5. Happy',
                            asset: ChilluSoundController.happyAsset,
                            onTrigger: () {
                              ChilluSoundController.instance.testPlay(ChilluSoundController.happyAsset);
                              _chilluController.happy();
                            },
                          ),
                          _buildSoundTestButton(
                            label: '6. Excited',
                            asset: ChilluSoundController.excitedAsset,
                            onTrigger: () {
                              ChilluSoundController.instance.testPlay(ChilluSoundController.excitedAsset);
                              _chilluController.excited();
                            },
                          ),
                          _buildSoundTestButton(
                            label: '7. Celebrating',
                            asset: ChilluSoundController.celebratingAsset,
                            onTrigger: () {
                              ChilluSoundController.instance.testPlay(ChilluSoundController.celebratingAsset);
                              _chilluController.itemAdded();
                            },
                          ),
                          _buildSoundTestButton(
                            label: '8. Confused',
                            asset: ChilluSoundController.confusedAsset,
                            onTrigger: () {
                              ChilluSoundController.instance.testPlay(ChilluSoundController.confusedAsset);
                              _chilluController.confused();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Auxiliary buttons row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            icon: const Icon(Icons.touch_app_rounded, size: 14),
                            label: const Text('Unlock Audio', style: TextStyle(fontSize: 11)),
                            onPressed: () => ChilluSoundController.instance.unlockAudioContext(),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            icon: const Icon(Icons.restart_alt_rounded, size: 14),
                            label: const Text('Reset Session', style: TextStyle(fontSize: 11)),
                            onPressed: () => ChilluSoundController.instance.resetSession(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiagBadge(String title, String val, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.mutedText),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                '$title: $val',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundTestButton({
    required String label,
    required String asset,
    required VoidCallback onTrigger,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.white,
      ),
      onPressed: onTrigger,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, size: 15, color: AppColors.freshGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }
}