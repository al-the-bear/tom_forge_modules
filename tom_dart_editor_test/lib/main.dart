import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart' show rootBundle;
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/src/context/packages.dart';
import 'package:analyzer/src/dart/analysis/analysis_options.dart';
import 'package:analyzer/src/file_system/file_system.dart';
import 'package:analyzer/dart/analysis/results.dart' as results;
import 'package:path/path.dart' as path;

// Import from the tom_dart_editor library
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
  // Code editor controller with implicit imports
  late final DartCodeController _codeController;

  List<CodeError> _errors = [];
  bool _isAnalyzing = false;
  String? _analyzerError;
  bool _isLoading = true;
  Uint8List? _sdkSummaryBytes;
  Uint8List? _packageSummaryBytes;
  final List<String> _debugLog = [];
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 500);

  // Cached driver for completions
  AnalysisDriverWithPackages? _cachedDriver;
  bool _packageUrisRegistered = false;
  bool _implicitImportsValidated = false;
  List<CompletionItem>? _packageTypeCompletions;

  @override
  void initState() {
    super.initState();

    // Initialize code controller with implicit imports
    _codeController = DartCodeController(
      initialCode: '''void main() {
  String name = 42;  // Type error
  print(name)  // Missing semicolon
  undefinedFunction();  // Undefined function
}
''',
      implicitImports: [
        'dart:async',
        'dart:collection',
        'dart:math',
        'package:dcli/dcli.dart',
        'package:path/path.dart',
      ],
    );

    _initializeSdkSummary();
  }

  Future<void> _initializeSdkSummary() async {
    _log('Loading bundled summaries...');
    try {
      final sdkByteData = await rootBundle.load('assets/sdk_summary.sum');
      _log('Loaded SDK summary: ${sdkByteData.lengthInBytes} bytes');

      final pkgByteData = await rootBundle.load('assets/packages.sum');
      _log('Loaded package summary: ${pkgByteData.lengthInBytes} bytes');

      setState(() {
        _sdkSummaryBytes = sdkByteData.buffer.asUint8List();
        _packageSummaryBytes = pkgByteData.buffer.asUint8List();
        _isLoading = false;
        // Reset cached driver and package config when summaries are (re)loaded
        _cachedDriver = null;
        _packageUrisRegistered = false;
        _implicitImportsValidated = false;
        _packageTypeCompletions = null;
      });
      _log('Summaries ready in memory');
      // Run initial analysis now that summaries are loaded
      _analyzeCode();
    } catch (e) {
      _log('ERROR loading summaries: $e');
      setState(() {
        _analyzerError = 'Failed to load summaries: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  /// Get completions from the analyzer for package types and members.
  Future<List<CompletionItem>> _getAnalyzerCompletions(
    String code,
    int cursorOffset,
    String prefix,
  ) async {
    if (_sdkSummaryBytes == null) return [];

    final completions = <CompletionItem>[];

    // Get or create the cached driver
    _cachedDriver ??= _createAnalysisDriver();
    await _ensurePackageUrisRegistered(_cachedDriver!);

    // Lazy-load package type completions
    if (_packageTypeCompletions == null) {
      try {
        _packageTypeCompletions = await _extractPackageTypes(
          _cachedDriver!,
          _codeController.implicitImports,
        );
        _log(
          'Cached ${_packageTypeCompletions!.length} package type completions',
        );
      } catch (e) {
        // Reset driver so it retries fresh next time
        _log('ERROR extracting package types, resetting driver: $e');
        _cachedDriver = null;
        return completions;
      }
    }

    // Check if this is a member access (after a dot), with or without a typed
    // prefix.  Handles both:
    //   "name."       → cursor right after dot, prefix = ""
    //   "name.start"  → cursor after typed chars, prefix = "start"
    //   _showParameterHelp also calls with dotOffset+prefix="startsWith"
    final textBeforeCursor = code.substring(0, cursorOffset);
    final dotAccessMatch = RegExp(
      r'[a-zA-Z_][a-zA-Z0-9_]*\.([a-zA-Z_][a-zA-Z0-9_]*)?$',
    ).firstMatch(textBeforeCursor);
    final isDotCompletion = dotAccessMatch != null;

    // When it is a dot completion, derive the offset right after the dot so
    // that _getMemberCompletions always sees "identifier." without any prefix.
    final dotOffset = isDotCompletion
        ? cursorOffset - (dotAccessMatch.group(1)?.length ?? 0)
        : cursorOffset;

    if (isDotCompletion) {
      // Pass dotOffset (right after the dot, before any typed prefix) so
      // _getMemberCompletions correctly extracts the identifier before the dot.
      final memberCompletions = await _getMemberCompletions(
        code,
        dotOffset,
        prefix,
      );
      completions.addAll(memberCompletions);
    } else {
      // Add local variable completions first (they sort before globals).
      final localVars = _extractLocalCompletions(code, cursorOffset);
      for (final item in localVars) {
        if (prefix.isEmpty || item.label.startsWith(prefix)) {
          completions.add(item);
        }
      }

      // Add package/SDK completions with case-sensitive prefix filter.
      for (final item in _packageTypeCompletions!) {
        if (prefix.isEmpty || item.label.startsWith(prefix)) {
          completions.add(item);
        }
      }
    }

    return completions;
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

    _log(
      'Registering ${packageUris.length} package URI(s) from packages.sum',
    );

    for (final uri in packageUris) {
      try {
        await session.getLibraryByUri(uri);
      } catch (e) {
        _log('Could not register package URI $uri: $e');
      }
    }

    _packageUrisRegistered = true;
    _log('Package URI registration complete');
  }

  Future<void> _ensureImplicitImportsResolvable(
    AnalysisDriverWithPackages driver,
  ) async {
    if (_implicitImportsValidated) return;

    final session = driver.currentSession;
    for (final importUri in _codeController.implicitImports) {
      if (!importUri.startsWith('package:')) {
        continue;
      }

      try {
        final result = await session.getLibraryByUri(importUri);
        if (result is! results.LibraryElementResult) {
          _log(
            'Unresolved implicit import from bundled summaries: $importUri (${result.runtimeType})',
          );
        }
      } catch (e) {
        _log(
            'Unresolved implicit import from bundled summaries: $importUri ($e)');
      }
    }

    _implicitImportsValidated = true;
  }

  /// Extract public type names from SDK and package libraries.
  ///
  /// Package completions are loaded from all libraries present in the package
  /// summary bundle (`assets/packages.sum`) so additional bundled packages are
  /// discoverable even when they are not listed in [implicitImports].
  ///
  /// [implicitImports] are still loaded first to keep common packages
  /// (e.g. `package:dcli/dcli.dart`, `package:path/path.dart`) prioritized in
  /// the debug output and warm-up sequence.
  Future<List<CompletionItem>> _extractPackageTypes(
    AnalysisDriverWithPackages driver,
    List<String> implicitImports,
  ) async {
    final completions = <CompletionItem>[];
    final session = driver.currentSession;
    final seenNames = <String>{};

    // Process SDK libraries (dart:core, dart:async, etc.)
    for (final sdkUri in driver.sdkLibraryUris) {
      final uriStr = sdkUri.toString();
      try {
        final result = await session.getLibraryByUri(uriStr);
        // Use the full dart: URI as the package name (e.g., "dart:core")
        final packageName = uriStr;

        if (result is results.LibraryElementResult) {
          _extractLibraryElements(
            result.element,
            packageName,
            seenNames,
            completions,
          );
        }
      } catch (e) {
        _log('Could not load SDK library $uriStr: $e');
      }
    }

    // Process package libraries from both implicit imports and everything
    // available in the package summary bundle.
    final packageImports = <String>[];
    final seenPackageUris = <String>{};

    // 1) Add package URIs from implicit imports first.
    for (final uri in implicitImports) {
      if (uri.startsWith('package:') && seenPackageUris.add(uri)) {
        packageImports.add(uri);
      }
    }

    // 2) Add all package libraries from the summary bundle.
    for (final uri in driver.packageLibraryUris) {
      if (uri.startsWith('package:') && seenPackageUris.add(uri)) {
        packageImports.add(uri);
      }
    }

    _log(
      'Loading completions for ${packageImports.length} package import(s): $packageImports',
    );

    for (final uriStr in packageImports) {
      try {
        final uri = Uri.parse(uriStr);
        final result = await session.getLibraryByUri(uriStr);
        final packageName = uri.pathSegments.isNotEmpty
            ? 'package:${uri.pathSegments.first}'
            : uriStr;

        if (result is results.LibraryElementResult) {
          _extractLibraryElements(
            result.element,
            packageName,
            seenNames,
            completions,
          );
          _log('Loaded $uriStr — ${completions.length} completions so far');
        } else {
          _log(
            'getLibraryByUri($uriStr) returned ${result.runtimeType} — check summary bundle',
          );
        }
      } catch (e) {
        _log('Could not load library $uriStr: $e');
      }
    }

    return completions;
  }

  /// Extract elements from a library and add them to completions.
  void _extractLibraryElements(
    LibraryElement library,
    String packageName,
    Set<String> seenNames,
    List<CompletionItem> completions,
  ) {
    // In analyzer 10.x, LibraryElement has direct access to classes, enums, etc.

    // Get public classes
    for (final classElement in library.classes) {
      final name = classElement.name!;
      if (!classElement.isPrivate && !seenNames.contains(name)) {
        seenNames.add(name);
        completions.add(_buildClassCompletion(classElement, packageName));
      }
    }

    // Get public enums
    for (final enumElement in library.enums) {
      final name = enumElement.name!;
      if (!enumElement.isPrivate && !seenNames.contains(name)) {
        seenNames.add(name);
        completions.add(_buildEnumCompletion(enumElement, packageName));
      }
    }

    // Get public mixins
    for (final mixinElement in library.mixins) {
      final name = mixinElement.name!;
      if (!mixinElement.isPrivate && !seenNames.contains(name)) {
        seenNames.add(name);
        completions.add(_buildMixinCompletion(mixinElement, packageName));
      }
    }

    // Get public extensions
    for (final extElement in library.extensions) {
      final name = extElement.name;
      if (name != null && !extElement.isPrivate && !seenNames.contains(name)) {
        seenNames.add(name);
        completions.add(_buildExtensionCompletion(extElement, packageName));
      }
    }

    // Get public top-level functions
    for (final funcElement in library.topLevelFunctions) {
      final name = funcElement.name!;
      if (!funcElement.isPrivate && !seenNames.contains(name)) {
        seenNames.add(name);
        completions.add(_buildFunctionCompletion(funcElement, packageName));
      }
    }

    // Get public top-level getters
    for (final getter in library.getters) {
      final name = getter.name!;
      if (!getter.isPrivate && !seenNames.contains(name)) {
        seenNames.add(name);
        completions.add(_buildGetterCompletionTopLevel(getter, packageName));
      }
    }

    // Get public top-level variables
    for (final variable in library.topLevelVariables) {
      final name = variable.name!;
      if (!variable.isPrivate && !seenNames.contains(name)) {
        seenNames.add(name);
        completions.add(_buildVariableCompletion(variable, packageName));
      }
    }
  }

  /// Build a completion item for a class with full member information.
  /// Handles both concrete and abstract classes, including inherited members.
  CompletionItem _buildClassCompletion(
    InterfaceElement classElement,
    String packageName,
  ) {
    final members = <MemberInfo>[];
    final seenMembers = <String>{};

    // Debug logging for specific classes
    final isDebugClass =
        classElement.name == 'Map' || classElement.name == 'List';
    if (isDebugClass) {
      debugPrint('=== DEBUG ${classElement.name} ===');
      debugPrint('  Methods: ${classElement.methods.length}');
      debugPrint('  Getters: ${classElement.getters.length}');
      debugPrint('  Setters: ${classElement.setters.length}');
      debugPrint('  Fields: ${classElement.fields.length}');
      debugPrint('  Constructors: ${classElement.constructors.length}');
      debugPrint('  AllSupertypes: ${classElement.allSupertypes.length}');
      for (final m in classElement.methods) {
        debugPrint('    Method: ${m.name} (private: ${m.isPrivate})');
      }
      for (final a in classElement.getters) {
        debugPrint('    Getter: ${a.name} (private: ${a.isPrivate})');
      }
      for (final a in classElement.setters) {
        debugPrint('    Setter: ${a.name} (private: ${a.isPrivate})');
      }
      for (final st in classElement.allSupertypes) {
        debugPrint(
          '    Supertype: ${st.element.name} (methods: ${st.element.methods.length})',
        );
      }
    }

    // Add constructors (only for this class, not inherited)
    for (final constructor in classElement.constructors) {
      if (!constructor.isPrivate) {
        final constructorName = constructor.name;
        final name = (constructorName == null ||
                constructorName.isEmpty ||
                constructorName == 'new')
            ? classElement.name!
            : '${classElement.name!}.$constructorName';
        if (!seenMembers.contains(name)) {
          seenMembers.add(name);
          members.add(
            MemberInfo(
              name: name,
              signature: _buildConstructorSignature(
                constructor,
                classElement.name!,
              ),
              kind: CompletionKind.constructor,
            ),
          );
        }
      }
    }

    // Add all methods from this class
    for (final method in classElement.methods) {
      final methodName = method.name!;
      if (!method.isPrivate && !seenMembers.contains(methodName)) {
        seenMembers.add(methodName);
        members.add(
          MemberInfo(
            name: methodName,
            signature: _buildMethodSignature(method),
            kind: CompletionKind.method,
          ),
        );
      }
    }

    // Add getters from this class
    for (final accessor in classElement.getters) {
      final accessorName = accessor.name!;
      if (!accessor.isPrivate && !seenMembers.contains(accessorName)) {
        seenMembers.add(accessorName);
        members.add(
          MemberInfo(
            name: accessorName,
            signature: _buildGetterSignature(accessor),
            kind: CompletionKind.getter,
          ),
        );
      }
    }

    // Add setters from this class
    for (final accessor in classElement.setters) {
      if (!accessor.isPrivate) {
        final setterName = accessor.name!.replaceFirst('=', '');
        final setterKey = 'set:$setterName';
        if (!seenMembers.contains(setterKey)) {
          seenMembers.add(setterKey);
          members.add(
            MemberInfo(
              name: setterName,
              signature: _buildSetterSignature(accessor),
              kind: CompletionKind.setter,
            ),
          );
        }
      }
    }

    // Add fields from this class
    for (final field in classElement.fields) {
      final fieldName = field.name!;
      if (!field.isPrivate &&
          !field.isSynthetic &&
          !seenMembers.contains(fieldName)) {
        seenMembers.add(fieldName);
        members.add(
          MemberInfo(
            name: fieldName,
            signature: _buildFieldSignature(field),
            kind: field.isConst
                ? CompletionKind.constant
                : CompletionKind.property,
          ),
        );
      }
    }

    // Include members from ALL supertypes (interfaces, mixins, superclasses)
    // This is crucial for abstract classes like Map, List which define methods via interfaces
    for (final supertype in classElement.allSupertypes) {
      final superElement = supertype.element;

      // Add methods from supertype
      for (final method in superElement.methods) {
        final methodName = method.name!;
        if (!method.isPrivate && !seenMembers.contains(methodName)) {
          seenMembers.add(methodName);
          members.add(
            MemberInfo(
              name: methodName,
              signature: _buildMethodSignature(method),
              kind: CompletionKind.method,
            ),
          );
        }
      }

      // Add getters from supertype
      for (final accessor in superElement.getters) {
        final accessorName = accessor.name!;
        if (!accessor.isPrivate && !seenMembers.contains(accessorName)) {
          seenMembers.add(accessorName);
          members.add(
            MemberInfo(
              name: accessorName,
              signature: _buildGetterSignature(accessor),
              kind: CompletionKind.getter,
            ),
          );
        }
      }

      // Add setters from supertype
      for (final accessor in superElement.setters) {
        if (!accessor.isPrivate) {
          final setterName = accessor.name!.replaceFirst('=', '');
          final setterKey = 'set:$setterName';
          if (!seenMembers.contains(setterKey)) {
            seenMembers.add(setterKey);
            members.add(
              MemberInfo(
                name: setterName,
                signature: _buildSetterSignature(accessor),
                kind: CompletionKind.setter,
              ),
            );
          }
        }
      }
    }

    if (isDebugClass) {
      debugPrint('  Final members count: ${members.length}');
    }

    // Build signature with modifiers
    final modifiers = <String>[];
    if (classElement is ClassElement && classElement.isAbstract) {
      modifiers.add('abstract');
    }
    if (classElement is ClassElement && classElement.isSealed) {
      modifiers.add('sealed');
    }
    if (classElement is ClassElement && classElement.isFinal) {
      modifiers.add('final');
    }
    if (classElement is ClassElement && classElement.isInterface) {
      modifiers.add('interface');
    }

    final modifierStr = modifiers.isEmpty ? '' : '${modifiers.join(' ')} ';

    return CompletionItem(
      label: classElement.name!,
      kind: CompletionKind.className,
      detail: packageName,
      signature: '${modifierStr}class ${classElement.name!}',
      members: members,
      sortOrder: 10,
    );
  }

  /// Build a completion item for an enum with full member information.
  CompletionItem _buildEnumCompletion(
    EnumElement enumElement,
    String packageName,
  ) {
    final members = <MemberInfo>[];
    final seenMembers = <String>{};
    final enumName = enumElement.name!;

    // Add enum values first
    for (final value in enumElement.fields) {
      final valueName = value.name!;
      if (value.isEnumConstant && !seenMembers.contains(valueName)) {
        seenMembers.add(valueName);
        members.add(
          MemberInfo(
            name: valueName,
            signature: '$enumName.$valueName',
            kind: CompletionKind.enumValue,
          ),
        );
      }
    }

    // Add methods
    for (final method in enumElement.methods) {
      final methodName = method.name!;
      if (!method.isPrivate && !seenMembers.contains(methodName)) {
        seenMembers.add(methodName);
        members.add(
          MemberInfo(
            name: methodName,
            signature: _buildMethodSignature(method),
            kind: CompletionKind.method,
          ),
        );
      }
    }

    // Add getters
    for (final accessor in enumElement.getters) {
      final accessorName = accessor.name!;
      if (!accessor.isPrivate && !seenMembers.contains(accessorName)) {
        seenMembers.add(accessorName);
        members.add(
          MemberInfo(
            name: accessorName,
            signature: _buildGetterSignature(accessor),
            kind: CompletionKind.getter,
          ),
        );
      }
    }

    return CompletionItem(
      label: enumName,
      kind: CompletionKind.enumType,
      detail: packageName,
      signature: 'enum $enumName',
      members: members,
      sortOrder: 10,
    );
  }

  /// Build a completion item for a mixin with full member information.
  CompletionItem _buildMixinCompletion(
    MixinElement mixinElement,
    String packageName,
  ) {
    final members = <MemberInfo>[];
    final seenMembers = <String>{};
    final mixinName = mixinElement.name!;

    // Add methods
    for (final method in mixinElement.methods) {
      final methodName = method.name!;
      if (!method.isPrivate && !seenMembers.contains(methodName)) {
        seenMembers.add(methodName);
        members.add(
          MemberInfo(
            name: methodName,
            signature: _buildMethodSignature(method),
            kind: CompletionKind.method,
          ),
        );
      }
    }

    // Add getters
    for (final accessor in mixinElement.getters) {
      final accessorName = accessor.name!;
      if (!accessor.isPrivate && !seenMembers.contains(accessorName)) {
        seenMembers.add(accessorName);
        members.add(
          MemberInfo(
            name: accessorName,
            signature: _buildGetterSignature(accessor),
            kind: CompletionKind.getter,
          ),
        );
      }
    }

    // Add setters
    for (final accessor in mixinElement.setters) {
      if (!accessor.isPrivate) {
        final setterName = accessor.name!.replaceFirst('=', '');
        final setterKey = 'set:$setterName';
        if (!seenMembers.contains(setterKey)) {
          seenMembers.add(setterKey);
          members.add(
            MemberInfo(
              name: setterName,
              signature: _buildSetterSignature(accessor),
              kind: CompletionKind.setter,
            ),
          );
        }
      }
    }

    // Add fields
    for (final field in mixinElement.fields) {
      final fieldName = field.name!;
      if (!field.isPrivate &&
          !field.isSynthetic &&
          !seenMembers.contains(fieldName)) {
        seenMembers.add(fieldName);
        members.add(
          MemberInfo(
            name: fieldName,
            signature: _buildFieldSignature(field),
            kind: field.isConst
                ? CompletionKind.constant
                : CompletionKind.property,
          ),
        );
      }
    }

    return CompletionItem(
      label: mixinName,
      kind: CompletionKind.mixin,
      detail: packageName,
      signature: 'mixin $mixinName',
      members: members,
      sortOrder: 10,
    );
  }

  /// Build a completion item for an extension with full member information.
  CompletionItem _buildExtensionCompletion(
    ExtensionElement extElement,
    String packageName,
  ) {
    final members = <MemberInfo>[];
    final seenMembers = <String>{};
    final extensionName = extElement.name ?? 'extension';

    // Add methods
    for (final method in extElement.methods) {
      final methodName = method.name!;
      if (!method.isPrivate && !seenMembers.contains(methodName)) {
        seenMembers.add(methodName);
        members.add(
          MemberInfo(
            name: methodName,
            signature: _buildMethodSignature(method),
            kind: CompletionKind.method,
          ),
        );
      }
    }

    // Add getters
    for (final accessor in extElement.getters) {
      final accessorName = accessor.name!;
      if (!accessor.isPrivate && !seenMembers.contains(accessorName)) {
        seenMembers.add(accessorName);
        members.add(
          MemberInfo(
            name: accessorName,
            signature: _buildGetterSignature(accessor),
            kind: CompletionKind.getter,
          ),
        );
      }
    }

    // Add setters
    for (final accessor in extElement.setters) {
      if (!accessor.isPrivate) {
        final setterName = accessor.name!.replaceFirst('=', '');
        final setterKey = 'set:$setterName';
        if (!seenMembers.contains(setterKey)) {
          seenMembers.add(setterKey);
          members.add(
            MemberInfo(
              name: setterName,
              signature: _buildSetterSignature(accessor),
              kind: CompletionKind.setter,
            ),
          );
        }
      }
    }

    // Add fields
    for (final field in extElement.fields) {
      final fieldName = field.name!;
      if (!field.isPrivate &&
          !field.isSynthetic &&
          !seenMembers.contains(fieldName)) {
        seenMembers.add(fieldName);
        members.add(
          MemberInfo(
            name: fieldName,
            signature: _buildFieldSignature(field),
            kind: field.isConst
                ? CompletionKind.constant
                : CompletionKind.property,
          ),
        );
      }
    }

    final extendedType = extElement.extendedType.getDisplayString();
    return CompletionItem(
      label: extensionName,
      kind: CompletionKind.extension,
      detail: packageName,
      signature: 'extension $extensionName on $extendedType',
      members: members,
      sortOrder: 10,
    );
  }

  /// Build a completion item for a top-level function.
  CompletionItem _buildFunctionCompletion(
    TopLevelFunctionElement funcElement,
    String packageName,
  ) {
    return CompletionItem(
      label: funcElement.name!,
      kind: CompletionKind.function,
      detail: packageName,
      signature: _buildFunctionSignature(funcElement),
      sortOrder: 15,
    );
  }

  /// Build a completion item for a top-level getter.
  CompletionItem _buildGetterCompletionTopLevel(
    GetterElement getter,
    String packageName,
  ) {
    return CompletionItem(
      label: getter.name!,
      kind: CompletionKind.getter,
      detail: packageName,
      signature: _buildGetterSignature(getter),
      sortOrder: 20,
    );
  }

  /// Build a completion item for a top-level variable.
  CompletionItem _buildVariableCompletion(
    TopLevelVariableElement variable,
    String packageName,
  ) {
    return CompletionItem(
      label: variable.name!,
      kind:
          variable.isConst ? CompletionKind.constant : CompletionKind.variable,
      detail: packageName,
      signature: _buildTopLevelVariableSignature(variable),
      sortOrder: 20,
    );
  }

  /// Build function signature string.
  String _buildFunctionSignature(TopLevelFunctionElement func) {
    final returnType = func.returnType.getDisplayString();
    final params = _buildParameterList(func.formalParameters);
    return '$returnType ${func.name}($params)';
  }

  /// Build method signature string.
  String _buildMethodSignature(MethodElement method) {
    final modifiers = <String>[];
    if (method.isStatic) modifiers.add('static');
    if (method.isAbstract) modifiers.add('abstract');

    final returnType = method.returnType.getDisplayString();
    final params = _buildParameterList(method.formalParameters);

    final modifierStr = modifiers.isNotEmpty ? '${modifiers.join(' ')} ' : '';
    return '$modifierStr$returnType ${method.name}($params)';
  }

  /// Build constructor signature string.
  String _buildConstructorSignature(
    ConstructorElement constructor,
    String className,
  ) {
    final modifiers = <String>[];
    if (constructor.isConst) modifiers.add('const');
    if (constructor.isFactory) modifiers.add('factory');

    final params = _buildParameterList(constructor.formalParameters);
    final constructorName = constructor.name;
    final name = (constructorName == null ||
            constructorName.isEmpty ||
            constructorName == 'new')
        ? className
        : '$className.$constructorName';

    final modifierStr = modifiers.isNotEmpty ? '${modifiers.join(' ')} ' : '';
    return '$modifierStr$name($params)';
  }

  /// Build getter signature string.
  String _buildGetterSignature(PropertyAccessorElement getter) {
    final modifiers = <String>[];
    if (getter.isStatic) modifiers.add('static');
    if (getter.isAbstract) modifiers.add('abstract');

    final returnType = getter.returnType.getDisplayString();

    final modifierStr = modifiers.isNotEmpty ? '${modifiers.join(' ')} ' : '';
    return '$modifierStr$returnType get ${getter.name}';
  }

  /// Build setter signature string.
  String _buildSetterSignature(PropertyAccessorElement setter) {
    final modifiers = <String>[];
    if (setter.isStatic) modifiers.add('static');
    if (setter.isAbstract) modifiers.add('abstract');

    final params = _buildParameterList(setter.formalParameters);
    final name = setter.name!.replaceFirst('=', '');

    final modifierStr = modifiers.isNotEmpty ? '${modifiers.join(' ')} ' : '';
    return '${modifierStr}set $name($params)';
  }

  /// Build field signature string.
  String _buildFieldSignature(FieldElement field) {
    final modifiers = <String>[];
    if (field.isStatic) modifiers.add('static');
    if (field.isConst) modifiers.add('const');
    if (field.isFinal) modifiers.add('final');
    if (field.isLate) modifiers.add('late');

    final type = field.type.getDisplayString();

    final modifierStr = modifiers.isNotEmpty ? '${modifiers.join(' ')} ' : '';
    return '$modifierStr$type ${field.name}';
  }

  /// Build top-level variable signature string.
  String _buildTopLevelVariableSignature(TopLevelVariableElement variable) {
    final modifiers = <String>[];
    if (variable.isConst) modifiers.add('const');
    if (variable.isFinal) modifiers.add('final');
    if (variable.isLate) modifiers.add('late');

    final type = variable.type.getDisplayString();

    final modifierStr = modifiers.isNotEmpty ? '${modifiers.join(' ')} ' : '';
    return '$modifierStr$type ${variable.name}';
  }

  /// Build parameter list string.
  String _buildParameterList(List<FormalParameterElement> params) {
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
    if (positionalRequired.isNotEmpty) {
      parts.add(positionalRequired.join(', '));
    }
    if (positionalOptional.isNotEmpty) {
      parts.add('[${positionalOptional.join(', ')}]');
    }
    if (named.isNotEmpty) {
      parts.add('{${named.join(', ')}}');
    }

    return parts.join(', ');
  }

  /// Extract local variable/parameter completions from the code before [cursorOffset].
  ///
  /// Scans for typed declarations (`String name`, `int count`) and
  /// keyword-declared variables (`var x`, `final result`, `const k`) and
  /// returns completion items with `sortOrder: -1` so they appear before
  /// globals in the popup.
  List<CompletionItem> _extractLocalCompletions(String code, int cursorOffset) {
    final completions = <CompletionItem>[];
    final seenNames = <String>{};

    // Only look at code before the cursor.
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

    // Pattern 1: UppercaseType varName (covers String, List<T>, Map<K,V>?, etc.)
    // Variable name must start with lowercase to avoid matching class declarations.
    final typedPattern = RegExp(
      r'\b([A-Z][a-zA-Z0-9_]*)(?:<[^;={]*>)?[?]?\s+([a-z_][a-zA-Z0-9_]*)\s*(?=[=;,]|\s+in\b)',
    );
    for (final m in typedPattern.allMatches(searchCode)) {
      addVar(m.group(2)!, m.group(1)!);
    }

    // Pattern 2: Primitive lowercase type keywords (int, double, bool, num, dynamic)
    final primitivePattern = RegExp(
      r'\b(int|double|bool|num|dynamic)\s+([a-z_][a-zA-Z0-9_]*)\s*(?=[=;,]|\s+in\b|\s*\))',
    );
    for (final m in primitivePattern.allMatches(searchCode)) {
      addVar(m.group(2)!, m.group(1)!);
    }

    // Pattern 3: var / final / const declarations (optionally with a type annotation)
    final kwDeclPattern = RegExp(
      r'\b(?:var|final|const|late)\s+(?:(?:[A-Za-z][a-zA-Z0-9_]*)(?:<[^;={]*>)?[?]?\s+)?([a-z_][a-zA-Z0-9_]*)\s*[=;]',
    );
    for (final m in kwDeclPattern.allMatches(searchCode)) {
      addVar(m.group(1)!, '');
    }

    return completions;
  }

  /// Returns true if [name] is a Dart reserved word or built-in identifier
  /// that should not be treated as a variable name.
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

  /// Get member completions for a dot-access expression.
  /// NOTE: Currently only works for type names (e.g., List., String.),
  /// not for variable instances (e.g., myList.) which would require full type inference.
  Future<List<CompletionItem>> _getMemberCompletions(
    String code,
    int cursorOffset,
    String prefix,
  ) async {
    final completions = <CompletionItem>[];

    // Find the expression before the dot
    final textBeforeCursor = code.substring(0, cursorOffset);
    final trimmed = textBeforeCursor.trimRight();

    // Must end with a dot
    if (!trimmed.endsWith('.')) return completions;

    // Extract the identifier before the dot
    final beforeDot = trimmed.substring(0, trimmed.length - 1).trimRight();
    final identifierMatch = RegExp(
      r'([a-zA-Z_][a-zA-Z0-9_]*)$',
    ).firstMatch(beforeDot);

    if (identifierMatch == null) return completions;

    final identifier = identifierMatch.group(1)!;
    _log('Looking up members for: $identifier');

    // Look up the identifier as a type name in our cached completions
    final typeCompletion = _packageTypeCompletions?.firstWhere(
      (item) => item.label == identifier,
      orElse: () =>
          const CompletionItem(label: '', kind: CompletionKind.className),
    );

    if (typeCompletion != null &&
        typeCompletion.label.isNotEmpty &&
        typeCompletion.members != null) {
      // Found a type with members - convert members to completion items
      for (final member in typeCompletion.members!) {
        // Filter by prefix if provided
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
      _log(
        'Found ${completions.length} member completions for type $identifier',
      );
    } else {
      // Identifier is not a known type name – try to infer its type from
      // variable / parameter declarations in the source code.
      // Pass the cursor offset so we only search in the code before the dot
      // and take the *last* (closest) declaration of this identifier.
      final inferredTypeName = _inferTypeFromCode(
        code,
        identifier,
        cursorOffset,
      );
      _log('Inferred type for "$identifier": $inferredTypeName');

      if (inferredTypeName != null) {
        final inferredTypeCompletion = _packageTypeCompletions?.firstWhere(
          (item) => item.label == inferredTypeName,
          orElse: () =>
              const CompletionItem(label: '', kind: CompletionKind.className),
        );

        if (inferredTypeCompletion != null &&
            inferredTypeCompletion.label.isNotEmpty &&
            inferredTypeCompletion.members != null) {
          for (final member in inferredTypeCompletion.members!) {
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
          _log(
            'Found ${completions.length} member completions via inferred type $inferredTypeName',
          );
        } else {
          _log(
            'Inferred type "$inferredTypeName" not found in package type completions',
          );
        }
      } else {
        _log(
          'No type found for "$identifier" – variable type inference not supported yet',
        );
      }
    }

    return completions;
  }

  /// Infers the declared type of [identifier] from the source [code] by looking
  /// for variable/parameter declarations of the form `TypeName identifier`.
  /// Only searches the code up to [cursorOffset] and returns the LAST (closest
  /// to the cursor) declaration, so the correct type is used when multiple
  /// variables share a name in different scopes.
  /// Returns the base type name (e.g. `String` for `String? name`), or null.
  String? _inferTypeFromCode(String code, String identifier, int cursorOffset) {
    // Only search the portion of code BEFORE the cursor (before the dot).
    final searchCode = code.substring(0, cursorOffset);
    // Match: TypeName identifier  (optionally nullable, optionally generic)
    // Covers: String name, List<String> items, Map<K,V>? data, etc.
    final pattern = RegExp(
      r'\b([A-Z][a-zA-Z0-9_]*)(?:<[^>]*>)?\??\s+' +
          RegExp.escape(identifier) +
          r'\b',
    );
    // Take all matches and use the LAST one (closest to the cursor).
    final matches = pattern.allMatches(searchCode);
    if (matches.isEmpty) return null;
    return matches.last.group(1);
  }

  /// Get sort order for a completion kind - constructors first, then methods, etc.
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

  void _onCodeChanged(String code) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    // Start new debounce timer
    _debounceTimer = Timer(_debounceDuration, () {
      if (_sdkSummaryBytes != null && !_isAnalyzing) {
        _analyzeCode();
      }
    });
  }

  void _log(String message) {
    debugPrint('[AnalyzerApp] $message');
    setState(() {
      _debugLog.add(
        '[${DateTime.now().toString().substring(11, 19)}] $message',
      );
      if (_debugLog.length > 50) {
        _debugLog.removeAt(0);
      }
    });
  }

  Future<Directory> _createAnalysisTempDirectory() async {
    return Directory.systemTemp.createTemp('dart_analyzer_');
  }

  Future<void> _analyzeCode() async {
    if (_sdkSummaryBytes == null) {
      _log('ERROR: SDK summary not loaded');
      return;
    }

    _log('Starting analysis...');
    setState(() {
      _isAnalyzing = true;
      _errors = [];
      _analyzerError = null;
    });

    Directory? tempDir;
    try {
      _log('Creating temp directory...');
      tempDir = await _createAnalysisTempDirectory();
      final tempFile = File(path.join(tempDir.path, 'analysis_target.dart'));

      _cachedDriver ??= _createAnalysisDriver();
      await _ensurePackageUrisRegistered(_cachedDriver!);
      await _ensureImplicitImportsResolvable(_cachedDriver!);
      final driver = _cachedDriver!;
      _log('Running analysis with shared cached driver');

      // Get the FULL code with implicit imports prepended
      final fullCode = _codeController.fullCode;
      final lineOffset = _codeController.lineOffset;
      _log('Analyzing ${fullCode.length} chars (line offset: $lineOffset)');
      _log('Implicit imports: ${_codeController.implicitImports}');

      await tempFile.writeAsString(fullCode);

      driver.changeFile(tempFile.path);
      await driver.applyPendingFileChanges();

      final session = driver.currentSession;

      results.SomeErrorsResult errorsResult;
      try {
        errorsResult = await session.getErrors(tempFile.path);
      } catch (e) {
        setState(() {
          _analyzerError = 'Analysis failed: $e';
        });
        await tempDir.delete(recursive: true);
        return;
      }

      if (errorsResult is ErrorsResult) {
        final lineInfo = errorsResult.lineInfo;
        final errorsList = errorsResult.diagnostics;
        _log('Got ${errorsList.length} errors from analyzer');

        setState(() {
          _errors = errorsList
              .map((error) {
                final location = lineInfo.getLocation(error.offset);
                // Adjust line number to account for implicit imports
                final adjustedLine = _codeController.adjustLineNumber(
                  location.lineNumber,
                );

                _log(
                  '${error.severity.name.toUpperCase()}: ${error.diagnosticCode.name} at line $adjustedLine',
                );

                // Skip errors in the implicit import section
                if (adjustedLine < 1) {
                  return null;
                }

                // Skip unused import warnings
                if (error.diagnosticCode.name.contains('UNUSED_IMPORT')) {
                  return null;
                }

                // Skip URI_DOES_NOT_EXIST for implicit imports –
                // they are resolved via the package summary, not the file system.
                if (error.diagnosticCode.name == 'URI_DOES_NOT_EXIST') {
                  final isImplicitImport = _codeController.implicitImports.any(
                    (imp) => error.message.contains(imp),
                  );
                  if (isImplicitImport) return null;
                }

                return CodeError(
                  message: error.message,
                  line: adjustedLine,
                  column: location.columnNumber,
                  offset: error.offset,
                  length: error.length,
                  severity: error.severity.name,
                  code: error.diagnosticCode.name,
                );
              })
              .whereType<CodeError>()
              .toList();
        });
        _log('${_errors.length} errors after line adjustment');
      } else {
        _log('ERROR: Unexpected result type: ${errorsResult.runtimeType}');
        setState(() {
          _analyzerError = 'Unexpected result: ${errorsResult.runtimeType}';
        });
      }

      await tempDir.delete(recursive: true);
      tempDir = null;
      _log('Analysis complete');
    } catch (e, stack) {
      _log('ERROR: $e');
      setState(() {
        _analyzerError = 'Analysis failed: $e\n\nStack trace:\n$stack';
      });
      if (tempDir != null) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _showErrorDetails(CodeError error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              error.isError ? Icons.error : Icons.warning,
              color: error.isError ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(error.code),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.message),
            const SizedBox(height: 8),
            Text(
              'Line ${error.line}, Column ${error.column}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart Code Analyzer (Standalone)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Show implicit imports info
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: 'Implicit imports',
            onPressed: () => _showImportsDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading SDK summary...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status bar
                  _buildStatusBar(),
                  const SizedBox(height: 16),

                  // Code editor
                  Expanded(
                    flex: 2,
                    child: DartCodeEditor(
                      controller: _codeController,
                      errors: _errors,
                      onChanged: _onCodeChanged,
                      onErrorTap: _showErrorDetails,
                      onCompletionRequest: _getAnalyzerCompletions,
                      // Pink border marks the boundary of the reusable component.
                      theme: DartEditorTheme.dark().copyWith(
                        editor: const EditorColors.dark().copyWith(
                          border: Colors.pinkAccent,
                          borderWidth: 2.5,
                        ),
                      ),
                      placeholder:
                          'Enter Dart code...\n\nImplicit imports are included automatically.\nHover over errors to see details.',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Analyze button
                  ElevatedButton.icon(
                    onPressed: (_isAnalyzing || _sdkSummaryBytes == null)
                        ? null
                        : _analyzeCode,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Code'),
                  ),
                  const SizedBox(height: 16),

                  // Results area with tabs
                  Expanded(
                    flex: 2,
                    child: DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          TabBar(
                            tabs: [
                              Tab(text: 'Errors (${_errors.length})'),
                              const Tab(text: 'Full Code'),
                              Tab(text: 'Debug (${_debugLog.length})'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildErrorsTab(),
                                _buildFullCodeTab(),
                                _buildDebugLogTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _sdkSummaryBytes != null
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _sdkSummaryBytes != null ? Icons.check_circle : Icons.error,
            color: _sdkSummaryBytes != null ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _sdkSummaryBytes != null
                ? 'SDK summary loaded • ${_codeController.implicitImports.length} implicit imports'
                : 'SDK summary failed to load',
            style: TextStyle(
              color: _sdkSummaryBytes != null ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showImportsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Implicit Imports'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The following imports are automatically included:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            for (final import in _codeController.implicitImports)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_right, size: 16),
                    Text(
                      import,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Line offset: ${_codeController.lineOffset}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorsTab() {
    if (_analyzerError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            _analyzerError!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_errors.isEmpty) {
      return Center(
        child: Text(
          _isAnalyzing
              ? 'Analyzing...'
              : 'No errors found (or not yet analyzed)',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      itemCount: _errors.length,
      itemBuilder: (context, index) {
        final error = _errors[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(
              error.isError
                  ? Icons.error
                  : error.isWarning
                      ? Icons.warning
                      : Icons.info,
              color: error.isError
                  ? Colors.red
                  : error.isWarning
                      ? Colors.orange
                      : Colors.blue,
            ),
            title: Text(error.message),
            subtitle: Text(
              'Line ${error.line}, Column ${error.column} • ${error.code}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            onTap: () => _showErrorDetails(error),
          ),
        );
      },
    );
  }

  Widget _buildFullCodeTab() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '// Full code sent to analyzer (with implicit imports):',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _codeController.fullCode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugLogTab() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _debugLog.length,
        itemBuilder: (context, index) {
          final log = _debugLog[index];
          final isError = log.contains('ERROR');
          return Text(
            log,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: isError ? Colors.red : Colors.greenAccent,
            ),
          );
        },
      ),
    );
  }
}
