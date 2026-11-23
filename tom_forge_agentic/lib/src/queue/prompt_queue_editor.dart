import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_agentic_ui/tom_agentic_ui.dart';


/// Hosts the [PromptQueueView] as a Forge **middle-panel** editor (§5 Col 2).
///
/// The shell's layout only places [ForgeEditor]s in the middle splits (side and
/// bottom panels take [ForgeView]s). The queue is a persistent tool surface,
/// not a document, so this wrapper is a non-closable editor that declines every
/// real file ([canHandle] → reject) and never reports a dirty state — it exists
/// purely to give the queue column its own column in the editor area instead of
/// being stacked inside the bottom chat view.
class PromptQueueEditor extends ForgeSurfaceEditor {
  PromptQueueEditor({required this.controller})
      : _title = ValueNotifier<String>('Prompt Queue'),
        _titleExtension = ValueNotifier<String?>(null);

  /// The queue controller the hosted [PromptQueueView] renders and drives.
  final PromptQueueController controller;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;

  @override
  IconData get icon => Icons.playlist_play_outlined;

  @override
  Uri get uri => Uri(scheme: 'agent', host: 'chat', path: '/queue');

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  Widget buildMain(BuildContext context) =>
      PromptQueueView(controller: controller);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}
