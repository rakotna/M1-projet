
# Blueprint: Système de Transcription de Notes Intelligent

## Vue d'ensemble

Ce projet vise à créer une application mobile Flutter qui sert d'interface à un backend d'Intelligence Artificielle. L'application permet aux utilisateurs de scanner des feuilles de notes manuscrites à l'aide de l'appareil photo de leur téléphone. L'image capturée est envoyée à un service backend qui utilise un réseau de neurones (OCR) pour reconnaître le numéro de l'étudiant et sa note. Les données extraites sont ensuite affichées à l'utilisateur pour confirmation.

## Fonctionnalités (Version 1.0)

- **Interface de Scan Moderne :**
  - Affichage en plein écran du flux vidéo de la caméra.
  - Superposition graphique pour guider le cadrage du document.
  - Bouton de capture flottant et esthétique.
  - Contrôle pour activer/désactiver le flash.

- **Écran de Confirmation des Résultats :**
  - Après la capture, une nouvelle page affiche les données extraites (simulées pour l'instant) :
    - **Numéro Étudiant :** [Numéro reconnu]
    - **Note :** [Note reconnue]
  - Boutons pour "Confirmer" ou "Reprendre le scan".

- **Simulation du Backend :**
  - Un service `ApiService` simulera un appel réseau.
  - Il retournera des données factices (ex: `{ "studentId": "12345", "grade": "17.5" }`) pour permettre de développer et tester l'interface de manière complète.

- **Navigation :**
    - Utilisation du package `go_router` pour une navigation déclarative et robuste entre les écrans.

- **Design et Style :**
  - Utilisation de `google_fonts` pour une typographie professionnelle.
  - Palette de couleurs moderne et cohérente définie dans `ThemeData`.
  - Transitions fluides entre les écrans.

## Structure du Projet

```
/lib
|-- /screens
|   |-- scan_screen.dart     # UI pour le scan de documents
|   |-- result_screen.dart   # UI pour afficher les résultats
|-- /services
|   |-- api_service.dart     # Service pour simuler l'appel à l'API
|-- main.dart                # Point d'entrée et configuration du routing
```

## Plan de développement actuel

- **Étape 1 :** Création du `blueprint.md` et ajout des dépendances. **(Terminé)**
- **Étape 2 :** Mettre en place la structure du projet (création des fichiers et dossiers). **(Terminé)**
- **Étape 3 :** Développer l'écran de scan (`scan_screen.dart`) avec la vue caméra.
- **Étape 4 :** Développer l'écran de résultats (`result_screen.dart`).
- **Étape 5 :** Implémenter le service de simulation (`api_service.dart`).
- **Étape 6 :** Configurer la navigation avec `go_router` dans `main.dart`.
- **Étape 7 :** Connecter tous les éléments ensemble.
