import 'package:flutter/material.dart';

class StyleMeScreen extends StatelessWidget {
  const StyleMeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFDFBF7),
      body: Center(
        child: Text(
          'Style Me',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
      ),
    );
  }
}
