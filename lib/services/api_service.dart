import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

class ApiService {
  // ✅ Ton URL ngrok
  static const String baseUrl = "https://thi-creasy-lightsomely.ngrok-free.dev";

  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/detect'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 405 || response.statusCode == 200;
    } catch (e) {
      developer.log('Erreur de connexion: $e', name: 'ApiService');
      return false;
    }
  }

  Future<Map<String, dynamic>> scanImage(String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect'),
      );

      // ✅ Ajoute le header ngrok
      request.headers['ngrok-skip-browser-warning'] = 'true';

      request.files.add(
        await http.MultipartFile.fromPath('frame', imagePath),
      );

      developer.log('📤 Envoi de l\'image au backend...', name: 'ApiService');
      
      var response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      
      var responseData = await response.stream.bytesToString();
      
      developer.log('📥 Réponse reçue (${response.statusCode}): $responseData', name: 'ApiService');
      
      if (response.statusCode == 200) {
        return json.decode(responseData);
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('❌ Erreur complète: $e', name: 'ApiService');
      throw Exception('Erreur de connexion: $e');
    }
  }
}
