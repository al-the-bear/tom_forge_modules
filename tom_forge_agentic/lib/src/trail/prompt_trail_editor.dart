import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'prompt_trail_controller.dart';
import 'prompt_trail_view.dart';

/// Hosts the [PromptTrailView] as a Forge **middle-panel** editor (§5 Col 3).
///
/// Like [PromptQueueEditor], the trail is a persistent tool surface rather than
/// a document, so this wrapper is a non-closable editor that declines every
/// real file ([canHandle] → reject) and never reports a dirty state. It gives
/// the request/answer trail its own editor column instead of being stacked
/// inside the bottom chat view.
class PromptTrailEditor extends ForgeEditor {
  PromptTrailEditor({required this.controller})
      : _title = ValueNotifier<String>('Prompt Trail'),
        _titleExtension = ValueNotifier<String?>(null),
        _isDirty = ValueNotifier<bool>(false);

  /// The trail controller the hosted [PromptTrailView] renders.
  final PromptTrailController controller;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;
  final ValueNotifier<bool> _isDirty;

  @override
  IconData get icon => Icons.history_outlined;

  @override
  Uri get uri => Uri(scheme: 'agent', host: 'chat', path: '/trail');

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

  // The trail is never a real document; the shell keeps routing opened files to
  // the document editor, not here.
  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  Widget buildMain(BuildContext context) =>
      PromptTrailView(controller: controller);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}
