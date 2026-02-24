import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../main.dart';
import 'result_screen.dart';

// ── Coin OBB ──
class ObbCorner {
  final double x, y;
  const ObbCorner(this.x, this.y);
}

// ── Box détectée ──
class DetectedBox {
  final String field;
  final double confidence;
  final String color;
  final String cropB64;
  // HBB pour compatibilité
  final Rect box;
  // OBB réel avec coins pour polygone incliné
  final List<ObbCorner>? corners;
  final double angle;

  const DetectedBox({
    required this.field,
    required this.confidence,
    required this.color,
    required this.cropB64,
    required this.box,
    this.corners,
    this.angle = 0.0,
  });

  factory DetectedBox.fromJson(Map<String, dynamic> json) {
    final b = json['box'] as Map<String, dynamic>;

    // Parser coins OBB si disponibles
    List<ObbCorner>? corners;
    double angle = 0.0;
    if (json.containsKey('obb')) {
      final obb = json['obb'] as Map<String, dynamic>;
      angle     = (obb['angle'] as num?)?.toDouble() ?? 0.0;
      final rawCorners = obb['corners'] as List<dynamic>?;
      if (rawCorners != null) {
        corners = rawCorners.map((c) {
          final cm = c as Map<String, dynamic>;
          return ObbCorner(
            (cm['x'] as num).toDouble(),
            (cm['y'] as num).toDouble(),
          );
        }).toList();
      }
    }

    return DetectedBox(
      field:      json['field']      as String,
      confidence: (json['confidence'] as num).toDouble(),
      color:      json['color']      as String? ?? '#6C63FF',
      cropB64:    json['crop_b64']   as String? ?? '',
      box: Rect.fromLTWH(
        (b['left']   as num).toDouble(),
        (b['top']    as num).toDouble(),
        (b['width']  as num).toDouble(),
        (b['height'] as num).toDouble(),
      ),
      corners: corners,
      angle:   angle,
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {

  CameraController? _cam;
  bool _isCamReady  = false;
  bool _isScanning  = false;
  bool _isSending   = false;
  bool _isCapturing = false;

  Timer? _frameTimer;

  List<DetectedBox>        _liveBoxes  = [];
  Map<String, DetectedBox> _bestMemory = {};

  final List<String> _logs  = [];
  int _framesSent    = 0;
  int _framesSuccess = 0;
  int _framesError   = 0;

  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _addLog('ScolarAI v4.0 — OBB avec angle');
    _addLog('API: ${AppConfig.apiUrl}');
    _initCamera();
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _cam?.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _addLog(String msg) {
    if (!mounted) return;
    final t  = DateTime.now();
    final ts = '${t.hour}:${t.minute.toString().padLeft(2,'0')}:'
               '${t.second.toString().padLeft(2,'0')}';
    setState(() {
      _logs.insert(0, '[$ts] $msg');
      if (_logs.length > 25) _logs.removeLast();
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) { _addLog('❌ Aucune caméra'); return; }
      _cam = CameraController(cameras[0], ResolutionPreset.high,
          enableAudio: false);
      await _cam!.initialize();
      await _cam!.setFocusMode(FocusMode.auto);
      await _cam!.setExposureMode(ExposureMode.auto);
      if (!mounted) return;
      setState(() => _isCamReady = true);
      _addLog('✅ Caméra HIGH prête');
    } catch (e) {
      _addLog('❌ Caméra: $e');
    }
  }

  void _startScan() {
    if (!_isCamReady) return;
    setState(() {
      _isScanning = true;
      _liveBoxes  = [];
      _bestMemory.clear();
      _framesSent = _framesSuccess = _framesError = 0;
    });
    _addLog('▶ Scan OBB — 1 frame/sec');
    _frameTimer = Timer.periodic(
        const Duration(milliseconds: 1000), (_) => _captureFrame());
  }

  void _stopScan() {
    _frameTimer?.cancel();
    setState(() => _isScanning = false);
    _addLog('⏹ Arrêt | OK:$_framesSuccess ERR:$_framesError');
  }

  Future<void> _captureFrame() async {
    if (_isCapturing || !_isCamReady || _isSending) return;
    _isCapturing = true;
    _framesSent++;

    try {
      final XFile photo = await _cam!.takePicture();
      final rawBytes    = await File(photo.path).readAsBytes();
      await File(photo.path).delete();

      final compressed = _compress(rawBytes, quality: 75, maxDim: 1024);
      final b64        = base64Encode(compressed);

      _addLog('📸 ${rawBytes.length~/1024}KB→${compressed.length~/1024}KB');

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/detect'),
        headers: {
          'Content-Type':               'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'image': b64}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        _framesError++;
        final preview = response.body.length > 60
            ? response.body.substring(0, 60) : response.body;
        _addLog('❌ HTTP ${response.statusCode}: $preview');
        return;
      }

      final json  = jsonDecode(response.body) as Map<String, dynamic>;
      final count = json['count'] as int? ?? 0;
      _framesSuccess++;

      if (count > 0) {
        final newBoxes = (json['boxes'] as List<dynamic>)
            .map((b) => DetectedBox.fromJson(b as Map<String, dynamic>))
            .toList();

        // Mémoire temporelle — meilleure conf par champ
        for (final box in newBoxes) {
          final prev = _bestMemory[box.field];
          if (prev == null || box.confidence > prev.confidence) {
            _bestMemory[box.field] = box;
            _addLog('💾 ${box.field}: ${(box.confidence*100).toStringAsFixed(0)}% '
                    '${box.angle.abs() > 1 ? "(${box.angle.toStringAsFixed(1)}°)" : ""}');
          }
        }

        if (!mounted) return;
        setState(() => _liveBoxes = newBoxes);
        _animCtrl.forward(from: 0);
      } else {
        if (!mounted) return;
        setState(() => _liveBoxes = []);
        _addLog('⚪ Aucune box dans cette frame');
      }

    } catch (e) {
      _framesError++;
      final s = e.toString();
      _addLog('❌ ${s.length > 70 ? s.substring(0,70) : s}');
    } finally {
      _isCapturing = false;
    }
  }

  Uint8List _compress(Uint8List bytes, {int quality = 75, int maxDim = 1024}) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      img.Image out = decoded;
      if (decoded.width > maxDim || decoded.height > maxDim) {
        out = decoded.width > decoded.height
            ? img.copyResize(decoded, width: maxDim,
                interpolation: img.Interpolation.linear)
            : img.copyResize(decoded, height: maxDim,
                interpolation: img.Interpolation.linear);
      }
      return Uint8List.fromList(img.encodeJpg(out, quality: quality));
    } catch (_) { return bytes; }
  }

  Future<void> _analyzeWithTrOCR() async {
    if (_bestMemory.isEmpty) { _addLog('❌ Rien mémorisé'); return; }
    _stopScan();
    setState(() => _isSending = true);
    _addLog('🤖 TrOCR — ${_bestMemory.length} crops redressés...');

    try {
      final cropsPayload = <String, String>{
        for (final e in _bestMemory.entries) e.key: e.value.cropB64
      };
      final XFile? finalPhoto = await _cam?.takePicture();

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/ocr'),
        headers: {
          'Content-Type':               'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({'crops': cropsPayload}),
      ).timeout(const Duration(seconds: 120));

      _addLog('📨 TrOCR: HTTP ${response.statusCode}');
      if (!mounted) return;

      if (response.statusCode == 200) {
        final json    = jsonDecode(response.body) as Map<String, dynamic>;
        // results est maintenant { field: { text, crop_b64 } }
        final raw     = json['results'] as Map<String, dynamic>? ?? {};
        final texts   = raw.map((k, v) {
          final vm = v as Map<String, dynamic>;
          return MapEntry(k, vm['text']?.toString() ?? '');
        });
        final cropB64s = raw.map((k, v) {
          final vm = v as Map<String, dynamic>;
          return MapEntry(k, vm['crop_b64']?.toString() ?? '');
        });

        _addLog('✅ Résultats: $texts');

        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ResultScreen(
            imagePath:  finalPhoto?.path ?? '',
            detections: {for (final e in _bestMemory.entries) e.key: e.value},
            bestConf:   {for (final e in _bestMemory.entries)
                          e.key: e.value.confidence},
            ocrResults: texts,
            cropImages: cropB64s,  // crops à afficher dans ResultScreen
          ),
        ));
      } else {
        _addLog('❌ TrOCR: ${response.statusCode}');
        setState(() => _isSending = false);
      }
    } catch (e) {
      _addLog('❌ Exception: $e');
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (_isCamReady)
          CameraPreview(_cam!)
        else
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),

