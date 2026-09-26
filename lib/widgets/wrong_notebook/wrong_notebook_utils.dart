import 'package:flutter/material.dart';

import '../../data/kpss_curriculum.dart';
import '../../theme/app_theme.dart';
import '../../theme/subject_neon_palette.dart';
import '../countdown_widget.dart';

/// Ders adından neon vurgu rengi (katalog eşleşmesi yoksa champagne).
Color wrongNotebookSubjectAccent(String dersAdi, {KpssType kpssType = KpssType.lisans}) {
  for (final subject in KpssCurriculum.subjectsFor(kpssType)) {
    if (subject.name == dersAdi) {
      return SubjectNeonPalette.forSubject(subject.id);
    }
  }
  return AppTheme.champagne;
}
