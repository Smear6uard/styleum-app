import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  bool _isLoading = true;
  Profile? _profile;
  int _wardrobeCount = 0;

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
    ]);

    if (mounted) {
      setState(() {
        _profile = results[0] as Profile?;
        _wardrobeCount = (results[1] as List<WardrobeItem>).length;
        _isLoading = false;
      });
    }
  }

  String _getDisplayName() {
    final username = _profile?.username;
    if (username == null || username.isEmpty) return 'Stylist';
    if (username.toLowerCase().startsWith('user_')) return 'Stylist';
    return username;
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: AppSpacing.lg),
              _buildStatsRow(),
              const SizedBox(height: AppSpacing.lg),
              _buildFriendsCard(),
              const SizedBox(height: AppSpacing.lg),
              _buildSettingsSection(),
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

  Widget _buildFriendsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Style is better with friends',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Share outfits and get opinions.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          // Placeholder silhouettes
          Row(
            children: [
              _buildPlaceholderAvatar(0),
              _buildPlaceholderAvatar(1),
              _buildPlaceholderAvatar(2),
              const SizedBox(width: 12),
              const Text(
                'Invite friends',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Add friends button
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Coming soon! We'll notify you."),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Add friends',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

  Widget _buildPlaceholderAvatar(int index) {
    final colors = [
      const Color(0xFFE8D5D5),
      const Color(0xFFD5E0E8),
      const Color(0xFFE8E5D5),
    ];

    return Container(
      width: 40,
      height: 40,
      margin: EdgeInsets.only(left: index > 0 ? -12 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors[index],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(
        Icons.person_outline,
        size: 20,
        color: colors[index].withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      children: [
        _buildSettingsItem(
          icon: Icons.notifications_outlined,
          label: 'Notifications',
          onTap: () {},
        ),
        _buildSettingsItem(
          icon: Icons.lock_outline,
          label: 'Privacy',
          onTap: () {},
        ),
        _buildSettingsItem(
          icon: Icons.help_outline,
          label: 'Help & Support',
          onTap: () {},
        ),
        _buildSettingsItem(
          icon: Icons.logout,
          label: 'Sign Out',
          onTap: () async {
            await Supabase.instance.client.auth.signOut();
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isDestructive ? AppColors.danger : AppColors.textMuted,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? AppColors.danger : AppColors.textPrimary,
                ),
              ),
            ),
            if (!isDestructive)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
