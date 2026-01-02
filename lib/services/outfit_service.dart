import 'package:styleum/services/wardrobe_service.dart';

class Outfit {
  final String id;
  final List<WardrobeItem> items;
  final int matchScore;
  final String styleHook;
  final String occasion;

  Outfit({
    required this.id,
    required this.items,
    required this.matchScore,
    required this.styleHook,
    required this.occasion,
  });
}

class OutfitService {
  final WardrobeService _wardrobeService = WardrobeService();

  static const List<String> _styleHooks = [
    'Smart casual with a bold twist',
    'Effortlessly chic and comfortable',
    'Modern minimalist vibes',
    'Classic with a contemporary edge',
    'Relaxed yet put-together',
    'Statement-making simplicity',
  ];

  Future<List<Outfit>> generateOutfits({
    required String userId,
    required String occasion,
    required String timeOfDay,
    required String weather,
    required String boldness,
  }) async {
    // Simulate AI processing time
    await Future.delayed(const Duration(milliseconds: 1500));

    // Fetch user's wardrobe items
    final wardrobeItems = await _wardrobeService.getWardrobeItems(userId);

    if (wardrobeItems.length < 5) {
      return [];
    }

    // Generate 4 outfits
    final outfitCount = 4;
    final outfits = <Outfit>[];

    for (int i = 0; i < outfitCount; i++) {
      // Pick 2-4 random items for each outfit
      final itemCount = 2 + (i % 3);
      final shuffled = List<WardrobeItem>.from(wardrobeItems)..shuffle();
      final selectedItems = shuffled.take(itemCount).toList();

      // Generate a match score based on boldness
      int baseScore;
      switch (boldness.toLowerCase()) {
        case 'safe':
          baseScore = 90;
          break;
        case 'balanced':
          baseScore = 85;
          break;
        case 'bold':
          baseScore = 80;
          break;
        case 'adventurous':
          baseScore = 75;
          break;
        default:
          baseScore = 85;
      }
      final score = baseScore + (DateTime.now().millisecond % 10);

      outfits.add(Outfit(
        id: 'outfit_${DateTime.now().millisecondsSinceEpoch}_$i',
        items: selectedItems,
        matchScore: score.clamp(70, 99),
        styleHook: _styleHooks[i % _styleHooks.length],
        occasion: occasion,
      ));
    }

    // Sort by match score descending
    outfits.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    return outfits;
  }

  Future<List<Outfit>> generateSurpriseOutfits(String userId) async {
    return generateOutfits(
      userId: userId,
      occasion: 'Casual',
      timeOfDay: 'Afternoon',
      weather: 'warm',
      boldness: 'Bold',
    );
  }
}
