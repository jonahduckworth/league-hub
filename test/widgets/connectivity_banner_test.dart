import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/widgets/connectivity_banner.dart';

Finder bannerSlideTransition() => find
    .descendant(
      of: find.byType(ConnectivityBanner),
      matching: find.byType(SlideTransition),
    )
    .first;

Finder bannerMaterial() => find
    .descendant(
      of: bannerSlideTransition(),
      matching: find.byType(Material),
    )
    .first;

Finder bannerContainer() => find
    .descendant(
      of: bannerSlideTransition(),
      matching: find.byType(Container),
    )
    .first;

void main() {
  group('ConnectivityBanner', () {
    test('resolveConnectivityBannerLookup uses injected lookup when provided',
        () async {
      final resolved = await resolveConnectivityBannerLookup(
        host: 'example.com',
        lookup: (_) async => [InternetAddress('8.8.8.8')],
      );

      expect(resolved.single.address, '8.8.8.8');
    });

    test('resolveConnectivityBannerLookup uses fallback when no lookup given',
        () async {
      final resolved = await resolveConnectivityBannerLookup(
        host: 'example.com',
        fallbackLookup: (_) async => [InternetAddress('1.1.1.1')],
      );

      expect(resolved.single.address, '1.1.1.1');
    });

    test('shouldHideOnlineBannerImmediately depends on prior offline state', () {
      expect(shouldHideOnlineBannerImmediately(false), isTrue);
      expect(shouldHideOnlineBannerImmediately(true), isFalse);
    });

    Widget createTestWidget({
      required Future<List<ConnectivityResult>> Function() connectivityCheck,
      Stream<List<ConnectivityResult>>? connectivityChanges,
      Future<List<InternetAddress>> Function(String host)? internetLookup,
      Stream<int>? pendingCountStream,
      int initialPendingCount = 0,
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(top: 20),
          ),
          child: ConnectivityBanner(
            connectivityCheck: connectivityCheck,
            connectivityChanges: connectivityChanges,
            internetLookup: internetLookup,
            pendingCountStream: pendingCountStream,
            initialPendingCount: initialPendingCount,
            child: const Scaffold(
              body: Center(child: Text('Test Content')),
            ),
          ),
        ),
      );
    }

    testWidgets('renders child widget content', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          connectivityCheck: () async => [ConnectivityResult.wifi],
        ),
      );
      await tester.pump();

      expect(find.text('Test Content'), findsOneWidget);
    });

    testWidgets('shows offline banner and pending count when disconnected',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          connectivityCheck: () async => [ConnectivityResult.none],
          internetLookup: (_) async => throw const SocketException('offline'),
          initialPendingCount: 2,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('No internet connection — 2 changes pending'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);

      final container = tester.widget<Container>(bannerContainer());
      final decoration = container.decoration as BoxDecoration?;
      expect(container.color, AppColors.danger);
      expect(decoration, isNull);
    });

    testWidgets('uses singular pending text for one pending change',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          connectivityCheck: () async => [ConnectivityResult.none],
          internetLookup: (_) async => throw const SocketException('offline'),
          initialPendingCount: 1,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('No internet connection — 1 change pending'),
        findsOneWidget,
      );
    });

    testWidgets(
        'treats failed connectivity check as online when lookup succeeds',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          connectivityCheck: () async => [ConnectivityResult.none],
          internetLookup: (_) async => [InternetAddress('8.8.8.8')],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.wifi_off), findsNothing);

      final slide = tester.widget<SlideTransition>(bannerSlideTransition());
      expect(slide.position.value.dy, -1);
    });

    testWidgets('shows back online state then hides after reconnect',
        (WidgetTester tester) async {
      final controller = StreamController<List<ConnectivityResult>>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        createTestWidget(
          connectivityCheck: () async => [ConnectivityResult.none],
          connectivityChanges: controller.stream,
          internetLookup: (_) async => throw const SocketException('offline'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No internet connection'), findsOneWidget);

      controller.add([ConnectivityResult.wifi]);
      await tester.pump();

      expect(find.text('Back online'), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);

      final onlineContainer = tester.widget<Container>(bannerContainer());
      expect(onlineContainer.color, AppColors.success);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 300));

      final slide = tester.widget<SlideTransition>(bannerSlideTransition());
      expect(slide.position.value.dy, -1);
    });

    testWidgets('stays hidden when already online and a reconnect event arrives',
        (WidgetTester tester) async {
      final controller = StreamController<List<ConnectivityResult>>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        createTestWidget(
          connectivityCheck: () async => [ConnectivityResult.wifi],
          connectivityChanges: controller.stream,
        ),
      );
      await tester.pump();

      controller.add([ConnectivityResult.wifi]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final slide = tester.widget<SlideTransition>(bannerSlideTransition());
      expect(slide.position.value.dy, -1);
    });

    testWidgets('updates pending count from stream while offline',
        (WidgetTester tester) async {
      final pendingController = StreamController<int>.broadcast();
      addTearDown(pendingController.close);

      await tester.pumpWidget(
        createTestWidget(
          connectivityCheck: () async => [ConnectivityResult.none],
          internetLookup: (_) async => throw const SocketException('offline'),
          pendingCountStream: pendingController.stream,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No internet connection'), findsOneWidget);

      pendingController.add(3);
      await tester.pump();

      expect(
        find.text('No internet connection — 3 changes pending'),
        findsOneWidget,
      );
    });

    testWidgets('applies safe-area top padding to the banner',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          connectivityCheck: () async => [ConnectivityResult.none],
          internetLookup: (_) async => throw const SocketException('offline'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final container = tester.widget<Container>(bannerContainer());
      final padding = container.padding as EdgeInsets;
      expect(padding.top, 24);
      expect(padding.left, 16);
      expect(padding.right, 16);
      expect(padding.bottom, 8);

      final material = tester.widget<Material>(bannerMaterial());
      expect(material.elevation, greaterThan(0));
    });
  });
}
