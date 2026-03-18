# League Hub

A Flutter app for managing sports leagues, hubs, and teams. Built for commissioners, administrators, and staff to communicate, share documents, and manage league operations from a single platform.

## Tech Stack

- **Flutter** 3.x (iOS & Android)
- **Firebase** — Auth, Firestore, Storage, Messaging
- **Riverpod** — State management
- **go_router** — Navigation
- **cached_network_image** — Image caching
- **shimmer** — Loading states

## Getting Started

1. **Clone the repo**
   ```bash
   git clone https://github.com/jonahduckworth/league-hub.git
   cd league-hub
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Connect Firebase** (required for auth/data)
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Follow the prompts to link your Firebase project. Uncomment the Firebase initialization line in `lib/main.dart`.

4. **Run the app**
   ```bash
   flutter run
   ```
   The app displays mock UI data before Firebase is configured.

## Project Structure

```
lib/
├── core/           # Theme, constants, utilities
├── models/         # Dart data models with fromJson/toJson
├── services/       # Firebase service layer (auth, firestore, storage, messaging)
├── providers/      # Riverpod state providers + mock data
├── navigation/     # go_router configuration
├── screens/        # App screens (login, dashboard, chat, docs, announcements, settings)
└── widgets/        # Reusable UI components
```

## Design System

| Token | Hex |
|---|---|
| Primary | `#1A3A5C` |
| Primary Light | `#2E75B6` |
| Accent | `#4DA3FF` |
| Background | `#F5F7FA` |
| Card | `#FFFFFF` |
| Text | `#1A1A2E` |
| Text Secondary | `#6B7280` |
| Text Muted | `#9CA3AF` |
| Border | `#E5E7EB` |
| Success | `#10B981` |
| Warning | `#F59E0B` |
| Danger | `#EF4444` |

## Firebase Setup

After running `flutterfire configure`, uncomment the initialization in `lib/main.dart`:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

## Contributing

This project uses clean architecture with a clear separation of concerns:
- **Models** are plain Dart classes with Firestore serialization
- **Services** are thin wrappers around Firebase SDKs
- **Providers** expose reactive state via Riverpod
- **Screens** are pure UI, reading from providers
