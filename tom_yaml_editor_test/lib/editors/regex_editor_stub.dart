import 'package:flutter/material.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

/// Upgraded Regex editor with test input field and live match indicator.
///
/// Shows the regex pattern editor at the top along with a test input field
/// below. The border changes to green when the test input matches the
/// pattern, red when it does not, and gray when the pattern is invalid.
///
/// Registered as `EditorSuffix(suffix: 'regex')`.
class RegexEditorStub extends StatefulWidget {
  final String pattern;
  final ValueChanged<Object?>? onChanged;
  final YamlEditorTheme theme;

  const RegexEditorStub({
    super.key,
    required this.pattern,
    required this.onChanged,
    required this.theme,
  });

  @override
  State<RegexEditorStub> createState() => _RegexEditorStubState();
}

class _RegexEditorStubState extends State<RegexEditorStub> {
  late TextEditingController _patternController;
  final TextEditingController _testController =
      TextEditingController(text: 'hello-world');
  bool _isValid = true;
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _patternController = TextEditingController(text: widget.pattern);
    _evaluate();
  }

  @override
  void didUpdateWidget(RegexEditorStub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pattern != widget.pattern &&
        widget.pattern != _patternController.text) {
      _patternController.text = widget.pattern;
      _evaluate();
    }
  }

  @override
  void dispose() {
    _patternController.dispose();
    _testController.dispose();
    super.dispose();
  }

  void _evaluate() {
    try {
      var regex = RegExp(_patternController.text);
      var testText = _testController.text;
      setState(() {
        _isValid = true;
        _matches = testText.isNotEmpty && regex.hasMatch(testText);
      });
    } catch (_) {
      setState(() {
        _isValid = false;
        _matches = false;
      });
    }
  }

  Color get _borderColor {
    if (!_isValid) return Colors.orange;
    if (_testController.text.isEmpty) return Colors.green.withAlpha(60);
    return _matches ? Colors.green : Colors.red;
  }

  Color get _accentColor {
    if (!_isValid) return Colors.orange;
    return _matches ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _accentColor.withAlpha(15),
              border: Border(
                bottom: BorderSide(color: _accentColor.withAlpha(40)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.find_in_page,
                    size: 13, color: _accentColor.withAlpha(180)),
                const SizedBox(width: 4),
                Text(
                  'Regex Pattern',
                  style: TextStyle(
                    fontSize: 11,
                    color: _accentColor.withAlpha(180),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Match indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _accentColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    !_isValid
                        ? 'invalid'
                        : _testController.text.isEmpty
                            ? '—'
                            : _matches
                                ? 'MATCH'
                                : 'NO MATCH',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Pattern input
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
            child: Row(
              children: [
                Text(
                  '/',
                  style: TextStyle(
                    fontFamily: widget.theme.fonts.valueFontFamily,
                    fontSize: 13,
                    color: Colors.green.shade300,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _patternController,
                    onChanged: (v) {
                      widget.onChanged?.call(v);
                      _evaluate();
                    },
                    readOnly: widget.onChanged == null,
                    style: TextStyle(
                      fontFamily: widget.theme.fonts.valueFontFamily,
                      fontSize: 12,
                      color: Colors.green.shade300,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Text(
                  '/',
                  style: TextStyle(
                    fontFamily: widget.theme.fonts.valueFontFamily,
                    fontSize: 13,
                    color: Colors.green.shade300,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Divider(height: 1, color: _accentColor.withAlpha(30)),
          // Test input
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
            child: Row(
              children: [
                Text(
                  'Test: ',
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.theme.colors.hintColor,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _testController,
                    onChanged: (_) => _evaluate(),
                    style: TextStyle(
                      fontFamily: widget.theme.fonts.valueFontFamily,
                      fontSize: 11,
                      color: widget.theme.colors.valueColor.withAlpha(180),
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Type to test...',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: widget.theme.colors.hintColor.withAlpha(100),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Creates the [EditorSuffix] registration for the Regex editor.
EditorSuffix regexEditorSuffix() {
  return EditorSuffix(
    suffix: 'regex',
    label: 'Regex',
    icon: Icons.find_in_page,
    factory: ({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    }) {
      return RegexEditorStub(
        pattern: value as String? ?? '',
        onChanged: readOnly ? null : onChanged,
        theme: theme,
      );
    },
  );
}
