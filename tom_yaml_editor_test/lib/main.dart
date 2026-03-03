import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

import 'editors/editors.dart';

void main() {
  runApp(const YamlEditorTestApp());
}

/// Test application for the tom_yaml_editor component.
///
/// Demonstrates all YAML schema editor features including:
/// - 5 custom embedded editors (Dart, Markdown, Regex, JSON, Color)
/// - Subtree inspector in side-panel, bottom-sheet, and dialog modes
/// - Validation error list (bottom or side position)
/// - Theme switching (dark/light)
/// - All display feature toggles
/// - Undo/redo, load, copy workflow
class YamlEditorTestApp extends StatelessWidget {
  const YamlEditorTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YAML Schema Editor Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const YamlEditorTestPage(),
    );
  }
}

/// Main test page with the YAML editor and control panels.
class YamlEditorTestPage extends StatefulWidget {
  const YamlEditorTestPage({super.key});

  @override
  State<YamlEditorTestPage> createState() => _YamlEditorTestPageState();
}

class _YamlEditorTestPageState extends State<YamlEditorTestPage> {
  late YamlEditorController _controller;
  YamlSchema? _schema;
  late EditorRegistry _registry;

  // Theme & display toggles
  bool _useDarkTheme = true;
  bool _readOnly = false;
  bool _showTreeLines = true;
  bool _showCollapseToggles = true;
  bool _showAddButtons = true;
  bool _showRemoveButtons = true;
  bool _showInlineValidation = true;

  // Inspector & error list
  SubtreeInspectorMode _inspectorMode = SubtreeInspectorMode.bottomSheet;
  ErrorListPosition? _errorListPosition;
  bool _highlightErrorRows = true;

  // Dataset selection
  String _activeDataset = 'prompt'; // 'prompt' or 'workflow'

  final List<String> _log = [];
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _controller = YamlEditorController(
      initialYaml: _defaultYaml,
    );

