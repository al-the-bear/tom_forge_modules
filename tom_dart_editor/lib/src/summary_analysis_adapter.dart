import 'dart:io';
import 'dart:typed_data';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/results.dart' as results;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/context/packages.dart';
import 'package:analyzer/src/dart/analysis/analysis_options.dart';
import 'package:analyzer/src/file_system/file_system.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'analyzer_with_packages.dart';
import 'completion_provider.dart';
import 'dart_code_editor.dart';

/// Summary-backed analyzer/completion adapter for [DartCodeEditor].
///
/// This provides reusable diagnostics and completion logic so host apps can
/// embed [DartCodeEditor] without duplicating analyzer integration code.
class SummaryBackedDartAnalysisAdapter {
  final String sdkSummaryAsset;
  final String packageSummaryAsset;
  final List<String> implicitImports;

  Uint8List? _sdkSummaryBytes;
  Uint8List? _packageSummaryBytes;
  AnalysisDriverWithPackages? _cachedDriver;
  bool _packageUrisRegistered = false;
  bool _implicitImportsValidated = false;
  List<CompletionItem>? _packageTypeCompletions;

  SummaryBackedDartAnalysisAdapter({
    this.sdkSummaryAsset = 'assets/sdk_summary.sum',
    this.packageSummaryAsset = 'assets/packages.sum',
    this.implicitImports = const [
      'dart:async',
      'dart:collection',
      'dart:math',
      'package:path/path.dart',
    ],
  });

  Future<void> ensureInitialized() async {
    if (_sdkSummaryBytes != null) return;
    final sdkByteData = await rootBundle.load(sdkSummaryAsset);
    final pkgByteData = await rootBundle.load(packageSummaryAsset);
    _sdkSummaryBytes = sdkByteData.buffer.asUint8List();
    _packageSummaryBytes = pkgByteData.buffer.asUint8List();
    _cachedDriver = null;
    _packageUrisRegistered = false;
    _implicitImportsValidated = false;
    _packageTypeCompletions = null;
  }

