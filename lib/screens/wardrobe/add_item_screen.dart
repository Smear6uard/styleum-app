import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/services/achievements_service.dart';
import 'package:styleum/services/ai_analysis_service.dart';
import 'package:styleum/models/ai_analysis.dart';
import 'package:styleum/services/wardrobe_service.dart';
import 'package:styleum/theme/theme.dart';
import 'package:styleum/widgets/app_button.dart';

class AddItemScreen extends StatefulWidget {
  final VoidCallback? onItemAdded;
  final bool asBottomSheet;

  const AddItemScreen({
    super.key,
    this.onItemAdded,
    this.asBottomSheet = false,
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();

  File? _selectedImage;
  Uint8List? _compressedImage;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  bool _hasCameraSupport = false;

  String _selectedCategory = 'top';
  String _selectedColor = 'black';
  bool _isFavorite = false;

  final List<String> _categories = [
    'top',
    'bottom',
    'dress',
    'shoes',
    'outerwear',
    'accessories',
  ];

  String _getCategoryLabel(String value) {
    switch (value) {
      case 'top':
        return 'Tops';
      case 'bottom':
        return 'Bottoms';
      case 'dress':
        return 'Dresses';
      default:
        return value[0].toUpperCase() + value.substring(1);
    }
  }

  @override
  void initState() {
    super.initState();
    _hasCameraSupport = _imagePicker.supportsImageSource(ImageSource.camera);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final hasCamera = _imagePicker.supportsImageSource(ImageSource.camera);
      if (!hasCamera) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera not available in simulator'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (image != null) {
        try {
          Uint8List? imageBytes;

          try {
            imageBytes = await image.readAsBytes();
            if (imageBytes.isEmpty) {
              imageBytes = null;
            }
          } catch (e) {
            imageBytes = null;
          }

          if (imageBytes == null || imageBytes.isEmpty) {
            final file = File(image.path);
            if (await file.exists()) {
              final fileSize = await file.length();
              if (fileSize > 0) {
                imageBytes = await file.readAsBytes();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Failed to read image. Please try on a real device.'),
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
                return;
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Failed to read image. Please try on a real device.'),
                    duration: Duration(seconds: 4),
                  ),
                );
              }
              return;
            }
          }

          final finalImageBytes = imageBytes;

          final tempDir = Directory.systemTemp;
          final tempFile = File(
              '${tempDir.path}/styleum_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(finalImageBytes);

          if (!mounted) return;
          setState(() {
            _selectedImage = tempFile;
            _isAnalyzing = true;
          });

          final compressed =
              await _wardrobeService.compressImageFromBytes(finalImageBytes);

          if (compressed == null) {
            if (mounted) {
              setState(() => _isAnalyzing = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Failed to process image. Please try again.')),
              );
            }
            return;
          }

          if (!mounted) return;
          setState(() {
            _compressedImage = compressed;
            _isAnalyzing = false;
          });

          // Note: AI analysis now happens server-side after saving the item
          // User can edit category/color manually before saving
        } catch (e) {
          if (mounted) {
            setState(() => _isAnalyzing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error processing image: ${e.toString()}')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image')),
        );
      }
    }
  }

  Future<void> _saveItem() async {
    if (_compressedImage == null || _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add an image and name')),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save items')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final photoUrl = await _wardrobeService.uploadImage(
        _compressedImage!,
        user.id,
      );

      if (photoUrl == null) {
        throw Exception('Failed to upload image');
      }

      final itemId = await _wardrobeService.saveWardrobeItem(
        userId: user.id,
        photoUrl: photoUrl,
        itemName: _nameController.text.trim(),
        category: _selectedCategory,
        primaryColor: _selectedColor,
        isFavorite: _isFavorite,
      );

      if (itemId != null && mounted) {
        // Track wardrobe achievement progress
        AchievementsService().recordAction(
          user.id,
          AchievementAction.wardrobeItemAdded,
        );

        // Active Learning: If marked as favorite, record like interaction
        if (_isFavorite) {
          StyleLearningService().recordInteraction(
            type: StyleInteractionType.like,
            itemId: itemId,
          );
        }

        HapticFeedback.mediumImpact();
        widget.onItemAdded?.call();
        Navigator.of(context).pop(true);
        return;
      } else {
        throw Exception('Failed to save item');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asBottomSheet) {
      return _buildBottomSheetContent();
    }
    return _buildFullPageContent();
  }

  Widget _buildFullPageContent() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Item',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: _selectedImage == null
              ? _buildImagePicker()
              : _buildFormContent(),
        ),
      ),
    );
  }

  Widget _buildBottomSheetContent() {
    if (_selectedImage == null) {
      return _buildDarkThemeBottomSheet();
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildTitle(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  child: _buildFormContent(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDarkThemeBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle - centered
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 28),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkSheetSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            const Text(
              'Add to closet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Description - updated copy
            Text(
              'Add a few pieces — the AI gets better fast.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.darkSheetMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // Primary button - white card style
            GestureDetector(
              onTap: () async {
                await _pickImage(ImageSource.gallery);
              },
              child: Container(
                width: double.infinity,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Add with photos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "We'll auto-detect the details",
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Secondary button - dark style
            GestureDetector(
              onTap: () async {
                await _pickImage(ImageSource.camera);
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.darkSheetSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Take photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Tip text at bottom
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lightbulb_outline, size: 14, color: AppColors.darkSheetMuted),
                const SizedBox(width: 6),
                Text(
                  'Full-body photos can add multiple items at once.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.darkSheetMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTitle() {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      child: Text(
        'Add Item',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        if (_hasCameraSupport)
          Row(
            children: [
              Expanded(
                child: _buildPickerButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Take Photo',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildPickerButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose from Gallery',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          )
        else
          _buildPickerButton(
            icon: Icons.photo_library_outlined,
            label: 'Choose from Gallery',
            onTap: () => _pickImage(ImageSource.gallery),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          _hasCameraSupport
              ? 'Take a photo or select from your gallery to add a clothing item'
              : 'Select from your gallery to add a clothing item',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: AppColors.slate),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImagePreview(),
        const SizedBox(height: AppSpacing.lg),
        if (_isAnalyzing) ...[
          _buildAnalyzingState(),
        ] else ...[
          _buildNameField(),
          const SizedBox(height: AppSpacing.cardPadding),
          _buildCategorySelector(),
          const SizedBox(height: AppSpacing.md),
          _buildFavoriteToggle(),
          const SizedBox(height: AppSpacing.lg),
          _buildSaveButton(),
        ],
        const SizedBox(height: AppSpacing.cardPadding),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (_isAnalyzing)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                color: AppColors.espresso.withValues(alpha: 0.08),
                child: Shimmer.fromColors(
                  baseColor: Colors.white.withValues(alpha: 0.3),
                  highlightColor: Colors.white.withValues(alpha: 0.6),
                  child: const Center(
                    child: Text(
                      'Analyzing...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedImage = null;
                _compressedImage = null;
                _nameController.clear();
                _isFavorite = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.espresso.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingState() {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
          const SizedBox(height: AppSpacing.cardPadding),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: AppSpacing.cardPadding),
          Wrap(
            spacing: 12,
            children: List.generate(
              5,
              (index) => Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'e.g., Blue Denim Jacket',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.slateDark, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final isSelected = category == _selectedCategory;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: AnimatedContainer(
                duration: AppAnimations.normal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.slate : AppColors.border,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(
                        Icons.check,
                        size: 14,
                        color: AppColors.slate,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _getCategoryLabel(category),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? AppColors.slateDark : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFavoriteToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isFavorite = !_isFavorite),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? AppColors.slateDark : AppColors.textMuted,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            _isFavorite ? 'Favorite' : 'Mark as Favorite',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _isFavorite ? AppColors.slateDark : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return AppButton.primary(
      label: 'Save to Wardrobe',
      onPressed: _isSaving ? null : _saveItem,
      isLoading: _isSaving,
    );
  }
}

