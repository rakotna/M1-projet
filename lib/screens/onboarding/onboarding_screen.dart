import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/colors.dart';
import '../../core/widgets.dart';
import '../home_screen.dart';

// ============================================================
// MODÈLE D'UNE SLIDE
// ============================================================
class _OnboardingData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final List<String> chips;

  const _OnboardingData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.chips,
  });
}

// ============================================================
// DONNÉES DES 4 SLIDES
// ============================================================
const _slides = [
  _OnboardingData(
    title: 'ScolarAI',
    subtitle: 'Bulletins scolaires, réinventés',
    description:
        'Une intelligence artificielle dédiée aux établissements scolaires malgaches. '
        'Scannez, lisez et archivez vos bulletins en quelques secondes.',
    icon: Icons.document_scanner_rounded,
    primaryColor: AppColors.primary,
    secondaryColor: AppColors.secondary,
    chips: ['Madagascar 2026', 'IA embarquée', 'Hors-ligne possible'],
  ),
  _OnboardingData(
    title: 'Détection YOLO',
    subtitle: 'Voyez chaque champ en temps réel',
    description:
        'Pointez votre caméra vers un bulletin : YOLO OBB détecte et localise '
        'instantanément les 6 champs clés, même si le bulletin est légèrement incliné.',
    icon: Icons.camera_alt_rounded,
    primaryColor: Color(0xFF00D4FF),
    secondaryColor: Color(0xFF6C63FF),
    chips: ['YOLO OBB', 'Temps réel', '6 champs', 'Rotation ±45°'],
  ),
  _OnboardingData(
    title: 'TrOCR V3',
    subtitle: 'Lecture précise, même manuscrite',
    description:
        'Le modèle TrOCR analyse chaque zone détectée et retranscrit le texte '
        'avec une précision de 74 %. Corrigez les erreurs directement sur l\'écran résultat.',
    icon: Icons.auto_awesome_rounded,
    primaryColor: Color(0xFF00FF94),
    secondaryColor: Color(0xFF00D4FF),
    chips: ['TrOCR V3', '74 % précision', 'Correction manuelle', 'Mémoire temporelle'],
  ),
  _OnboardingData(
    title: 'Historique & Export',
    subtitle: 'Vos données, toujours accessibles',
    description:
        'Chaque bulletin scanné est sauvegardé dans Firebase et sur Google Drive. '
        'Exportez en JSON, CSV ou TXT pour alimenter votre propre dataset IA.',
    icon: Icons.cloud_done_rounded,
    primaryColor: Color(0xFFFF9F43),
    secondaryColor: Color(0xFFFF6B6B),
    chips: ['Firebase', 'Google Drive', 'JSON · CSV · TXT', 'Dataset IA'],
  ),
];

// ============================================================
// ÉCRAN ONBOARDING PRINCIPAL
// ============================================================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _bgController;
  late AnimationController _pulseController;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _goToHome();
    }
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final slide = _slides[_currentPage];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Fond animé avec orbes colorées selon la slide ──
          _AnimatedOrbBackground(
            controller: _bgController,
            size: size,
            primaryColor: slide.primaryColor,
            secondaryColor: slide.secondaryColor,
          ),

          // ── Contenu principal ──
          SafeArea(
            child: Column(
              children: [
                // Bouton "Passer"
                _buildSkipButton(),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (_, i) => _OnboardingPage(
                      data: _slides[i],
                      pulseController: _pulseController,
                      isActive: i == _currentPage,
                    ),
                  ),
                ),

                // Bas : indicateurs + bouton suivant
                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bouton Passer ──
  Widget _buildSkipButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: GestureDetector(
          onTap: _goToHome,
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: 20,
            child: Text(
              'Passer',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 300.ms);
  }

  // ── Barre du bas ──
  Widget _buildBottomBar() {
    final isLast = _currentPage == _slides.length - 1;
    final slide = _slides[_currentPage];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
      child: Column(
        children: [
          // Indicateurs de page
          _buildDots(),
          const SizedBox(height: 28),

          // Bouton principal
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: NeonButton(
              label: isLast ? 'C\'est parti  🚀' : 'Continuer',
              icon: isLast ? null : Icons.arrow_forward_rounded,
              color: slide.primaryColor,
              width: double.infinity,
              onTap: _nextPage,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.15);
  }

  // ── Dots indicateurs ──
  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (i) {
        final isActive = i == _currentPage;
        final color = _slides[i].primaryColor;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive ? color : Colors.white.withAlpha(51),
            boxShadow: isActive
                ? [BoxShadow(color: color.withAlpha(128), blurRadius: 8)]
                : null,
          ),
        );
      }),
    );
  }
}

