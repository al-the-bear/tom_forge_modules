import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// A lightweight panel placeholder rendered for shell regions whose real
/// content is built in later steps (left navigator, bottom chat, right
/// change-log, …).
///
/// Step 9 only needs the four DocSpecs regions to be *visibly present* and
/// labelled; the functional widgets (`PromptQueueView`, `ChatComposerView`,
/// the change log, …) arrive in Stages C–E. Centralising the placeholder body
/// here keeps every not-yet-wired region consistent and makes it obvious at a
/// glance which surfaces are still stubs.
class _PlaceholderBody extends StatelessWidget {
  const _PlaceholderBody({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: theme.disabledColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.disabledColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Not wired yet',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// A non-closable [ForgeView] stub used for side/bottom panel regions.
class PlaceholderView extends ForgeView {
  PlaceholderView({
    required String title,
    required this.icon,
  }) : _title = ValueNotifier<String>(title),
       _titleExtension = ValueNotifier<String?>(null);

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;

  @override
  final IconData icon;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) =>
      _PlaceholderBody(icon: icon, label: _title.value);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// A closable [ForgeEditor] stub used for the three middle splits (Document,
/// Queue, Trail). It declines every real file (`canHandle` → `reject`) so the
/// shell never routes opened documents into a placeholder; it exists purely so
/// the DocSpecs middle area shows the three labelled splits.
class PlaceholderEditor extends ForgeEditor {
  PlaceholderEditor({
    required String title,
    required this.icon,
    required this.uri,
  }) : _title = ValueNotifier<String>(title),
       _titleExtension = ValueNotifier<String?>(null);

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;
  final ValueNotifier<bool> _isDirty = ValueNotifier<bool>(false);

  @override
  final IconData icon;

  @override
  final Uri uri;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  ValueListenable<bool> get isDirty => _isDirty;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  void markClean() => _isDirty.value = false;

  // A placeholder never claims a real document; the shell keeps routing files
  // to the editors that will arrive in later steps.
  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  Widget buildMain(BuildContext context) =>
      _PlaceholderBody(icon: icon, label: _title.value);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}
