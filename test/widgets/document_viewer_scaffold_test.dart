import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/app_shell_header.dart';
import 'package:league_hub/widgets/document_viewer_scaffold.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(375, 812),
    const Size(812, 375),
  ]) {
    for (final scale in [1.0, 3.2]) {
      testWidgets('viewer safe areas, fixed header and back on $size at $scale',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: const EdgeInsets.only(top: 47, bottom: 34),
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const DocumentViewerScaffold(
                    title: 'A long policy title for the document viewer',
                    leagueName: 'Preview Hockey League',
                    actions: [
                      SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(child: Icon(Icons.ios_share)))
                    ],
                    child: SingleChildScrollView(
                      key: Key('document-viewport'),
                      child: SizedBox(height: 2000, width: double.infinity),
                    ),
                  ),
                )),
                child: const Text('Open policy'),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('Open policy'));
        await tester.pumpAndSettle();
        final header = find.byType(AppShellHeader);
        final viewport = find.byKey(const Key('document-viewport'));
        expect(tester.getTopLeft(header).dy, 0);
        expect(tester.getTopLeft(viewport).dy,
            closeTo(tester.getBottomLeft(header).dy + 8, 0.1));
        expect(
            tester.getBottomLeft(viewport).dy, closeTo(size.height - 34, 0.1));
        expect(
            tester
                .widget<AppHeaderLogoMark>(find.byType(AppHeaderLogoMark))
                .label,
            'Preview Hockey League');
        final headerTop = tester.getTopLeft(header);
        await tester.drag(viewport, const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(header), headerTop);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Open policy'), findsOneWidget);
        expect(find.byType(DocumentViewerScaffold), findsNothing);
      });
    }
  }
}