  Future<List<CodeError>> analyzeCode(String code) async {
    await ensureInitialized();
    if (_sdkSummaryBytes == null) return const [];

    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp('dart_editor_analyzer_');
      final tempFile = File('${tempDir.path}/analysis_target.dart');

      _cachedDriver ??= _createAnalysisDriver();
      await _ensurePackageUrisRegistered(_cachedDriver!);
      await _ensureImplicitImportsResolvable(_cachedDriver!);

      final fullCode = _buildFullCode(code);
      final lineOffset = _lineOffset;

      await tempFile.writeAsString(fullCode);

      final driver = _cachedDriver!;
      driver.changeFile(tempFile.path);
      await driver.applyPendingFileChanges();

      final session = driver.currentSession;
      final errorsResult = await session.getErrors(tempFile.path);
      if (errorsResult is! ErrorsResult) return const [];

      final lineInfo = errorsResult.lineInfo;
      return errorsResult.diagnostics
          .map((error) {
            final location = lineInfo.getLocation(error.offset);
            final adjustedLine = location.lineNumber - lineOffset;
            if (adjustedLine < 1) return null;

            final codeName = error.diagnosticCode.lowerCaseName;

            if (codeName.contains('unused_import')) {
              return null;
            }
            if (codeName == 'uri_does_not_exist') {
              final isImplicitImport =
                  implicitImports.any((imp) => error.message.contains(imp));
              if (isImplicitImport) return null;
            }

            return CodeError(
              message: error.message,
              line: adjustedLine,
              column: location.columnNumber,
              offset: error.offset,
              length: error.length,
              severity: error.severity.name,
              code: codeName,
            );
          })
          .whereType<CodeError>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    } finally {
      if (tempDir != null) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<List<CompletionItem>> completions(
    String code,
    int cursorOffset,
    String prefix,
  ) async {
    await ensureInitialized();
    if (_sdkSummaryBytes == null) return const [];

    _cachedDriver ??= _createAnalysisDriver();
    await _ensurePackageUrisRegistered(_cachedDriver!);
    await _ensureImplicitImportsResolvable(_cachedDriver!);

    _packageTypeCompletions ??=
        await _extractPackageTypes(_cachedDriver!, implicitImports);

    final textBeforeCursor = code.substring(0, cursorOffset);
    final dotAccessMatch =
        RegExp(r'[a-zA-Z_][a-zA-Z0-9_]*\.([a-zA-Z_][a-zA-Z0-9_]*)?$')
            .firstMatch(textBeforeCursor);
    final isDotCompletion = dotAccessMatch != null;
    final dotOffset = isDotCompletion
        ? cursorOffset - (dotAccessMatch.group(1)?.length ?? 0)
        : cursorOffset;

    final out = <CompletionItem>[];
    if (isDotCompletion) {
      out.addAll(await _getMemberCompletions(code, dotOffset, prefix));
    } else {
      final localVars = _extractLocalCompletions(code, cursorOffset);
      for (final item in localVars) {
        if (prefix.isEmpty || item.label.startsWith(prefix)) {
          out.add(item);
        }
      }
      for (final item in _packageTypeCompletions ?? const <CompletionItem>[]) {
        if (prefix.isEmpty || item.label.startsWith(prefix)) {
          out.add(item);
        }
      }
    }

    return out;
  }

  AnalysisDriverWithPackages _createAnalysisDriver() {
    final resourceProvider = PhysicalResourceProvider.INSTANCE;
    _packageUrisRegistered = false;
    return createAnalysisDriverWithPackages(
      resourceProvider: resourceProvider,
      sdkSummaryBytes: _sdkSummaryBytes!,
      packageSummaryBytes: _packageSummaryBytes,
      analysisOptions: AnalysisOptionsImpl(),
      uriResolvers: [ResourceUriResolver(resourceProvider)],
      packages: Packages.empty,
    );
  }

  Future<void> _ensurePackageUrisRegistered(
    AnalysisDriverWithPackages driver,
  ) async {
    if (_packageUrisRegistered) return;
    final session = driver.currentSession;
    final packageUris = driver.packageLibraryUris
        .where((uri) => uri.startsWith('package:'))
        .toList(growable: false);

    for (final uri in packageUris) {
      try {
        await session.getLibraryByUri(uri);
      } catch (_) {}
    }
    _packageUrisRegistered = true;
  }

  Future<void> _ensureImplicitImportsResolvable(
    AnalysisDriverWithPackages driver,
  ) async {
    if (_implicitImportsValidated) return;

    final session = driver.currentSession;
    for (final importUri in implicitImports) {
      if (!importUri.startsWith('package:')) {
        continue;
      }

      try {
        await session.getLibraryByUri(importUri);
      } catch (_) {}
    }

    _implicitImportsValidated = true;
  }

  Future<List<CompletionItem>> _extractPackageTypes(
    AnalysisDriverWithPackages driver,
    List<String> implicitImports,
  ) async {
    final completions = <CompletionItem>[];
    final session = driver.currentSession;
    final seenNames = <String>{};

    for (final sdkUri in driver.sdkLibraryUris) {
      final uriStr = sdkUri.toString();
      try {
        final result = await session.getLibraryByUri(uriStr);
        if (result is results.LibraryElementResult) {
          _extractLibraryElements(
              result.element, uriStr, seenNames, completions);
        }
      } catch (_) {}
    }

    final packageImports = <String>[];
    final seenPackageUris = <String>{};
    for (final uri in implicitImports) {
      if (uri.startsWith('package:') && seenPackageUris.add(uri)) {
        packageImports.add(uri);
      }
    }
    for (final uri in driver.packageLibraryUris) {
      if (uri.startsWith('package:') && seenPackageUris.add(uri)) {
        packageImports.add(uri);
      }
    }

    for (final uriStr in packageImports) {
      try {
        final uri = Uri.parse(uriStr);
        final result = await session.getLibraryByUri(uriStr);
        final packageName = uri.pathSegments.isNotEmpty
            ? 'package:${uri.pathSegments.first}'
            : uriStr;
        if (result is results.LibraryElementResult) {
          _extractLibraryElements(
              result.element, packageName, seenNames, completions);
        }
      } catch (_) {}
    }

    return completions;
  }

  void _extractLibraryElements(
    LibraryElement library,
    String packageName,
    Set<String> seenNames,
    List<CompletionItem> completions,
  ) {
    for (final classElement in library.classes) {
      final name = classElement.name!;
      if (!classElement.isPrivate && !seenNames.contains(name)) {
        seenNames.add(name);
        completions.add(_buildClassCompletion(classElement, packageName));
      }
    }

    for (final enumElement in library.enums) {
      final name = enumElement.name!;
      if (!enumElement.isPrivate && !seenNames.contains(name)) {
        seenNames.add(name);
        completions.add(_buildEnumCompletion(enumElement, packageName));
      }
    }

    for (final funcElement in library.topLevelFunctions) {
      final name = funcElement.name!;
      if (!funcElement.isPrivate && !seenNames.contains(name)) {
        seenNames.add(name);
        completions.add(
          CompletionItem(
            label: name,
            kind: CompletionKind.function,
            detail: packageName,
            signature:
                '${funcElement.returnType.getDisplayString()} $name(${_formatParameterList(funcElement.formalParameters)})',
            documentation: funcElement.documentationComment,
          ),
        );
      }
    }
  }

  CompletionItem _buildClassCompletion(
    InterfaceElement classElement,
    String packageName,
  ) {
    final members = <MemberInfo>[];

    for (final constructor in classElement.constructors) {
      if (!constructor.isPrivate) {
        final constructorName = constructor.name;
        final ctorLabel = (constructorName == null ||
                constructorName.isEmpty ||
                constructorName == 'new')
            ? classElement.name!
            : '${classElement.name}.$constructorName';
        members.add(
          MemberInfo(
            name: ctorLabel,
            signature:
                '$ctorLabel(${_formatParameterList(constructor.formalParameters)})',
            kind: CompletionKind.constructor,
            documentation: constructor.documentationComment,
          ),
        );
      }
    }

    for (final method in classElement.methods) {
      if (!method.isPrivate) {
        members.add(
          MemberInfo(
            name: method.name!,
            signature:
                '${method.returnType.getDisplayString()} ${method.name}(${_formatParameterList(method.formalParameters)})',
            kind: CompletionKind.method,
            documentation: method.documentationComment,
          ),
        );
      }
    }

    for (final getter in classElement.getters) {
      if (!getter.isPrivate) {
        members.add(
          MemberInfo(
            name: getter.name!,
            signature: '${getter.returnType.getDisplayString()} ${getter.name}',
            kind: CompletionKind.getter,
            documentation: getter.documentationComment,
          ),
        );
      }
    }

    for (final setter in classElement.setters) {
      if (!setter.isPrivate) {
        final setterName = setter.name!.replaceFirst('=', '');
        members.add(
          MemberInfo(
            name: setterName,
            signature:
                'set $setterName(${_formatParameterList(setter.formalParameters)})',
            kind: CompletionKind.setter,
            documentation: setter.documentationComment,
          ),
        );
      }
    }

    return CompletionItem(
      label: classElement.name!,
      kind: CompletionKind.className,
      detail: packageName,
      signature: 'class ${classElement.name!}',
      documentation: classElement.documentationComment,
      members: members,
    );
  }

  CompletionItem _buildEnumCompletion(
      EnumElement enumElement, String packageName) {
    final members = <MemberInfo>[];
    for (final field in enumElement.fields) {
      if (field.isEnumConstant) {
        members.add(
          MemberInfo(
            name: field.name!,
            signature: field.name!,
            kind: CompletionKind.enumValue,
          ),
        );
      }
    }

    return CompletionItem(
      label: enumElement.name!,
      kind: CompletionKind.enumType,
      detail: packageName,
      signature: enumElement.name,
      documentation: enumElement.documentationComment,
      members: members,
    );
  }

  String _formatParameterList(List<FormalParameterElement> params) {
    if (params.isEmpty) return '';
    final positionalRequired = <String>[];
    final positionalOptional = <String>[];
    final named = <String>[];

    for (final param in params) {
      final type = param.type.getDisplayString();
      final paramStr = '$type ${param.name}';
      if (param.isNamed) {
        if (param.isRequired) {
          named.add('required $paramStr');
        } else {
          named.add(paramStr);
        }
      } else if (param.isOptionalPositional) {
        positionalOptional.add(paramStr);
      } else {
        positionalRequired.add(paramStr);
      }
    }

    final parts = <String>[];
    if (positionalRequired.isNotEmpty) parts.add(positionalRequired.join(', '));
    if (positionalOptional.isNotEmpty) {
      parts.add('[${positionalOptional.join(', ')}]');
    }
    if (named.isNotEmpty) parts.add('{${named.join(', ')}}');
    return parts.join(', ');
  }

  List<CompletionItem> _extractLocalCompletions(String code, int cursorOffset) {
    final completions = <CompletionItem>[];
    final seenNames = <String>{};
    final searchCode = code.substring(0, cursorOffset);

    void addVar(String name, String type) {
      if (!_isDartKeyword(name) && !seenNames.contains(name)) {
        seenNames.add(name);
        completions.add(
          CompletionItem(
            label: name,
            insertText: name,
            kind: CompletionKind.variable,
            detail: type.isEmpty ? null : type,
            sortOrder: -1,
          ),
        );
      }
    }

    final typedPattern = RegExp(
      r'\b([A-Z][a-zA-Z0-9_]*)(?:<[^;={]*>)?[?]?\s+([a-z_][a-zA-Z0-9_]*)\s*(?=[=;,]|\s+in\b)',
    );
    for (final m in typedPattern.allMatches(searchCode)) {
      addVar(m.group(2)!, m.group(1)!);
    }

    final primitivePattern = RegExp(
      r'\b(int|double|bool|num|dynamic)\s+([a-z_][a-zA-Z0-9_]*)\s*(?=[=;,]|\s+in\b|\s*\))',
    );
    for (final m in primitivePattern.allMatches(searchCode)) {
      addVar(m.group(2)!, m.group(1)!);
    }

    final kwDeclPattern = RegExp(
      r'\b(?:var|final|const|late)\s+(?:(?:[A-Za-z][a-zA-Z0-9_]*)(?:<[^;={]*>)?[?]?\s+)?([a-z_][a-zA-Z0-9_]*)\s*[=;]',
    );
    for (final m in kwDeclPattern.allMatches(searchCode)) {
      addVar(m.group(1)!, '');
    }

    return completions;
  }

  static bool _isDartKeyword(String name) {
    const keywords = {
      'if',
      'else',
      'for',
      'while',
      'do',
      'switch',
      'case',
      'break',
      'continue',
      'return',
      'try',
      'catch',
      'finally',
      'throw',
      'new',
      'null',
      'true',
      'false',
      'class',
      'extends',
      'implements',
      'with',
      'abstract',
      'static',
      'void',
      'in',
      'is',
      'as',
      'this',
      'super',
      'import',
      'export',
      'library',
      'part',
      'typedef',
      'enum',
      'mixin',
      'extension',
      'on',
      'show',
      'hide',
      'async',
      'await',
      'yield',
      'sync',
      'assert',
      'default',
      'var',
      'final',
      'const',
      'late',
      'required',
      'covariant',
      'external',
      'operator',
      'get',
      'set',
      'dynamic',
      'int',
      'double',
      'bool',
      'num',
      'never',
    };
    return keywords.contains(name);
  }

  Future<List<CompletionItem>> _getMemberCompletions(
    String code,
    int cursorOffset,
    String prefix,
  ) async {
    final completions = <CompletionItem>[];
    final textBeforeCursor = code.substring(0, cursorOffset);
    final trimmed = textBeforeCursor.trimRight();
    if (!trimmed.endsWith('.')) return completions;

    final beforeDot = trimmed.substring(0, trimmed.length - 1).trimRight();
    final identifierMatch =
        RegExp(r'([a-zA-Z_][a-zA-Z0-9_]*)$').firstMatch(beforeDot);
    if (identifierMatch == null) return completions;

    final identifier = identifierMatch.group(1)!;

    CompletionItem? typeCompletion = _packageTypeCompletions?.firstWhere(
      (item) => item.label == identifier,
      orElse: () => const CompletionItem(
        label: '',
        kind: CompletionKind.className,
      ),
    );

    if (typeCompletion == null || typeCompletion.label.isEmpty) {
      final inferredTypeName =
          _inferTypeFromCode(code, identifier, cursorOffset);
      if (inferredTypeName != null) {
        typeCompletion = _packageTypeCompletions?.firstWhere(
          (item) => item.label == inferredTypeName,
          orElse: () => const CompletionItem(
            label: '',
            kind: CompletionKind.className,
          ),
        );
      }
    }

    if (typeCompletion != null &&
        typeCompletion.label.isNotEmpty &&
        typeCompletion.members != null) {
      for (final member in typeCompletion.members!) {
        if (prefix.isEmpty || member.name.startsWith(prefix)) {
          completions.add(
            CompletionItem(
              label: member.name,
              insertText: member.name,
              kind: member.kind,
              signature: member.signature,
              documentation: member.documentation,
              detail: '$identifier.${member.name}',
              sortOrder: _getSortOrderForKind(member.kind),
            ),
          );
        }
      }
    }

    return completions;
  }

  String? _inferTypeFromCode(String code, String identifier, int cursorOffset) {
    final searchCode = code.substring(0, cursorOffset);
    final pattern = RegExp(
      r'\b([A-Z][a-zA-Z0-9_]*)(?:<[^>]*>)?\??\s+' +
          RegExp.escape(identifier) +
          r'\b',
    );
    final matches = pattern.allMatches(searchCode);
    if (matches.isEmpty) return null;
    return matches.last.group(1);
  }

  int _getSortOrderForKind(CompletionKind kind) {
    return switch (kind) {
      CompletionKind.constructor => 0,
      CompletionKind.method => 1,
      CompletionKind.getter => 2,
      CompletionKind.setter => 2,
      CompletionKind.property => 3,
      CompletionKind.enumValue => 1,
      _ => 4,
    };
  }

  String _buildFullCode(String userCode) {
    final importLines = implicitImports.map((i) => "import '$i';").join('\n');
    return '$importLines\n\n$userCode';
  }

  int get _lineOffset =>
      implicitImports.isEmpty ? 0 : implicitImports.length + 1;
}
