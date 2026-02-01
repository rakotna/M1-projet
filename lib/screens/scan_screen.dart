import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/screens/result_screen.dart';
import 'package:myapp/services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.cameras[0], // Utilise la première caméra disponible
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_isProcessing) return;

    try {
      setState(() { _isProcessing = true; });
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      // Appelle le service API simulé
      final apiService = ApiService();
      final results = await apiService.scanImage(image.path);

      if (!mounted) return;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ResultScreen(scanResult: results),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la capture : $e")),
      );
    } finally {
      setState(() { _isProcessing = false; });
    }
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
                CameraPreview(_controller),
                _buildUIOverlay(),
                if (_isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(),
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

  Widget _buildUIOverlay() {
    return Column(
        children: [
          // Top bar for flash control
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
                      _controller.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
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
                    border: Border.all(color: Colors.white.withOpacity(0.7), width: 2),
                    borderRadius: BorderRadius.circular(12)
                ),
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.document_scanner_outlined, color: Colors.white.withOpacity(0.7), size: 50),
                    SizedBox(height: 10),
                    Text("Placez la feuille de notes ici", style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.7)))
                  ],
                )
              ),
            ),
          ),
          // Bottom bar for capture button
          Padding(
            padding: const EdgeInsets.only(bottom: 50.0),
            child: GestureDetector(
              onTap: _takePicture,
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
