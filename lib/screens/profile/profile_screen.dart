import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/screens/achievements/achievements_screen.dart';
import 'package:styleum/screens/profile/settings_screen.dart';
import 'package:styleum/services/achievements_service.dart';
import 'package:styleum/services/profile_service.dart';
import 'package:styleum/services/wardrobe_service.dart';
import 'package:styleum/theme/theme.dart';
import 'package:styleum/widgets/skeleton_loader.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final WardrobeService _wardrobeService = WardrobeService();
  final AchievementsService _achievementsService = AchievementsService();

  bool _isLoading = true;
  Profile? _profile;
  int _wardrobeCount = 0;
  Map<String, int> _achievementStats = {'total': 22, 'unlocked': 0, 'unseen': 0};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final results = await Future.wait([
      _profileService.getProfile(user.id),
      _wardrobeService.getWardrobeItems(user.id),
      _achievementsService.getAchievementStats(user.id),
    ]);

    if (mounted) {
      setState(() {
        _profile = results[0] as Profile?;
        _wardrobeCount = (results[1] as List<WardrobeItem>).length;
        _achievementStats = results[2] as Map<String, int>;
        _isLoading = false;
      });
    }
  }

  String _getDisplayName() {
    // 1. Try Google sign-in metadata (most reliable for display name)
    final user = Supabase.instance.client.auth.currentUser;
    final googleName = user?.userMetadata?['full_name'] as String? ??
        user?.userMetadata?['name'] as String?;
    if (googleName != null && googleName.isNotEmpty) {
      return googleName.split(' ').first; // First name only
    }

    // 2. Try profile username
    final username = _profile?.username;
    if (username != null &&
        username.isNotEmpty &&
        !username.toLowerCase().startsWith('user_')) {
      return username;
    }

    // 3. Try email prefix
    final email = user?.email;
    if (email != null && email.contains('@')) {
      final prefix = email.split('@').first;
      if (!prefix.startsWith('user_') && prefix.length <= 20) {
        return prefix;
      }
    }

    // 4. Final fallback
    return 'Stylist';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _buildSkeletonProfile(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.slate, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: AppSpacing.lg),
              _buildStatsRow(),
              const SizedBox(height: AppSpacing.lg),
              _buildStyleJourneyRow(),
              const SizedBox(height: AppSpacing.lg),
              _buildReferralCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonProfile() {
    return SkeletonLoader(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const SkeletonCircle(size: 96),
            const SizedBox(height: 16),
            SkeletonText(width: 120, height: 20),
            const SizedBox(height: 8),
            SkeletonText(width: 80, height: 14),
            const SizedBox(height: 32),
            SkeletonBox(height: 80, borderRadius: 12),
            const SizedBox(height: 24),
            SkeletonBox(height: 180, borderRadius: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Avatar
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.slate.withValues(alpha: 0.1),
          ),
          child: const Icon(
            Icons.person,
            size: 48,
            color: AppColors.slate,
          ),
        ),
        const SizedBox(height: 16),
        // Name
        Text(
          _getDisplayName(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        // Location
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
            SizedBox(width: 4),
            Text(
              'Chicago, IL',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final streak = _profile?.currentStreak ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [AppShadows.subtle],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('$_wardrobeCount', 'Items'),
          _buildStatDivider(),
          _buildStatItem('$streak', 'Day Streak'),
          _buildStatDivider(),
          _buildStatItem('0', 'Outfits'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.border,
    );
  }

  Widget _buildReferralCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [AppShadows.card],
      ),
      child: Column(
        children: [
          _buildGradientOrbs(),
          const SizedBox(height: 16),
          const Text(
            'Know someone who stares at\ntheir closet too long?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _shareApp,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.textPrimary, width: 1),
              ),
              child: const Center(
                child: Text(
                  'Send them Styleum',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "You'll both get a free month",
            style: TextStyle(
              fontSize: 12,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientOrbs() {
    return SizedBox(
      width: 84,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: _buildOrb(
              const [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
            ),
          ),
          _buildOrb(
            const [Color(0xFF6B8CFF), Color(0xFFA78BFA)],
          ),
          Positioned(
            right: 0,
            child: _buildOrb(
              const [Color(0xFF6EE7B7), Color(0xFF5EEAD4)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(List<Color> colors) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }

  void _shareApp() {
    Share.share(
      'Check out Styleum - it picks outfits from your closet. https://styleum.app',
    );
  }

  Widget _buildStyleJourneyRow() {
    final unlocked = _achievementStats['unlocked'] ?? 0;
    final total = _achievementStats['total'] ?? 22;
    final unseen = _achievementStats['unseen'] ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          AppPageRoute(page: const AchievementsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                color: AppColors.slate,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Style Journey', style: AppTypography.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '$unlocked of $total achievements',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
            if (unseen > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.slate,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unseen',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

}
