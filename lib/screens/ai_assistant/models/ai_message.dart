import 'package:flutter/foundation.dart';

/// Represents a single message within the AI Assistant conversation
@immutable
class AiChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? action;
  final bool requiresConfirmation;
  final bool isConfirmed;
  final bool needsClarification;
  final String? clarifyingQuestion;
  final List<Map<String, dynamic>> inventoryItems;
  final Map<String, dynamic>? meal;
  final List<Map<String, dynamic>> suggestedDeductions;
  final String? attachedImageBase64;

  const AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.action,
    this.requiresConfirmation = false,
    this.isConfirmed = false,
    this.needsClarification = false,
    this.clarifyingQuestion,
    this.inventoryItems = const [],
    this.meal,
    this.suggestedDeductions = const [],
    this.attachedImageBase64,
  });

  AiChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? action,
    bool? requiresConfirmation,
    bool? isConfirmed,
    bool? needsClarification,
    String? clarifyingQuestion,
    List<Map<String, dynamic>>? inventoryItems,
    Map<String, dynamic>? meal,
    List<Map<String, dynamic>>? suggestedDeductions,
    String? attachedImageBase64,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      action: action ?? this.action,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      needsClarification: needsClarification ?? this.needsClarification,
      clarifyingQuestion: clarifyingQuestion ?? this.clarifyingQuestion,
      inventoryItems: inventoryItems ?? this.inventoryItems,
      meal: meal ?? this.meal,
      suggestedDeductions: suggestedDeductions ?? this.suggestedDeductions,
      attachedImageBase64: attachedImageBase64 ?? this.attachedImageBase64,
    );
  }
}
