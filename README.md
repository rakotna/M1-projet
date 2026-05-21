# ScolarAI

Application Flutter permettant la **numérisation (OCR)** et l’**extraction structurée** des informations issues de *bulletins scolaires malgaches* (édition 2026).

Le projet combine :
- capture d’images (caméra / galerie),
- détection de zones d’intérêt (modèle **YOLO** via TFLite),
- reconnaissance de texte (pipeline OCR),
- stockage et exploitation des données (Firebase / local),
- export (PDF / Excel) et partage.

> Repo : `rakotna/M1-projet`

---

## Fonctionnalités

- **Capture & import** : caméra (stream) et import depuis la galerie.
- **Pré-traitements image** : amélioration et normalisation via la lib `image`.
- **Détection** : modèle **YOLO** embarqué (TFLite) pour localiser les champs.
- **OCR** : extraction du texte depuis les zones détectées.
- **Persistance** :
  - **Firebase** : `firebase_core`, `cloud_firestore`.
  - **Local** : `sqflite` + `shared_preferences`.
- **Exports** :
  - **PDF** (`pdf`, `printing`)
  - **Excel (.xlsx)** (`excel`) + **partage** (`share_plus`)
- **UI & animations** : `lottie`, `shimmer`, `flutter_animate`, `glassmorphism`, `google_fonts`.

---

## Stack technique

- **Flutter / Dart** (SDK `>=3.9.0 <4.0.0`)
- **Firebase** : Firestore
- **On-device ML** : `tflite_flutter`
- **Caméra** : `camera`
- **Réseau** : `http`, `dio`
- **Base locale** : `sqflite`

---

## Prérequis

- Flutter installé (canal stable recommandé)
- Un environnement Android Studio / Xcode selon votre cible
- Un projet Firebase configuré si vous utilisez Firestore

---

## Installation

1. Cloner le dépôt :
   ```bash
   git clone https://github.com/rakotna/M1-projet.git
   cd M1-projet
   ```

2. Installer les dépendances :
   ```bash
   flutter pub get
   ```

3. Lancer l’application :
   ```bash
   flutter run
   ```

---

## Configuration Firebase (optionnel mais recommandé)

Si le projet utilise Firestore, configurez Firebase pour vos plateformes via FlutterFire :

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Cela génère généralement un fichier `lib/firebase_options.dart` (selon la configuration).

---

## Structure (indicative)

- `lib/` : code source Flutter
- `assets/` : modèles, images et animations
  - `assets/models/` : modèles TFLite / ressources ML
  - `assets/animations/` : animations Lottie
  - `assets/images/` : images UI

---

## Qualité & conventions

- Analyse statique :
  ```bash
  flutter analyze
  ```
- Formatage :
  ```bash
  dart format .
  ```

---

## Roadmap (idées)

- Amélioration du post-traitement OCR (normalisation, correction, validation)
- Tests automatiques (unitaires / widgets)
- Mode hors-ligne avancé et synchronisation
- Export CSV et templates d’exports personnalisables

---

## Contribution

Les contributions sont bienvenues :
1. Fork
2. Créez une branche (`feature/...`)
3. Ouvrez une Pull Request

---

## Licence

Aucune licence n’est définie pour le moment. Si vous souhaitez ouvrir le projet, ajoutez un fichier `LICENSE` (MIT/Apache-2.0/GPL…).

---

## Auteur

- **rakotna** — https://github.com/rakotna
