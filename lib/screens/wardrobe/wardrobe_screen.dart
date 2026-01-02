import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/services/wardrobe_service.dart';
import 'package:styleum/screens/wardrobe/add_item_screen.dart';
import 'package:styleum/theme/theme.dart';
import 'package:styleum/widgets/skeleton_loader.dart';
import 'package:styleum/widgets/empty_state.dart';
import 'package:styleum/widgets/animated_list_item.dart';

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

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

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
      builder: (context) => const AddItemScreen(asBottomSheet: true),
    ).then((result) {
      if (result == true) {
        _loadItems();
        // Show success toast after closing
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added! This helps improve your daily outfits.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedIds.contains(itemId)) {
        _selectedIds.remove(itemId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(itemId);
      }
    });
  }

  void _enterSelectionMode(String itemId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(itemId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isSelectionMode ? _buildSelectionHeader() : _buildHeader(),
                const SizedBox(height: AppSpacing.md),
                _buildAddToClosetPill(),
                const SizedBox(height: AppSpacing.sm),
                _buildSubheader(),
                const SizedBox(height: AppSpacing.sm),
                _buildCategoryChips(),
                const SizedBox(height: AppSpacing.md),
                Expanded(child: _buildContent()),
              ],
            ),
            if (_isSelectionMode && _selectedIds.isNotEmpty)
              _buildSelectionFloatingPill(),
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

  Widget _buildSelectionHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.cardPadding,
        AppSpacing.cardPadding,
        AppSpacing.cardPadding,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_selectedIds.length} selected',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  // TODO: Delete selected items
                },
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _exitSelectionMode,
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddToClosetPill() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding),
      child: AnimatedOpacity(
        opacity: _isSelectionMode ? 0.4 : 1.0,
        duration: AppAnimations.normal,
        child: GestureDetector(
          onTap: _isSelectionMode ? null : _openAddItemSheet,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Add to Closet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubheader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding),
      child: Row(
        children: [
          const Text(
            'Newest',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textPrimary),
          Text(
            '  •  ${_items.length} items',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionFloatingPill() {
    return Positioned(
      left: AppSpacing.cardPadding,
      right: AppSpacing.cardPadding,
      bottom: AppSpacing.lg,
      child: GestureDetector(
        onTap: () {
          // Navigate to Style Me with selected items
          final selectedItems = _items.where((item) => _selectedIds.contains(item.id)).toList();
          // TODO: Navigate to Style Me screen with selectedItems
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Styling ${selectedItems.length} items...'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [AppShadows.primaryButton],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('✨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Style ${_selectedIds.length} items',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          ListView.builder(
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.slate : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          Icon(Icons.check, size: 14, color: AppColors.slate),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? AppColors.slate : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SkeletonWardrobeGrid();
    }

    if (_items.isEmpty) {
      return EmptyState(
        headline: 'Start building your closet',
        description: 'Add a few pieces to get personalized outfit suggestions',
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
      color: AppColors.slate,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return AnimatedListItem(
            index: index,
            child: _buildItemCard(item),
          );
        },
      ),
    );
  }

  Widget _buildItemCard(WardrobeItem item) {
    final isSelected = _selectedIds.contains(item.id);

    return GestureDetector(
      onLongPress: () {
        if (!_isSelectionMode) {
          _enterSelectionMode(item.id);
        }
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleItemSelection(item.id);
        } else {
          // TODO: Navigate to item detail
        }
      },
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: isSelected
              ? Border.all(color: AppColors.slate, width: 2)
              : null,
          boxShadow: const [AppShadows.subtle],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(12),
                      bottom: isSelected ? Radius.zero : Radius.zero,
                    ),
                    child: item.photoUrl != null
                        ? Image.network(
                            item.photoUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
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
            // Selection checkbox
            if (_isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: AppAnimations.fast,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.slate : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.slate : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}
