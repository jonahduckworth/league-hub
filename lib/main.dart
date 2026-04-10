import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'navigation/router.dart';
import 'providers/auth_provider.dart';
import 'services/messaging_service.dart';
import 'widgets/connectivity_banner.dart';
import 'widgets/error_boundary.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register the top-level background handler before runApp.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ---------- Global error handling ----------

  // Replace the default red-screen error widget with a friendlier fallback.
  ErrorWidget.builder = appErrorWidget;

  // Catch Flutter framework errors (layout, build, painting).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  // Catch async errors that escape the Flutter framework (Dart zone / isolate).
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformError: $error\n$stack');
    return true; // Prevents the runtime from terminating the app.
  };

  runApp(
    ProviderScope(
      overrides: [
        messagingServiceProvider.overrideWithValue(
          MessagingService(router: router),
        ),
      ],
      child: const LeagueHubApp(),
    ),
  );
}

class LeagueHubApp extends ConsumerStatefulWidget {
  const LeagueHubApp({super.key});

  @override
  ConsumerState<LeagueHubApp> createState() => _LeagueHubAppState();
}

class _LeagueHubAppState extends ConsumerState<LeagueHubApp> {
  bool _notificationsInitialized = false;

  @override
  Widget build(BuildContext context) {
    // Watch auth state to initialize notifications when a user signs in.
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    if (user != null && !_notificationsInitialized) {
      _notificationsInitialized = true;
      // Initialize async — don't block the build.
      Future.microtask(() {
        ref.read(messagingServiceProvider).initialize(user.id);
      });
    } else if (user == null && _notificationsInitialized) {
      _notificationsInitialized = false;
    }

    return MaterialApp.router(
      title: 'League Hub',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Wrap every route in the connectivity banner and error boundary.
        return ConnectivityBanner(
          child: ErrorBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
