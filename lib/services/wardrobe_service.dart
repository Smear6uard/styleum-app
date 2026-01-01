import 'package:supabase_flutter/supabase_flutter.dart';

class WardrobeItem {
  final String id;
  final String? photoUrl;
  final String? category;
  final String? primaryColor;
  final String? itemName;

  WardrobeItem({
    required this.id,
    this.photoUrl,
    this.category,
    this.primaryColor,
    this.itemName,
  });

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    return WardrobeItem(
      id: json['id'] as String,
      photoUrl: json['photo_url'] as String?,
      category: json['category'] as String?,
      primaryColor: json['primary_color'] as String?,
      itemName: json['item_name'] as String?,
    );
  }
}

class WardrobeService {
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<List<WardrobeItem>> getWardrobeItems(String userId) async {
    try {
      final response = await _supabase
          .from('wardrobe_items')
          .select('id, photo_url, category, primary_color, item_name')
          .eq('user_id', userId);

      return (response as List)
          .map((item) => WardrobeItem.fromJson(item))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<int> getWardrobeCount(String userId) async {
    try {
      final response = await _supabase
          .from('wardrobe_items')
          .select()
          .eq('user_id', userId)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      return 0;
    }
  }
}
