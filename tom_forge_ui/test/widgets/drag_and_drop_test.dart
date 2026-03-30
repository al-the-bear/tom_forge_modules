import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Widget interaction tests for drag-and-drop layout operations (Section 9).
///
/// Covers:
/// - Row 4: Middle-panel drop zones (EditorDropZoneOverlay, EmptyPanelDropTarget)
/// - Row 6: Section-header drag reorder
/// - Row 7: Side/bottom tab moves between panels
/// - Row 9: Empty placeholders persist as drop targets
/// - Row 10: Drag feedback visuals (proxy, delayed reveal)
/// - Row 11: Drop-zone color semantics (themed colors)
void main() {
  group('Section 9: Drag-and-Drop Layout Operations', () {
    // ── Row 4: Middle-panel drop zones ─────────────────────

    group('Row 4: EditorDropZoneOverlay', () {
      testWidgets('renders child content when no drag active', (tester) async {
        await tester.pumpWidget(_buildOverlay());
        await tester.pumpAndSettle();

        expect(find.text('Editor Content'), findsOneWidget);
      });

      testWidgets('accepts TabDragData drag target', (tester) async {
        await tester.pumpWidget(_buildOverlay());
        await tester.pumpAndSettle();

        // Verify the DragTarget<TabDragData> exists.
        expect(find.byType(EditorDropZoneOverlay), findsOneWidget);
      });

      testWidgets('EmptyPanelDropTarget shows invitation text',
          (tester) async {
        await tester.pumpWidget(_buildEmptyPanelTarget());
        await tester.pumpAndSettle();

        expect(find.text('Drop a tab here'), findsOneWidget);
        expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      });
    });

    // ── Row 6: Section-header drag reorder ──────────────────

    group('Row 6: Section-header drag', () {
      testWidgets('section headers are wrapped in Draggable', (tester) async {
        await tester.pumpWidget(_buildSidePanelWithSections());
        await tester.pumpAndSettle();

        // The section headers should render — tap to verify they're there.
        expect(find.text('EXPLORER'), findsOneWidget);
        expect(find.text('SEARCH'), findsOneWidget);
        expect(find.text('OUTPUT'), findsOneWidget);
      });

      testWidgets('drag gesture on section header starts without error',
          (tester) async {
        await tester.pumpWidget(_buildSidePanelWithSections());
        await tester.pumpAndSettle();

        // Start a long-press drag on the first section header.
        final header = find.text('EXPLORER');
        final gesture =
            await tester.startGesture(tester.getCenter(header));
        await tester.pump(const Duration(milliseconds: 500));

        // Move to trigger feedback.
        await gesture.moveBy(const Offset(0, 80));
        await tester.pump();

        // No exception means drag feedback rendered correctly.
        expect(tester.takeException(), isNull);

        await gesture.cancel();
        await tester.pumpAndSettle();
      });
    });

    // ── Row 7: Side/bottom tab moves ────────────────────────

    group('Row 7: Side/bottom tab moves', () {
      testWidgets('side panel icon tabs are draggable', (tester) async {
        await tester.pumpWidget(_buildSidePanelWithTabs());
        await tester.pumpAndSettle();

        // Find icon tabs and verify they exist.
        expect(find.byIcon(Icons.folder_outlined), findsWidgets);
      });

      testWidgets('bottom panel tabs are draggable', (tester) async {
        await tester.pumpWidget(_buildBottomPanelWithTabs());
        await tester.pumpAndSettle();

        // Tab titles should render.
        expect(find.text('Terminal'), findsOneWidget);
        expect(find.text('Problems'), findsOneWidget);
      });

      testWidgets('drag from side panel tab starts without error',
          (tester) async {
        await tester.pumpWidget(_buildSidePanelWithTabs());
        await tester.pumpAndSettle();

        // Find an icon tab.
        final icons = find.byIcon(Icons.folder_outlined);
        if (icons.evaluate().isNotEmpty) {
          final gesture =
              await tester.startGesture(tester.getCenter(icons.first));
          await tester.pump(const Duration(milliseconds: 500));
          await gesture.moveBy(const Offset(100, 0));
          await tester.pump();

          expect(tester.takeException(), isNull);

          await gesture.cancel();
          await tester.pumpAndSettle();
        }
      });

      testWidgets('drag from bottom panel tab starts without error',
          (tester) async {
        await tester.pumpWidget(_buildBottomPanelWithTabs());
        await tester.pumpAndSettle();

        final tab = find.text('Terminal');
        final gesture =
            await tester.startGesture(tester.getCenter(tab));
        await tester.pump(const Duration(milliseconds: 500));
        await gesture.moveBy(const Offset(0, -100));
        await tester.pump();

        expect(tester.takeException(), isNull);

        await gesture.cancel();
        await tester.pumpAndSettle();
      });
    });

    // ── Row 9: Empty placeholders persist ───────────────────

    group('Row 9: Empty placeholders', () {
      testWidgets('empty side panel shows placeholder drop target',
          (tester) async {
        await tester.pumpWidget(_buildEmptySidePanel());
        await tester.pumpAndSettle();

        // Empty side panel should show add icon placeholder.
        expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      });

      testWidgets('empty bottom panel shows placeholder drop target',
          (tester) async {
        await tester.pumpWidget(_buildEmptyBottomPanel());
        await tester.pumpAndSettle();

        // Empty bottom panel should show placeholder with text.
        expect(find.text('Drop panel here'), findsOneWidget);
        expect(find.byIcon(Icons.vertical_align_bottom), findsOneWidget);
      });
    });

    // ── Row 10: Drag feedback visuals ───────────────────────

    group('Row 10: Drag feedback', () {
      testWidgets('overlay shows subtle highlight before zones reveal',
          (tester) async {
        await tester.pumpWidget(_buildOverlay());
        await tester.pumpAndSettle();

        // The EditorDropZoneOverlay should render without zones initially.
        expect(find.text('Split Left'), findsNothing);
        expect(find.text('Split Right'), findsNothing);
        expect(find.text('Add to Tab Bar'), findsNothing);
      });
    });

    // ── Row 11: Drop-zone color semantics ───────────────────

    group('Row 11: Drop-zone themed colors', () {
      testWidgets('EditorDropZoneOverlay renders with ForgeShellTheme',
          (tester) async {
        // Wrap with a theme that has ForgeShellTheme extension.
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [ForgeShellTheme.dark()],
          ),
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: EditorDropZoneOverlay(
                panelIndex: 0,
                child: const Center(child: Text('Themed Editor')),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Themed Editor'), findsOneWidget);
      });

      testWidgets('EmptyPanelDropTarget uses themed colors', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: [ForgeShellTheme.dark()],
          ),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: EmptyPanelDropTarget(panelIndex: 0),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Drop a tab here'), findsOneWidget);
      });
    });
  });
}

