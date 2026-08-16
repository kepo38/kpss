import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Boot sırasında — logo yok, yalnızca arka plan (native splash ile aynı renk).
class BootSplashScreen extends StatelessWidget {
  const BootSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.ink,
      body: SizedBox.expand(),
    );
  }
}
