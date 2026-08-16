import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/cloud_sync_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/scale_button.dart';

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _service = CloudSyncService.instance;
  bool _loading = false;

  Future<void> _signIn(Future<void> Function() action) async {
    setState(() => _loading = true);
    await action();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Bulut Senkronizasyon'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.cloud_sync_outlined, size: 64, color: AppTheme.lightPrimary),
            const SizedBox(height: 16),
            Text(
              'Verilerinizi tüm cihazlarda senkronize tutun',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 16),
            ),
            const SizedBox(height: 32),
            if (_service.isConnected) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Bağlı: ${_service.userEmail}'),
                  subtitle: _service.lastSync != null
                      ? Text(
                          'Son senkron: ${DateFormat('d MMM HH:mm', 'tr').format(_service.lastSync!)}',
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              ScaleButton(
                onPressed: _loading ? null : () => _signIn(_service.syncNow),
                child: FilledButton.icon(
                  onPressed: _loading ? null : () => _signIn(_service.syncNow),
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Şimdi Senkronize Et'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await _service.signOut();
                  setState(() {});
                },
                child: const Text('Çıkış Yap'),
              ),
            ] else ...[
              ScaleButton(
                onPressed: _loading
                    ? null
                    : () => _signIn(_service.signInWithGoogle),
                child: OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _signIn(_service.signInWithGoogle),
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Google ile Giriş Yap'),
                ),
              ),
              const SizedBox(height: 12),
              ScaleButton(
                onPressed: _loading
                    ? null
                    : () => _signIn(_service.signInWithApple),
                child: FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _signIn(_service.signInWithApple),
                  icon: const Icon(Icons.apple),
                  label: const Text('Apple ile Giriş Yap'),
                ),
              ),
            ],
            const Spacer(),
            Text(
              'Konu ilerlemesi, görevler, deneme sonuçları ve rozetler senkronize edilir.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
