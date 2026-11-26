import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeColorSetting;
import 'package:tom_forge_kit/tom_forge_kit.dart' show ForgeTextScopeWidget;

import '../configuration_ui_trail.dart';
import '../forge_configuration_labels.dart';
import '../forge_configuration_ui_texts.dart';

/// The swatches the colour picker offers: Material's primaries, then grey,
/// black and white.
const List<Color> forgeColorSwatches = [
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.yellow,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.brown,
  Colors.blueGrey,
  Colors.grey,
  Color(0xFF000000),
  Color(0xFFFFFFFF),
];

/// Lets the user choose a colour, starting at [initial] (`0xAARRGGBB`): a
/// saturation and brightness area, a hue slider, an opacity slider (with
/// [allowAlpha]), swatches, a preview and the hex value to type. Answers the
/// colour chosen (opaque without [allowAlpha]), or null when the user
/// cancelled.
Future<int?> showForgeColorPicker(
  BuildContext context, {
  required int initial,
  bool allowAlpha = false,
}) => showDialog<int>(
  context: context,
  builder: ForgeTextScopeWidget.keep(
    context,
    (context) =>
        ForgeColorPickerDialog(initial: initial, allowAlpha: allowAlpha),
  ),
);

/// The dialog [showForgeColorPicker] shows.
class ForgeColorPickerDialog extends StatefulWidget {
  const ForgeColorPickerDialog({
    super.key,
    required this.initial,
    this.allowAlpha = false,
  });

  final int initial;
  final bool allowAlpha;

  @override
  State<ForgeColorPickerDialog> createState() => _ForgeColorPickerDialogState();
}

class _ForgeColorPickerDialogState extends State<ForgeColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(Color(widget.initial | 0xFF000000));
  late double _alpha = widget.allowAlpha
      ? ((widget.initial >> 24) & 0xFF) / 255
      : 1;
  late final TextEditingController _hex = TextEditingController(
    text: ForgeColorSetting.toHex(_argb),
  );

  int get _argb {
    final rgb = _hsv.toColor().toARGB32() & 0xFFFFFF;
    final alpha = widget.allowAlpha ? (_alpha * 255).round() : 0xFF;
    return (alpha << 24) | rgb;
  }

  void _set({HSVColor? hsv, double? alpha, bool fromHex = false}) {
    setState(() {
      if (hsv != null) _hsv = hsv;
      if (alpha != null) _alpha = alpha;
    });
    if (!fromHex) _hex.text = ForgeColorSetting.toHex(_argb);
  }

  void _setArgb(int argb, {bool fromHex = false}) => _set(
    hsv: HSVColor.fromColor(Color(argb | 0xFF000000)),
    alpha: widget.allowAlpha ? ((argb >> 24) & 0xFF) / 255 : 1,
    fromHex: fromHex,
  );

  void _pickArea(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = 1 - (local.dy / size.height).clamp(0.0, 1.0);
    _set(hsv: _hsv.withSaturation(s).withValue(v));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const areaSize = Size(280, 160);
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    return AlertDialog(
      title: Text(
        ForgeConfigurationLabels.resolveIn(
          context,
          ForgeConfigurationUiTexts.chooseColour,
        ),
      ),
      content: SizedBox(
        width: areaSize.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              key: const ValueKey('forge.configuration.colour.area'),
              onPanDown: (d) => _pickArea(d.localPosition, areaSize),
              onPanUpdate: (d) => _pickArea(d.localPosition, areaSize),
              child: SizedBox.fromSize(
                size: areaSize,
                child: CustomPaint(
                  painter: _SaturationValuePainter(
                    hue: hueColor,
                    saturation: _hsv.saturation,
                    value: _hsv.value,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ForgeConfigurationLabels.resolveIn(
                context,
                ForgeConfigurationUiTexts.hue,
              ),
              style: theme.textTheme.labelSmall,
            ),
            Slider(
              key: const ValueKey('forge.configuration.colour.hue'),
              value: _hsv.hue,
              max: 360,
              activeColor: hueColor,
              onChanged: (hue) => _set(hsv: _hsv.withHue(hue)),
            ),
            if (widget.allowAlpha) ...[
              Text(
                ForgeConfigurationLabels.resolveIn(
                  context,
                  ForgeConfigurationUiTexts.opacity,
                ),
                style: theme.textTheme.labelSmall,
              ),
              Slider(
                key: const ValueKey('forge.configuration.colour.opacity'),
                value: _alpha,
                onChanged: (alpha) => _set(alpha: alpha),
              ),
            ],
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final (i, swatch) in forgeColorSwatches.indexed)
                  Tooltip(
                    message: ForgeColorSetting.toHex(swatch.toARGB32()),
                    child: InkWell(
                      key: ValueKey('forge.configuration.colour.swatch.$i'),
                      onTap: () => _setArgb(
                        widget.allowAlpha
                            ? (swatch.toARGB32() & 0xFFFFFF) |
                                  ((_alpha * 255).round() << 24)
                            : swatch.toARGB32(),
                      ),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: swatch,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  key: const ValueKey('forge.configuration.colour.preview'),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(_argb),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('forge.configuration.colour.hex'),
                    controller: _hex,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                      LengthLimitingTextInputFormatter(9),
                    ],
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      final argb = ForgeColorSetting.parseHex(text);
                      if (argb != null) _setArgb(argb, fromHex: true);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            ForgeConfigurationLabels.resolveIn(
              context,
              ForgeConfigurationUiTexts.cancel,
            ),
          ),
        ),
        FilledButton(
          onPressed: () {
            configurationUiTrail(
              'colour picked: ${ForgeColorSetting.toHex(_argb)}',
            );
            Navigator.of(context).pop(_argb);
          },
          child: Text(
            ForgeConfigurationLabels.resolveIn(
              context,
              ForgeConfigurationUiTexts.ok,
            ),
          ),
        ),
      ],
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  final Color hue;
  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFFFFFFFF), hue],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xFF000000)],
        ).createShader(rect),
    );
    canvas.restore();
    final marker = Offset(saturation * size.width, (1 - value) * size.height);
    canvas.drawCircle(
      marker,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = value > 0.5
            ? const Color(0xFF000000)
            : const Color(0xFFFFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter old) =>
      old.hue != hue || old.saturation != saturation || old.value != value;
}
