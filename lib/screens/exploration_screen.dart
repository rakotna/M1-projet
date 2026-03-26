import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import 'scan_screen.dart';
import 'result_screen.dart'; // On a toujours besoin de lancer cet écran

// ================================================================
// ÉCRAN D'IMPORTATION (SIMPLIFIÉ)
// ================================================================
class ExplorationScreen extends StatefulWidget {
  const ExplorationScreen({super.key});

  @override
  State<ExplorationScreen> createState() => _ExplorationScreenState();
}

class _ExplorationScreenState extends State<ExplorationScreen> {
  final ImagePicker _picker = ImagePicker();

  bool   _isAnalyzing = false;
  String _statusMsg   = '';
  double _progress    = 0;

  // ──────────────────────────────────────────────────────────
  // IMPORT GALERIE
  // ──────────────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90, // Qualité légèrement réduite pour l'envoi
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null) return;
      
      // Lancer le pipeline d'analyse
      await _runPipeline(picked.path);

    } catch (e) {
      _showError('Impossible d\'ouvrir la galerie : $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // CAMÉRA → Redirige vers ScanScreen
  // ──────────────────────────────────────────────────────────
  void _openScanScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
  }

  // ──────────────────────────────────────────────────────────
  // MODIFIÉ : PIPELINE COMPLET
  // Le but est maintenant de rassembler les données et de les envoyer
  // à l'écran de résultat `ResultScreen`.
  // ──────────────────────────────────────────────────────────
  Future<void> _runPipeline(String imagePath) async {
    setState(() {
      _isAnalyzing = true;
      _statusMsg   = '📤 Envoi de l\'image au serveur…';
      _progress    = 0.10;
    });

    try {
      final rawBytes = await File(imagePath).readAsBytes();
      final b64Image = base64Encode(rawBytes);

      // ── ÉTAPE 1 : /detect ─────────────────────────────────
      setState(() {
        _statusMsg = '🔍 Analyse de la structure (YOLO)…';
        _progress  = 0.25;
      });

      final detectRes = await http.post(
        Uri.parse('${AppConfig.apiUrl}/detect'),
        headers: AppConfig.apiHeaders,
        body: jsonEncode({'image': b64Image}),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      if (detectRes.statusCode != 200) {
        _showError('Détection YOLO échouée (HTTP ${detectRes.statusCode})');
        return;
      }

      final detectJson = jsonDecode(detectRes.body) as Map<String, dynamic>;
      final count = detectJson['count'] as int? ?? 0;
      if (count == 0) {
        _showError('Aucun champ de bulletin détecté sur cette image.');
        return;
      }

      setState(() {
        _statusMsg = '💾 $count zones — sélection des meilleures…';
        _progress  = 0.45;
      });

      final rawBoxes = (detectJson['boxes'] as List<dynamic>)
          .map((b) => DetectedBox.fromJson(b as Map<String, dynamic>))
          .toList();

      final Map<String, DetectedBox> bestMemory = {};
      for (final box in rawBoxes) {
        final prev = bestMemory[box.field];
        if (prev == null || box.confidence > prev.confidence) {
          bestMemory[box.field] = box;
        }
      }

      if (bestMemory.isEmpty) {
        _showError('Zones détectées mais non exploitables.');
        return;
      }

      // ── ÉTAPE 2 : /ocr ────────────────────────────────────
      setState(() {
        _statusMsg = '🤖 Reconnaissance du texte (TrOCR)…';
        _progress = 0.65;
      });

      final cropsPayload = <String, String>{
        for (final e in bestMemory.entries) e.key: e.value.cropB64,
      };

      final ocrRes = await http.post(
        Uri.parse('${AppConfig.apiUrl}/ocr'),
        headers: AppConfig.apiHeaders,
        body: jsonEncode({'crops': cropsPayload}),
      ).timeout(const Duration(seconds: 120));

      if (!mounted) return;
      if (ocrRes.statusCode != 200) {
        _showError('Reconnaissance OCR échouée (HTTP ${ocrRes.statusCode})');
        return;
      }

      setState(() {
        _statusMsg = '✅ Analyse terminée !';
        _progress  = 1.0;
      });

      // ── PRÉPARATION DES DONNÉES POUR RESULT SCREEN ─────────
      final ocrJson   = jsonDecode(ocrRes.body) as Map<String, dynamic>;
      final rawResult = ocrJson['results'] as Map<String, dynamic>? ?? {};

      final ocrTexts = rawResult.map((k, v) => MapEntry(k, (v as Map)['text']?.toString() ?? ''));
      final cropB64s = rawResult.map((k, v) => MapEntry(k, (v as Map)['crop_b64']?.toString() ?? ''));
      final confs = <String, double>{ for (final e in bestMemory.entries) e.key: e.value.confidence };
      final detections = <String, dynamic>{ for (final k in ocrTexts.keys) k: k }; // Simuler les détections

      // Arrêter l'indicateur d'analyse avant de naviguer
      setState(() { _isAnalyzing = false; });

      // ── NAVIGATION VERS L'ÉCRAN DE RÉSULTAT COMPLET ──────────
      if(mounted){
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              imagePath: imagePath,
              detections: detections, 
              bestConf: confs,
              ocrResults: ocrTexts,
              cropImages: cropB64s,
            ),
          ),
        );
      }

    } catch (e) {
      final msg = e.toString();
      _showError('Erreur : ${msg.length > 100 ? msg.substring(0, 100) : msg}');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() { _isAnalyzing = false; _statusMsg = ''; _progress = 0; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 12)),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ================================================================
  // BUILD (SIMPLIFIÉ)
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A0A1A), Color(0xFF1A0A2E), Color(0xFF0A1A2E)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildImportTab()),
              ],
            ),
          ),
          if (_isAnalyzing) _buildAnalyzingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const GlassCard(
            padding: EdgeInsets.all(10),
            borderRadius: 12,
            child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Importer un bulletin', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Depuis la galerie ou la caméra', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38)),
          ],
        ),
      ]),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _ImportCard(
            icon: Icons.photo_library_rounded,
            title: 'Importer depuis la galerie',
            subtitle: 'Choisir une image de bulletin existante',
            color: AppColors.primary,
            onTap: _pickFromGallery,
          ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.12),
          const SizedBox(height: 20),
          _ImportCard(
            icon: Icons.videocam_rounded,
            title: 'Utiliser la caméra live',
            subtitle: 'Scanner avec le retour vidéo en temps réel',
            color: AppColors.secondary,
            badge: 'RECOMMANDÉ',
            onTap: _openScanScreen,
          ).animate().fadeIn(delay: 220.ms).slideX(begin: 0.12),
          const SizedBox(height: 40),
          const Divider(color: Colors.white10),
          const SizedBox(height: 20),
          const Icon(Icons.info_outline_rounded, color: Colors.white24, size: 24),
          const SizedBox(height: 12),
          Text(
            'Après sélection, l\'image sera analysée par le serveur pour en extraire les informations, puis vous pourrez les vérifier et les sauvegarder.',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingOverlay() {
    return Container(
      color: Colors.black.withAlpha(200),
      child: Center(
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
          width: 290,
          borderColor: AppColors.primary.withAlpha(102),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 38)
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 1200.ms, color: AppColors.secondary),
              const SizedBox(height: 18),
              Text(_statusMsg, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 7,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(_progress < 0.5 ? AppColors.secondary : _progress < 0.85 ? AppColors.primary : AppColors.accent),
                ),
              ),
              const SizedBox(height: 8),
              Text('${(_progress * 100).toInt()} %', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white38)),
            ],
          ),
        ),
      ),
    );
  }
}

// WIDGETS INTERNES SIMPLIFIÉS

class _ImportCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _ImportCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, this.badge, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
        borderColor: color.withAlpha(115),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (badge != null)
              Positioned(
                top: -10, right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: AppColors.error),
                  child: Text(badge!, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                ),
              ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(33),
                  border: Border.all(color: color.withAlpha(128), width: 2),
                  boxShadow: [BoxShadow(color: color.withAlpha(71), blurRadius: 16)],
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text(subtitle, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white38), textAlign: TextAlign.center),
            ]),
          ],
        ),
      ),
    );
  }
}
