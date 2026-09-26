import 'package:flutter/material.dart';

import '../services/store_rating_service.dart';
import '../theme/app_theme.dart';

/// Play Store güncelleme uyarısı — uygulama açılışında bir kez gösterilir.
Future<bool?> showAppUpdateDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog(
      icon: Icon(
        Icons.system_update_alt_rounded,
        size: 48,
        color: AppTheme.champagne.withValues(alpha: 0.95),
      ),
      title: const Text('Güncelleme Var'),
      content: const Text(
        'Tavsiye edilen son versiyonu indirmek için Google Play açılsın mı?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Şimdi Değil',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Evet'),
        ),
      ],
    ),
  );
}

Future<bool> showAppUpdateDialogAndMaybeOpenStore(BuildContext context) async {
  final openStore = await showAppUpdateDialog(context);
  if (openStore == true) {
    await StoreRatingService.openStoreListing();
    return true;
  }
  return false;
}
