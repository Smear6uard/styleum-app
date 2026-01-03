import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/services/profile_service.dart';
import 'package:styleum/services/wardrobe_service.dart';
import 'package:styleum/repositories/outfit_repository.dart';
import 'package:styleum/models/outfit.dart';
import 'package:styleum/screens/wardrobe/add_item_screen.dart';
import 'package:styleum/screens/wardrobe/item_detail_screen.dart';
import 'package:styleum/screens/style_shuffle/style_shuffle_screen.dart';
import 'package:styleum/theme/theme.dart';
import 'package:styleum/widgets/animated_list_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProfileService _profileService = ProfileService();
  final WardrobeService _wardrobeService = WardrobeService();

  bool _isLoading = true;
  Profile? _profile;
  int _wardrobeCount = 0;

  // V2: Outfit carousel state
  List<ScoredOutfit> _outfits = [];
  int _currentOutfitIndex = 0;
  final PageController _outfitPageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _outfitPageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load profile and wardrobe in parallel
      final results = await Future.wait([
        _profileService.getProfile(user.id),
        _wardrobeService.getWardrobeItems(user.id),
      ]);

      final profile = results[0] as Profile?;
      final wardrobeItems = results[1] as List<WardrobeItem>;

      // Load outfits if we have enough wardrobe items
      List<ScoredOutfit> outfits = [];
      if (wardrobeItems.length >= 5) {
        try {
          final repo = await OutfitRepository.create();
          final outfitResult = await repo.getTodaysOutfits();
          if (outfitResult.isSuccess && outfitResult.outfits != null) {
            outfits = outfitResult.outfits!;
          }
        } catch (e) {
          // Outfit loading failed - continue without outfits
        }
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _wardrobeCount = wardrobeItems.length;
          _outfits = outfits;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning.';
    if (hour < 17) return 'Afternoon.';
    return 'Evening.';
  }

  double _getHeroHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight < 700) return screenHeight * 0.45;
    if (screenHeight < 850) return screenHeight * 0.52;
    return screenHeight * 0.58;
  }

  void _openAddItemSheet() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AddItemScreen(asBottomSheet: true, onItemAdded: () => _loadData()),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  Future<void> _wearThisOutfit() async {
    if (_outfits.isEmpty) return;

    final outfit = _outfits[_currentOutfitIndex];
    try {
      final repo = await OutfitRepository.create();
      await repo.markAsWorn(outfit);
      // Could show confirmation or update streak
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.slate)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildHeader(),
              ),
              const SizedBox(height: 24),

              // HERO SECTION - ALWAYS SHOW
              AnimatedEntrance(child: _buildHeroSection()),
              const SizedBox(height: 24),

              // Stats strip
              _buildStatsStrip(),

              // Secondary row - just Shuffle
              _buildSecondaryRow(
                title: 'Shuffle',
                subtitle: 'Teach your taste',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StyleShuffleScreen()),
                  );
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getGreeting(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '72° · Sunny',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textMuted,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCarousel() {
    if (_outfits.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: _getHeroHeight(context),
      child: PageView.builder(
        controller: _outfitPageController,
        itemCount: _outfits.length.clamp(0, 4),
        onPageChanged: (i) => setState(() => _currentOutfitIndex = i),
        itemBuilder: (context, index) => _buildOutfitCard(_outfits[index]),
      ),
    );
  }

  Widget _buildOutfitCard(ScoredOutfit outfit) {
    return GestureDetector(
      onTap: () => _showOutfitVisualization(outfit),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            // Single hero image - the TOP item
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: _buildItemImage(outfit.candidate.top),
              ),
            ),
            // Dot indicator at bottom
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: _buildDotIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemImage(WardrobeItem item) {
    if (item.photoUrl != null) {
      return Image.network(
        item.photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppColors.border,
          child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
        ),
      );
    }
    return Container(
      color: AppColors.border,
      child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
    );
  }

  Widget _buildDotIndicator() {
    final count = _outfits.length.clamp(0, 4);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == _currentOutfitIndex;
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
          ),
        );
      }),
    );
  }

  Widget _buildOutfitMetaRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "TODAY'S TOP PICK",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.slate,
              letterSpacing: 1.5,
            ),
          ),
          GestureDetector(
            onTap: () {
              // Navigate to all outfits
            },
            child: Text(
              'See all',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.slate,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    // Has outfits - show carousel
    if (_outfits.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroCarousel(),
          const SizedBox(height: 12),
          _buildOutfitMetaRow(),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _outfits[_currentOutfitIndex].whyItWorks,
              style: AppTypography.headingSmall,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildWearThisButton(),
          ),
          const SizedBox(height: 20),
          _buildOutfitBreakdown(),
        ],
      );
    }

    // No outfits - show placeholder card with onboarding inside
    return _buildHeroPlaceholder();
  }

  Widget _buildHeroPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: _getHeroHeight(context),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.checkroom_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              _wardrobeCount < 5
                  ? 'Add ${5 - _wardrobeCount} more items'
                  : 'Building your outfits...',
              style: AppTypography.headingSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _wardrobeCount < 5
                  ? 'to unlock daily outfit picks'
                  : 'Check back in a moment',
              style: AppTypography.bodyMedium,
            ),
            if (_wardrobeCount < 5) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _openAddItemSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Add items',
                    style: AppTypography.labelLarge.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOutfitBreakdown() {
    if (_outfits.isEmpty) return const SizedBox.shrink();

    final outfit = _outfits[_currentOutfitIndex];
    final items = _getOutfitItems(outfit.candidate);
    final displayItems = items.take(3).toList();
    final hasMore = items.length > 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          const Text(
            'OUTFIT BREAKDOWN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.slate,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Item rows
          ...displayItems.map((item) => _buildBreakdownRow(item)),

          // "+ N more" expandable
          if (hasMore) _buildExpandMoreRow(items.length - 3),
        ],
      ),
    );
  }

  List<WardrobeItem> _getOutfitItems(OutfitCandidate candidate) {
    return [
      candidate.top,
      candidate.bottom,
      candidate.shoes,
      if (candidate.outerwear != null) candidate.outerwear!,
      if (candidate.accessory != null) candidate.accessory!,
    ];
  }

  Widget _buildBreakdownRow(WardrobeItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            // 48x48 thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: _buildItemImage(item),
              ),
            ),
            const SizedBox(width: 12),
            // Item name
            Expanded(
              child: Text(
                item.itemName ?? item.category.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Chevron
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandMoreRow(int count) {
    return GestureDetector(
      onTap: () {
        // Show all items in the visualization sheet
        if (_outfits.isNotEmpty) {
          _showOutfitVisualization(_outfits[_currentOutfitIndex]);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(
              '+ $count more',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 18, color: AppColors.slate),
          ],
        ),
      ),
    );
  }

  void _showOutfitVisualization(ScoredOutfit outfit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OutfitVisualizationSheet(
        outfit: outfit,
        onWear: () {
          Navigator.pop(context);
          _wearThisOutfit();
        },
      ),
    );
  }

  Widget _buildWearThisButton() {
    return GestureDetector(
      onTap: _wearThisOutfit,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Wear this',
            style: AppTypography.labelLarge.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsStrip() {
    final streak = _profile?.currentStreak ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                '$streak',
                'DAY STREAK',
                (streak / 30).clamp(0.0, 1.0),
              ),
            ),
            Container(width: 1, color: AppColors.border),
            Expanded(
              child: _buildStatItem('3/5', 'COLOR POP', 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, double progress) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.slate,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryRow({
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTypography.bodySmall),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Full outfit visualization sheet - Scattered flat lay style
class _OutfitVisualizationSheet extends StatelessWidget {
  final ScoredOutfit outfit;
  final VoidCallback onWear;

  const _OutfitVisualizationSheet({
    required this.outfit,
    required this.onWear,
  });

  List<WardrobeItem> _getOutfitItems(OutfitCandidate candidate) {
    return [
      candidate.top,
      candidate.bottom,
      candidate.shoes,
      if (candidate.outerwear != null) candidate.outerwear!,
      if (candidate.accessory != null) candidate.accessory!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _getOutfitItems(outfit.candidate);
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(context),

          // Title + Occasion label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Look",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  outfit.vibes.isNotEmpty
                      ? outfit.vibes.first.toUpperCase()
                      : 'DAILY LOOK',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.slate,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scattered flat lay area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildScatteredLayout(items, context, screenWidth),
            ),
          ),

          // Item count hint
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${items.length} items · tap any to view',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.slate,
              ),
            ),
          ),

          // Action bar
          _buildActionBar(context),
          const SizedBox(height: 16),

          // Wear this button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _buildWearButton(),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildScatteredLayout(List<WardrobeItem> items, BuildContext context, double screenWidth) {
    final contentWidth = screenWidth - 40; // 20px padding each side
    final positions = _getScatteredPositions(items.length, contentWidth);

    return Stack(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final pos = positions[index];

        return Positioned(
          left: pos['left'],
          top: pos['top'],
          child: Transform.rotate(
            angle: pos['rotation'] ?? 0.0,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
                );
              },
              child: SizedBox(
                width: pos['width'],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: pos['width'],
                      height: pos['height'],
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.photoUrl != null
                            ? Image.network(
                                item.photoUrl!,
                                fit: BoxFit.cover,
                              )
                            : const Center(
                                child: Icon(Icons.image_outlined, color: AppColors.textMuted),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.itemName ?? item.category.name,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Map<String, double>> _getScatteredPositions(int count, double contentWidth) {
    // Predefined positions for editorial scattered look
    // Top/Bottom are larger (main pieces), shoes/accessories smaller
    // Sizes increased ~15% for better visibility
    final allPositions = <Map<String, double>>[
      // TOP - large, top-left area
      {'left': 0, 'top': 0, 'width': contentWidth * 0.6, 'height': 205, 'rotation': -0.02},
      // BOTTOM - large, middle-left, slightly below and offset
      {'left': 8, 'top': 185, 'width': contentWidth * 0.58, 'height': 195, 'rotation': 0.015},
      // SHOES - medium, bottom-right
      {'left': contentWidth * 0.48, 'top': 230, 'width': contentWidth * 0.5, 'height': 160, 'rotation': -0.025},
      // OUTERWEAR - smaller, top-right
      {'left': contentWidth * 0.56, 'top': 15, 'width': contentWidth * 0.42, 'height': 138, 'rotation': 0.03},
      // ACCESSORY - even smaller, scattered
      {'left': contentWidth * 0.62, 'top': 145, 'width': 92, 'height': 92, 'rotation': -0.04},
    ];

    return allPositions.take(count).toList();
  }

  Widget _buildActionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionButton(Icons.bookmark_outline, () {
            // TODO: Save outfit
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Outfit saved!')),
            );
          }),
          const SizedBox(width: 16),
          _buildActionButton(Icons.edit_outlined, () {
            // TODO: Edit outfit
          }),
          const SizedBox(width: 16),
          _buildActionButton(Icons.thumb_down_outlined, () {
            Navigator.pop(context);
            // TODO: Mark as rejected
          }),
          const SizedBox(width: 16),
          _buildActionButton(Icons.share_outlined, () {
            // TODO: Share outfit
          }),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Icon(icon, size: 28, color: AppColors.slate),
      ),
    );
  }

  Widget _buildWearButton() {
    return GestureDetector(
      onTap: onWear,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Wear this',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
