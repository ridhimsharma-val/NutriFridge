/// Model for recipe video recommendations shown in the Meal Detail screen.
class RecipeVideoItem {
  final String id;
  final String title;
  final String channelName;
  final String duration;
  final String thumbnailAsset;
  final bool isSamplePlaceholder;

  const RecipeVideoItem({
    required this.id,
    required this.title,
    required this.channelName,
    required this.duration,
    required this.thumbnailAsset,
    this.isSamplePlaceholder = true,
  });

  /// Sample video recommendations for Paneer Rice Bowl
  static const List<RecipeVideoItem> defaultVideos = [
    RecipeVideoItem(
      id: 'vid_1',
      title: 'Homestyle Paneer Rice Bowl in 15 Minutes',
      channelName: 'Fresh Kitchen Tales',
      duration: '8:24',
      thumbnailAsset: 'assets/images/paneer_rice_bowl.jpg',
      isSamplePlaceholder: true,
    ),
    RecipeVideoItem(
      id: 'vid_2',
      title: 'Healthy High-Protein Paneer Fried Rice',
      channelName: 'NutriCook Daily',
      duration: '11:05',
      thumbnailAsset: 'assets/images/foods/paneer_curry.jpg',
      isSamplePlaceholder: true,
    ),
    RecipeVideoItem(
      id: 'vid_3',
      title: 'Quick Fridge-to-Table Paneer Veggie Bowl',
      channelName: 'Simple Healthy Meals',
      duration: '6:48',
      thumbnailAsset: 'assets/images/foods/dal_rice.jpg',
      isSamplePlaceholder: true,
    ),
  ];
}
