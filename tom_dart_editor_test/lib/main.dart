import 'package:flutter/material.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';

void main() {
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
  late final DartCodeController _controller;
  List<CodeError> _errors = const [];

  @override
  void initState() {
    super.initState();
    _controller = DartCodeController(
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
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              child: SummaryBackedDartCodeEditor(
                controller: _controller,
                sdkSummaryAsset: 'assets/sdk_summary.sum',
                packageSummaryAsset: 'assets/packages.sum',
                theme: DartEditorTheme.dark(),
                onChanged: (code) {
                  _controller.userCode = code;
                },
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
