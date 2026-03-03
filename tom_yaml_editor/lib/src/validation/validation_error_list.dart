import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../yaml_editor_theme.dart';

/// The position of the error list relative to the editor.
enum ErrorListPosition {
  /// Error list appears below the editor.
  bottom,

  /// Error list appears to the side of the editor.
  side,
}

/// A scrollable list of all validation errors with severity icons,
/// path breadcrumbs, and messages. Clicking an error navigates to the
/// corresponding node in the tree.
///
/// ```dart
/// ValidationErrorList(
///   errors: controller.errors,
///   onErrorTap: (error) => navigateToError(error),
///   theme: YamlEditorTheme.dark(),
/// )
/// ```
class ValidationErrorList extends StatelessWidget {
  /// The validation errors to display.
  final List<ValidationError> errors;

  /// Callback when an error is tapped (for click-to-navigate).
  final ValueChanged<ValidationError>? onErrorTap;

  /// Theme for styling.
  final YamlEditorTheme theme;

  /// Whether to sort errors by severity (errors first, then warnings).
  final bool sortBySeverity;

  const ValidationErrorList({
    super.key,
    required this.errors,
    this.onErrorTap,
    this.theme = const YamlEditorTheme(),
    this.sortBySeverity = true,
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) {
      return _buildEmptyState();
    }

    var displayErrors = sortBySeverity ? _sortedErrors() : errors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: displayErrors.length,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemBuilder: (context, index) {
              return _ValidationErrorRow(
                error: displayErrors[index],
                onTap: onErrorTap != null
                    ? () => onErrorTap!(displayErrors[index])
                    : null,
                theme: theme,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: theme.structureColors.addButton,
            ),
            const SizedBox(width: 8),
            Text(
              'No validation errors',
              style: TextStyle(
                color: theme.colors.hintColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    var errorCount =
        errors.where((e) => e.severity == ValidationSeverity.error).length;
    var warningCount =
        errors.where((e) => e.severity == ValidationSeverity.warning).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colors.separatorColor.withAlpha(80),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Problems',
            style: TextStyle(
              color: theme.colors.keyColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          if (errorCount > 0) ...[
            Icon(Icons.error, size: 12, color: theme.colors.errorColor),
            const SizedBox(width: 2),
            Text(
              '$errorCount',
              style: TextStyle(
                color: theme.colors.errorColor,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (warningCount > 0) ...[
            Icon(Icons.warning, size: 12, color: theme.colors.warningColor),
            const SizedBox(width: 2),
            Text(
              '$warningCount',
              style: TextStyle(
                color: theme.colors.warningColor,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<ValidationError> _sortedErrors() {
    return [...errors]..sort((a, b) {
        // Errors before warnings
        if (a.severity == ValidationSeverity.error &&
            b.severity != ValidationSeverity.error) {
          return -1;
        }
        if (a.severity != ValidationSeverity.error &&
            b.severity == ValidationSeverity.error) {
          return 1;
        }
        // Then by path depth
        return a.path.length.compareTo(b.path.length);
      });
  }
}

/// A single row in the validation error list.
class _ValidationErrorRow extends StatefulWidget {
  final ValidationError error;
  final VoidCallback? onTap;
  final YamlEditorTheme theme;

  const _ValidationErrorRow({
    required this.error,
    this.onTap,
    required this.theme,
  });

  @override
  State<_ValidationErrorRow> createState() => _ValidationErrorRowState();
}

class _ValidationErrorRowState extends State<_ValidationErrorRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    var isError = widget.error.severity == ValidationSeverity.error;
    var severityColor = isError
        ? widget.theme.colors.errorColor
        : widget.theme.colors.warningColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color:
              _isHovered ? widget.theme.colors.hoverColor : Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Severity icon
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  isError ? Icons.error : Icons.warning,
                  size: 14,
                  color: severityColor,
                ),
              ),
              const SizedBox(width: 8),

              // Path breadcrumb + message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Path breadcrumb
                    if (widget.error.path.isNotEmpty) _buildPathBreadcrumb(),

                    // Error message
                    Text(
                      widget.error.message,
                      style: TextStyle(
                        color: widget.theme.colors.valueColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPathBreadcrumb() {
    var segments = widget.error.path.map((p) => p.toString()).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    '›',
                    style: TextStyle(
                      color: widget.theme.colors.hintColor,
                      fontSize: 10,
                    ),
                  ),
                ),
              Text(
                segments[i],
                style: TextStyle(
                  fontFamily: widget.theme.fonts.keyFontFamily,
                  fontSize: 10,
                  color: widget.theme.colors.hintColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
