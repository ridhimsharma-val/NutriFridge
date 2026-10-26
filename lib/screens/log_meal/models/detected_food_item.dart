/// Model representing an identified food item and its portion estimation.
class DetectedFoodItem {
  final String id;
  String name;
  double amount;
  String unit;
  String? imageAsset;

  DetectedFoodItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    this.imageAsset,
  });

  String get formattedQuantity =>
      '${amount % 1 == 0 ? amount.toInt() : amount} $unit';

  DetectedFoodItem copyWith({
    String? id,
    String? name,
    double? amount,
    String? unit,
    String? imageAsset,
  }) {
    return DetectedFoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      imageAsset: imageAsset ?? this.imageAsset,
    );
  }

  /// Initial sample detection dataset for prototype UI review.
  static List<DetectedFoodItem> get initialSampleDetection => [
        DetectedFoodItem(
          id: 'item_paneer',
          name: 'Paneer',
          amount: 100,
          unit: 'g',
          imageAsset: 'assets/images/foods/paneer.png',
        ),
        DetectedFoodItem(
          id: 'item_rice',
          name: 'Rice',
          amount: 150,
          unit: 'g',
          imageAsset: 'assets/images/foods/dal_rice.jpg',
        ),
        DetectedFoodItem(
          id: 'item_vegetables',
          name: 'Vegetables',
          amount: 80,
          unit: 'g',
          imageAsset: 'assets/images/categories/vegetables.jpg',
        ),
      ];
}
