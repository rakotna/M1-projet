// import 'package:camera/camera.dart';
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:myapp/services/api_service.dart';

// class ScanScreen extends StatefulWidget {
//   final List<CameraDescription> cameras;

//   const ScanScreen({super.key, required this.cameras});

//   @override
//   State<ScanScreen> createState() => _ScanScreenState();
// }

// class _ScanScreenState extends State<ScanScreen> {
//   late CameraController _controller;
//   late Future<void> _initializeControllerFuture;
//   bool _isFlashOn = false;
//   bool _isProcessing = false;

//   @override
//   void initState() {
//     super.initState();
//     _controller = CameraController(
//       widget.cameras[0], // Utilise la première caméra disponible
//       ResolutionPreset.high,
//     );
//     _initializeControllerFuture = _controller.initialize();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   Future<void> _takePicture() async {
//     if (_isProcessing) return;

//     try {
//       setState(() { _isProcessing = true; });
//       await _initializeControllerFuture;
//       final image = await _controller.takePicture();

//       // Appelle le service API simulé
//       final apiService = ApiService();
//       final results = await apiService.scanImage(image.path);

//       if (!mounted) return;
      
//       context.go('/results', extra: results);

//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Erreur lors de la capture : $e")),
//       );
//     } finally {
//       setState(() { _isProcessing = false; });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: FutureBuilder<void>(
//         future: _initializeControllerFuture,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.done) {
//             return Stack(
//               children: [
//                 CameraPreview(_controller),
//                 _buildUIOverlay(),
//                 if (_isProcessing)
//                   Container(
//                     color: Colors.black.withOpacity(0.5),
//                     child: const Center(
//                       child: CircularProgressIndicator(),
//                     ),
//                   ),
//               ],
//             );
//           } else {
//             return const Center(child: CircularProgressIndicator());
//           }
//         },
//       ),
//     );
//   }

//   Widget _buildUIOverlay() {
//     return Column(
//         children: [
//           // Top bar for flash control
//           Container(
//             padding: const EdgeInsets.only(top: 40, right: 20),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 IconButton(
//                   icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
//                   color: Colors.white,
//                   iconSize: 32,
//                   onPressed: () {
//                     setState(() {
//                       _isFlashOn = !_isFlashOn;
//                       _controller.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
//                     });
//                   },
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: Center(
//               child: Container(
//                  decoration: BoxDecoration(
//                     border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
//                     borderRadius: BorderRadius.circular(12)
//                 ),
//                 width: MediaQuery.of(context).size.width * 0.9,
//                 height: MediaQuery.of(context).size.height * 0.3,
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.document_scanner_outlined, color: Colors.white.withOpacity(0.7), size: 50),
//                     SizedBox(height: 10),
//                     Text("Placez la feuille de notes ici", style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.7)))
//                   ],
//                 )
//               ),
//             ),
//           ),
//           // Bottom bar for capture button
//           Padding(
//             padding: const EdgeInsets.only(bottom: 50.0),
//             child: GestureDetector(
//               onTap: _takePicture,
//               child: Container(
//                 height: 80,
//                 width: 80,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: Colors.transparent,
//                   border: Border.all(color: Colors.white, width: 4),
//                 ),
//                 child: Center(
//                   child: Container(
//                     height: 65,
//                     width: 65,
//                     decoration: const BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: Colors.white,
//                     ),
//                   ), 
//                 ),
//               ),
//             ),
//           ),
//         ],
//       );
//     }
// }
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/services/api_service.dart';
import 'package:myapp/screens/result_screen.dart';
import 'dart:async';

class ScanScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ScanScreen({super.key, required this.cameras});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isFlashOn = false;
  bool _isProcessing = false;
  bool _isConnected = false;
  bool _isCheckingConnection = true;
  
  // ✅ Nouvelles variables pour la détection en temps réel
  Timer? _detectionTimer;
  List<Map<String, dynamic>> _detections = [];
  String _currentNote = "---";

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.cameras[0],
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
    _checkBackendConnection();
    
    // ✅ Démarre la détection automatique après initialisation
    _initializeControllerFuture.then((_) {
      _startContinuousDetection();
    });
  }

  Future<void> _checkBackendConnection() async {
    setState(() { _isCheckingConnection = true; });
    
    final connected = await _apiService.checkConnection();
    
    if (mounted) {
      setState(() {
        _isConnected = connected;
        _isCheckingConnection = false;
      });
    }
  }

  // ✅ Détection continue toutes les 1.5 secondes
  void _startContinuousDetection() {
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!_isProcessing && _isConnected) {
        _detectObjects();
      }
    });
  }

  // ✅ Fonction de détection sans prendre de photo
  Future<void> _detectObjects() async {
    if (_isProcessing || !_controller.value.isInitialized) return;

    try {
      setState(() { _isProcessing = true; });
      
      final image = await _controller.takePicture();
      final results = await _apiService.scanImage(image.path);

      if (!mounted) return;

      setState(() {
        _detections = List<Map<String, dynamic>>.from(results['detections'] ?? []);
        _currentNote = results['note'] ?? '---';
      });

    } catch (e) {
      print('Erreur détection: $e');
    } finally {
      if (mounted) {
        setState(() { _isProcessing = false; });
      }
    }
  }

  // ✅ Fonction pour capturer et naviguer vers les résultats
  Future<void> _takePictureAndNavigate() async {
    if (_isProcessing) return;

    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Backend non connecté"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Arrête la détection continue
      _detectionTimer?.cancel();
      
      setState(() { _isProcessing = true; });
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      final results = await _apiService.scanImage(image.path);

      if (!mounted) return;

      final scanResult = {
        'studentId': 'Non implémenté',
        'grade': results['note'] ?? 'Non reconnue',
      };

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ResultScreen(scanResult: scanResult),
        ),
      );
      
      // Redémarre la détection après retour
      _startContinuousDetection();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      if (mounted) {
        setState(() { _isProcessing = false; });
      }
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                // Caméra
                Positioned.fill(
                  child: CameraPreview(_controller),
                ),
                
                // ✅ Overlay avec détections
                Positioned.fill(
                  child: CustomPaint(
                    painter: DetectionPainter(
                      detections: _detections,
                      cameraSize: Size(
                        _controller.value.previewSize?.height ?? 1,
                        _controller.value.previewSize?.width ?? 1,
                      ),
                    ),
                  ),
                ),
                
                // UI Controls
                _buildUIOverlay(),
                _buildConnectionIndicator(),
                
                // Note actuelle en haut au centre
                if (_currentNote != "---")
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _currentNote,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                
                if (_isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    return Positioned(
      top: 50,
      left: 20,
      child: GestureDetector(
        onTap: _checkBackendConnection,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isCheckingConnection)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _isConnected ? Colors.green : Colors.red,
                  size: 16,
                ),
              const SizedBox(width: 6),
              Text(
                _isCheckingConnection
                    ? 'Vérification...'
                    : (_isConnected ? 'Connecté' : 'Déconnecté'),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUIOverlay() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(top: 40, right: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
                color: Colors.white,
                iconSize: 32,
                onPressed: () {
                  setState(() {
                    _isFlashOn = !_isFlashOn;
                    _controller.setFlashMode(
                      _isFlashOn ? FlashMode.torch : FlashMode.off
                    );
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.7),
                  width: 2
                ),
                borderRadius: BorderRadius.circular(12)
              ),
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.document_scanner_outlined,
                    color: Colors.white.withOpacity(0.7),
                    size: 50
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Placez la feuille de notes ici",
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.7)
                    )
                  )
                ],
              )
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 50.0),
          child: GestureDetector(
            onTap: _takePictureAndNavigate,
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: Container(
                  height: 65,
                  width: 65,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ), 
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ✅ CustomPainter pour dessiner les boîtes de détection
class DetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size cameraSize;

  DetectionPainter({
    required this.detections,
    required this.cameraSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var detection in detections) {
      final box = detection['box'] as List;
      final text = detection['text'] as String;
      final conf = detection['conf'] as num;

      // Conversion des coordonnées normalisées
      final x1 = box[0] * size.width;
      final y1 = box[1] * size.height;
      final x2 = box[2] * size.width;
      final y2 = box[3] * size.height;

      // Rectangle vert
      final paint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;

      canvas.drawRect(
        Rect.fromLTRB(x1, y1, x2, y2),
        paint,
      );

      // Label "Note" en haut
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Note',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Background du label
      final labelBg = Paint()..color = Colors.green;
      canvas.drawRect(
        Rect.fromLTWH(x1, y1 - 30, textPainter.width + 20, 30),
        labelBg,
      );
      textPainter.paint(canvas, Offset(x1 + 10, y1 - 25));

      // Valeur détectée en bas
      if (text.isNotEmpty && text != "---") {
        final valuePainter = TextPainter(
          text: TextSpan(
            text: '$text (${conf.toStringAsFixed(1)}%)',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        valuePainter.layout();

        canvas.drawRect(
          Rect.fromLTWH(x1, y2 + 5, valuePainter.width + 20, 35),
          labelBg,
        );
        valuePainter.paint(canvas, Offset(x1 + 10, y2 + 13));
      }
    }
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) {
    return detections != oldDelegate.detections;
  }
}