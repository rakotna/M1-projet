import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientation portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Status bar transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const ScolarAIApp());
}

class ScolarAIApp extends StatelessWidget {
  const ScolarAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScolarAI',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(context),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: GoogleFonts.poppinsTextTheme(textTheme).copyWith(
        displayLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
        displayMedium: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge:    GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
        bodyMedium:   GoogleFonts.poppins(fontSize: 14, color: Colors.white60),
      ),
      colorScheme: const ColorScheme.dark(
        primary:   Color(0xFF6C63FF),   // Violet néon
        secondary: Color(0xFF00D4FF),   // Cyan électrique
        tertiary:  Color(0xFF00FF94),   // Vert menthe
        error:     Color(0xFFFF4757),   // Rouge vif
        surface:   Color(0xFF0A0A1A),   // Fond très sombre
        onSurface: Color(0xFFE8E8FF),   // Texte clair
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0A1A),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ============================================
// CONSTANTES GLOBALES
// ============================================
class AppColors {
  static const primary    = Color(0xFF6C63FF);
  static const secondary  = Color(0xFF00D4FF);
  static const accent     = Color(0xFF00FF94);
  static const error      = Color(0xFFFF4757);
  static const background = Color(0xFF0A0A1A);
  static const surface    = Color(0xFF1A1A2E);
  static const glass      = Color(0x1AFFFFFF);
  static const glassBorder = Color(0x33FFFFFF);

  // Couleurs par champ OCR
  static const fieldColors = {
    'nom':       Color(0xFF6C63FF),
    'prenom':    Color(0xFF00D4FF),
    'matiere':   Color(0xFFFFBE0B),
    'note':      Color(0xFF00FF94),
    'matricule': Color(0xFFFF6B6B),
    'classe':    Color(0xFFFF9F43),
  };
}

class AppConfig {

  // Dans main.dart — ligne AppConfig
  static const String apiUrl = "https://thi-creasy-lightsomely.ngrok-free.dev";
  static const Map<String, String> apiHeaders = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  // Champs OCR
  static const List<String> fields = [
    'matricule', 'nom', 'prenom', 'classe', 'matiere', 'note'
  ];

  // Labels affichés
  static const Map<String, String> fieldLabels = {
    'nom':       'Nom',
    'prenom':    'Prénom',
    'matiere':   'Matière',
    'note':      'Note',
    'matricule': 'Matricule',
    'classe':    'Classe',
  };

  // Icônes par champ
  static const Map<String, IconData> fieldIcons = {
    'nom':       Icons.person,
    'prenom':    Icons.badge,
    'matiere':   Icons.book,
    'note':      Icons.grade,
    'matricule': Icons.numbers,
    'classe':    Icons.class_,
  };
}

// ============================================
// WIDGET GLASSMORPHISM RÉUTILISABLE
// ============================================
class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.borderRadius = 20,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: color ?? AppColors.glass,
        border: Border.all(
          color: borderColor ?? AppColors.glassBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

// ============================================
// BOUTON NÉON RÉUTILISABLE
// ============================================
class NeonButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color? color;
  final double? width;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
    this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [c, c.withOpacity(0.7)],
          ),
          boxShadow: [
            BoxShadow(color: c.withOpacity(0.4), blurRadius: 20, spreadRadius: 0),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label, style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            )),
          ],
        ),
      ),
    );
  }
}
