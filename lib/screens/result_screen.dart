import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../main.dart';
import 'scan_screen.dart';
import 'history_screen.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final Map<String, dynamic> detections;
  final Map<String, double>  bestConf;
  final Map<String, String>  ocrResults;
  final Map<String, String>  cropImages;

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

  Map<String, TextEditingController> _controllers = {};
  Map<String, bool> _isEditing  = {};
  Map<String, bool> _showCrop   = {};
  Map<String, bool> _isModified = {}; // champ modifié par utilisateur

  bool   _isSaving    = false;
  bool   _saveSuccess = false;
  String _saveMsg     = '';
  int    _totalDataset = 0;
  String _sessionId   = '';

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
    for (final field in AppConfig.fields) {
      final text = widget.ocrResults[field] ?? '';
      _controllers[field] = TextEditingController(text: text);
      _isEditing[field]   = false;
      _showCrop[field]    = true;
      _isModified[field]  = false;
      // Listener pour détecter modification
      _controllers[field]!.addListener(() {
        final original = widget.ocrResults[field] ?? '';
        final current  = _controllers[field]!.text;
        if (_isModified[field] != (current != original)) {
          setState(() => _isModified[field] = current != original);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  // ── Sauvegarder dans Drive via API Colab ──
  Future<void> _saveToAPI() async {
    setState(() { _isSaving = true; _saveMsg = 'Envoi vers Google Drive...'; });

    try {
      // Construire payload corrections
      final corrections = <String, dynamic>{};
      for (final field in AppConfig.fields) {
        final cropB64 = widget.cropImages[field] ?? '';
        if (cropB64.isEmpty) continue;

        final textOriginal = widget.ocrResults[field] ?? '';
        final textCorrige  = _controllers[field]!.text.trim();
        final modifie      = _isModified[field] ?? false;

        corrections[field] = {
          'text_original': textOriginal,
          'text_corrige':  textCorrige,
          'crop_b64':      cropB64,
          'confidence':    widget.bestConf[field] ?? 0.0,
          'modifie':       modifie,
        };
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/save'),
        headers: {
          'Content-Type':               'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'session_id':  _sessionId,
          'corrections': corrections,
        }),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final json  = jsonDecode(response.body) as Map<String, dynamic>;
        final saved = (json['saved'] as List?)?.length ?? 0;
        final total = json['total_corrections'] as int? ?? 0;

        setState(() {
          _saveSuccess  = true;
          _totalDataset = total;
          _saveMsg      = '✅ $saved champs sauvegardés | Dataset: $total corrections';
          _isSaving     = false;
        });

        // Snackbar succès
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Sauvegardé dans Drive ! Total dataset: $total',
              style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));

      } else {
        setState(() {
          _saveMsg  = '❌ Erreur ${response.statusCode}';
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        _saveMsg  = '❌ Erreur: ${e.toString().substring(0, 60)}';
        _isSaving = false;
      });
    }
  }

  // ── Nombre de champs modifiés ──
  int get _modifiedCount =>
      _isModified.values.where((v) => v).length;

  int get _detectedCount =>
      widget.ocrResults.values.where((v) => v.isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        // Fond dégradé
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A1A), Color(0xFF1A0A2E), Color(0xFF0A1A2E)],
          ),
        )),

        SafeArea(child: Column(children: [
          _buildHeader(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              const SizedBox(height: 8),

              // Statut sauvegarde
              if (_saveMsg.isNotEmpty) _buildSaveStatus(),

              // Photo du bulletin
              if (widget.imagePath.isNotEmpty) _buildImage(),

              const SizedBox(height: 14),

              // Cartes champs
              ...AppConfig.fields.map(_buildFieldCard),

              const SizedBox(height: 20),

              // Boutons
              _buildActionButtons(),

              const SizedBox(height: 32),
            ]),
          )),
        ])),

        // Loading
        if (_isSaving)
          Container(color: Colors.black.withOpacity(0.7),
            child: Center(child: GlassCard(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(_saveMsg, style: const TextStyle(fontFamily: 'Poppins',
                    color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
              ]),
            ))),
      ]),
    );
  }

  // ── Header ──
  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: GlassCard(padding: const EdgeInsets.all(10), borderRadius: 12,
            child: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20)),
      ),
      Column(children: [
        const Text('Résultats OCR', style: TextStyle(fontFamily: 'Poppins',
            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        Row(children: [
          Text('$_detectedCount reconnu(s)',
              style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 11, color: Colors.white54)),
          if (_modifiedCount > 0) ...[
            const Text(' • ', style: TextStyle(color: Colors.white24)),
            Text('$_modifiedCount modifié(s)',
                style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 11, color: AppColors.accent)),
          ],
        ]),
      ]),
      // Badge dataset
      GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        borderRadius: 12,
        borderColor: AppColors.secondary.withOpacity(0.4),
        child: Column(children: [
          Text(_totalDataset > 0 ? '$_totalDataset' : '—',
              style: const TextStyle(fontFamily: 'Poppins',
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.secondary)),
          const Text('data', style: TextStyle(fontFamily: 'Poppins',
              fontSize: 8, color: Colors.white38)),
        ]),
      ),
    ]),
  );

  Widget _buildSaveStatus() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: GlassCard(
      padding: const EdgeInsets.all(12),
      borderColor: (_saveSuccess ? AppColors.accent : AppColors.error).withOpacity(0.4),
      color: (_saveSuccess ? AppColors.accent : AppColors.error).withOpacity(0.08),
      child: Row(children: [
        Icon(_saveSuccess ? Icons.cloud_done : Icons.error_outline,
            color: _saveSuccess ? AppColors.accent : AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_saveMsg, style: TextStyle(
            fontFamily: 'Poppins', fontSize: 11,
            color: _saveSuccess ? AppColors.accent : AppColors.error))),
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

  // ── Carte champ ──
  Widget _buildFieldCard(String field) {
    final color    = AppColors.fieldColors[field] ?? AppColors.primary;
    final text     = _controllers[field]!.text;
    final hasData  = widget.detections.containsKey(field);
    final conf     = widget.bestConf[field];
    final editing  = _isEditing[field] ?? false;
    final showCrop = _showCrop[field] ?? true;
    final cropB64  = widget.cropImages[field] ?? '';
    final modified = _isModified[field] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: modified
            ? AppColors.accent.withOpacity(0.6)
            : hasData ? color.withOpacity(0.4) : Colors.white10,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: color.withOpacity(0.15)),
                child: Icon(AppConfig.fieldIcons[field], color: color, size: 14)),
              const SizedBox(width: 8),
              Text(AppConfig.fieldLabels[field] ?? field,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                      fontWeight: FontWeight.w600, color: color)),
              if (conf != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                      color: color.withOpacity(0.15)),
                  child: Text('${(conf*100).toStringAsFixed(0)}%',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 9,
                          color: color))),
              ],
              // Badge modifié
              if (modified) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.accent.withOpacity(0.2)),
                  child: const Text('✏️ modifié',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 9,
                          color: AppColors.accent)),
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
                        color: showCrop ? color : Colors.white38, size: 18)),
                ),
              GestureDetector(
                onTap: () => setState(() => _isEditing[field] = !editing),
                child: Icon(editing ? Icons.check_circle : Icons.edit,
                    color: editing ? AppColors.accent : Colors.white38, size: 18)),
            ]),
          ]),

          const SizedBox(height: 10),

          // Crop + valeur
          if (hasData)
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Crop image
              if (cropB64.isNotEmpty && showCrop) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 88, height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: modified
                              ? AppColors.accent.withOpacity(0.6)
                              : color.withOpacity(0.5),
                          width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.memory(
                      base64Decode(cropB64),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.white24, size: 18)),
                    ),
                  ),
                ).animate().fadeIn().slideX(begin: -0.2),
                Container(width: 1, height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: color.withOpacity(0.25)),
              ],

              // Valeur OCR / champ édition
              Expanded(
                child: editing
                    ? TextField(
                        controller: _controllers[field],
                        autofocus: true,
                        style: const TextStyle(fontFamily: 'Poppins',
                            fontSize: 18, color: Colors.white,
                            fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: color.withOpacity(0.1),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: color)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: color, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          hintText: 'Corrigez ici...',
                          hintStyle: const TextStyle(color: Colors.white24,
                              fontFamily: 'Poppins', fontSize: 13),
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
                            style: TextStyle(fontFamily: 'Poppins',
                                fontSize: 22, fontWeight: FontWeight.w700,
                                color: text.isEmpty
                                    ? Colors.white24
                                    : modified ? AppColors.accent : Colors.white),
                          ),
                          if (text.isEmpty)
                            const Text('Non reconnu',
                                style: TextStyle(fontFamily: 'Poppins',
                                    fontSize: 11, color: Colors.white38,
                                    fontStyle: FontStyle.italic)),
                        ],
                      ),
              ),
            ])
          else
            const Text('Non détecté', style: TextStyle(fontFamily: 'Poppins',
                fontSize: 13, color: Colors.white24,
                fontStyle: FontStyle.italic)),
        ]),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: AppConfig.fields.indexOf(field) * 60))
        .slideX(begin: 0.08);
  }

  // ── Boutons d'action ──
  Widget _buildActionButtons() {
    return Column(children: [

      // ── Bouton sauvegarder (principal) ──
      NeonButton(
        label: _saveSuccess
            ? '✅ Sauvegardé dans Drive !'
            : _modifiedCount > 0
                ? 'Sauvegarder ($_modifiedCount corrections) → Drive'
                : 'Confirmer et sauvegarder → Drive',
        icon: _saveSuccess ? Icons.cloud_done : Icons.cloud_upload,
        color: _saveSuccess ? AppColors.accent : AppColors.primary,
        width: double.infinity,
        onTap: _isSaving || _saveSuccess ? () {} : _saveToAPI,
      ),

      const SizedBox(height: 10),

      // ── Boutons export ──
      Row(children: [
        Expanded(child: _buildExportButton('JSON', Icons.code, 'json')),
        const SizedBox(width: 8),
        Expanded(child: _buildExportButton('CSV', Icons.table_chart, 'csv')),
        const SizedBox(width: 8),
        Expanded(child: _buildExportButton('TXT', Icons.text_snippet, 'txt')),
        const SizedBox(width: 8),
        Expanded(child: _buildExportButton('Stats', Icons.analytics, 'stats')),
      ]),

      const SizedBox(height: 10),

      // ── Scanner autre ──
      NeonButton(
        label: 'Scanner un autre bulletin',
        icon: Icons.camera_alt,
        color: AppColors.secondary,
        width: double.infinity,
        onTap: () => Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const ScanScreen())),
      ),
    ]).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2);
  }

  Widget _buildExportButton(String label, IconData icon, String format) {
    return GestureDetector(
      onTap: () => _exportData(format),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        borderColor: AppColors.secondary.withOpacity(0.3),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.secondary, size: 16),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontFamily: 'Poppins',
              fontSize: 10, fontWeight: FontWeight.w600,
              color: AppColors.secondary)),
        ]),
      ),
    );
  }

  // ── Export ──
  Future<void> _exportData(String format) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('📥 Export $format en cours...',
            style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/export/$format'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (format == 'stats' && response.statusCode == 200) {
        // Afficher stats dans dialog
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _showStatsDialog(json);
      } else if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Export $format sauvegardé dans Drive !',
              style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erreur export: ${response.statusCode}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showStatsDialog(Map<String, dynamic> stats) {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📊 Statistiques Dataset',
              style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 20),
          _statRow('Total corrections', '${stats['total']}', AppColors.accent),
          _statRow('Modifiés', '${stats['modifies']}', AppColors.primary),
          _statRow('Confirmés', '${stats['confirmes']}', AppColors.secondary),
          _statRow('Taux correction', '${stats['taux_correction']}%', Colors.orange),
          _statRow('Images crops', '${stats['crops_count']}', Colors.purple),
          const SizedBox(height: 12),
          const Text('Confiance moyenne par champ',
              style: TextStyle(fontFamily: 'Poppins',
                  fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 8),
          ...((stats['confiance_moy'] as Map<String, dynamic>?) ?? {})
              .entries.map((e) {
            final color = AppColors.fieldColors[e.key] ?? AppColors.primary;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                Text(AppConfig.fieldLabels[e.key] ?? e.key,
                    style: TextStyle(fontFamily: 'Poppins',
                        fontSize: 12, color: color)),
                Text('${e.value}%', style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ]),
            );
          }),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(
                fontFamily: 'Poppins', color: AppColors.accent)),
          ),
        ]),
      ),
    ));
  }

  Widget _statRow(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontFamily: 'Poppins',
          fontSize: 13, color: Colors.white70)),
      Text(value, style: TextStyle(fontFamily: 'Poppins',
          fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}