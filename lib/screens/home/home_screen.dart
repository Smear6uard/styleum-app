import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/services/profile_service.dart';
import 'package:styleum/services/wardrobe_service.dart';
import 'package:styleum/screens/wardrobe/add_item_screen.dart';
import 'package:styleum/theme/theme.dart';
import 'package:styleum/widgets/app_button.dart';
import 'package:styleum/widgets/animated_list_item.dart';
import 'package:styleum/widgets/wardrobe_onboarding_card.dart';

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
  List<WardrobeItem> _wardrobeItems = [];

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
        _wardrobeItems = results[1] as List<WardrobeItem>;
        _wardrobeCount = _wardrobeItems.length;
        _isLoading = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String? _getFirstName() {
    final username = _profile?.username;
    if (username == null || username.isEmpty) return null;
    if (username.toLowerCase().startsWith('user_')) return null;

    // Get first word as first name
    final parts = username.trim().split(RegExp(r'\s+'));
    final firstName = parts.first;

    // Capitalize first letter
    if (firstName.isEmpty) return null;
    return firstName[0].toUpperCase() + firstName.substring(1).toLowerCase();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.slate)),
      );
    }

    final firstName = _getFirstName();
    final greeting = firstName != null
        ? '${_getGreeting()}, $firstName!'
        : '${_getGreeting()}!';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(greeting),
              const SizedBox(height: 8),
              _buildWeatherRow(),
              const SizedBox(height: 24),
              if (_wardrobeCount >= 5) ...[
                AnimatedEntrance(child: _buildTopPickCard()),
                const SizedBox(height: 16),
              ],
              AnimatedEntrance(
                delay: Duration(milliseconds: _wardrobeCount >= 5 ? 100 : 0),
                child: _buildChallengeRow(),
              ),
              const SizedBox(height: 16),
              AnimatedEntrance(
                delay: Duration(milliseconds: _wardrobeCount >= 5 ? 200 : 100),
                child: WardrobeOnboardingCard(
                  wardrobeCount: _wardrobeCount,
                  onAddPressed: _openAddItemSheet,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String greeting) {
    final streak = _profile?.currentStreak ?? 0;
    final subheading = _wardrobeCount >= 5
        ? "Here's your look for today"
        : "Let's build your closet";

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subheading,
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Row(
          children: [
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
            const SizedBox(width: 8),
            _buildStreakBadge(streak),
          ],
        ),
      ],
    );
  }

  Widget _buildStreakBadge(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.slate,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherRow() {
    return const Row(
      children: [
        Icon(Icons.wb_sunny, color: Color(0xFFFBBF24), size: 20),
        SizedBox(width: 8),
        Text(
          '72°F • Sunny • Chicago, IL',
          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildTopPickCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Center(
                  child: Icon(Icons.image_outlined, size: 48, color: AppColors.textMuted),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.slate,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '94',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Top Pick",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Smart casual with a bold twist',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.primary(
                        label: 'Wear This Today',
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton.secondary(
                        label: 'See All 4',
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeRow() {
    final streak = _profile?.currentStreak ?? 0;

    return GestureDetector(
      onTap: () {
        // Navigate to Challenges tab (index 3)
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🔥 $streak day streak',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Color Pop',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 0.6,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.slate),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '3/5',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slateDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
