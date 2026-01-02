import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:styleum/screens/achievements/achievements_screen.dart';
import 'package:styleum/screens/home/home_screen.dart';
import 'package:styleum/screens/wardrobe/wardrobe_screen.dart';
import 'package:styleum/screens/style_me/style_me_screen.dart';
import 'package:styleum/screens/profile/profile_screen.dart';
import 'package:styleum/services/achievements_service.dart';
import 'package:styleum/services/outfit_service.dart';
import 'package:styleum/theme/theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Style Me generation state (lifted from StyleMeScreen)
  bool _isStyleMeGenerating = false;
  double _styleMeProgress = 0.0;
  List<Outfit>? _pendingOutfits;
  String? _styleMeError;
  Map<String, dynamic>? _lastSelections;

  final OutfitService _outfitService = OutfitService();

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // Dismiss any snackbars when navigating to Style Me tab
    if (index == 2) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  Future<void> _startStyleMeGeneration(Map<String, dynamic> selections) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isStyleMeGenerating = true;
      _styleMeProgress = 0.0;
      _styleMeError = null;
      _lastSelections = selections;
    });

    // Simulate progress for better UX
    for (int i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted && _isStyleMeGenerating) {
        setState(() => _styleMeProgress = i / 10);
      }
    }

    try {
      final outfits = await _outfitService.generateOutfits(
        userId: user.id,
        occasion: selections['occasion'] as String,
        timeOfDay: selections['time'] as String,
        weather: selections['weather'] as String,
        boldness: selections['boldness'] as String,
      );

      if (mounted) {
        setState(() {
          _pendingOutfits = outfits;
          _isStyleMeGenerating = false;
        });

        // Track outfit generation achievement
        AchievementsService().recordAction(
          user.id,
          AchievementAction.outfitGenerated,
        );

        // Show toast only if not on Style Me tab (hide when viewing results on Style Me tab)
        if (_currentIndex != 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Your outfits are ready!'),
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () => _onTabTapped(2),
              ),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStyleMeGenerating = false;
          _styleMeError = 'Failed to generate outfits. Please try again.';
        });
      }
    }
  }

  void _clearStyleMeResults() {
    setState(() {
      _pendingOutfits = null;
    });
  }

  void _clearStyleMeError() {
    setState(() {
      _styleMeError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              const HomeScreen(),
              const WardrobeScreen(),
              StyleMeScreen(
                isGenerating: _isStyleMeGenerating,
                progress: _styleMeProgress,
                pendingOutfits: _pendingOutfits,
                errorMessage: _styleMeError,
                lastSelections: _lastSelections,
                onStartGeneration: _startStyleMeGeneration,
                onClearResults: _clearStyleMeResults,
                onClearError: _clearStyleMeError,
                onNavigateToWardrobe: () => _onTabTapped(1),
              ),
              const AchievementsScreen(),
              const ProfileScreen(),
            ],
          ),
          // Progress bar - above bottom nav (only show when on Style Me tab)
          if (_isStyleMeGenerating && _currentIndex == 2)
            Positioned(
              bottom: 56, // Just above BottomNavigationBar
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _styleMeProgress,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.slate),
                minHeight: 3,
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                ),
                _buildNavItem(
                  index: 1,
                  icon: CupertinoIcons.square_grid_2x2,
                  activeIcon: CupertinoIcons.square_grid_2x2_fill,
                  label: 'Wardrobe',
                ),
                _buildStyleMeNavItem(index: 2),
                _buildNavItem(
                  index: 3,
                  icon: Icons.emoji_events_outlined,
                  activeIcon: Icons.emoji_events,
                  label: 'Achievements',
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.slate : AppColors.textMuted,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppColors.slate : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleMeNavItem({required int index}) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: InkWell(
          onTap: () => _onTabTapped(index),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.slate,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.style,
                  color: AppColors.slate,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  'Style Me',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.slate,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
