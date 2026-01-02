import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/services/wardrobe_service.dart';
import 'package:styleum/screens/wardrobe/add_item_screen.dart';
import 'package:styleum/theme/theme.dart';
import 'package:styleum/widgets/skeleton_loader.dart';
import 'package:styleum/widgets/empty_state.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  final List<String> _categories = [
    'All',
    'Tops',
    'Bottoms',
    'Dresses',
    'Shoes',
    'Outerwear',
    'Accessories'
  ];

  static const Map<String, List<String>> _categoryMappings = {
    'Tops': ['tops', 'top', 'shirt', 't-shirt', 'sweater', 'hoodie', 'blouse', 'tank'],
    'Bottoms': ['bottoms', 'bottom', 'pants', 'jeans', 'shorts', 'skirt', 'trousers'],
    'Dresses': ['dress', 'dresses', 'romper', 'jumpsuit', 'one-piece'],
    'Shoes': ['shoes', 'shoe', 'sneakers', 'boots', 'sandals', 'heels', 'loafers'],
    'Outerwear': ['outerwear', 'jacket', 'coat', 'blazer', 'cardigan'],
    'Accessories': ['accessories', 'accessory', 'hat', 'bag', 'belt', 'watch', 'scarf', 'jewelry'],
  };

  bool _isLoading = true;
  String _selectedCategory = 'All';
  List<WardrobeItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    final allItems = await _wardrobeService.getWardrobeItems(user.id);

    List<WardrobeItem> filteredItems;
    if (_selectedCategory == 'All') {
      filteredItems = allItems;
    } else {
      final validCategories = _categoryMappings[_selectedCategory] ?? [];
      filteredItems = allItems.where((item) {
        final itemCategory = item.category?.toLowerCase() ?? '';
        return validCategories.contains(itemCategory);
      }).toList();
    }

    if (mounted) {
      setState(() {
        _items = filteredItems;
        _isLoading = false;
      });
    }
  }

  void _openAddItemSheet() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddItemScreen(),
    ).then((result) {
      if (result == true) {
        _loadItems();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.md),
            _buildCategoryChips(),
            const SizedBox(height: AppSpacing.md),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.cardPadding,
        AppSpacing.cardPadding,
        0,
      ),
      child: const Text(
        'My Wardrobe',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: EdgeInsets.only(right: index < _categories.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = category);
                _loadItems();
              },
              child: AnimatedContainer(
                duration: AppAnimations.normal,
                curve: AppAnimations.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.cherry : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.cherry : AppColors.border,
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SkeletonWardrobeGrid();
    }

    if (_items.isEmpty) {
      return EmptyState(
        headline: 'Your wardrobe is empty',
        description: 'Add items to get outfit suggestions',
        icon: Icons.checkroom,
        ctaLabel: 'Add Your First Item',
        onCtaPressed: _openAddItemSheet,
      );
    }

    return _buildItemsGrid();
  }

  Widget _buildItemsGrid() {
    return RefreshIndicator(
      onRefresh: _loadItems,
      color: AppColors.cherry,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: _items.length + 1, // +1 for Add Item card
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddItemCard();
          }
          final item = _items[index - 1];
          return _buildItemCard(item);
        },
      ),
    );
  }

  Widget _buildAddItemCard() {
    return GestureDetector(
      onTap: _openAddItemSheet,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.border,
          borderRadius: AppSpacing.radiusMd,
          dashWidth: 6,
          dashSpace: 4,
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                size: 32,
                color: AppColors.textMuted,
              ),
              SizedBox(height: 8),
              Text(
                'Add item',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(WardrobeItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: const [AppShadows.subtle],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: item.photoUrl != null
                  ? Image.network(
                      item.photoUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.border,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.textMuted,
                            size: 32,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.border,
                      child: const Center(
                        child: Icon(
                          Icons.checkroom,
                          color: AppColors.textMuted,
                          size: 32,
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              item.itemName ?? 'Unnamed Item',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace;
  }
}
