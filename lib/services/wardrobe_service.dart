import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/models/wardrobe_item.dart';

export 'package:styleum/models/wardrobe_item.dart';

class WardrobeService {
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<List<WardrobeItem>> getWardrobeItems(String userId) async {
    try {
      final response = await _supabase
          .from('wardrobe_items')
          .select('''
            id, user_id, photo_url, category, primary_color, item_name, seasons, occasions,
            thumbnail_url, subcategory, color_hex, created_at,
            material, style_bucket, formality, seasonality, tags, times_worn, last_worn,
            dense_caption, ocr_text, vibe_scores, era_detected, era_confidence,
            is_unorthodox, unorthodox_description, construction_notes, user_verified
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final items = (response as List)
          .map((item) => WardrobeItem.fromJson(item))
          .toList();
      return items;
    } catch (e) {
      return [];
    }
  }

  Future<List<WardrobeItem>> getWardrobeItemsByCategory(
      String userId, String category) async {
    try {
      final response = await _supabase
          .from('wardrobe_items')
          .select('''
            id, user_id, photo_url, category, primary_color, item_name, seasons, occasions,
            thumbnail_url, subcategory, color_hex, created_at,
            material, style_bucket, formality, seasonality, tags, times_worn, last_worn,
            dense_caption, ocr_text, vibe_scores, era_detected, era_confidence,
            is_unorthodox, unorthodox_description, construction_notes, user_verified
          ''')
          .eq('user_id', userId)
          .eq('category', category.toLowerCase())
          .order('created_at', ascending: false);

      final items = (response as List)
          .map((item) => WardrobeItem.fromJson(item))
          .toList();
      return items;
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

  Future<Uint8List?> compressImage(File file) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80,
      );
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> compressImageFromBytes(Uint8List imageBytes) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80,
      );
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadImage(Uint8List imageData, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$userId/$timestamp.jpg';

      await _supabase.storage.from('wardrobe').uploadBinary(
            path,
            imageData,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      final url = _supabase.storage.from('wardrobe').getPublicUrl(path);
      return url;
    } catch (e) {
      return null;
    }
  }

  /// Trigger AI analysis for an item via Edge Function
  /// This calls Florence-2 + Gemini to analyze the clothing item
  Future<Map<String, dynamic>> analyzeItem(String itemId, String imageUrl) async {
    try {
      final response = await _supabase.functions.invoke(
        'analyze-item',
        body: {
          'item_id': itemId,
          'image_url': imageUrl,
        },
      );

      if (response.status != 200) {
        throw Exception('Analysis failed: ${response.data}');
      }

      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Save a wardrobe item and trigger AI analysis
  /// Returns the item ID on success, null on failure
  Future<String?> saveWardrobeItem({
    required String userId,
    required String photoUrl,
    required String itemName,
    required String category,
    required String primaryColor,
    bool isFavorite = false,
    bool triggerAnalysis = true,
  }) async {
    final data = {
      'user_id': userId,
      'photo_url': photoUrl,
      'item_name': itemName,
      'category': category.toLowerCase(),
      'primary_color': primaryColor.toLowerCase(),
      'is_favorite': isFavorite,
    };

    try {
      // Insert and return the new row to get the ID
      final response = await _supabase
          .from('wardrobe_items')
          .insert(data)
          .select('id')
          .single();

      final itemId = response['id'] as String;

      // Trigger AI analysis in the background (fire and forget)
      if (triggerAnalysis) {
        // Don't await - let it run in background
        analyzeItem(itemId, photoUrl).catchError((e) {
          // Silently handle analysis failures
          return <String, dynamic>{};
        });
      }

      return itemId;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteWardrobeItem(String itemId, String? photoUrl) async {
    try {
      if (photoUrl != null && photoUrl.contains('wardrobe')) {
        final uri = Uri.parse(photoUrl);
        final pathSegments = uri.pathSegments;
        final storageIndex = pathSegments.indexOf('wardrobe');
        if (storageIndex != -1 && storageIndex < pathSegments.length - 1) {
          final filePath = pathSegments.sublist(storageIndex + 1).join('/');
          await _supabase.storage.from('wardrobe').remove([filePath]);
        }
      }

      await _supabase.from('wardrobe_items').delete().eq('id', itemId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
