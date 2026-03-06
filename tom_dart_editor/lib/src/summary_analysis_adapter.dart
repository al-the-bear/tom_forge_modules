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
  final bool includeAllPackageCompletions;
  final List<String>? allowedPackagePrefixes;

  Uint8List? _sdkSummaryBytes;
  Uint8List? _packageSummaryBytes;
  AnalysisDriverWithPackages? _cachedDriver;
  bool _packageUrisRegistered = false;
  bool _implicitImportsValidated = false;
  List<String>? _resolvedImplicitImports;
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
    this.includeAllPackageCompletions = false,
    this.allowedPackagePrefixes,
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
    _resolvedImplicitImports = null;
    _packageTypeCompletions = null;
  }

  Future<List<CodeError>> analyzeCode(String code) {
    return _analyzeCodeInternal(code, retryOnFailure: true);
  }

  Future<List<CodeError>> _analyzeCodeInternal(
    String code, {
    required bool retryOnFailure,
  }) async {
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
      final codeOffset = fullCode.length - code.length;

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

            final adjustedOffset = error.offset - codeOffset;
            if (adjustedOffset < 0) return null;

            final codeName = error.diagnosticCode.lowerCaseName;

            if (codeName.contains('unused_import')) {
              return null;
            }
            if (codeName == 'uri_does_not_exist') {
              final isImplicitImport = _effectiveImplicitImports
                  .any((imp) => error.message.contains(imp));
              if (isImplicitImport) return null;
            }

            return CodeError(
              message: error.message,
              line: adjustedLine,
              column: location.columnNumber,
              offset: adjustedOffset,
              length: error.length,
              severity: error.severity.name,
              code: codeName,
            );
          })
          .whereType<CodeError>()
          .toList(growable: false);
    } catch (_) {
      if (!retryOnFailure) return const [];

      _cachedDriver = null;
      _packageUrisRegistered = false;
      _implicitImportsValidated = false;
      _resolvedImplicitImports = null;
      _packageTypeCompletions = null;

      return _analyzeCodeInternal(code, retryOnFailure: false);
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
  ) {
    return _completionsInternal(
      code,
      cursorOffset,
      prefix,
      retryOnFailure: true,
    );
  }

  Future<List<CompletionItem>> _completionsInternal(
    String code,
    int cursorOffset,
    String prefix, {
    required bool retryOnFailure,
  }) async {
    await ensureInitialized();
    if (_sdkSummaryBytes == null) return const [];

    try {
      _cachedDriver ??= _createAnalysisDriver();
      await _ensurePackageUrisRegistered(_cachedDriver!);
      await _ensureImplicitImportsResolvable(_cachedDriver!);

      _packageTypeCompletions ??=
          await _extractPackageTypes(_cachedDriver!, _effectiveImplicitImports);

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
        for (final item
            in _packageTypeCompletions ?? const <CompletionItem>[]) {
          if (prefix.isEmpty || item.label.startsWith(prefix)) {
            out.add(item);
          }
        }
      }

      return out;
    } catch (_) {
      if (!retryOnFailure) return const [];

      _cachedDriver = null;
      _packageUrisRegistered = false;
      _implicitImportsValidated = false;
      _resolvedImplicitImports = null;
      _packageTypeCompletions = null;

      return _completionsInternal(
        code,
        cursorOffset,
        prefix,
        retryOnFailure: false,
      );
    }
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
    final resolvedImports = <String>[];
    for (final importUri in implicitImports) {
      if (!importUri.startsWith('package:')) {
        resolvedImports.add(importUri);
        continue;
      }

      try {
        await session.getLibraryByUri(importUri);
        resolvedImports.add(importUri);
      } catch (_) {}
    }

    _resolvedImplicitImports = resolvedImports;
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
    if (includeAllPackageCompletions) {
      for (final uri in driver.packageLibraryUris) {
        if (uri.startsWith('package:') &&
            _matchesAllowedPackagePrefixes(uri) &&
            seenPackageUris.add(uri)) {
          packageImports.add(uri);
        }
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

  bool _matchesAllowedPackagePrefixes(String packageUri) {
    final prefixes = allowedPackagePrefixes;
    if (prefixes == null || prefixes.isEmpty) {
      return true;
    }
    return prefixes.any(packageUri.startsWith);
  }

  void _extractLibraryElements(
    LibraryElement library,
    String packageName,
    Set<String> seenNames,
    List<CompletionItem> completions,
  ) {
    final visitedLibraries = <LibraryElement>{};

    void addFromLibrary(LibraryElement current, {int depth = 0}) {
      if (visitedLibraries.contains(current) || depth > 8) return;
      visitedLibraries.add(current);

      try {
        for (final classElement in current.classes) {
          final name = classElement.name;
          if (name != null &&
              !classElement.isPrivate &&
              !seenNames.contains(name)) {
            seenNames.add(name);
            completions.add(_buildClassCompletion(classElement, packageName));
          }
        }

        for (final enumElement in current.enums) {
          final name = enumElement.name;
          if (name != null &&
              !enumElement.isPrivate &&
              !seenNames.contains(name)) {
            seenNames.add(name);
            completions.add(_buildEnumCompletion(enumElement, packageName));
          }
        }

        for (final funcElement in current.topLevelFunctions) {
          final name = funcElement.name;
          if (name != null &&
              !funcElement.isPrivate &&
              !seenNames.contains(name)) {
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

        for (final exportedLibrary in current.exportedLibraries) {
          addFromLibrary(exportedLibrary, depth: depth + 1);
        }
      } catch (_) {}
    }

    addFromLibrary(library);
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
    try {
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

      var members = <MemberInfo>[];
      if (typeCompletion != null &&
          typeCompletion.label.isNotEmpty &&
          typeCompletion.members != null) {
        members = List<MemberInfo>.from(typeCompletion.members!);
      } else {
        final inferredTypeName =
            _inferTypeFromCode(code, identifier, cursorOffset);
        if (inferredTypeName != null) {
          members = _extractLocalClassMembers(code, inferredTypeName);
        }
      }

      if (members.isNotEmpty) {
        for (final member in members) {
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
    } catch (_) {
      return const [];
    }

    return completions;
  }

  List<MemberInfo> _extractLocalClassMembers(String code, String className) {
    final classRegex = RegExp(
      'class\\s+${RegExp.escape(className)}(?:\\s+extends\\s+[^\\{]+)?\\s*\\{([\\s\\S]*?)\\n\\}',
      multiLine: true,
    );
    final classMatch = classRegex.firstMatch(code);
    if (classMatch == null) return const [];

    final body = classMatch.group(1) ?? '';
    final members = <MemberInfo>[];
    final seen = <String>{};

    void addMember(String name, CompletionKind kind, {String? signature}) {
      if (name.isEmpty || _isDartKeyword(name) || seen.contains(name)) return;
      seen.add(name);
      members.add(
        MemberInfo(
          name: name,
          signature: signature ?? name,
          kind: kind,
        ),
      );
    }

    final getterRegex = RegExp(
      r'(?:[A-Za-z_][A-Za-z0-9_<>,\?\s\.]*)?\s+get\s+([a-zA-Z_][a-zA-Z0-9_]*)\b',
      multiLine: true,
    );
    for (final match in getterRegex.allMatches(body)) {
      final name = match.group(1) ?? '';
      addMember(name, CompletionKind.getter, signature: name);
    }

    final setterRegex = RegExp(
      r'\bset\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(',
      multiLine: true,
    );
    for (final match in setterRegex.allMatches(body)) {
      final name = match.group(1) ?? '';
      addMember(name, CompletionKind.setter, signature: '$name(...)');
    }

    final methodRegex = RegExp(
      r'(?:[A-Za-z_][A-Za-z0-9_<>,\?\s\.]*)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\(([^\)]*)\)\s*\{',
      multiLine: true,
    );
    const excludedMethodNames = {
      'if',
      'for',
      'while',
      'switch',
      'catch',
      'return',
      'assert',
    };
    for (final match in methodRegex.allMatches(body)) {
      final name = match.group(1) ?? '';
      if (excludedMethodNames.contains(name)) continue;
      final params = (match.group(2) ?? '').trim();
      addMember(name, CompletionKind.method, signature: '$name($params)');
    }

    final fieldRegex = RegExp(
      r'(?:final|var|late|const|[A-Za-z_][A-Za-z0-9_<>,\?\.]*)\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*(?:=|;)',
      multiLine: true,
    );
    for (final match in fieldRegex.allMatches(body)) {
      final name = match.group(1) ?? '';
      addMember(name, CompletionKind.property, signature: name);
    }

    return members;
  }

  String? _inferTypeFromCode(String code, String identifier, int cursorOffset) {
    final searchCode = code.substring(0, cursorOffset);

    if (identifier == 'this' || identifier == 'super') {
      final classMatches = RegExp(
        r'class\s+([A-Z][a-zA-Z0-9_]*)(?:\s+extends\s+([A-Z][a-zA-Z0-9_]*))?',
      ).allMatches(searchCode);
      if (classMatches.isNotEmpty) {
        final last = classMatches.last;
        if (identifier == 'this') {
          return last.group(1);
        }
        final superType = last.group(2);
        if (superType != null && superType.isNotEmpty) {
          return superType;
        }
      }
    }

    final typedDeclPattern = RegExp(
      r'\b([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)?)(?:<[^>]*>)?\??\s+' +
          RegExp.escape(identifier) +
          r'\b',
    );
    final typedDeclMatches = typedDeclPattern.allMatches(searchCode);
    if (typedDeclMatches.isNotEmpty) {
      final rawType = typedDeclMatches.last.group(1);
      if (rawType != null &&
          rawType != 'var' &&
          rawType != 'final' &&
          rawType != 'const' &&
          rawType != 'late') {
        final unprefixed =
            rawType.contains('.') ? rawType.split('.').last : rawType;
        return unprefixed;
      }
    }

    final inferredCtorPattern = RegExp(
      r'\b(?:var|final|const|late)\s+' +
          RegExp.escape(identifier) +
          r'\s*=\s*([A-Z][a-zA-Z0-9_]*)(?:<[^>]*>)?(?:\.[a-zA-Z_][a-zA-Z0-9_]*)?\s*\(',
    );
    final inferredCtorMatches = inferredCtorPattern.allMatches(searchCode);
    if (inferredCtorMatches.isNotEmpty) {
      return inferredCtorMatches.last.group(1);
    }

    final inferredFunctionCallPattern = RegExp(
      r'\b(?:var|final|const|late)\s+' +
          RegExp.escape(identifier) +
          r'\s*=\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\(',
    );
    final inferredFunctionCallMatches =
        inferredFunctionCallPattern.allMatches(searchCode);
    if (inferredFunctionCallMatches.isNotEmpty) {
      final functionName = inferredFunctionCallMatches.last.group(1);
      if (functionName != null && functionName.isNotEmpty) {
        final functionCompletion = _packageTypeCompletions?.firstWhere(
          (item) =>
              item.kind == CompletionKind.function &&
              item.label == functionName,
          orElse: () => const CompletionItem(
            label: '',
            kind: CompletionKind.function,
          ),
        );
        final signature = functionCompletion?.signature;
        if (signature != null && signature.isNotEmpty) {
          final signatureMatch = RegExp(
            r'^(.+?)\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\(',
            dotAll: true,
          ).firstMatch(signature);
          if (signatureMatch != null) {
            final rawReturnType = (signatureMatch.group(1) ?? '').trim();
            final normalized = _normalizeReturnTypeForLookup(rawReturnType);
            if (normalized.isNotEmpty && normalized != 'void') {
              return normalized;
            }
          }
        }
      }
    }

    final inferredStringPattern = RegExp(
      r'\b(?:var|final|const|late)\s+' +
          RegExp.escape(identifier) +
          r'''\s*=\s*(['"]).*\1\s*;?''',
      dotAll: true,
    );
    if (inferredStringPattern.hasMatch(searchCode)) return 'String';

    final inferredBoolPattern = RegExp(
      r'\b(?:var|final|const|late)\s+' +
          RegExp.escape(identifier) +
          r'\s*=\s*(true|false)\b',
    );
    if (inferredBoolPattern.hasMatch(searchCode)) return 'bool';

    final inferredNumPattern = RegExp(
      r'\b(?:var|final|const|late)\s+' +
          RegExp.escape(identifier) +
          r'\s*=\s*([0-9]+(?:\.[0-9]+)?)\b',
    );
    final numMatches = inferredNumPattern.allMatches(searchCode);
    if (numMatches.isNotEmpty) {
      final value = numMatches.last.group(1) ?? '';
      return value.contains('.') ? 'double' : 'int';
    }

    final inferredListPattern = RegExp(
      r'\b(?:var|final|const|late)\s+' +
          RegExp.escape(identifier) +
          r'\s*=\s*\[',
    );
    if (inferredListPattern.hasMatch(searchCode)) return 'List';

    final inferredMapPattern = RegExp(
      r'\b(?:var|final|const|late)\s+' +
          RegExp.escape(identifier) +
          r'\s*=\s*\{',
    );
    if (inferredMapPattern.hasMatch(searchCode)) return 'Map';

    return null;
  }

  String _normalizeReturnTypeForLookup(String raw) {
    if (raw.isEmpty) return raw;

    var value = raw.replaceAll('?', '').trim();

    final functionGenericIndex = value.indexOf(' Function');
    if (functionGenericIndex > 0) {
      value = value.substring(0, functionGenericIndex).trim();
    }

    final genericStart = value.indexOf('<');
    if (genericStart > 0) {
      value = value.substring(0, genericStart).trim();
    }

    if (value.contains('.')) {
      value = value.split('.').last.trim();
    }

    return value;
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
    final importLines =
        _effectiveImplicitImports.map((i) => "import '$i';").join('\n');
    return '$importLines\n\n$userCode';
  }

  List<String> get _effectiveImplicitImports =>
      _resolvedImplicitImports ?? implicitImports;

  int get _lineOffset => _effectiveImplicitImports.isEmpty
      ? 0
      : _effectiveImplicitImports.length + 1;
}
