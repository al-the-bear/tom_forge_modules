import 'package:flutter/material.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';

import 'generated/summary_scopes.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Register the summary scope buildkit.yaml declares (the pair
  // tom_dart_editor_bundler builds), before the first frame.
  await SummaryScopes.initialize();
  runApp(const DartAnalyzerApp());
}

class DartAnalyzerApp extends StatelessWidget {
  const DartAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dart Code Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AnalyzerScreen(),
    );
  }
}

class AnalyzerScreen extends StatefulWidget {
  const AnalyzerScreen({super.key});

  @override
  State<AnalyzerScreen> createState() => _AnalyzerScreenState();
}

class _AnalyzerScreenState extends State<AnalyzerScreen> {
  List<CodeError> _errors = const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart Editor Test App'),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SimpleSummaryBackedDartCodeEditor(
                initialCode: '''void main() {
  String name = 42;
  print(name)
  undefinedFunction();
}
''',
                implicitImports: const [
                  'dart:async',
                  'dart:collection',
                  'dart:math',
                  'package:dcli/dcli.dart',
                  'package:path/path.dart',
                ],
                // The summaries of the scope buildkit.yaml declares.
                scope: SummaryScopes.dartEditor,
                theme: DartEditorTheme.dark(),
                onErrorsChanged: (errors) {
                  if (!mounted) return;
                  setState(() {
                    _errors = errors;
                  });
                },
              ),
            ),
          ),
          Container(
            width: 360,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: _ErrorPanel(errors: _errors),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final List<CodeError> errors;

  const _ErrorPanel({required this.errors});

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) {
      return const Center(
        child: Text('No analyzer issues'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: errors.length,
      separatorBuilder: (_, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final error = errors[index];
        final color = error.isError
            ? Colors.redAccent
            : error.isWarning
                ? Colors.orangeAccent
                : Colors.lightBlueAccent;
        return ListTile(
          dense: true,
          leading: Icon(Icons.circle, size: 10, color: color),
          title: Text(
            error.code,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Line ${error.line}:${error.column} • ${error.message}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
