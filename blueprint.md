
# Blueprint: ScolarAI

## Overview

ScolarAI is a Flutter application designed to perform Optical Character Recognition (OCR) on Malagasy school report cards. The goal is to digitize and process the information from these documents efficiently.

## Features & Design

### Core Functionality
- **OCR:** Utilizes TFLite for on-device machine learning to recognize text from images and `http`/`dio` to potentially connect to a remote TrOCR API for more complex recognition tasks.
- **Camera Integration:** Uses the `camera` package to capture images of the report cards directly within the app.
- **Image Picking:** Allows users to select existing images from their device's gallery using `image_picker`.
- **PDF Export:** Generates and exports the extracted data into PDF documents using the `pdf` and `printing` packages.
- **Firebase Integration:** Uses `cloud_firestore` to store and sync data.

### UI/UX
- **Animations:** The UI will be enhanced with animations from `flutter_animate`, `lottie`, and `animated_text_kit` to create a more engaging user experience.
- **Styling:** `glassmorphism` will be used for modern UI effects. `shimmer` will provide loading indicators.
- **Custom Fonts:** The application uses the "Poppins" font family.
- **SVG Support:** `flutter_svg` is included for using scalable vector graphics.

### Utilities
- **Permissions:** `permission_handler` manages necessary device permissions (e.g., camera, storage).
- **Local Storage:** `shared_preferences` is used for simple key-value data persistence.
- **Date/Time Formatting:** `intl` is used for internationalization and date formatting.
- **Unique IDs:** `uuid` is used to generate unique identifiers for documents or entries.

## Current Plan

The initial setup is complete. The project dependencies have been defined in `pubspec.yaml` and successfully installed. The next step is to start building the application's user interface and implementing the core features.
