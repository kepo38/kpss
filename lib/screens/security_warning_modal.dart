import 'package:flutter/material.dart';

import '../constants/brand_constants.dart';

/// Kapatılamayan güvenli bağlantı uyarısı — VPN/DNS tespit edildiğinde gösterilir.
Future<void> showSecurityWarningModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        icon: Icon(
          Icons.shield_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Güvenli Bağlantı Uyarısı'),
        content: const Text(
          'Cihazınızda aktif bir VPN tüneli veya reklam engelleyici özel DNS '
          'tespit edildi. ${BrandConstants.appName} içeriğini korumak için uygulama '
          'kullanımı geçici olarak kilitlenmiştir.\n\n'
          'Lütfen VPN ve özel DNS ayarlarınızı kapatıp uygulamayı yeniden başlatın.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              // Kapatılamaz modal — yalnızca bilgilendirme.
            },
            child: const Text('Anladım'),
          ),
        ],
      ),
    ),
  );
}
