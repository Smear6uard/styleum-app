import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/services/outfit_service.dart';
import 'package:styleum/services/wardrobe_service.dart';
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
  final ValueChanged<bool>? onAllAnsweredChanged;

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
    this.onAllAnsweredChanged,
  });

  @override
  State<StyleMeScreen> createState() => _StyleMeScreenState();
}

class _StyleMeScreenState extends State<StyleMeScreen> {
  final WardrobeService _wardrobeService = WardrobeService();

  bool _isLoading = true;
  int _wardrobeCount = 0;

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
    _loadWardrobeCount();
    _restoreSelections();
  }

  @override
  void didUpdateWidget(StyleMeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset outfit index when new outfits arrive
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

  Future<void> _loadWardrobeCount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final count = await _wardrobeService.getWardrobeCount(user.id);
    if (mounted) {
      setState(() {
        _wardrobeCount = count;
        _isLoading = false;
      });
    }
  }

  void _startGeneration() {
    if (_selectedOccasion == null || _selectedTime == null || _selectedBoldness == null) return;

    widget.onStartGeneration({
      'occasion': _selectedOccasion!,
      'time': _selectedTime!,
      'weather': 'warm', // Weather is contextual, defaulting to warm
      'boldness': _selectedBoldness!,
    });
  }

  void _generateSurprise() {
    widget.onStartGeneration({
      'occasion': 'Casual',
      'time': 'Afternoon',
      'weather': 'warm',
      'boldness': 'Bold',
    });
  }

  void _resetToSelection() {
    widget.onClearResults();
  }

  void _wearOutfit(Outfit outfit) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Logged!',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from favorites'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        _savedOutfitIds.add(outfit.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to favorites'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SkeletonOutfitGrid(),
        ),
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
      return _buildResultsView();
    }

    return _buildSelectionView();
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
                const Icon(
                  Icons.checkroom,
                  size: 48,
                  color: AppColors.cherry,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Not enough items yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add at least 5 pieces to get outfit suggestions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: widget.onNavigateToWardrobe,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cherry,
                    side: const BorderSide(color: AppColors.cherry),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Go to Wardrobe',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
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
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "We couldn't build your outfits",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    widget.onClearError();
                    _startGeneration();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cherry,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
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
      body: Stack(
        children: [
          // Dimmed selection view
          Opacity(
            opacity: 0.4,
            child: IgnorePointer(
              child: _buildSelectionViewContent(),
            ),
          ),
          // Bottom sheet overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.espresso.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loadingText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: widget.progress > 0 ? widget.progress : null,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cherry),
                        minHeight: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Selection view content without Scaffold (for reuse in loading state)
  Widget _buildSelectionViewContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            _buildWeatherContext(),
            if (_hasAnySelection) ...[
              const SizedBox(height: 16),
              _buildSelectedPills(),
            ],
            const SizedBox(height: 24),
            _buildQuestion(
              "What's the occasion?",
              _occasions,
              _selectedOccasion,
              (_) {},
            ),
            if (_selectedOccasion != null) ...[
              const SizedBox(height: 16),
              _buildQuestion(
                "When are you heading out?",
                _times,
                _selectedTime,
                (_) {},
              ),
            ],
            if (_selectedTime != null) ...[
              const SizedBox(height: 16),
              _buildQuestion(
                "How bold are we going?",
                _boldnessLevels,
                _selectedBoldness,
                (_) {},
              ),
            ],
            if (_allAnswered) ...[
              const SizedBox(height: 24),
              _buildPreviewText(),
              const SizedBox(height: 12),
              _GetOutfitsButton(onPressed: _startGeneration),
              const SizedBox(height: 12),
              _buildSurpriseMeLink(),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper to clear cascading selections
  void _clearOccasion() {
    setState(() {
      _selectedOccasion = null;
      _selectedTime = null;
      _selectedBoldness = null;
    });
    _notifyAllAnsweredChanged();
  }

  void _clearTime() {
    setState(() {
      _selectedTime = null;
      _selectedBoldness = null;
    });
    _notifyAllAnsweredChanged();
  }

  void _clearBoldness() {
    setState(() {
      _selectedBoldness = null;
    });
    _notifyAllAnsweredChanged();
  }

  bool get _hasAnySelection =>
      _selectedOccasion != null || _selectedTime != null || _selectedBoldness != null;

  bool get _allAnswered =>
      _selectedOccasion != null && _selectedTime != null && _selectedBoldness != null;

  void _notifyAllAnsweredChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onAllAnsweredChanged?.call(_allAnswered);
    });
  }

  // ===== SELECTION VIEW =====
  Widget _buildSelectionView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildWeatherContext(),
              if (_hasAnySelection) ...[
                const SizedBox(height: 16),
                _buildSelectedPills(),
              ],
              const SizedBox(height: 24),
              // Question 1: Always visible
              _buildQuestion(
                "What's the occasion?",
                _occasions,
                _selectedOccasion,
                (value) {
                  setState(() {
                    if (_selectedOccasion == value) {
                      _clearOccasion();
                    } else {
                      _selectedOccasion = value;
                      _notifyAllAnsweredChanged();
                    }
                  });
                },
              ),
              // Question 2: After Q1 answered
              if (_selectedOccasion != null) ...[
                const SizedBox(height: 16),
                _buildAnimatedQuestion(
                  "When are you heading out?",
                  _times,
                  _selectedTime,
                  (value) {
                    setState(() {
                      if (_selectedTime == value) {
                        _clearTime();
                      } else {
                        _selectedTime = value;
                        _notifyAllAnsweredChanged();
                      }
                    });
                  },
                ),
              ],
              // Question 3: After Q2 answered
              if (_selectedTime != null) ...[
                const SizedBox(height: 16),
                _buildAnimatedQuestion(
                  "How bold are we going?",
                  _boldnessLevels,
                  _selectedBoldness,
                  (value) {
                    setState(() {
                      if (_selectedBoldness == value) {
                        _clearBoldness();
                      } else {
                        _selectedBoldness = value;
                        _notifyAllAnsweredChanged();
                      }
                    });
                  },
                ),
              ],
              // Button: After all answered
              if (_allAnswered) ...[
                const SizedBox(height: 24),
                _buildPreviewText(),
                const SizedBox(height: 12),
                _GetOutfitsButton(onPressed: _startGeneration),
                const SizedBox(height: 12),
                _buildSurpriseMeLink(),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Text(
      'Style Me',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildWeatherContext() {
    return Row(
      children: [
        const Text(
          '☀️ 72°F Sunny • Chicago, IL',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            // TODO: Show weather override options
          },
          child: const Text(
            'Change',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.cherry,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (_selectedOccasion != null)
            _buildPill(_selectedOccasion!, _clearOccasion),
          if (_selectedTime != null) ...[
            const SizedBox(width: 8),
            _buildPill(_selectedTime!, _clearTime),
          ],
          if (_selectedBoldness != null) ...[
            const SizedBox(width: 8),
            _buildPill(_selectedBoldness!, _clearBoldness),
          ],
        ],
      ),
    );
  }

  Widget _buildPill(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.cherry,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(
    String title,
    List<String> options,
    String? selected,
    ValueChanged<String> onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildChipRow(options, selected, onSelected),
      ],
    );
  }

  Widget _buildAnimatedQuestion(
    String title,
    List<String> options,
    String? selected,
    ValueChanged<String> onSelected,
  ) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: _buildQuestion(title, options, selected, onSelected),
    );
  }

  Widget _buildChipRow(
    List<String> options,
    String? selected,
    ValueChanged<String> onSelected,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = option == selected;
        return _SelectableChip(
          label: option,
          isSelected: isSelected,
          onTap: () => onSelected(option),
        );
      }).toList(),
    );
  }

  Widget _buildPreviewText() {
    final occasion = _selectedOccasion?.toLowerCase() ?? '';
    final time = _selectedTime?.toLowerCase() ?? '';
    return Center(
      child: Text(
        '4 $occasion $time looks coming',
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildSurpriseMeLink() {
    return GestureDetector(
      onTap: widget.isGenerating ? null : _generateSurprise,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'or surprise me',
            style: TextStyle(
              fontSize: 14,
              color: widget.isGenerating ? AppColors.textMuted.withValues(alpha: 0.5) : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward,
            size: 16,
            color: widget.isGenerating ? AppColors.textMuted.withValues(alpha: 0.5) : AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  // ===== RESULTS VIEW =====
  Widget _buildResultsView() {
    final currentOutfit = widget.pendingOutfits![_selectedOutfitIndex];
    final isSaved = _savedOutfitIds.contains(currentOutfit.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResultsHeader(),
                    const SizedBox(height: 16),
                    _buildMainOutfitCard(currentOutfit),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        currentOutfit.styleHook,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPrimaryCTA(currentOutfit),
                    const SizedBox(height: 12),
                    _buildSecondaryActions(currentOutfit, isSaved),
                    const SizedBox(height: 24),
                    _buildThumbnailStrip(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Your Outfits',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        OutlinedButton(
          onPressed: _resetToSelection,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textMuted,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Redo',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildMainOutfitCard(Outfit outfit) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(outfit.id),
        height: MediaQuery.of(context).size.height * 0.5,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.espresso.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Placeholder outfit image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.style_outlined,
                      size: 64,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${outfit.items.length} items',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Score badge with animation
            Positioned(
              top: 12,
              right: 12,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('badge_${outfit.id}'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cherry.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${outfit.matchScore}% match',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryCTA(Outfit outfit) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.espresso.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => _wearOutfit(outfit),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cherry,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Wear This Today',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActions(Outfit outfit, bool isSaved) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Save button
        IconButton(
          onPressed: () => _toggleSave(outfit),
          icon: TweenAnimationBuilder<double>(
            key: ValueKey('save_${outfit.id}_$isSaved'),
            tween: Tween(begin: 1.0, end: isSaved ? 1.2 : 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Icon(
                  isSaved ? Icons.favorite : Icons.favorite_border,
                  color: AppColors.cherry,
                  size: 28,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 24),
        // Share button
        IconButton(
          onPressed: () => _showShareSheet(outfit),
          icon: const Icon(
            Icons.ios_share,
            color: AppColors.textMuted,
            size: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailStrip() {
    return Center(
      child: SizedBox(
        height: 70,
        child: ListView.separated(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          itemCount: widget.pendingOutfits!.length,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final isSelected = index == _selectedOutfitIndex;
            final outfit = widget.pendingOutfits![index];

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedOutfitIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.cherry : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${outfit.matchScore}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.cherry : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===== SHARE BOTTOM SHEET =====
  void _showShareSheet(Outfit outfit) {
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
              // Drag handle
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
                  'Share this look',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _buildShareOption(
                Icons.link,
                'Copy Link',
                () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildShareOption(
                Icons.download,
                'Save Image',
                () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Image saved to gallery'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildShareOption(
                Icons.camera_alt,
                'Share to Instagram',
                () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening Instagram...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildShareOption(
                Icons.more_horiz,
                'More...',
                () {
                  Navigator.pop(context);
                  // Would use share_plus package in production
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== SELECTABLE CHIP WIDGET =====
class _SelectableChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SelectableChip> createState() => _SelectableChipState();
}

class _SelectableChipState extends State<_SelectableChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 50),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFFC4515E)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFFC4515E)
                  : const Color(0xFFE5E5E5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isSelected) ...[
                const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.isSelected
                      ? Colors.white
                      : const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== GET OUTFITS BUTTON WIDGET =====
class _GetOutfitsButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _GetOutfitsButton({required this.onPressed});

  @override
  State<_GetOutfitsButton> createState() => _GetOutfitsButtonState();
}

class _GetOutfitsButtonState extends State<_GetOutfitsButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.mediumImpact();
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 50),
        child: Container(
          height: 60,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.cherry,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.cherry.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Get My Outfits',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
