import 'package:flutter/material.dart';

import '../constants/brand_constants.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Yalnızca Google / Play Store hesabı ile giriş.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService.instance;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _signIn() async {
    final ok = await _auth.signInWithGoogle();
    if (!ok && mounted && _auth.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_auth.lastError!),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _auth.busy;

    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(
                child: Image.asset(
                  BrandConstants.logoAsset,
                  width: 148,
                  height: 148,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.track_changes_rounded,
                    size: 88,
                    color: AppTheme.champagne.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                BrandConstants.brandLine1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  height: 0.95,
                  letterSpacing: -1.5,
                  color: Colors.white,
                ),
              ),
              Text(
                BrandConstants.brandLine2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  height: 0.95,
                  letterSpacing: 6,
                  color: AppTheme.champagneLight,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Play Store’daki Google hesabınla giriş yap.\nİlerlemen ve premium bu hesaba bağlanır.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: busy ? null : _signIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.ink,
                    disabledBackgroundColor: Colors.white24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.g_mobiledata, size: 28),
                            SizedBox(width: 6),
                            Text(
                              'Google ile devam et',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Cihazındaki Google hesabı kullanılır.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
