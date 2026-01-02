import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/services/achievements_service.dart';
import 'package:styleum/services/outfit_service.dart';
import 'package:styleum/services/wardrobe_service.dart';
import 'package:styleum/services/profile_service.dart';
import 'package:styleum/theme/theme.dart';
import 'package:styleum/widgets/skeleton_loader.dart';

class StyleMeScreen extends StatefulWidget {
  final bool isGenerating;
  final double progress;
  final List<Outfit>? pendingOutfits;
  final String? errorMessage;
  final Map<String, dynamic>? lastSelections;
  final Function(Map<String, dynamic>) onStartGeneration;
  final VoidCallback onClearResults;
  final VoidCallback onClearError;
  final VoidCallback onNavigateToWardrobe;

  const StyleMeScreen({
    super.key,
    required this.isGenerating,
    required this.progress,
    this.pendingOutfits,
    this.errorMessage,
    this.lastSelections,
    required this.onStartGeneration,
    required this.onClearResults,
    required this.onClearError,
    required this.onNavigateToWardrobe,
  });

  @override
  State<StyleMeScreen> createState() => _StyleMeScreenState();
}

class _StyleMeScreenState extends State<StyleMeScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  final ProfileService _profileService = ProfileService();

  bool _isLoading = true;
  int _wardrobeCount = 0;
  int _streakCount = 0;

  // Customization state (for bottom sheet)
  String? _selectedOccasion;
  String? _selectedTime;
  String? _selectedBoldness;

  int _selectedOutfitIndex = 0;
  final Set<String> _savedOutfitIds = {};

  final List<String> _occasions = ['Casual', 'Formal', 'Gym', 'Travel'];
  final List<String> _times = ['Morning', 'Afternoon', 'Evening'];
  final List<String> _boldnessLevels = ['Safe', 'Balanced', 'Bold'];

  @override
  void initState() {
    super.initState();
    _loadData();
    _restoreSelections();
  }

  @override
  void didUpdateWidget(StyleMeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pendingOutfits != oldWidget.pendingOutfits && widget.pendingOutfits != null) {
      setState(() => _selectedOutfitIndex = 0);
    }
  }

  void _restoreSelections() {
    if (widget.lastSelections != null) {
      setState(() {
        _selectedOccasion = widget.lastSelections!['occasion'] as String?;
        _selectedTime = widget.lastSelections!['time'] as String?;
        _selectedBoldness = widget.lastSelections!['boldness'] as String?;
      });
    }
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final results = await Future.wait([
      _wardrobeService.getWardrobeCount(user.id),
      _profileService.getProfile(user.id),
    ]);

    if (mounted) {
      setState(() {
        _wardrobeCount = results[0] as int;
        final profile = results[1] as Profile?;
        _streakCount = profile?.currentStreak ?? 0;
        _isLoading = false;
      });
    }
  }

  // Generate with smart defaults
  void _generateWithDefaults() {
    widget.onStartGeneration({
      'occasion': _selectedOccasion ?? 'Casual',
      'time': _selectedTime ?? 'Afternoon',
      'weather': 'warm',
      'boldness': _selectedBoldness ?? 'Balanced',
    });
  }

  // Generate with specific modifier
  void _generateWithModifier(String modifier) {
    String boldness = _selectedBoldness ?? 'Balanced';

    if (modifier == 'casual') {
      boldness = 'Safe';
    } else if (modifier == 'bold') {
      boldness = 'Bold';
    }

    widget.onStartGeneration({
      'occasion': _selectedOccasion ?? 'Casual',
      'time': _selectedTime ?? 'Afternoon',
      'weather': 'warm',
      'boldness': boldness,
    });
  }

  void _resetToHome() {
    widget.onClearResults();
  }

  void _wearOutfit(Outfit outfit) {
    HapticFeedback.lightImpact();

    // Track achievement
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      AchievementsService().recordAction(
        user.id,
        AchievementAction.outfitWorn,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Logged!', style: TextStyle(color: AppColors.textPrimary)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleSave(Outfit outfit) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_savedOutfitIds.contains(outfit.id)) {
        _savedOutfitIds.remove(outfit.id);
      } else {
        _savedOutfitIds.add(outfit.id);
      }
    });
  }

  bool get _hasCustomizations =>
      _selectedOccasion != null || _selectedTime != null || _selectedBoldness != null;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: SkeletonOutfitGrid()),
      );
    }

    if (_wardrobeCount < 5) {
      return _buildEmptyState();
    }

    if (widget.errorMessage != null) {
      return _buildErrorState();
    }

    if (widget.isGenerating) {
      return _buildLoadingState();
    }

    if (widget.pendingOutfits != null && widget.pendingOutfits!.isNotEmpty) {
      return _buildResultView();
    }

    return _buildHomeView();
  }

  // ===== EMPTY STATE =====
  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.checkroom, size: 48, color: AppColors.slate),
                const SizedBox(height: 16),
                const Text(
                  'Not enough items yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add at least 5 pieces to get outfit suggestions',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                _buildSecondaryPillButton('Go to Wardrobe', widget.onNavigateToWardrobe),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== ERROR STATE =====
  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  "We couldn't build your outfits",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                _buildPrimaryButton('Try Again', () {
                  widget.onClearError();
                  _generateWithDefaults();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== LOADING STATE =====
  Widget _buildLoadingState() {
    final loadingText = widget.progress > 0.7 ? 'Almost done...' : 'Building outfits...';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    value: widget.progress > 0 ? widget.progress : null,
                    strokeWidth: 3,
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  loadingText,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== HOME VIEW (Result-First) =====
  Widget _buildHomeView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Weather bar
              _buildWeatherBar(),

              // Flexible space to center hero
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hero section
                    const Text(
                      'What should I\nwear today?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "I'll pick something based on your weather,\nwardrobe, and style.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Active customizations (filter tags)
                    if (_hasCustomizations) ...[
                      _buildActiveFilters(),
                      const SizedBox(height: 16),
                    ],

                    // Primary CTA
                    _buildPrimaryButton('Style Me', _generateWithDefaults),
                    const SizedBox(height: 16),

                    // Customize link
                    GestureDetector(
                      onTap: _showCustomizeSheet,
                      child: const Text(
                        'Customize',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Context cards at bottom
              _buildContextCards(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherBar() {
    return Row(
      children: [
        const Text(
          '72°F Sunny',
          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
        const Text(
          ' • ',
          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
        const Expanded(
          child: Text(
            'Chicago, IL',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ),
        GestureDetector(
          onTap: () {
            // TODO: Weather override
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Weather settings coming soon'), behavior: SnackBarBehavior.floating),
            );
          },
          child: const Text(
            'Change',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.slate),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (_selectedOccasion != null)
          _buildFilterTag(_selectedOccasion!, () => setState(() => _selectedOccasion = null)),
        if (_selectedTime != null)
          _buildFilterTag(_selectedTime!, () => setState(() => _selectedTime = null)),
        if (_selectedBoldness != null)
          _buildFilterTag(_selectedBoldness!, () => setState(() => _selectedBoldness = null)),
      ],
    );
  }

  Widget _buildFilterTag(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.filterTagBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildContextCards() {
    return Row(
      children: [
        Expanded(
          child: _buildContextCard('$_streakCount days', 'Consistency'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildContextCard('$_wardrobeCount items', 'Wardrobe'),
        ),
      ],
    );
  }

  Widget _buildContextCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ===== CUSTOMIZE BOTTOM SHEET =====
  void _showCustomizeSheet() {
    // Temporary state for the sheet
    String? tempOccasion = _selectedOccasion;
    String? tempTime = _selectedTime;
    String? tempBoldness = _selectedBoldness;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Customize your outfit',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            tempOccasion = null;
                            tempTime = null;
                            tempBoldness = null;
                          });
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.slate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Occasion
                  const Text(
                    "What's the occasion?",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _occasions.map((option) {
                      final isSelected = option == tempOccasion;
                      return _buildSheetChip(option, isSelected, () {
                        setSheetState(() => tempOccasion = isSelected ? null : option);
                      });
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Time
                  const Text(
                    'When are you heading out?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _times.map((option) {
                      final isSelected = option == tempTime;
                      return _buildSheetChip(option, isSelected, () {
                        setSheetState(() => tempTime = isSelected ? null : option);
                      });
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Boldness
                  const Text(
                    'How bold?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _boldnessLevels.map((option) {
                      final isSelected = option == tempBoldness;
                      return _buildSheetChip(option, isSelected, () {
                        setSheetState(() => tempBoldness = isSelected ? null : option);
                      });
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Apply button
                  _buildPrimaryButton('Apply & Generate', () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedOccasion = tempOccasion;
                      _selectedTime = tempTime;
                      _selectedBoldness = tempBoldness;
                    });
                    _generateWithDefaults();
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppColors.slate : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== RESULT VIEW =====
  Widget _buildResultView() {
    final currentOutfit = widget.pendingOutfits![_selectedOutfitIndex];
    final isSaved = _savedOutfitIds.contains(currentOutfit.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header: Back + Save
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _resetToHome,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _toggleSave(currentOutfit),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        isSaved ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isSaved ? AppColors.slate : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Outfit card (~70% of remaining space)
              Expanded(
                flex: 7,
                child: _buildOutfitCard(currentOutfit),
              ),
              const SizedBox(height: 16),

              // Title and why
              Text(
                currentOutfit.styleHook,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Picked for 72° weather and your ${_selectedBoldness?.toLowerCase() ?? 'balanced'} style.',
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Primary CTA
              _buildPrimaryButton('Wear This Today', () => _wearOutfit(currentOutfit)),
              const SizedBox(height: 12),

              // Adjustment pills
              _buildAdjustmentPills(),
              const SizedBox(height: 16),

              // See all options link
              GestureDetector(
                onTap: () => _showAllOptionsSheet(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'See all ${widget.pendingOutfits!.length} options',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.slate),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 16, color: AppColors.slate),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutfitCard(Outfit outfit) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(outfit.id),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [AppShadows.card],
        ),
        child: Stack(
          children: [
            // Item thumbnails grid
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildItemThumbnails(outfit.items),
            ),
            // Score badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.slateDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${outfit.matchScore}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemThumbnails(List<WardrobeItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text(
              'No items',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    // Calculate grid layout based on item count
    final itemCount = items.length;
    final crossAxisCount = itemCount <= 2 ? itemCount : (itemCount <= 4 ? 2 : 3);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item.photoUrl != null
              ? Image.network(
                  item.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.border,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.textMuted,
                        size: 24,
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
                      size: 24,
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildAdjustmentPills() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAdjustmentPill('More casual', () => _generateWithModifier('casual')),
        const SizedBox(width: 8),
        _buildAdjustmentPill('More bold', () => _generateWithModifier('bold')),
        const SizedBox(width: 8),
        _buildAdjustmentPill('Try again', () => _generateWithDefaults(), icon: Icons.refresh),
      ],
    );
  }

  Widget _buildAdjustmentPill(String label, VoidCallback onTap, {IconData? icon}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.textPrimary),
              if (label.isNotEmpty) const SizedBox(width: 4),
            ],
            if (label.isNotEmpty)
              Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
              ),
          ],
        ),
      ),
    );
  }

  void _showAllOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'All Options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.pendingOutfits!.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final outfit = widget.pendingOutfits![index];
                    final isSelected = index == _selectedOutfitIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedOutfitIndex = index);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.slate : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.style_outlined, size: 24, color: AppColors.textMuted),
                            const SizedBox(height: 4),
                            Text(
                              '${outfit.matchScore}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? AppColors.slate : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ===== SHARED BUTTON COMPONENTS =====
  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryPillButton(String label, VoidCallback onPressed) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
