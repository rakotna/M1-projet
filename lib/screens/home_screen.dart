import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import 'scan_screen.dart';
import 'history_screen.dart';
import 'exploration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgController;
  String _connectionStatus = '⚪ Non testé';
  Color  _connectionColor  = Colors.white38;
  bool   _isTesting        = false;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  // ── Test connexion API ──
  Future<void> _testConnection() async {
    setState(() {
      _isTesting         = true;
      _connectionStatus  = '🔄 Connexion...';
      _connectionColor   = Colors.orange;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/status'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _connectionStatus = '✅ Connecté — ScolarAI API active';
          _connectionColor  = AppColors.accent;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ API connectée avec succès !',
              style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        setState(() {
          _connectionStatus = '❌ Erreur ${response.statusCode}';
          _connectionColor  = AppColors.error;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectionStatus = '❌ Hors ligne — Vérifiez Colab';
        _connectionColor  = AppColors.error;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('❌ Impossible de joindre le serveur',
            style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          _AnimatedBackground(controller: _bgController, size: size),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  _buildLogo(),
                  const SizedBox(height: 16),
                  _buildTitle(),
                  const SizedBox(height: 6),
                  _buildSubtitle(),
                  const SizedBox(height: 24),

                  // ── Carte statut API ──
                  _buildApiStatusCard(),

                  const SizedBox(height: 16),

                  // ── Carte scan principale ──
                  _buildScanCard(context),

                  const SizedBox(height: 16),
                  _buildStatsGrid(),
                  const SizedBox(height: 16),
                  _buildHistoryButton(context),
                  const SizedBox(height: 10),
                  _buildExplorationButton(context),
                  const SizedBox(height: 32),
                  _buildFooter(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logo ──
  Widget _buildLogo() {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withAlpha(128), blurRadius: 30),
        ],
      ),
      child: const Icon(Icons.document_scanner, color: Colors.white, size: 40),
    )
        .animate()
        .scale(duration: 600.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 400.ms);
  }

  // ── Titre animé ──
  Widget _buildTitle() {
    return AnimatedTextKit(
      animatedTexts: [
        TypewriterAnimatedText(
          'ScolarAI',
          textStyle: const TextStyle(
            fontFamily: 'Poppins', fontSize: 40,
            fontWeight: FontWeight.w700, color: Colors.white,
            letterSpacing: 2,
          ),
          speed: const Duration(milliseconds: 100),
        ),
      ],
      isRepeatingAnimation: false,
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'OCR Bulletins Scolaires • Madagascar 2026',
      style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
          color: Colors.white.withAlpha(128), letterSpacing: 1),
      textAlign: TextAlign.center,
    ).animate().fadeIn(delay: 800.ms, duration: 600.ms);
  }

  // ── Carte statut API ──
  Widget _buildApiStatusCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: _connectionColor.withAlpha(102),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _connectionColor,
                  boxShadow: [
                    BoxShadow(color: _connectionColor.withAlpha(128),
                        blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _connectionStatus,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                    color: _connectionColor, fontWeight: FontWeight.w600),
              ),
            ]),
            // Bouton test
            GestureDetector(
              onTap: _isTesting ? null : _testConnection,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: _isTesting
                        ? [Colors.grey, Colors.grey.shade700]
                        : [AppColors.secondary, AppColors.primary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withAlpha(77),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: _isTesting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.wifi_find, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text('Tester', style: TextStyle(fontFamily: 'Poppins',
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: Colors.white)),
                      ]),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        const Divider(color: Colors.white10),
        const SizedBox(height: 8),

        const Row(children: [
          Icon(Icons.link, color: Colors.white24, size: 12),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              AppConfig.apiUrl,
              style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 10, color: Colors.white30),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ]),
    ).animate().fadeIn(delay: 600.ms, duration: 500.ms).slideY(begin: -0.1);
  }

  // ── Carte scan ──
  Widget _buildScanCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ScanScreen())),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        borderColor: AppColors.primary.withAlpha(128),
        child: Column(children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                AppColors.primary.withAlpha(77),
                AppColors.secondary.withAlpha(77),
              ]),
              border: Border.all(
                  color: AppColors.primary.withAlpha(128), width: 2),
            ),
            child: const Icon(Icons.camera_alt,
                color: AppColors.primary, size: 32),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05),
                     duration: 1500.ms),

          const SizedBox(height: 14),
          const Text('Scanner un Bulletin', style: TextStyle(
              fontFamily: 'Poppins', fontSize: 18,
              fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 6),
          Text(
            'Vidéo temps réel → YOLO détecte\nMémoire max → TrOCR reconnaît',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                color: Colors.white.withAlpha(140), height: 1.5),
          ),

          const SizedBox(height: 16),
          Wrap(
            spacing: 6, runSpacing: 6,
            alignment: WrapAlignment.center,
            children: AppConfig.fields.map((field) {
              final color = AppConfig.fieldColors[field] ?? AppColors.primary;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: color.withAlpha(30),
                  border: Border.all(color: color.withAlpha(128)),
                ),
                child: Text(AppConfig.fieldLabels[field] ?? field,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                        fontWeight: FontWeight.w600, color: color)),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),
          NeonButton(
            label: 'Démarrer le scan',
            icon: Icons.play_arrow,
            color: AppColors.primary,
            width: double.infinity,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ScanScreen())),
          ),
        ]),
      ),
    )
        .animate()
        .slideY(begin: 0.2, duration: 600.ms, delay: 400.ms, curve: Curves.easeOut)
        .fadeIn(duration: 600.ms, delay: 400.ms);
  }

  // ── Stats ──
  Widget _buildStatsGrid() {
    final stats = [
      {'label': 'Précision', 'value': '74%',  'icon': Icons.analytics,  'color': AppColors.accent},
      {'label': 'Champs',   'value': '6',     'icon': Icons.grid_view,  'color': AppColors.secondary},
      {'label': 'Matricule','value': '90%',   'icon': Icons.numbers,    'color': AppColors.primary},
      {'label': 'Modèle',   'value': 'V3',    'icon': Icons.memory,     'color': const Color(0xFFFF9F43)},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: stats.asMap().entries.map((entry) {
        final i = entry.key; final stat = entry.value;
        final color = stat['color'] as Color;
        return GlassCard(
          padding: const EdgeInsets.all(12),
          borderColor: color.withAlpha(77),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(38),
              ),
              child: Icon(stat['icon'] as IconData, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(stat['value'] as String, style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 18,
                  fontWeight: FontWeight.w700, color: color)),
              Text(stat['label'] as String, style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 11, color: Colors.white54)),
            ]),
          ]),
        )
            .animate()
            .slideX(begin: i.isEven ? -0.2 : 0.2, duration: 500.ms,
                    delay: Duration(milliseconds: 600 + i * 80))
            .fadeIn(duration: 500.ms,
                    delay: Duration(milliseconds: 600 + i * 80));
      }).toList(),
    );
  }

  // ── Historique ──
  Widget _buildHistoryButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const HistoryScreen())),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: AppColors.secondary.withAlpha(38)),
              child: const Icon(Icons.history,
                  color: AppColors.secondary, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Historique', style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              Text('Bulletins scannés', style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 11, color: Colors.white54)),
            ]),
          ]),
          const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
        ]),
      ),
    ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.1, delay: 900.ms);
  }

  Widget _buildExplorationButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExplorationScreen()),
      ),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        borderColor: const Color(0xFF1D6F42).withAlpha(128),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1D6F42).withAlpha(46),
                ),
                child: const Icon(Icons.add_photo_alternate_rounded,
                    color: Color(0xFF2E8B57), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exploration',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  Text('Importer image • Export Excel',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white54)),
                ],
              ),
            ]),
            // Badge Excel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF1D6F42).withAlpha(51),
                border: Border.all(
                    color: const Color(0xFF2E8B57).withAlpha(128)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.table_chart_rounded,
                    color: Color(0xFF2E8B57), size: 12),
                const SizedBox(width: 4),
                Text('XLSX',
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2E8B57))),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white38, size: 14),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 950.ms).slideY(begin: 0.1);
  }

  Widget _buildFooter() {
    return Text(
      'YOLO OBB + TrOCR V3 • Mémoire temporelle\nMade with ❤️ in Madagascar 2026',
      textAlign: TextAlign.center,
      style: TextStyle(fontFamily: 'Poppins', fontSize: 10,
          color: Colors.white.withAlpha(64), height: 1.6),
    ).animate().fadeIn(delay: 1200.ms);
  }
}

// ── Fond animé avec orbes ──
class _AnimatedBackground extends StatelessWidget {
  final AnimationController controller;
  final Size size;
  const _AnimatedBackground({required this.controller, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        return Stack(children: [
          Container(color: AppColors.background),
          Positioned(
            left: size.width * 0.1 + sin(t * 2 * pi) * 25,
            top:  size.height * 0.08 + cos(t * 2 * pi) * 18,
            child: const _Orb(color: AppColors.primary, size: 200),
          ),
          Positioned(
            right: size.width * 0.05 + cos(t * 2 * pi) * 20,
            top:   size.height * 0.35 + sin(t * 2 * pi) * 25,
            child: const _Orb(color: AppColors.secondary, size: 160),
          ),
          Positioned(
            left:   size.width * 0.2 + sin(t * 2 * pi + 1) * 18,
            bottom: size.height * 0.08 + cos(t * 2 * pi + 1) * 20,
            child: const _Orb(color: AppColors.accent, size: 140),
          ),
        ]);
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
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withAlpha(64), Colors.transparent],
        ),
      ),
    );
  }
}
