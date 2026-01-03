import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/services/wardrobe_service.dart';
import 'package:styleum/services/ai_analysis_service.dart';
import 'package:styleum/models/ai_analysis.dart';
import 'package:styleum/theme/theme.dart';

class StyleShuffleScreen extends StatefulWidget {
  const StyleShuffleScreen({super.key});

  @override
  State<StyleShuffleScreen> createState() => _StyleShuffleScreenState();
}

class _StyleShuffleScreenState extends State<StyleShuffleScreen> {
  final WardrobeService _wardrobeService = WardrobeService();
  List<WardrobeItem> _items = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  int _likeCount = 0;
  int _skipCount = 0;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final items = await _wardrobeService.getWardrobeItems(user.id);
    items.shuffle();

    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  void _onLike() {
    if (_currentIndex >= _items.length) return;

    final item = _items[_currentIndex];
    StyleLearningService().recordInteraction(
      type: StyleInteractionType.like,
      itemId: item.id,
    );
    HapticFeedback.lightImpact();

    setState(() {
      _likeCount++;
      _currentIndex++;
    });
  }

  void _onSkip() {
    if (_currentIndex >= _items.length) return;

    final item = _items[_currentIndex];
    StyleLearningService().recordInteraction(
      type: StyleInteractionType.skip,
      itemId: item.id,
    );
    HapticFeedback.lightImpact();

    setState(() {
      _skipCount++;
      _currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Style Shuffle', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.pink, size: 18),
                const SizedBox(width: 4),
                Text('$_likeCount', style: const TextStyle(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentIndex >= _items.length
              ? _buildComplete()
              : _buildCard(),
    );
  }

  Widget _buildCard() {
    final item = _items[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress
          LinearProgressIndicator(
            value: _currentIndex / _items.length,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation(AppColors.slate),
          ),
          const SizedBox(height: 8),
          Text(
            '${_currentIndex + 1} of ${_items.length}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Card
          Expanded(
            child: Dismissible(
              key: Key(item.id),
              onDismissed: (direction) {
                if (direction == DismissDirection.startToEnd) {
                  _onLike();
                } else {
                  _onSkip();
                }
              },
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 32),
                child: const Icon(Icons.favorite, color: Colors.green, size: 48),
              ),
              secondaryBackground: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 32),
                child: const Icon(Icons.skip_next, color: Colors.grey, size: 48),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [AppShadows.card],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Expanded(
                      child: item.photoUrl != null
                          ? Image.network(item.photoUrl!, fit: BoxFit.cover, width: double.infinity)
                          : Container(color: AppColors.border),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName ?? 'Unknown Item',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.styleBucket.name} \u2022 ${item.category.name}',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(Icons.close, 'Skip', Colors.grey, _onSkip),
              _buildActionButton(Icons.favorite, 'Like', Colors.pink, _onLike),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildComplete() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              'All caught up!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You liked $_likeCount items, skipped $_skipCount',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