        // ── Boxes OBB inclinées ──
        if (_liveBoxes.isNotEmpty)
          IgnorePointer(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
              child: CustomPaint(
                painter: _ObbBoxPainter(boxes: _liveBoxes),
                child: const SizedBox.expand(),
              ),
            ),
          ),

        // ── Coins visée ──
        IgnorePointer(
          child: CustomPaint(
            painter: _CornersPainter(isScanning: _isScanning),
            child: const SizedBox.expand(),
          ),
        ),

        SafeArea(child: Column(children: [
          _buildTopBar(),
          const Spacer(),
          _buildLogsPanel(),
          const SizedBox(height: 8),
          _buildChips(),
          const SizedBox(height: 10),
          _buildButtons(),
          const SizedBox(height: 20),
        ])),

        if (_isSending)
          Container(color: Colors.black.withOpacity(0.7),
            child: Center(child: GlassCard(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                const Text('TrOCR analyse les crops redressés...',
                    style: TextStyle(fontFamily: 'Poppins',
                        color: Colors.white, fontSize: 14)),
                const SizedBox(height: 6),
                Text('${_bestMemory.length} zones mémorisées',
                    style: const TextStyle(fontFamily: 'Poppins',
                        color: Colors.white54, fontSize: 12)),
              ]),
            )),
          ),
      ]),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      GestureDetector(
        onTap: () { _stopScan(); Navigator.pop(context); },
        child: GlassCard(padding: const EdgeInsets.all(10), borderRadius: 12,
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18)),
      ),
      const SizedBox(width: 10),
      Expanded(child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: 16,
        child: Text('📡 $_framesSent | ✅ $_framesSuccess | ❌ $_framesError',
            style: const TextStyle(fontFamily: 'Poppins',
                fontSize: 10, color: Colors.white70),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      )),
      const SizedBox(width: 10),
      GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: 12,
        borderColor: AppColors.accent.withOpacity(0.5),
        child: Text('${_bestMemory.length}/6',
            style: const TextStyle(fontFamily: 'Poppins',
                fontSize: 14, fontWeight: FontWeight.w700,
                color: AppColors.accent)),
      ),
    ]),
  );

  Widget _buildLogsPanel() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GlassCard(
      padding: const EdgeInsets.all(10), borderRadius: 12,
      child: SizedBox(
        height: 110,
        child: _logs.isEmpty
            ? const Center(child: Text('Logs...',
                style: TextStyle(fontFamily: 'Poppins',
                    fontSize: 11, color: Colors.white38)))
            : ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (_, i) => Text(_logs[i],
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10,
                    color: _logs[i].contains('❌') ? AppColors.error
                        : _logs[i].contains('✅') ? AppColors.accent
                        : _logs[i].contains('💾') ? AppColors.primary
                        : _logs[i].contains('📸') ? Colors.orange
                        : Colors.white60),
                ),
      ),
    )),
  );

  Widget _buildChips() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: AppConfig.fields.map((field) {
      final best  = _bestMemory[field];
      final live  = _liveBoxes.any((b) => b.field == field);
      final color = AppColors.fieldColors[field] ?? AppColors.primary;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: live ? color.withOpacity(0.4)
              : best != null ? color.withOpacity(0.2) : Colors.black54,
          border: Border.all(
            color: live ? color
                : best != null ? color.withOpacity(0.5) : Colors.white24,
            width: live ? 2 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(live ? Icons.visibility
              : best != null ? Icons.check_circle : Icons.circle_outlined,
              color: live ? color
                  : best != null ? color.withOpacity(0.8) : Colors.white38,
              size: 12),
          const SizedBox(width: 4),
          Text(AppConfig.fieldLabels[field] ?? field,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                  fontWeight: best != null ? FontWeight.w600 : FontWeight.normal,
                  color: best != null ? color : Colors.white38)),
          if (best != null) ...[
            const SizedBox(width: 3),
            Text('${(best.confidence*100).toStringAsFixed(0)}%',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 9,
                    color: color.withOpacity(0.8))),
            if (best.angle.abs() > 2) ...[
              const SizedBox(width: 2),
              Text('${best.angle.toStringAsFixed(0)}°',
                  style: const TextStyle(fontFamily: 'Poppins',
                      fontSize: 8, color: Colors.orange)),
            ],
          ],
        ]),
      );
    }).toList()),
  );

  Widget _buildButtons() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(children: [
      if (!_isScanning)
        NeonButton(label: _isCamReady ? 'Démarrer le scan' : 'Caméra...',
            icon: Icons.play_arrow_rounded, color: AppColors.primary,
            width: double.infinity,
            onTap: _isCamReady ? _startScan : () {})
      else
        NeonButton(label: 'Pause', icon: Icons.pause_rounded,
            color: AppColors.error, width: double.infinity, onTap: _stopScan),
      if (_bestMemory.isNotEmpty) ...[
        const SizedBox(height: 10),
        NeonButton(
            label: 'Analyser ${_bestMemory.length} zone(s) ✨',
            icon: Icons.auto_awesome, color: AppColors.accent,
            width: double.infinity, onTap: _analyzeWithTrOCR),
      ],
    ]),
  );
}

