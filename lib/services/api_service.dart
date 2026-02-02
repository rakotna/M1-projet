// import 'dart:math';

// // Classe pour simuler les appels à votre backend d'IA.
// class ApiService {
//   // Simule l'envoi d'une image et la réception des données reconnues.
//   Future<Map<String, String>> scanImage(String imagePath) async {
//     // Simule une latence réseau de 1 à 3 secondes.
//     await Future.delayed(Duration(seconds: 1 + Random().nextInt(2)));

//     // Simule une réponse réussie du backend.
//     // Dans une vraie application, vous feriez un appel HTTP ici.
//     return {
//       'studentId': '${10000 + Random().nextInt(89999)}', // Génère un ID étudiant aléatoire
//       'grade': '${12 + Random().nextDouble() * (8)}'.substring(0, 4), // Génère une note entre 12.0 et 20.0
//     };
//   }
// }

import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  // ⚠️ Remplace par ton URL ngrok après avoir lancé le backend
  static const String baseUrl = "https://thi-creasy-lightsomely.ngrok-free.dev";

    // Nouvelle méthode pour tester la connexion
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/detect'),
      ).timeout(const Duration(seconds: 3));
      
      return response.statusCode == 405 || response.statusCode == 200;
      // 405 = Method Not Allowed (normal pour GET sur route POST)
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> scanImage(String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('frame', imagePath),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        return json.decode(responseData);
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
}
