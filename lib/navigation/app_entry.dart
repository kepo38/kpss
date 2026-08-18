import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/exam_track_onboarding_screen.dart';
import '../screens/main_shell.dart';
import '../services/auth_service.dart';
import '../services/kpss_preference_service.dart';
import '../widgets/boot_splash_screen.dart';

/// Oturum açık kullanıcı — onboarding veya ana kabuk.
/// Sınav seçimi auth tamamlanmadan gösterilebilir.
class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        if (!KpssPreferenceService.instance.hasChosenExam) {
          final user = AuthService.instance.user ?? UserModel.placeholderGuest();
          return ExamTrackOnboardingScreen(user: user);
        }

        final user = AuthService.instance.user;
        if (user == null) {
          return const BootSplashScreen();
        }
        return MainShell(user: user);
      },
    );
  }
}