// ── Painter OBB inclinés ──
class _ObbBoxPainter extends CustomPainter {
  final List<DetectedBox> boxes;
  const _ObbBoxPainter({required this.boxes});

  Color _hex(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in boxes) {
      final color = _hex(box.color);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      if (box.corners != null && box.corners!.length == 4) {
        // ── Polygone OBB incliné ──
        final pts = box.corners!.map((c) =>
            Offset(c.x * size.width, c.y * size.height)).toList();

        final path = Path()
          ..moveTo(pts[0].dx, pts[0].dy)
          ..lineTo(pts[1].dx, pts[1].dy)
          ..lineTo(pts[2].dx, pts[2].dy)
          ..lineTo(pts[3].dx, pts[3].dy)
          ..close();

        // Ombre
        canvas.drawPath(path,
          Paint()..color = color.withOpacity(0.15)
                 ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

        // Contour OBB
        canvas.drawPath(path, paint);

        // Label au premier coin
        final labelPt = pts[0];
        _drawLabel(canvas, color, labelPt,
            '${AppConfig.fieldLabels[box.field] ?? box.field} '
            '${(box.confidence*100).toStringAsFixed(0)}%'
            '${box.angle.abs() > 1 ? " ${box.angle.toStringAsFixed(0)}°" : ""}');

      } else {
        // Fallback HBB
        final rect = Rect.fromLTWH(
          box.box.left   * size.width,
          box.box.top    * size.height,
          box.box.width  * size.width,
          box.box.height * size.height,
        );
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);
        _drawLabel(canvas, color, rect.topLeft,
            '${AppConfig.fieldLabels[box.field] ?? box.field} '
            '${(box.confidence*100).toStringAsFixed(0)}%');
      }
    }
  }

  void _drawLabel(Canvas canvas, Color color, Offset pt, String text) {
    const labelW = 130.0;
    const labelH = 20.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(pt.dx, pt.dy - labelH - 2, labelW, labelH),
          const Radius.circular(4)),
      Paint()..color = color,
    );
    (TextPainter(
      text: TextSpan(text: ' $text',
          style: const TextStyle(color: Colors.white,
              fontSize: 9, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: labelW))
        .paint(canvas, Offset(pt.dx + 2, pt.dy - labelH));
  }

  @override
  bool shouldRepaint(_ObbBoxPainter old) => true;
}

// ── Painter coins ──
class _CornersPainter extends CustomPainter {
  final bool isScanning;
  const _CornersPainter({required this.isScanning});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = isScanning ? AppColors.accent : Colors.white54
      ..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const m = 32.0; const l = 28.0;
    final w = size.width; final h = size.height;
    canvas.drawLine(Offset(m,m+l), Offset(m,m), p);
    canvas.drawLine(Offset(m,m), Offset(m+l,m), p);
    canvas.drawLine(Offset(w-m-l,m), Offset(w-m,m), p);
    canvas.drawLine(Offset(w-m,m), Offset(w-m,m+l), p);
    canvas.drawLine(Offset(m,h-m-l), Offset(m,h-m), p);
    canvas.drawLine(Offset(m,h-m), Offset(m+l,h-m), p);
    canvas.drawLine(Offset(w-m-l,h-m), Offset(w-m,h-m), p);
    canvas.drawLine(Offset(w-m,h-m-l), Offset(w-m,h-m), p);
  }

  @override
  bool shouldRepaint(_CornersPainter old) => old.isScanning != isScanning;
}