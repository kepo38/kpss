import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soru ekranının önünde kapatılabilir not kartı.
class QuizQuestionNoteCard extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onSave;
  final VoidCallback onClose;

  const QuizQuestionNoteCard({
    super.key,
    required this.initialText,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<QuizQuestionNoteCard> createState() => _QuizQuestionNoteCardState();
}

class _QuizQuestionNoteCardState extends State<QuizQuestionNoteCard> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _closeAndSave() {
    widget.onSave(_controller.text);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.46),
      child: GestureDetector(
        onTap: _closeAndSave,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1C2A42),
                      AppTheme.inkSoft,
                      AppTheme.ink,
                    ],
                  ),
                  border: Border.all(color: AppTheme.champagne, width: 1.3),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.champagne.withValues(alpha: 0.22),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.sticky_note_2_rounded,
                            color: AppTheme.champagneLight,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Bu soruya not',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Kapat',
                            onPressed: _closeAndSave,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kapattığınızda kaydedilir. Deftere tekrar girince durur.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.58),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        focusNode: _focus,
                        maxLines: 8,
                        minLines: 5,
                        maxLength: 2000,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                        cursorColor: AppTheme.champagne,
                        decoration: InputDecoration(
                          hintText: 'Kendi cümlenizle not alın…',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          counterStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 10,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.champagne,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _closeAndSave,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.champagne,
                            foregroundColor: AppTheme.ink,
                          ),
                          child: const Text(
                            'Kaydet',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
