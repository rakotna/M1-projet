import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import 'scan_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Fond gradient
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
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const GlassCard(
                          padding: EdgeInsets.all(10),
                          borderRadius: 12,
                          child: Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      Text('Historique', style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700, color: Colors.white)),
                      const GlassCard(
                        padding: EdgeInsets.all(10),
                        borderRadius: 12,
                        child: Icon(Icons.filter_list,
                            color: Colors.white54, size: 20),
                      ),
                    ],
                  ),
                ),

                // ── Liste des bulletins ──
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('bulletins')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmpty(context);
                      }

                      final docs = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          return _BulletinCard(data: data, index: index)
                              .animate()
                              .fadeIn(delay: Duration(milliseconds: index * 60))
                              .slideX(begin: 0.1);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── FAB Scanner ──
          Positioned(
            bottom: 32,
            right: 24,
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ScanScreen())),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withOpacity(0.5),
                        blurRadius: 20),
                  ],
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const Icon(Icons.inbox_outlined,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Aucun bulletin scanné',
              style: GoogleFonts.poppins(fontSize: 18,
                  fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Scannez votre premier bulletin !',
              style: GoogleFonts.poppins(fontSize: 14,
                  color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 32),
          NeonButton(
            label: 'Scanner maintenant',
            icon: Icons.camera_alt,
            color: AppColors.primary,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ScanScreen())),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

// ── Carte d'un bulletin dans l'historique ──
class _BulletinCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final int index;

  const _BulletinCard({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final champs = data['champs'] as Map<String, dynamic>? ?? {};
    final nom    = champs['nom']    as String? ?? '—';
    final prenom = champs['prenom'] as String? ?? '—';
    final note   = champs['note']   as String? ?? '—';
    final mat    = champs['matiere'] as String? ?? '—';
    final matr   = champs['matricule'] as String? ?? '—';
    final date   = data['date']  as String? ?? '';
    final heure  = data['heure'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header carte
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.6),
                          AppColors.secondary.withOpacity(0.6),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text('${index + 1}',
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$nom $prenom',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      Text('N° $matr', style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white38)),
                    ],
                  ),
                ]),
                // Note badge
                if (note != '—')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [AppColors.accent, Color(0xFF00A86B)],
                      ),
                    ),
                    child: Text(note,
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
              ],
            ),

            if (mat != '—') ...[
              const SizedBox(height: 10),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Tag(Icons.book, mat, AppColors.secondary),
                  Text('$date  $heure',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: Colors.white24)),
                ],
              ),
            ],
          ],
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
      Text(label, style: GoogleFonts.poppins(
          fontSize: 12, color: color)),
    ]);
  }
}