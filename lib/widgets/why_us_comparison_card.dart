import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/savings_constants.dart';
import '../screens/premium/premium_paywall_screen.dart';
import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Profil üst barındaki bilgilendirici «NEDEN BİZ» tetikleyici.
class WhyUsButton extends StatelessWidget {
  final double height;

  const WhyUsButton({super.key, this.height = 30});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final ink = dark ? AppTheme.champagneLight : const Color(0xFF6B5428);
    return ScaleButton(
      onPressed: () => showWhyUsComparisonDialog(context),
      child: Tooltip(
        message: 'Kitap ile uygulama farkını gör',
        child: Semantics(
          button: true,
          label: 'Neden biz? Bilgi',
          child: Container(
            height: height,
            padding: const EdgeInsets.fromLTRB(8, 0, 11, 0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              color: dark
                  ? const Color(0xFF1A2436)
                  : const Color(0xFFFFF8EE),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: dark ? 0.55 : 0.65),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: ink.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 5),
                Text(
                  'NEDEN BİZ',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.55,
                    height: 1,
                    color: ink,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: ink.withValues(alpha: 0.55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showWhyUsComparisonDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const WhyUsComparisonCard();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      );
    },
  );
}

/// Ortada parşömen tarzı Kitap vs Uygulama karşılaştırma kartı.
class WhyUsComparisonCard extends StatelessWidget {
  const WhyUsComparisonCard({super.key});

  static const _priceTl = SavingsConstants.paywallMonthlyHighlightTl;

  static const _bookBullets = [
    'Her baskıda kapak ve düzen değişir; hangi sürümü aldığınız, hangi müfredata uyduğu belirsiz kalır.',
    'Kitap + kargo + yeni baskı maliyeti yüksektir; bir hata için tüm seti yenilemek zorunda kalırsınız.',
    'Çözümler çoğu zaman kısa ve yüzeyseldir; çeldirici şıkların neden yanlış olduğu anlatılmaz.',
    'Baskı hatası veya müfredat değişikliği için aylar beklersiniz; elinizdeki kitap güncellenmez.',
    'Yüzlerce soruyu bilmeseniz de hepsini taşırsınız — boşa zaman ve raf alanı.',
  ];

  static const _appBullets = [
    'Tek uygulama, tek sürüm: kapak karmaşası yok; herkes aynı güncel içeriği görür.',
    'Abonelikle erişirsiniz; her yeni baskı için tekrar para vermezsiniz.',
    'Detaylı çözümler: doğru cevap ve yanlış şıkların nedenleri net anlatılır.',
    'Hata düzelince anlık bildirimle güncellenir; içerik sürekli taze kalır.',
    'İlerlemeniz, yanlış defteriniz ve tekrar listeniz telefonunuzda — kes-yapıştır yok.',
  ];

  Future<void> _openPaywall(BuildContext context) async {
    Navigator.of(context).pop();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = (size.width * 0.92).clamp(280.0, 560.0);
    final maxH = size.height * 0.86;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8F1E3),
                  Color(0xFFEFE4D0),
                  Color(0xFFE8DCC4),
                ],
              ),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.85),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: 0.28),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _ParchmentGrainPainter()),
                  ),
                  Column(
                    children: [
                      _Header(onClose: () => Navigator.of(context).pop()),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Neden Kitap Değil de Bu Uygulama?',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                  color: const Color(0xFF1C2434),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Kapak değişen, pahalı ve kısa çözümlü kitaplar yerine '
                                'anında güncellenen, net anlatımlı çalışma.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                  color: const Color(0xFF5A6578),
                                ),
                              ),
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final sideBySide = constraints.maxWidth >= 420;
                                  const book = _CompareColumn(
                                    title: 'Klasik Ders Kitapları',
                                    bullets: WhyUsComparisonCard._bookBullets,
                                    positive: false,
                                  );
                                  const app = _CompareColumn(
                                    title: 'HEDEF Kamu Uygulaması',
                                    bullets: WhyUsComparisonCard._appBullets,
                                    positive: true,
                                  );
                                  if (sideBySide) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: app),
                                        const SizedBox(width: 10),
                                        Expanded(child: book),
                                      ],
                                    );
                                  }
                                  return Column(
                                    children: [
                                      app,
                                      const SizedBox(height: 10),
                                      book,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _ShimmerCta(
                          label: 'Premium ile çalışmaya başla ($_priceTl TL)',
                          onPressed: () => _openPaywall(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
      child: Row(
        children: [
          const SizedBox(width: 36),
          Expanded(
            child: Text(
              'Kitap vs Uygulama',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: AppTheme.champagne.withValues(alpha: 0.95),
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: 'Kapat',
            icon: const Icon(Icons.close_rounded, size: 22),
            color: const Color(0xFF3C4454),
          ),
        ],
      ),
    );
  }
}

class _CompareColumn extends StatelessWidget {
  final String title;
  final List<String> bullets;
  final bool positive;

  const _CompareColumn({
    required this.title,
    required this.bullets,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final border = positive
        ? const Color(0xFF2F9E7A)
        : const Color(0xFFB45A5A);
    final headerBg = positive
        ? const Color(0xFF1F6F5B)
        : const Color(0xFF6E4545);
    final cardBg = positive
        ? const Color(0xFFE8F5F0)
        : const Color(0xFFF3E8E8);
    final mark = positive ? '✓' : '❌';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          if (positive)
            BoxShadow(
              color: const Color(0xFF2F9E7A).withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.25,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              children: [
                for (var i = 0; i < bullets.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mark,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: positive
                              ? const Color(0xFF1F6F5B)
                              : const Color(0xFF8B3A3A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bullets[i],
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            color: const Color(0xFF2A3344),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerCta extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _ShimmerCta({required this.label, required this.onPressed});

  @override
  State<_ShimmerCta> createState() => _ShimmerCtaState();
}

class _ShimmerCtaState extends State<_ShimmerCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onPressed: widget.onPressed,
      child: AnimatedBuilder(
        animation: _shine,
        builder: (context, child) {
          final t = _shine.value;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment(-1.2 + t * 2.4, 0),
                end: Alignment(-0.2 + t * 2.4, 1),
                colors: const [
                  Color(0xFFB8893A),
                  Color(0xFFE2C998),
                  Color(0xFFC9A86C),
                  Color(0xFF8F6E32),
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC9A86C).withValues(alpha: 0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Text(
          widget.label,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: const Color(0xFF1C2434),
          ),
        ),
      ),
    );
  }
}

class _ParchmentGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B7355).withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final edge = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.transparent,
          const Color(0xFF8B7355).withValues(alpha: 0.08),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, edge);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
