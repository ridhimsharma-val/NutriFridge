/// Model for recipe video recommendations shown in the Meal Detail screen.
class RecipeVideoItem {
  final String id;
  final String title;
  final String channelName;
  final String duration;
  final String? thumbnailUrl;
  final String? thumbnailAsset;
  final String videoUrl;
  final String? viewCount;
  final String? publishedAt;
  final bool isSamplePlaceholder;

  const RecipeVideoItem({
    required this.id,
    required this.title,
    required this.channelName,
    required this.duration,
    this.thumbnailUrl,
    this.thumbnailAsset,
    required this.videoUrl,
    this.viewCount,
    this.publishedAt,
    this.isSamplePlaceholder = false,
  });

  factory RecipeVideoItem.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['videoId'] ?? '').toString();
    return RecipeVideoItem(
      id: id,
      title: (json['title'] ?? '').toString(),
      channelName: (json['channelName'] ?? json['channel'] ?? json['creator'] ?? '').toString(),
      duration: (json['duration'] ?? '').toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      thumbnailAsset: json['thumbnailAsset']?.toString(),
      videoUrl: (json['videoUrl'] ?? (id.isNotEmpty ? 'https://www.youtube.com/watch?v=$id' : '')).toString(),
      viewCount: json['viewCount']?.toString(),
      publishedAt: json['publishedAt']?.toString(),
      isSamplePlaceholder: false,
    );
  }

  /// Sample video recommendations for automated tests or fixtures
  static const List<RecipeVideoItem> sampleVideosForTesting = [
    RecipeVideoItem(
      id: 'vid_1',
      title: 'Homestyle Paneer Rice Bowl in 15 Minutes',
      channelName: 'Fresh Kitchen Tales',
      duration: '8:24',
      thumbnailAsset: 'assets/images/paneer_rice_bowl.jpg',
      videoUrl: 'https://www.youtube.com/watch?v=vid_1',
      isSamplePlaceholder: true,
    ),
    RecipeVideoItem(
      id: 'vid_2',
      title: 'Healthy High-Protein Paneer Fried Rice',
      channelName: 'NutriCook Daily',
      duration: '11:05',
      thumbnailAsset: 'assets/images/foods/paneer_curry.jpg',
      videoUrl: 'https://www.youtube.com/watch?v=vid_2',
      isSamplePlaceholder: true,
    ),
  ];
}
