import 'package:flutter/foundation.dart';

/// Type of food entity being resolved
enum FoodEntityType {
  ingredient,
  recipe;

  String toDbString() => name;

  static FoodEntityType fromString(String val) {
    if (val.toLowerCase() == 'recipe') return FoodEntityType.recipe;
    return FoodEntityType.ingredient;
  }
}

/// A search candidate returned by an image provider (e.g., Pexels)
@immutable
class FoodImageCandidate {
  final String photoId;
  final String imageUrl;
  final String thumbnailUrl;
  final String photographerName;
  final String photographerUrl;
  final String sourcePageUrl;
  final String altDescription;
  final String provider;
  final int score;

  const FoodImageCandidate({
    required this.photoId,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.photographerName,
    required this.photographerUrl,
    required this.sourcePageUrl,
    required this.altDescription,
    this.provider = 'pexels',
    this.score = 0,
  });

  factory FoodImageCandidate.fromJson(Map<String, dynamic> json) {
    return FoodImageCandidate(
      photoId: (json['photoId'] ?? json['id'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      thumbnailUrl: (json['thumbnailUrl'] ?? json['imageUrl'] ?? '').toString(),
      photographerName: (json['photographerName'] ?? json['photographer'] ?? 'Pexels Photographer').toString(),
      photographerUrl: (json['photographerUrl'] ?? json['photographer_url'] ?? 'https://www.pexels.com').toString(),
      sourcePageUrl: (json['sourcePageUrl'] ?? json['url'] ?? 'https://www.pexels.com').toString(),
      altDescription: (json['altDescription'] ?? json['alt'] ?? '').toString(),
      provider: (json['provider'] ?? 'pexels').toString(),
      score: (json['score'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'photoId': photoId,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'photographerName': photographerName,
      'photographerUrl': photographerUrl,
      'sourcePageUrl': sourcePageUrl,
      'altDescription': altDescription,
      'provider': provider,
      'score': score,
    };
  }
}

/// The unified model representing a resolved or mapped food image
@immutable
class FoodImageModel {
  final String? id;
  final FoodEntityType entityType;
  final String entityKey;
  final String displayName;
  final String imageUrl;
  final String provider; // 'pexels', 'curated', 'user_override', 'placeholder'
  final String? providerPhotoId;
  final String? photographerName;
  final String? photographerUrl;
  final String? sourcePageUrl;
  final String? altDescription;
  final String? panCutoutUrl;
  final bool isPanOverride;
  final bool isUserOverride;
  final String? userId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FoodImageModel({
    this.id,
    required this.entityType,
    required this.entityKey,
    required this.displayName,
    required this.imageUrl,
    this.provider = 'pexels',
    this.providerPhotoId,
    this.photographerName,
    this.photographerUrl,
    this.sourcePageUrl,
    this.altDescription,
    this.panCutoutUrl,
    this.isPanOverride = false,
    this.isUserOverride = false,
    this.userId,
    this.createdAt,
    this.updatedAt,
  });

  String get displayImageUrl => imageUrl;
  bool get hasPanCutout => panCutoutUrl != null && panCutoutUrl!.isNotEmpty;

  bool get isNetwork => imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
  bool get isAsset => imageUrl.startsWith('assets/');
  bool get isPlaceholder => provider == 'placeholder';

  bool get hasAttribution =>
      photographerName != null &&
      photographerName!.isNotEmpty &&
      provider == 'pexels';

  String get attributionText {
    if (!hasAttribution) return '';
    return 'Photo by $photographerName on Pexels';
  }

  FoodImageModel copyWith({
    String? id,
    FoodEntityType? entityType,
    String? entityKey,
    String? displayName,
    String? imageUrl,
    String? provider,
    String? providerPhotoId,
    String? photographerName,
    String? photographerUrl,
    String? sourcePageUrl,
    String? altDescription,
    String? panCutoutUrl,
    bool? isPanOverride,
    bool? isUserOverride,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FoodImageModel(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityKey: entityKey ?? this.entityKey,
      displayName: displayName ?? this.displayName,
      imageUrl: imageUrl ?? this.imageUrl,
      provider: provider ?? this.provider,
      providerPhotoId: providerPhotoId ?? this.providerPhotoId,
      photographerName: photographerName ?? this.photographerName,
      photographerUrl: photographerUrl ?? this.photographerUrl,
      sourcePageUrl: sourcePageUrl ?? this.sourcePageUrl,
      altDescription: altDescription ?? this.altDescription,
      panCutoutUrl: panCutoutUrl ?? this.panCutoutUrl,
      isPanOverride: isPanOverride ?? this.isPanOverride,
      isUserOverride: isUserOverride ?? this.isUserOverride,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FoodImageModel.fromJson(Map<String, dynamic> json) {
    return FoodImageModel(
      id: json['id']?.toString(),
      entityType: FoodEntityType.fromString((json['entity_type'] ?? json['entityType'] ?? 'ingredient').toString()),
      entityKey: (json['entity_key'] ?? json['entityKey'] ?? '').toString(),
      displayName: (json['display_name'] ?? json['displayName'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? '').toString(),
      provider: (json['provider'] ?? 'pexels').toString(),
      providerPhotoId: json['provider_photo_id']?.toString() ?? json['providerPhotoId']?.toString(),
      photographerName: json['photographer_name']?.toString() ?? json['photographerName']?.toString(),
      photographerUrl: json['photographer_url']?.toString() ?? json['photographerUrl']?.toString(),
      sourcePageUrl: json['source_page_url']?.toString() ?? json['sourcePageUrl']?.toString(),
      altDescription: json['alt_description']?.toString() ?? json['altDescription']?.toString(),
      panCutoutUrl: json['pan_cutout_url']?.toString() ?? json['panCutoutUrl']?.toString(),
      isPanOverride: json['is_pan_override'] == true || json['isPanOverride'] == true,
      isUserOverride: json['is_user_override'] == true || json['isUserOverride'] == true,
      userId: json['user_id']?.toString() ?? json['userId']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'entity_type': entityType.toDbString(),
      'entity_key': entityKey,
      'display_name': displayName,
      'image_url': imageUrl,
      'provider': provider,
      'provider_photo_id': providerPhotoId,
      'photographer_name': photographerName,
      'photographer_url': photographerUrl,
      'source_page_url': sourcePageUrl,
      'alt_description': altDescription,
      'pan_cutout_url': panCutoutUrl,
      'is_pan_override': isPanOverride,
      'is_user_override': isUserOverride,
      'user_id': userId,
    };
  }

  Map<String, dynamic> toJson() => toDbMap();
}
