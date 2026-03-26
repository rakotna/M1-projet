import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../main.dart';
import '../services/database_helper.dart';
import '../models/scan_result.dart';
import 'scan_screen.dart';

enum _SortMode { recent, ancien, note, nom }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<ScanResult>> _resultsFuture;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  _SortMode _sortMode = _SortMode.recent;
  bool _showFilterPanel = false;

  bool _isExporting = false;

  final Set<int> _selectedIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  void _refreshHistory() {
    setState(() {
      _resultsFuture = DatabaseHelper.instance.readAllResults();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ScanResult> _filterAndSort(List<ScanResult> results) {
    var filtered = results.where((result) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return [
        result.nom,
        result.prenom,
        result.ocrResults['matricule'] ?? '',
        result.matiere,
        result.ocrResults['classe'] ?? '',
        result.note,
      ].any((v) => v.toLowerCase().contains(q));
    }).toList();

    switch (_sortMode) {
      case _SortMode.recent:
        filtered.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
        break;
      case _SortMode.ancien:
        filtered.sort((a, b) => a.scannedAt.compareTo(b.scannedAt));
        break;
      case _SortMode.note:
        filtered.sort((a, b) {
          final na = double.tryParse(a.note.replaceAll(',', '.')) ?? -1;
          final nb = double.tryParse(b.note.replaceAll(',', '.')) ?? -1;
          return nb.compareTo(na);
        });
        break;
      case _SortMode.nom:
        filtered.sort((a, b) {
          final na = '${a.nom}${a.prenom}'.toLowerCase();
          final nb = '${b.nom}${b.prenom}'.toLowerCase();
          return na.compareTo(nb);
        });
        break;
    }

    return filtered;
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Supprimer ${_selectedIds.length} bulletin(s) ?',
        message: 'Cette action est irréversible.',
        confirmLabel: 'Supprimer',
        confirmColor: AppColors.error,
      ),
    );
    if (confirm != true) return;

    for (final id in _selectedIds) {
      await DatabaseHelper.instance.delete(id);
    }

    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
    _refreshHistory();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('🗑️ Bulletins supprimés', style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _deleteSingle(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmDialog(
        title: 'Supprimer ce bulletin ?',
        message: 'Cette action est irréversible.',
        confirmLabel: 'Supprimer',
        confirmColor: AppColors.error,
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.instance.delete(id);
    _refreshHistory();
  }

  Future<void> _exportToExcel(List<ScanResult> results) async {
    if (results.isEmpty) return;

    setState(() => _isExporting = true);

    try {
      final excel = Excel.createExcel();
      final Sheet sheet = excel['Bulletins'];
      excel.setDefaultSheet('Bulletins');

      const headers = [
        '#', 'Date Scan', 'Heure Scan', 'Matricule', 'Nom', 'Prénom',
        'Classe', 'Matière', 'Note'
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (var i = 0; i < results.length; i++) {
        final result = results[i];
        final rowData = [
          TextCellValue('${i + 1}'),
          TextCellValue('${result.scannedAt.day}/${result.scannedAt.month}/${result.scannedAt.year}'),
          TextCellValue('${result.scannedAt.hour}:${result.scannedAt.minute}'),
          TextCellValue(result.ocrResults['matricule'] ?? ''),
          TextCellValue(result.nom),
          TextCellValue(result.prenom),
          TextCellValue(result.ocrResults['classe'] ?? ''),
          TextCellValue(result.matiere),
          TextCellValue(result.note),
        ];
        sheet.appendRow(rowData);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Encodage Excel échoué');

      final directory = await getApplicationDocumentsDirectory();
      const fileName = 'ScolarAI_Historique.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      setState(() => _isExporting = false);

      final result = await OpenFilex.open(filePath);

      if(result.type != ResultType.done) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Impossible d\'ouvrir le fichier. Installez une application de tableur (Ex: Google Sheets).', style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: AppColors.error,
        ));
      } else {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Fichier Excel "$fileName" mis à jour.', style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: AppColors.accent,
        ));
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Export échoué : $e', style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0A0A1A), Color(0xFF1A0A2E), Color(0xFF0A1A2E)],
            ),
          ),
        ),
        SafeArea(
          child: FutureBuilder<List<ScanResult>>(
            future: _resultsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}', style: GoogleFonts.poppins(color: Colors.white)));
              }

              final allResults = snapshot.data ?? [];
              final filteredResults = _filterAndSort(allResults);

              return Column(children: [
                _buildHeader(filteredResults, allResults.length),
                _buildSearchBar(),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _showFilterPanel ? _buildFilterPanel() : const SizedBox.shrink(),
                ),
                if (_selectionMode) _buildSelectionBar(),
                Expanded(
                  child: filteredResults.isEmpty
                      ? _buildEmpty(context, allResults.isEmpty)
                      : _buildList(filteredResults),
                ),
              ]);
            },
          ),
        ),
        if (!_selectionMode)
          Positioned(
            bottom: 32, right: 24,
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                  boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(128), blurRadius: 20)],
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
              ),
            ),
          ),
        if (_isExporting)
          Container(
            color: Colors.black.withAlpha(178),
            child: Center(
              child: GlassCard(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Génération Excel…', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildHeader(List<ScanResult> filtered, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const GlassCard(
              padding: EdgeInsets.all(10), borderRadius: 12,
              child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            ),
          ),
          Column(children: [
            Text('Historique', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(
              _searchQuery.isNotEmpty || _sortMode != _SortMode.recent
                  ? '${filtered.length} / $total bulletins'
                  : '$total bulletins',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.white38),
            ),
          ]),
          Row(children: [
            GestureDetector(
              onTap: filtered.isEmpty ? null : () => _exportToExcel(filtered),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(colors: [Color(0xFF1D6F42), Color(0xFF27AE60)]),
                  boxShadow: [BoxShadow(color: const Color(0xFF1D6F42).withAlpha(102), blurRadius: 12)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.table_chart_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 5),
                  Text('Excel', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _showFilterPanel = !_showFilterPanel),
              child: GlassCard(
                padding: const EdgeInsets.all(10),
                borderRadius: 12,
                borderColor: _showFilterPanel ? AppColors.primary.withAlpha(153) : AppColors.glassBorder,
                child: Icon(Icons.tune_rounded, color: _showFilterPanel ? AppColors.primary : Colors.white54, size: 18),
              ),
            ),
          ]),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), borderRadius: 14,
        child: Row(children: [
          const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nom, prénom, matricule, matière, note…',
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.white24),
                border: InputBorder.none, isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
              child: const Icon(Icons.close_rounded, color: Colors.white38, size: 16),
            ),
        ]),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildFilterPanel() {
    const modes = [
      (_SortMode.recent, Icons.schedule_rounded, 'Plus récent'),
      (_SortMode.ancien, Icons.history_rounded, 'Plus ancien'),
      (_SortMode.note, Icons.grade_rounded, 'Note ↓'),
      (_SortMode.nom, Icons.sort_by_alpha_rounded, 'Nom A→Z'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: AppColors.primary.withAlpha(51),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trier par', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: modes.map((m) {
                final isActive = _sortMode == m.$1;
                return GestureDetector(
                  onTap: () => setState(() => _sortMode = m.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isActive ? AppColors.primary.withAlpha(64) : Colors.transparent,
                      border: Border.all(
                        color: isActive ? AppColors.primary : Colors.white24,
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(m.$2, size: 14, color: isActive ? AppColors.primary : Colors.white54),
                      const SizedBox(width: 6),
                      Text(m.$3, style: GoogleFonts.poppins(fontSize: 12, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal, color: isActive ? AppColors.primary : Colors.white54)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.error.withAlpha(38),
        border: Border.all(color: AppColors.error.withAlpha(102)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${_selectedIds.length} sélectionné(s)', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.error)),
          Row(children: [
            GestureDetector(
              onTap: _deleteSelected,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.error),
                child: Text('Supprimer', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() {
                _selectedIds.clear();
                _selectionMode = false;
              }),
              child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildList(List<ScanResult> results) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final id = result.id!;

        return _BulletinCard(
          result: result,
          index: index,
          selected: _selectedIds.contains(id),
          onLongPress: () => setState(() {
            _selectionMode = true;
            _selectedIds.add(id);
          }),
          onTap: () {
            if (_selectionMode) {
              setState(() {
                if (_selectedIds.contains(id)) {
                  _selectedIds.remove(id);
                  if (_selectedIds.isEmpty) _selectionMode = false;
                } else {
                  _selectedIds.add(id);
                }
              });
            }
          },
          onDelete: () => _deleteSingle(id),
        ).animate().fadeIn(delay: Duration(milliseconds: index * 50)).slideX(begin: 0.08);
      },
    );
  }

  Widget _buildEmpty(BuildContext context, bool noData) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withAlpha(25),
            border: Border.all(color: AppColors.primary.withAlpha(77)),
          ),
          child: Icon(noData ? Icons.inbox_outlined : Icons.search_off_rounded, color: AppColors.primary, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          noData ? 'Aucun bulletin scanné' : 'Aucun résultat pour\n"$_searchQuery"',
          style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          noData ? 'Scannez votre premier bulletin !' : 'Essayez un autre terme de recherche',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white.withAlpha(102)),
        ),
        if (noData) ...[
          const SizedBox(height: 32),
          NeonButton(
            label: 'Scanner maintenant',
            icon: Icons.camera_alt, color: AppColors.primary,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
          ),
        ],
      ]).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

class _BulletinCard extends StatelessWidget {
  final ScanResult result;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  const _BulletinCard({
    required this.result,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final nom = result.nom;
    final prenom = result.prenom;
    final note = result.note;
    final mat = result.matiere;
    final matr = result.ocrResults['matricule'] ?? '—';
    final classe = result.ocrResults['classe'] ?? '';
    final date = '${result.scannedAt.day}/${result.scannedAt.month}/${result.scannedAt.year}';
    final heure = '${result.scannedAt.hour}:${result.scannedAt.minute}';

    Color noteColor = AppColors.accent;
    final noteVal = double.tryParse(note.replaceAll(',', '.')) ?? -1;
    if (noteVal >= 0) {
      if (noteVal >= 14) {
        noteColor = AppColors.accent;
      } else if (noteVal >= 10) noteColor = AppColors.secondary;
      else noteColor = AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.error.withAlpha(178) : AppColors.glassBorder,
              width: selected ? 2 : 1.5,
            ),
            color: selected ? AppColors.error.withAlpha(20) : AppColors.glass,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    selected
                        ? Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.error.withAlpha(51),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: const Icon(Icons.check_rounded, color: AppColors.error, size: 18),
                          )
                        : Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [AppColors.primary.withAlpha(153), AppColors.secondary.withAlpha(153)]),
                            ),
                            child: Center(
                              child: Text('${index + 1}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$nom $prenom', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                      Row(children: [
                        Text('N° $matr', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white38)),
                        if (classe.isNotEmpty) ...[
                          const Text('  •  ', style: TextStyle(color: Colors.white24, fontSize: 11)),
                          Text(classe, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white38)),
                        ],
                      ]),
                    ]),
                  ]),
                  Row(children: [
                    if (note.isNotEmpty && note != '—')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(colors: [noteColor, noteColor.withAlpha(178)]),
                        ),
                        child: Text(note, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white24, size: 18),
                    ),
                  ]),
                ]),
                if (mat.isNotEmpty && mat != '—') ...[
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _Tag(Icons.book_rounded, mat, AppColors.secondary),
                    Text('$date  $heure', style: GoogleFonts.poppins(fontSize: 11, color: Colors.white24)),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Tag(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.poppins(fontSize: 12, color: color)),
    ]);
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.warning_amber_rounded, color: confirmColor, size: 40),
          const SizedBox(height: 14),
          Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 12), borderRadius: 12,
                  child: Text('Annuler', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54), textAlign: TextAlign.center),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: confirmColor),
                  child: Text(confirmLabel, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), textAlign: TextAlign.center),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
