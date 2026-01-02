import 'package:flutter/material.dart';
import 'package:styleum/theme/theme.dart';
import 'package:styleum/widgets/empty_state.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: EmptyState(
          headline: 'Ready for a challenge?',
          description: 'Weekly style challenges unlock badges and rewards',
          icon: Icons.emoji_events_outlined,
          ctaLabel: 'Coming Soon',
          onCtaPressed: () {
            // TODO: Navigate to challenges when implemented
          },
        ),
      ),
    );
  }
}
