import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/services/profile_service.dart';
import 'package:styleum/services/wardrobe_service.dart';
import 'package:styleum/screens/wardrobe/add_item_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color cherry = Color(0xFFC4515E);
  static const Color background = Color(0xFFFFFFFF);
  static const Color inputFieldBackground = Color(0xFFF7F7F7);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E5E5);
  static const Color success = Color(0xFF5F7A61);
  static const Color error = Color(0xFF9B3C46);
  static const Color espressoShadow = Color(0x142C1810);

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(child: CircularProgressIndicator(color: cherry)),
      );
    }

    final firstName = _getFirstName();
    final greeting = firstName != null
        ? '${_getGreeting()}, $firstName!'
        : '${_getGreeting()}!';

    return Scaffold(
      backgroundColor: background,
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
              if (_wardrobeCount < 5)
                _buildAddItemsCard()
              else
                _buildTopPickCard(),
              const SizedBox(height: 16),
              _buildChallengeRow(),
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
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subheading,
                style: const TextStyle(fontSize: 14, color: textMuted),
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
                border: Border.all(color: borderColor),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: textMuted,
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
        color: cherry,
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
          style: TextStyle(fontSize: 14, color: textMuted),
        ),
      ],
    );
  }

  Widget _buildWardrobeThumbnails() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final hasItem = index < _wardrobeItems.length;
        final photoUrl = hasItem ? _wardrobeItems[index].photoUrl : null;

        return Padding(
          padding: EdgeInsets.only(left: index > 0 ? 12 : 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: photoUrl != null
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.checkroom,
                        color: textMuted,
                        size: 24,
                      ),
                    )
                  : const Icon(Icons.checkroom, color: textMuted, size: 24),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAddItemsCard() {
    final itemsNeeded = 5 - _wardrobeCount;
    final progress = _wardrobeCount / 5;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: espressoShadow,
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildWardrobeThumbnails(),
          const SizedBox(height: 20),
          const Text(
            'Build Your Wardrobe',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add $itemsNeeded more item${itemsNeeded == 1 ? '' : 's'} to unlock outfit suggestions',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: borderColor,
              valueColor: const AlwaysStoppedAnimation<Color>(cherry),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: cherry.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddItemScreen(onItemAdded: () => _loadData()),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'Add Items',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cherry,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPickCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: espressoShadow,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 250,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Center(
                  child: Icon(Icons.image_outlined, size: 48, color: textMuted),
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
                    color: cherry,
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
                    color: textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Smart casual with a bold twist',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: cherry.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cherry,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Wear This Today',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cherry,
                          side: const BorderSide(color: cherry),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'See All 4',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
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
            color: cherry.withValues(alpha: 0.05),
            border: Border.all(color: borderColor),
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
                  color: textPrimary,
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Color Pop',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        value: 0.6,
                        backgroundColor: borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(cherry),
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
                      color: cherry,
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