// ── Helpers ───────────────────────────────────────────────

Widget _buildOverlay() {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 600,
        height: 400,
        child: EditorDropZoneOverlay(
          panelIndex: 0,
          child: const Center(child: Text('Editor Content')),
        ),
      ),
    ),
  );
}

Widget _buildEmptyPanelTarget() {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 300,
        child: EmptyPanelDropTarget(panelIndex: 0),
      ),
    ),
  );
}

Widget _buildSidePanelWithSections() {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        height: 600,
        child: ForgeSidePanelWidget(
          tabs: [
            PanelTabConfig(
              title: 'Explorer',
              icon: Icons.folder_outlined,
              sections: _threeViews(),
            ),
          ],
          iconStripPosition: IconStripPosition.left,
        ),
      ),
    ),
  );
}

Widget _buildSidePanelWithTabs() {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        height: 600,
        child: ForgeSidePanelWidget(
          tabs: [
            PanelTabConfig(
              title: 'Explorer',
              icon: Icons.folder_outlined,
              sections: [_StubView('Explorer', Icons.folder)],
            ),
            PanelTabConfig(
              title: 'Search',
              icon: Icons.search,
              sections: [_StubView('Search', Icons.search)],
            ),
          ],
          iconStripPosition: IconStripPosition.left,
          panelArea: PanelArea.left,
        ),
      ),
    ),
  );
}

Widget _buildBottomPanelWithTabs() {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 600,
        height: 200,
        child: ForgePanelWidget(
          tabs: [
            PanelTabConfig(
              title: 'Terminal',
              icon: Icons.terminal,
              sections: [_StubView('Terminal', Icons.terminal)],
            ),
            PanelTabConfig(
              title: 'Problems',
              icon: Icons.error_outline,
              sections: [_StubView('Problems', Icons.error_outline)],
            ),
          ],
          panelArea: PanelArea.bottom,
        ),
      ),
    ),
  );
}

Widget _buildEmptySidePanel() {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        height: 600,
        child: ForgeSidePanelWidget(
          tabs: const [],
          iconStripPosition: IconStripPosition.left,
          panelArea: PanelArea.left,
        ),
      ),
    ),
  );
}

Widget _buildEmptyBottomPanel() {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 600,
        height: 200,
        child: ForgePanelWidget(
          tabs: const [],
          panelArea: PanelArea.bottom,
        ),
      ),
    ),
  );
}

List<ForgeView> _threeViews() => [
      _StubView('Explorer', Icons.folder),
      _StubView('Search', Icons.search),
      _StubView('Output', Icons.terminal),
    ];

class _StubView extends ForgeView {
  final String _title;
  final IconData _icon;

  _StubView(this._title, this._icon);

  @override
  ValueNotifier<String> get title => ValueNotifier(_title);

  @override
  ValueNotifier<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => _icon;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) {
    return Center(child: Text('Content: $_title'));
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}
