import 'package:flutter/widgets.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart'
    show TomFunctionObserver, TomObservable, TomObservableObservation;
import 'package:tom_flutter_ui/tom_flutter_ui.dart' show TomField;

import '../configuration_ui_trail.dart';
import '../forge_setting_editor_registry.dart';

/// An editor drawn by one of `tom_flutter_ui`'s form fields (a
/// `TomFormFieldFamily` field, no `TomForm` around it): [create] makes the
/// field with the value in effect; what the user makes in it goes to the
/// request's `onChanged`, and a value changed from outside (a reset, another
/// window) is put into the field.
class ForgeSettingTomField<T extends Object> extends StatefulWidget {
  const ForgeSettingTomField({
    super.key,
    required this.request,
    required this.create,
  });

  /// What is edited.
  final ForgeSettingEditorRequest request;

  /// Makes the field under [tomId] holding [initial].
  final TomField<T> Function(String tomId, T initial) create;

  @override
  State<ForgeSettingTomField<T>> createState() =>
      _ForgeSettingTomFieldState<T>();
}

class _ForgeSettingTomFieldState<T extends Object>
    extends State<ForgeSettingTomField<T>> {
  late final TomField<T> _field;
  late final TomFunctionObserver<TomObservable> _observer;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _field = widget.create(widget.request.fieldId, widget.request.value as T);
    _observer = _field >> (_) => _onFieldChanged();
  }

  void _onFieldChanged() {
    if (_syncing) return;
    final value = _field.get();
    configurationUiTrail(
      'edit ${widget.request.setting.storage.location} = $value',
    );
    widget.request.onChanged(value);
  }

  @override
  void didUpdateWidget(covariant ForgeSettingTomField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final setting = widget.request.setting;
    final value = widget.request.value;
    if (setting.sameValue(oldWidget.request.value, value)) return;
    if (setting.sameValue(_field.get(), value)) return;
    _syncing = true;
    try {
      _field.set(value as T);
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _field.removeObserver(_observer);
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.request.enabled;
    return Semantics(
      label: widget.request.label,
      enabled: enabled,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(opacity: enabled ? 1 : 0.5, child: _field.widget),
      ),
    );
  }
}