// ============================================================
// WIDGET D'UNE SLIDE
// ============================================================
class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  final AnimationController pulseController;
  final bool isActive;

  const _OnboardingPage({
    required this.data,
    required this.pulseController,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Icône centrale animée ──
          _buildAnimatedIcon(),
          const SizedBox(height: 40),

          // ── Titre ──
          Text(
            data.title,
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          )
              .animate(key: ValueKey('title_${data.title}'))
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2),

          const SizedBox(height: 8),

          // ── Sous-titre coloré ──
          Text(
            data.subtitle,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: data.primaryColor,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          )
              .animate(key: ValueKey('sub_${data.title}'))
              .fadeIn(duration: 500.ms, delay: 80.ms)
              .slideY(begin: 0.15),

          const SizedBox(height: 20),

          // ── Description ──
          GlassCard(
            padding: const EdgeInsets.all(18),
            borderColor: data.primaryColor.withAlpha(64),
            child: Text(
              data.description,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withAlpha(191),
                height: 1.7,
              ),
              textAlign: TextAlign.center,
            ),
          )
              .animate(key: ValueKey('desc_${data.title}'))
              .fadeIn(duration: 500.ms, delay: 160.ms)
              .slideY(begin: 0.1),

          const SizedBox(height: 20),

          // ── Chips de fonctionnalités ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: data.chips.asMap().entries.map((entry) {
              final i = entry.key;
              final chip = entry.value;
              return _FeatureChip(
                label: chip,
                color: data.primaryColor,
                delay: Duration(milliseconds: 240 + i * 60),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Icône avec anneaux de pulsation ──
  Widget _buildAnimatedIcon() {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (_, __) {
        final pulse = pulseController.value;
        return SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Anneau externe pulsant
              Container(
                width: 140 + pulse * 14,
                height: 140 + pulse * 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: data.primaryColor.withAlpha(30 + (pulse * 20).toInt()),
                    width: 1.5,
                  ),
                ),
              ),
              // Anneau intermédiaire
              Container(
                width: 118 + pulse * 8,
                height: 118 + pulse * 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: data.primaryColor.withAlpha(51 + (pulse * 25).toInt()),
                    width: 1.5,
                  ),
                ),
              ),
              // Cercle principal avec gradient
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      data.primaryColor.withAlpha(89),
                      data.secondaryColor.withAlpha(38),
                    ],
                  ),
                  border: Border.all(
                    color: data.primaryColor.withAlpha(128),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: data.primaryColor.withAlpha(77 + (pulse * 38).toInt()),
                      blurRadius: 24 + pulse * 10,
                    ),
                  ],
                ),
                child: Icon(
                  data.icon,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ],
          ),
        );
      },
    )
        .animate(key: ValueKey('icon_${data.title}'))
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 400.ms);
  }
}

// ============================================================
// CHIP DE FONCTIONNALITÉ
// ============================================================
class _FeatureChip extends StatelessWidget {
  final String label;
  final Color color;
  final Duration delay;

  const _FeatureChip({
    required this.label,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withAlpha(30),
        border: Border.all(color: color.withAlpha(115), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: delay)
        .scale(
          begin: const Offset(0.85, 0.85),
          delay: delay,
          duration: 350.ms,
          curve: Curves.easeOut,
        );
  }
}

// ============================================================
// FOND AVEC ORBES ANIMÉES (couleurs dynamiques selon la slide)
// ============================================================
class _AnimatedOrbBackground extends StatelessWidget {
  final AnimationController controller;
  final Size size;
  final Color primaryColor;
  final Color secondaryColor;

  const _AnimatedOrbBackground({
    required this.controller,
    required this.size,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        return Stack(
          children: [
            Container(color: AppColors.background),
            // Orbe principale en haut à gauche
            Positioned(
              left: size.width * 0.05 + sin(t * 2 * pi) * 20,
              top: size.height * 0.05 + cos(t * 2 * pi) * 16,
              child: _Orb(color: primaryColor, size: 220),
            ),
            // Orbe secondaire à droite
            Positioned(
              right: size.width * 0.0 + cos(t * 2 * pi) * 18,
              top: size.height * 0.30 + sin(t * 2 * pi) * 22,
              child: _Orb(color: secondaryColor, size: 170),
            ),
            // Orbe basse
            Positioned(
              left: size.width * 0.25 + sin(t * 2 * pi + 1.2) * 16,
              bottom: size.height * 0.05 + cos(t * 2 * pi + 1.2) * 18,
              child: _Orb(color: primaryColor.withAlpha(128), size: 150),
            ),
          ],
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;

  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withAlpha(56), Colors.transparent],
        ),
      ),
    );
  }
}