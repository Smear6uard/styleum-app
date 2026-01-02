import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WardrobeItem {
  final String id;
  final String? photoUrl;
  final String? category;
  final String? primaryColor;
  final String? itemName;
  final List<String>? seasons;
  final List<String>? occasions;

  WardrobeItem({
    required this.id,
    this.photoUrl,
    this.category,
    this.primaryColor,
    this.itemName,
    this.seasons,
    this.occasions,
  });

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    return WardrobeItem(
      id: json['id'] as String,
      photoUrl: json['photo_url'] as String?,
      category: json['category'] as String?,
      primaryColor: json['primary_color'] as String?,
      itemName: json['item_name'] as String?,
      seasons: json['seasons'] != null
          ? List<String>.from(json['seasons'] as List)
          : null,
      occasions: json['occasions'] != null
          ? List<String>.from(json['occasions'] as List)
          : null,
    );
  }
}

class WardrobeService {
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<List<WardrobeItem>> getWardrobeItems(String userId) async {
    try {
      final response = await _supabase
          .from('wardrobe_items')
          .select('id, photo_url, category, primary_color, item_name, seasons, occasions')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => WardrobeItem.fromJson(item))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<WardrobeItem>> getWardrobeItemsByCategory(
      String userId, String category) async {
    try {
      final response = await _supabase
          .from('wardrobe_items')
          .select('id, photo_url, category, primary_color, item_name, seasons, occasions')
          .eq('user_id', userId)
          .eq('category', category.toLowerCase())
          .order('created_at', ascending: false);

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

  Future<Uint8List?> compressImage(File file) async {
    try {
      print('WardrobeService.compressImage: Starting compression for ${file.path}');
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80,
      );
      print('WardrobeService.compressImage: Compression result size: ${result?.length ?? 0} bytes');
      return result;
    } catch (e, stackTrace) {
      print('WardrobeService.compressImage ERROR: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<Uint8List?> compressImageFromBytes(Uint8List imageBytes) async {
    try {
      print('WardrobeService.compressImageFromBytes: Starting compression, input size: ${imageBytes.length} bytes');
      final result = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80,
      );
      print('WardrobeService.compressImageFromBytes: Compression result size: ${result.length} bytes');
      return result;
    } catch (e, stackTrace) {
      print('WardrobeService.compressImageFromBytes ERROR: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<String?> uploadImage(Uint8List imageData, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$userId/$timestamp.jpg';
      print('WardrobeService.uploadImage: Starting upload, path: $path, size: ${imageData.length} bytes');

      await _supabase.storage.from('wardrobe').uploadBinary(
            path,
            imageData,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      print('WardrobeService.uploadImage: Upload successful');

      final url = _supabase.storage.from('wardrobe').getPublicUrl(path);

      print('WardrobeService.uploadImage: Public URL: $url');
      return url;
    } catch (e, stackTrace) {
      print('WardrobeService.uploadImage ERROR: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<Map<String, dynamic>> analyzeItem(String imageUrl) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final mockResponses = [
      {
        'itemName': 'Navy Blue Blazer',
        'category': 'outerwear',
        'primaryColor': 'navy',
        'seasons': ['fall', 'winter', 'spring'],
        'occasions': ['work', 'formal'],
      },
      {
        'itemName': 'White Cotton T-Shirt',
        'category': 'top',
        'primaryColor': 'white',
        'seasons': ['spring', 'summer'],
        'occasions': ['casual', 'athletic'],
      },
      {
        'itemName': 'Black Slim Jeans',
        'category': 'bottom',
        'primaryColor': 'black',
        'seasons': ['fall', 'winter', 'spring'],
        'occasions': ['casual', 'work'],
      },
      {
        'itemName': 'Brown Leather Boots',
        'category': 'shoes',
        'primaryColor': 'brown',
        'seasons': ['fall', 'winter'],
        'occasions': ['casual', 'work'],
      },
    ];

    return mockResponses[DateTime.now().millisecond % mockResponses.length];
  }

  Future<bool> saveWardrobeItem({
    required String userId,
    required String photoUrl,
    required String itemName,
    required String category,
    required String primaryColor,
    bool isFavorite = false,
  }) async {
    final data = {
      'user_id': userId,
      'photo_url': photoUrl,
      'item_name': itemName,
      'category': category.toLowerCase(),
      'primary_color': primaryColor.toLowerCase(),
      'is_favorite': isFavorite,
    };
    print('saveWardrobeItem: Inserting data: $data');

    try {
      final response = await _supabase.from('wardrobe_items').insert(data);
      print('saveWardrobeItem: Save response: $response');
      return true;
    } catch (e) {
      print('saveWardrobeItem: Database save error: $e');
      print('saveWardrobeItem: Error type: ${e.runtimeType}');
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
