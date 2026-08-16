import 'package:flutter/material.dart';

/// Tüm alt sayfalarda kullanılan belirgin geri tuşu.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AppBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
      tooltip: 'Geri',
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}
