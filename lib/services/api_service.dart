import 'dart:math';

// Classe pour simuler les appels à votre backend d'IA.
class ApiService {
  // Simule l'envoi d'une image et la réception des données reconnues.
  Future<Map<String, String>> scanImage(String imagePath) async {
    // Simule une latence réseau de 1 à 3 secondes.
    await Future.delayed(Duration(seconds: 1 + Random().nextInt(2)));

    // Simule une réponse réussie du backend.
    // Dans une vraie application, vous feriez un appel HTTP ici.
    return {
      'studentId': '${10000 + Random().nextInt(89999)}', // Génère un ID étudiant aléatoire
      'grade': '${12 + Random().nextDouble() * (8)}'.substring(0, 4), // Génère une note entre 12.0 et 20.0
    };
  }
}
