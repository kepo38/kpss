import 'package:flutter/material.dart';

import '../models/wrong_notebook_session_filter.dart';
import '../screens/wrong_questions_screen.dart';
import '../services/ad_manager.dart';

/// Test bitişinden filtreli Yanlış Defteri ekranını açar.
Future<void> openWrongNotebookSession(
  NavigatorState navigator,
  WrongNotebookSessionFilter filter,
) async {
  AdManager.instance.skipNextPageTransition();
  await navigator.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => WrongQuestionsScreen(sessionFilter: filter),
    ),
  );
}