    _loadSchema();
    _registerEditors();
  }

  Future<void> _loadSchema() async {
    try {
      var schemaFile = _activeDataset == 'workflow'
          ? 'assets/complex_schema.json'
          : 'assets/prompt_schema.json';
      var jsonStr = await rootBundle.loadString(schemaFile);
      var json = jsonDecode(jsonStr) as Map<String, dynamic>;
      setState(() {
        _schema = YamlSchema.fromJson(json);
        // Recreate controller with schema
        var currentYaml = _controller.yamlText;
        _controller.dispose();
        _controller = YamlEditorController(
          initialYaml: currentYaml,
          schema: _schema,
        );
        _addLog('Schema loaded: ${json['title'] ?? 'untitled'}');
      });
    } catch (e) {
      _addLog('Schema load error: $e');
    }
  }

  Future<void> _switchDataset(String dataset) async {
    if (dataset == _activeDataset) return;
    _activeDataset = dataset;

    try {
      String schemaFile;
      String yamlFile;
      if (dataset == 'workflow') {
        schemaFile = 'assets/complex_schema.json';
        yamlFile = 'assets/complex_workflow.yaml';
      } else {
        schemaFile = 'assets/prompt_schema.json';
        yamlFile = 'assets/sample_prompt.yaml';
      }

      var jsonStr = await rootBundle.loadString(schemaFile);
      var json = jsonDecode(jsonStr) as Map<String, dynamic>;
      var yaml = await rootBundle.loadString(yamlFile);

      setState(() {
        _schema = YamlSchema.fromJson(json);
        _controller.dispose();
        _controller = YamlEditorController(
          initialYaml: yaml,
          schema: _schema,
        );
        _addLog('Switched to "$dataset" dataset');
      });
    } catch (e) {
      _addLog('Dataset switch error: $e');
    }
  }

  void _registerEditors() {
    // Register all 5 custom editors
    var colorSuffix = colorEditorSuffix();
    _registry = EditorRegistry.defaults()
        .register(dartEditorSuffix())
        .register(markdownEditorSuffix())
        .register(regexEditorSuffix())
        .register(jsonEditorSuffix())
        .register(colorSuffix)
        .withResolver(colorEditorResolver(colorSuffix));
  }

  void _addLog(String message) {
    setState(() {
      _log.add('[${DateTime.now().toString().substring(11, 19)}] $message');
      if (_log.length > 200) {
        _log.removeRange(0, _log.length - 200);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  YamlEditorTheme get _currentTheme {
    var base = _useDarkTheme ? YamlEditorTheme.dark() : YamlEditorTheme.light();
    return base.copyWith(
      showTreeLines: _showTreeLines,
      showCollapseToggles: _showCollapseToggles,
      showAddButtons: _showAddButtons,
      showRemoveButtons: _showRemoveButtons,
      showInlineValidation: _showInlineValidation,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // Left panel: YAML Schema Editor
          Expanded(
            flex: 3,
            child: YamlSchemaEditor(
              controller: _controller,
              theme: _currentTheme,
              editorRegistry: _registry,
              readOnly: _readOnly,
              inspectorMode: _inspectorMode,
              errorListPosition: _errorListPosition,
              highlightErrorRows: _highlightErrorRows,
              onChanged: (yaml) {
                _addLog('YAML changed (${yaml.length} chars)');
              },
              onValidationChanged: (errors) {
                if (errors.isNotEmpty) {
                  _addLog('Validation: ${errors.length} error(s)');
                  for (var e in errors) {
                    _addLog('  → $e');
                  }
                } else {
                  _addLog('Validation: OK');
                }
              },
            ),
          ),

          // Right panel: Controls and log
          SizedBox(
            width: 340,
            child: Column(
              children: [
                Expanded(flex: 3, child: _buildControlPanel()),
                Expanded(flex: 2, child: _buildLogPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('YAML Schema Editor Test'),
      actions: [
        IconButton(
          icon: const Icon(Icons.undo),
          tooltip: 'Undo',
          onPressed: _controller.canUndo
              ? () {
                  _controller.undo();
                  _addLog('Undo');
                }
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.redo),
          tooltip: 'Redo',
          onPressed: _controller.canRedo
              ? () {
                  _controller.redo();
                  _addLog('Redo');
                }
              : null,
        ),
        const SizedBox(width: 8),
        // Dataset switcher
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'prompt',
              label: Text('Prompt', style: TextStyle(fontSize: 11)),
            ),
            ButtonSegment(
              value: 'workflow',
              label: Text('Workflow', style: TextStyle(fontSize: 11)),
            ),
          ],
          selected: {_activeDataset},
          onSelectionChanged: (v) => _switchDataset(v.first),
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.file_open),
          tooltip: 'Load sample YAML',
          onPressed: _loadSampleYaml,
        ),
        IconButton(
          icon: const Icon(Icons.restore),
          tooltip: 'Reset to default YAML',
          onPressed: () {
            _controller.setYaml(_defaultYaml);
            _addLog('Reset to default');
          },
        ),
        IconButton(
          icon: const Icon(Icons.speed),
          tooltip: 'Load 500-key stress-test YAML',
          onPressed: () {
            _controller.setYaml(_generateLargeYaml(500));
            _addLog('Loaded 500-key stress-test YAML');
          },
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copy YAML to clipboard',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _controller.yamlText));
            _addLog('YAML copied to clipboard');
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // --- Editor Settings ---
          _SectionHeader(label: 'Editor Settings'),
          const SizedBox(height: 4),
          SwitchListTile(
            title: const Text('Dark theme'),
            subtitle: Text(
              _useDarkTheme ? 'Dark mode active' : 'Light mode active',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: _useDarkTheme,
            onChanged: (v) => setState(() => _useDarkTheme = v),
            secondary: Icon(_useDarkTheme ? Icons.dark_mode : Icons.light_mode,
                size: 20),
            dense: true,
          ),
          SwitchListTile(
            title: const Text('Read only'),
            value: _readOnly,
            onChanged: (v) => setState(() => _readOnly = v),
            secondary: const Icon(Icons.lock_outline, size: 20),
            dense: true,
          ),

          const Divider(),

          // --- Display Options ---
          _SectionHeader(label: 'Display Options'),
          const SizedBox(height: 4),
          _ToggleTile(
            label: 'Tree lines',
            value: _showTreeLines,
            onChanged: (v) => setState(() => _showTreeLines = v),
          ),
          _ToggleTile(
            label: 'Collapse toggles',
            value: _showCollapseToggles,
            onChanged: (v) => setState(() => _showCollapseToggles = v),
          ),
          _ToggleTile(
            label: 'Add buttons',
            value: _showAddButtons,
            onChanged: (v) => setState(() => _showAddButtons = v),
          ),
          _ToggleTile(
            label: 'Remove buttons',
            value: _showRemoveButtons,
            onChanged: (v) => setState(() => _showRemoveButtons = v),
          ),
          _ToggleTile(
            label: 'Inline validation',
            value: _showInlineValidation,
            onChanged: (v) => setState(() => _showInlineValidation = v),
          ),

          const Divider(),

          // --- Inspector Mode ---
          _SectionHeader(label: 'Inspector Mode'),
          const SizedBox(height: 4),
          SegmentedButton<SubtreeInspectorMode>(
            segments: const [
              ButtonSegment(
                value: SubtreeInspectorMode.sidePanel,
                label: Text('Side', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.view_sidebar, size: 16),
              ),
              ButtonSegment(
                value: SubtreeInspectorMode.bottomSheet,
                label: Text('Bottom', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.expand_more, size: 16),
              ),
              ButtonSegment(
                value: SubtreeInspectorMode.dialog,
                label: Text('Dialog', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.open_in_new, size: 16),
              ),
            ],
            selected: {_inspectorMode},
            onSelectionChanged: (v) => setState(() => _inspectorMode = v.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle:
                  WidgetStatePropertyAll(Theme.of(context).textTheme.bodySmall),
            ),
          ),

          const SizedBox(height: 12),

          // --- Error List Position ---
          _SectionHeader(label: 'Error List'),
          const SizedBox(height: 4),
          SegmentedButton<ErrorListPosition?>(
            segments: const [
              ButtonSegment(
                value: null,
                label: Text('Off', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.visibility_off, size: 16),
              ),
              ButtonSegment(
                value: ErrorListPosition.bottom,
                label: Text('Bottom', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.expand_more, size: 16),
              ),
              ButtonSegment(
                value: ErrorListPosition.side,
                label: Text('Side', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.view_sidebar, size: 16),
              ),
            ],
            selected: {_errorListPosition},
            onSelectionChanged: (v) =>
                setState(() => _errorListPosition = v.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle:
                  WidgetStatePropertyAll(Theme.of(context).textTheme.bodySmall),
            ),
          ),
          const SizedBox(height: 4),
          _ToggleTile(
            label: 'Highlight error rows',
            value: _highlightErrorRows,
            onChanged: (v) => setState(() => _highlightErrorRows = v),
          ),

          const Divider(),

          // --- Info ---
          _SectionHeader(label: 'Info'),
          const SizedBox(height: 4),
          _InfoRow(
            label: 'Schema',
            value: _schema != null
                ? _schema!.rawSchema['title'] as String? ?? 'loaded'
                : 'not loaded',
          ),
          _InfoRow(
            label: 'Valid',
            value: _controller.isValid ? 'Yes' : 'No',
            valueColor: _controller.isValid ? Colors.green : Colors.red,
          ),
          _InfoRow(
            label: 'Editors',
            value: _registry.suffixes.join(', '),
          ),
        ],
      ),
    );
  }

  Widget _buildLogPanel() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Event Log',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${_log.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.clear_all, size: 16),
                  tooltip: 'Clear log',
                  onPressed: () => setState(() => _log.clear()),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _logScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _log.length,
              itemBuilder: (context, index) {
                return Text(
                  _log[index],
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    height: 1.4,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSampleYaml() async {
    try {
      var yamlFile = _activeDataset == 'workflow'
          ? 'assets/complex_workflow.yaml'
          : 'assets/sample_prompt.yaml';
      var yaml = await rootBundle.loadString(yamlFile);
      _controller.setYaml(yaml);
      _addLog('Sample YAML loaded from $yamlFile');
    } catch (e) {
      _addLog('Failed to load sample: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// Control panel helper widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleSmall);
  }
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w500,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stress-test YAML generator
// ---------------------------------------------------------------------------

/// Generates a YAML document with approximately [keyCount] keys organised into
/// nested sections. Used for performance profiling (Phase 8.4).
String _generateLargeYaml(int keyCount) {
  var buf = StringBuffer('# Stress-test YAML with ~$keyCount keys\n');
  var keysWritten = 0;
  var section = 0;

  while (keysWritten < keyCount) {
    section++;
    buf.writeln('section-$section:');
    // Each section has ~10 scalar keys + a nested sub-section of ~5 keys
    for (var i = 1; i <= 10 && keysWritten < keyCount; i++) {
      buf.writeln('  key-${section}_$i: "value $section.$i"');
      keysWritten++;
    }
    if (keysWritten < keyCount) {
      buf.writeln('  nested-$section:');
      for (var j = 1; j <= 5 && keysWritten < keyCount; j++) {
        buf.writeln('    child-${section}_$j: ${section * 100 + j}');
        keysWritten++;
      }
    }
    if (keysWritten < keyCount) {
      buf.writeln('  description-markdown: |');
      buf.writeln('    # Section $section');
      buf.writeln('    This is **section $section** of the stress test.');
      keysWritten++;
    }
  }

  return buf.toString();
}

// ---------------------------------------------------------------------------
// Default YAML content
// ---------------------------------------------------------------------------

const _defaultYaml = '''
# Sample prompt configuration
prompt:
  meta-data:
    name: My First Prompt
    id: prompt-001
    version: 1
    description-markdown: |
      # Description
      This prompt does **something useful**.
  script-dart: |
    void main() {
      print('Hello from the YAML editor!');
    }
  template-markdown: |
    ## Result
    Output: {{result}}
  filter-regex: "^test.*"
  config-json: |
    {
      "timeout": 30,
      "retries": 3
    }
  highlight-color: "4CAF50"
  execution-count: 1
  enabled: true
  tags:
    - test
    - example
''';
