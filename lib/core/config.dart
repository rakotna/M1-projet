import 'package:flutter/material.dart';
import 'colors.dart';

class AppConfig {
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

  // Couleurs par champ
  static const Map<String, Color> fieldColors = {
    'nom':       AppColors.primary,
    'prenom':    AppColors.secondary,
    'matiere':   Color(0xFF29B6F6), // Light Blue
    'note':      AppColors.accent,
    'matricule': Color(0xFFFF9F43), // Orange
    'classe':    Color(0xFF7E57C2), // Deep Purple
  };
}