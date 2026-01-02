import 'package:flutter/material.dart';
import 'package:styleum/theme/theme.dart';
import 'package:styleum/widgets/empty_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: EmptyState(
          headline: 'Complete your profile',
          description: 'Add your style preferences to get better recommendations',
          icon: Icons.person_outline,
          ctaLabel: 'Coming Soon',
          onCtaPressed: () {
            // TODO: Navigate to profile edit when implemented
          },
        ),
      ),
    );
  }
}
