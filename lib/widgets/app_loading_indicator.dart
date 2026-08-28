import 'package:flutter/material.dart';

/// Unified single loading indicator for the entire application.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D1D36),
            Color(0xFF0B172A),
            Color(0xFF091222),
          ],
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            color: Color(0xFF2CDFA2),
            strokeWidth: 3.0,
          ),
        ),
      ),
    );
  }
}

/// Fullscreen scaffold wrapper around [AppLoadingIndicator].
class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A1628),
      body: AppLoadingIndicator(),
    );
  }
}

