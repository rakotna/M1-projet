import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/database_helper.dart';
import '../models/scan_result.dart';
import 'scan_screen.dart';
import 'history_screen.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final Map<String, dynamic> detections;
  final Map<String, double> bestConf;
  final Map<String, String> ocrResults;
  final Map<String, String> cropImages;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.detections,
    required this.bestConf,
    required this.ocrResults,
    required this.cropImages,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _isEditing = {};
  final Map<String, bool> _showCrop = {};
  final Map<String, bool> _isModified = {};

  bool _isSaving = false;
  bool _saveSuccess = false;
  String _saveMsg = '';

  @override
  void initState() {
    super.initState();
    for (final field in AppConfig.fields) {
      final text = widget.ocrResults[field] ?? '';
      _controllers[field] = TextEditingController(text: text);
      _isEditing[field] = false;
      _showCrop[field] = true;
      _isModified[field] = false;
      _controllers[field]!.addListener(() {
        final original = widget.ocrResults[field] ?? '';
        final current = _controllers[field]!.text;
        if (_isModified[field] != (current != original)) {
          setState(() => _isModified[field] = current != original);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveToLocalDatabase() async {
    setState(() {
      _isSaving = true;
      _saveMsg = '💾 Sauvegarde dans l\'historique local…';
    });

    try {
      final ocrFinal = <String, String>{};
      for (final field in AppConfig.fields) {
        ocrFinal[field] = _controllers[field]!.text.trim();
      }

      final newResult = ScanResult(
        imagePath: widget.imagePath,
        ocrResults: ocrFinal,
        confidences: widget.bestConf,
        cropImages: widget.cropImages,
        scannedAt: DateTime.now(),
        note: ocrFinal['note'] ?? '',
        nom: ocrFinal['nom'] ?? '',
        prenom: ocrFinal['prenom'] ?? '',
        matiere: ocrFinal['matiere'] ?? '',
      );

      await DatabaseHelper.instance.create(newResult);

      if (!mounted) return;

      setState(() {
        _saveSuccess = true;
        _saveMsg = '✅ Bulletin sauvegardé dans l\'historique local !';
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sauvegardé dans l\'historique !', style: GoogleFonts.poppins()),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
            label: 'VOIR',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const HistoryScreen()));
              }
            }),
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveMsg = '❌ Erreur: ${e.toString().substring(0, 60)}';
          _isSaving = false;
        });
      }
    }
  }

  int get _modifiedCount => _isModified.values.where((v) => v).length;
  int get _detectedCount => widget.ocrResults.values.where((v) => v.isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        Container(
            decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A1A), Color(0xFF1A0A2E), Color(0xFF0A1A2E)],
          ),
        )),
        SafeArea(
            child: Column(children: [
          _buildHeader(),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              const SizedBox(height: 8),
              if (_saveMsg.isNotEmpty) _buildSaveStatus(),
              if (widget.imagePath.isNotEmpty) _buildImage(),
              const SizedBox(height: 14),
              ...AppConfig.fields.map(_buildFieldCard),
              const SizedBox(height: 20),
              _buildActionButtons(),
              const SizedBox(height: 32),
            ]),
          )),
        ])),
        if (_isSaving)
          Container(
              color: Colors.black.withAlpha(178),
              child: Center(
                  child: GlassCard(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(_saveMsg,
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center),
                ]),
              ))),
      ]),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const GlassCard(
                padding: EdgeInsets.all(10),
                borderRadius: 12,
                child: Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20)),
          ),
          Column(children: [
            Text('Résultats OCR', style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            Row(children: [
              Text('$_detectedCount reconnu(s)',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.white54)),
              if (_modifiedCount > 0) ...[
                const Text(' • ', style: TextStyle(color: Colors.white24)),
                Text('$_modifiedCount modifié(s)',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.accent)),
              ],
            ]),
          ]),
          const SizedBox(width: 50),
        ]),
      );

  Widget _buildSaveStatus() => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          borderColor: (_saveSuccess ? AppColors.accent : AppColors.error).withAlpha(102),
          color: (_saveSuccess ? AppColors.accent : AppColors.error).withAlpha(20),
          child: Row(children: [
            Icon(_saveSuccess ? Icons.cloud_done : Icons.error_outline,
                color: _saveSuccess ? AppColors.accent : AppColors.error,
                size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(_saveMsg,
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        height: 1.5,
                        color: _saveSuccess
                            ? AppColors.accent
                            : AppColors.error))),
          ]),
        ),
      ).animate().fadeIn().slideY(begin: -0.1);

  Widget _buildImage() => GlassCard(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(widget.imagePath),
              height: 110, width: double.infinity, fit: BoxFit.cover),
        ),
      ).animate().fadeIn(duration: 400.ms);

  Widget _buildFieldCard(String field) {
    final color = AppConfig.fieldColors[field] ?? AppColors.primary;
    final text = _controllers[field]!.text;
    final hasData = widget.detections.containsKey(field);
    final conf = widget.bestConf[field];
    final editing = _isEditing[field] ?? false;
    final showCrop = _showCrop[field] ?? true;
    final cropB64 = widget.cropImages[field] ?? '';
    final modified = _isModified[field] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: modified
            ? AppColors.accent.withAlpha(153)
            : hasData
                ? color.withAlpha(102)
                : Colors.white10,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: color.withAlpha(38)),
                  child: Icon(AppConfig.fieldIcons[field], color: color, size: 14)),
              const SizedBox(width: 8),
              Text(AppConfig.fieldLabels[field] ?? field,
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              if (conf != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: color.withAlpha(38)),
                  child: Text('${(conf * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(fontSize: 9, color: color)),
                ),
              ],
              if (modified) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.accent.withAlpha(51)),
                  child: Text('✏️ modifié',
                      style: GoogleFonts.poppins(
                          fontSize: 9, color: AppColors.accent)),
                ),
              ],
            ]),
            Row(children: [
              if (cropB64.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _showCrop[field] = !showCrop),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                        showCrop ? Icons.image : Icons.image_outlined,
                        color: showCrop ? color : Colors.white38,
                        size: 18),
                  ),
                ),
              GestureDetector(
                  onTap: () => setState(() => _isEditing[field] = !editing),
                  child: Icon(editing ? Icons.check_circle : Icons.edit,
                      color: editing ? AppColors.accent : Colors.white38,
                      size: 18)),
            ]),
          ]),
          const SizedBox(height: 10),
          if (hasData)
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              if (cropB64.isNotEmpty && showCrop) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 88,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: modified
                              ? AppColors.accent.withAlpha(153)
                              : color.withAlpha(127),
                          width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.memory(
                      base64Decode(cropB64),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___)
                           => const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.white24, size: 18)),
                    ),
                  ),
                ).animate().fadeIn().slideX(begin: -0.2),
                Container(
                    width: 1,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: color.withAlpha(64)),
              ],
              Expanded(
                child: editing
                    ? TextField(
                        controller: _controllers[field],
                        autofocus: true,
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: color.withAlpha(25),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: color)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: color, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          hintText: 'Corrigez ici...',
                          hintStyle: GoogleFonts.poppins(
                              color: Colors.white24, fontSize: 13),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check, color: AppColors.accent),
                            onPressed: () =>
                                setState(() => _isEditing[field] = false),
                          ),
                        ),
                        onSubmitted: (_) =>
                            setState(() => _isEditing[field] = false),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.isEmpty ? '—' : text,
                            style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: text.isEmpty
                                    ? Colors.white24
                                    : modified
                                        ? AppColors.accent
                                        : Colors.white),
                          ),
                          if (text.isEmpty)
                            Text('Non reconnu',
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.white38,
                                    fontStyle: FontStyle.italic)),
                        ],
                      ),
              ),
            ])
          else
            Text('Non détecté',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white24,
                    fontStyle: FontStyle.italic)),
        ]),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: AppConfig.fields.indexOf(field) * 60))
        .slideX(begin: 0.08);
  }

  Widget _buildActionButtons() {
    return Column(children: [
      NeonButton(
        label: _saveSuccess ? '✅ Sauvegardé !' : 'Sauvegarder dans l\'historique',
        icon: _saveSuccess ? Icons.check_circle : Icons.save,
        color: _saveSuccess ? AppColors.accent : AppColors.primary,
        width: double.infinity,
        onTap: _isSaving || _saveSuccess ? () {} : _saveToLocalDatabase,
      ),
      const SizedBox(height: 20),
      NeonButton(
        label: 'Scanner un autre bulletin',
        icon: Icons.camera_alt,
        color: AppColors.secondary,
        width: double.infinity,
        onTap: () => Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const ScanScreen())),
      ),
      const SizedBox(height: 10),
      NeonButton(
        label: 'Voir l\'historique',
        icon: Icons.history,
        color: Colors.grey.shade600,
        width: double.infinity,
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HistoryScreen())),
      ),
    ]).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2);
  }
}
