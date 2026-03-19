import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/avatar_widget.dart';

void main() {
  group('AvatarWidget', () {
    testWidgets('renders initials when no imageUrl', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(name: 'John Doe'),
          ),
        ),
      );

      expect(find.text('JD'), findsOneWidget);
    });

    testWidgets('renders single initial for single-word name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(name: 'Alice'),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('renders question mark for empty name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(name: ''),
          ),
        ),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('renders at default size without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(name: 'Test User'),
          ),
        ),
      );

      expect(find.byType(AvatarWidget), findsOneWidget);
      expect(find.text('TU'), findsOneWidget);
    });

    testWidgets('renders at custom size without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(name: 'Test', size: 60),
          ),
        ),
      );

      expect(find.byType(AvatarWidget), findsOneWidget);
    });

    testWidgets('renders initials when imageUrl is empty string', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(name: 'Jane Smith', imageUrl: ''),
          ),
        ),
      );

      expect(find.text('JS'), findsOneWidget);
    });

    testWidgets('accepts custom backgroundColor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(
              name: 'Test User',
              backgroundColor: Colors.red,
            ),
          ),
        ),
      );

      expect(find.byType(AvatarWidget), findsOneWidget);
    });

    testWidgets('renders as circle shape', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(name: 'Circle Test'),
          ),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final circleContainer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).shape == BoxShape.circle,
        orElse: () => throw TestFailure('No circle container found'),
      );
      expect(circleContainer, isNotNull);
    });

    testWidgets('renders correct initials for three-word name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarWidget(name: 'John Michael Doe'),
          ),
        ),
      );

      // getInitials uses first two words
      expect(find.text('JM'), findsOneWidget);
    });

    testWidgets('container has correct width and height for size 40', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: AvatarWidget(name: 'AB', size: 40)),
          ),
        ),
      );

      final renderBox = tester.renderObject<RenderBox>(
        find.byType(AvatarWidget),
      );

      expect(renderBox.size.width, 40.0);
      expect(renderBox.size.height, 40.0);
    });

    testWidgets('container has correct width and height for custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: AvatarWidget(name: 'XY', size: 80)),
          ),
        ),
      );

      final renderBox = tester.renderObject<RenderBox>(
        find.byType(AvatarWidget),
      );

      expect(renderBox.size.width, 80.0);
      expect(renderBox.size.height, 80.0);
    });
  });
}
