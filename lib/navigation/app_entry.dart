import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/exam_track_onboarding_screen.dart';
import '../screens/main_shell.dart';
import '../services/auth_service.dart';
import '../services/kpss_preference_service.dart';

/// Oturum açık kullanıcı — onboarding veya ana kabuk.
/// Sınav seçimi auth tamamlanmadan gösterilebilir.
class AppEntry extends StatelessWidget {
  final VoidCallback? onExamChosen;

  const AppEntry({super.key, this.onExamChosen});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AuthService.instance,
        KpssPreferenceService.instance,
      ]),
      builder: (context, _) {
        if (!KpssPreferenceService.instance.hasChosenExam) {
          final user = AuthService.instance.user ?? UserModel.placeholderGuest();
          return ExamTrackOnboardingScreen(
            user: user,
            onExamChosen: onExamChosen,
          );
        }

        final user = AuthService.instance.user ?? UserModel.placeholderGuest();
        return MainShell(user: user);
      },
    );
  }
}
