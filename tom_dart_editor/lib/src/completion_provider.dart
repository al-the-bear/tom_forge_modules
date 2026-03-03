import 'package:flutter/material.dart';

/// Types of completion items.
enum CompletionKind {
  keyword,
  className,
  enumType,
  mixin,
  extension,
  function,
  method,
  variable,
  parameter,
  property,
  constant,
  snippet,
  getter,
  setter,
  constructor,
  enumValue,
  typeAlias,
}

/// Represents a member of a class/enum/mixin/extension.
class MemberInfo {
  final String name;
  final String signature;
  final CompletionKind kind;
  final String? documentation;

  const MemberInfo({
    required this.name,
    required this.signature,
    required this.kind,
    this.documentation,
  });
}

/// A completion item for code completion.
class CompletionItem {
  final String label;
  final String insertText;
  final CompletionKind kind;
  final String? detail;
  final String? documentation;
  final int? sortOrder;

  /// Full signature for functions/methods/variables (e.g., "Future<void> myMethod(String name, int count)")
  final String? signature;

  /// Members for classes/enums/mixins/extensions
  final List<MemberInfo>? members;

  const CompletionItem({
    required this.label,
    String? insertText,
    required this.kind,
    this.detail,
    this.documentation,
    this.sortOrder,
    this.signature,
    this.members,
  }) : insertText = insertText ?? label;

  /// Whether this item is a composite type (class, enum, mixin, extension).
  bool get isCompositeType =>
      kind == CompletionKind.className ||
      kind == CompletionKind.enumType ||
      kind == CompletionKind.mixin ||
      kind == CompletionKind.extension;

  /// Icon for this completion kind.
  IconData get icon => switch (kind) {
    CompletionKind.keyword => Icons.code,
    CompletionKind.className => Icons.class_,
    CompletionKind.enumType => Icons.list_alt,
    CompletionKind.mixin => Icons.merge_type,
    CompletionKind.extension => Icons.extension,
    CompletionKind.function => Icons.functions,
    CompletionKind.method => Icons.functions_outlined,
    CompletionKind.variable => Icons.abc,
    CompletionKind.parameter => Icons.input,
    CompletionKind.property => Icons.account_tree,
    CompletionKind.constant => Icons.lock,
    CompletionKind.snippet => Icons.snippet_folder,
    CompletionKind.getter => Icons.output,
    CompletionKind.setter => Icons.input,
    CompletionKind.constructor => Icons.add_box,
    CompletionKind.enumValue => Icons.tag,
    CompletionKind.typeAlias => Icons.text_fields,
  };

  /// Color for this completion kind.
  Color colorFor(bool isDark) => switch (kind) {
    CompletionKind.keyword =>
      isDark ? const Color(0xFFC586C0) : const Color(0xFFAF00DB),
    CompletionKind.className ||
    CompletionKind.enumType ||
    CompletionKind.mixin ||
    CompletionKind.extension ||
    CompletionKind.typeAlias =>
      isDark ? const Color(0xFF4EC9B0) : const Color(0xFF267F99),
    CompletionKind.function ||
    CompletionKind.method ||
    CompletionKind.constructor =>
      isDark ? const Color(0xFFDCDCAA) : const Color(0xFF795E26),
    CompletionKind.variable ||
    CompletionKind.parameter ||
    CompletionKind.property =>
      isDark ? const Color(0xFF9CDCFE) : const Color(0xFF001080),
    CompletionKind.constant || CompletionKind.enumValue =>
      isDark ? const Color(0xFF4FC1FF) : const Color(0xFF0070C1),
    CompletionKind.snippet =>
      isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515),
    CompletionKind.getter =>
      isDark ? const Color(0xFF9CDCFE) : const Color(0xFF001080),
    CompletionKind.setter =>
      isDark ? const Color(0xFF9CDCFE) : const Color(0xFF001080),
  };
}
