import 'package:flutter/material.dart';

import '../services/theme_preference_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';

/// Profil / ayarlar için gece-gündüz-sistem seçici.
class ThemePreferencePicker extends StatelessWidget {
  final bool embedded;
  final bool neon;

  const ThemePreferencePicker({
    super.key,
    this.embedded = false,
    this.neon = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemePreferenceService.instance,
      builder: (context, _) {
        final service = ThemePreferenceService.instance;
        final selected = service.preference;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!embedded) ...[
              Text(
                'GÖRÜNÜM',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.champagne.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                child: Text(
                  'Görünüm',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(neon && embedded ? 4 : 6),
              decoration: BoxDecoration(
                color: neon && embedded ? Colors.transparent : AppTheme.inkSoft,
                borderRadius: BorderRadius.circular(12),
                border: neon && embedded
                    ? Border.all(color: AppTheme.neonEdge.withValues(alpha: 0.22))
                    : embedded
                        ? null
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
              ),
              child: Row(
                children: [
                  for (final value in AppThemePreference.values)
                    Expanded(
                      child: _ThemeChip(
                        label: service.labelFor(value),
                        icon: service.iconFor(value),
                        selected: selected == value,
                        neon: neon,
                        onTap: () => service.setPreference(value),
                      ),
                    ),
                ],
              ),
            ),
            if (!embedded) ...[
              const SizedBox(height: 8),
              Text(
                'Gündüz krem, gece lacivert görünüm. Sistem cihaz ayarını izler.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool neon;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.neon = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = neon ? AppTheme.neonEdge : AppTheme.champagne;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected
            ? accent.withValues(alpha: neon ? 0.18 : 0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: neon ? 0.75 : 0.65)
                    : Colors.transparent,
              ),
              boxShadow: selected && neon
                  ? SubjectNeonPalette.glow(accent, blur: 8)
                  : null,
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? (neon ? accent : AppTheme.champagneLight)
                      : Colors.white.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? (neon ? accent : AppTheme.champagneLight)
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
