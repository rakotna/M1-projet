import 'dart:convert';

class ScanResult {
  final int? id;
  final String imagePath;
  final Map<String, String> ocrResults;
  final Map<String, double> confidences;
  final Map<String, String> cropImages;
  final DateTime scannedAt;
  final String note;
  final String nom;
  final String prenom;
  final String matiere;

  const ScanResult({
    this.id,
    required this.imagePath,
    required this.ocrResults,
    required this.confidences,
    required this.cropImages,
    required this.scannedAt,
    required this.note,
    required this.nom,
    required this.prenom,
    required this.matiere,
  });

  ScanResult copy({
    int? id,
    String? imagePath,
    Map<String, String>? ocrResults,
    Map<String, double>? confidences,
    Map<String, String>? cropImages,
    DateTime? scannedAt,
    String? note,
    String? nom,
    String? prenom,
    String? matiere,
  }) =>
      ScanResult(
        id: id ?? this.id,
        imagePath: imagePath ?? this.imagePath,
        ocrResults: ocrResults ?? this.ocrResults,
        confidences: confidences ?? this.confidences,
        cropImages: cropImages ?? this.cropImages,
        scannedAt: scannedAt ?? this.scannedAt,
        note: note ?? this.note,
        nom: nom ?? this.nom,
        prenom: prenom ?? this.prenom,
        matiere: matiere ?? this.matiere,
      );

  static ScanResult fromJson(Map<String, Object?> json) => ScanResult(
        id: json['id'] as int?,
        imagePath: json['imagePath'] as String,
        ocrResults: Map<String, String>.from(jsonDecode(json['ocrResults'] as String)),
        confidences: Map<String, double>.from(jsonDecode(json['confidences'] as String)),
        cropImages: Map<String, String>.from(jsonDecode(json['cropImages'] as String)),
        scannedAt: DateTime.parse(json['scannedAt'] as String),
        note: json['note'] as String,
        nom: json['nom'] as String,
        prenom: json['prenom'] as String,
        matiere: json['matiere'] as String,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'ocrResults': jsonEncode(ocrResults),
        'confidences': jsonEncode(confidences),
        'cropImages': jsonEncode(cropImages),
        'scannedAt': scannedAt.toIso8601String(),
        'note': note,
        'nom': nom,
        'prenom': prenom,
        'matiere': matiere,
      };

  static final List<String> fields = [
    'id', 'imagePath', 'ocrResults', 'confidences', 'cropImages', 'scannedAt', 'note', 'nom', 'prenom', 'matiere'
  ];
}
