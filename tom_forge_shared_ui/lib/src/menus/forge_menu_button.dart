import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// The widget key of the menu entry for the action [actionId]:
/// `forge.menu.<actionId>`.
Key forgeMenuEntryKey(String actionId) => ValueKey('forge.menu.$actionId');

/// Draws a [ForgeMenuModel] as menu children for a [MenuAnchor], a
/// [SubmenuButton] or a [MenuBar] of the application's: one
/// [MenuItemButton] per action — its icon, label and key, disabled while
/// the action cannot run, running it through `api.executeAction` — and a
/// divider between two groups.
List<Widget> forgeMenuChildren(ForgeKitApi api, ForgeMenuModel model) => [
  for (final entry in model.entries)
    switch (entry) {
      ForgeMenuSeparatorEntry() => const Divider(height: 1),
      ForgeMenuActionEntry(:final action) => MenuItemButton(
        key: forgeMenuEntryKey(action.id),
        leadingIcon: action.icon == null ? null : Icon(action.icon, size: 16),
        trailingIcon: action.shortcut == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(action.shortcut!),
              ),
        onPressed: action.enabled ? () => api.executeAction(action.id) : null,
        child: Text(action.label),
      ),
    },
];

/// A button that opens the menu of one [location] of the kit
/// ([ForgeMenuModel.of]): the actions placed there, read when the menu
/// opens, so it shows their state at that moment. It imposes no menu bar:
/// an application puts as many as it likes wherever it likes, or draws the
/// entries in its own [MenuBar] with [forgeMenuChildren].
///
/// The button shows [child], else the menu's title; a location with no
/// visible action shows a disabled button.
class ForgeMenuButton extends StatefulWidget {
  const ForgeMenuButton({
    super.key,
    required this.api,
    required this.location,
    this.child,
  });

  final ForgeKitApi api;
  final ForgeMenuLocation location;

  /// What the button shows; null: the menu's title (`File`, `Edit`, ...).
  final Widget? child;

  @override
  State<ForgeMenuButton> createState() => _ForgeMenuButtonState();
}

class _ForgeMenuButtonState extends State<ForgeMenuButton> {
  late ForgeMenuModel _model = ForgeMenuModel.of(widget.api, widget.location);

  void _read() =>
      setState(() => _model = ForgeMenuModel.of(widget.api, widget.location));

  @override
  void didUpdateWidget(ForgeMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _model = ForgeMenuModel.of(widget.api, widget.location);
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    onOpen: _read,
    menuChildren: forgeMenuChildren(widget.api, _model),
    builder: (context, controller, _) => TextButton(
      key: ValueKey('forge.menu.button.${widget.location.name}'),
      onPressed: _model.isEmpty
          ? null
          : () => controller.isOpen ? controller.close() : controller.open(),
      child: widget.child ?? Text(_model.title),
    ),
  );
}
