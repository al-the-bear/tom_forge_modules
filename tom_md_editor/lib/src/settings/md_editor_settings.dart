import '../constants/md_constants.dart';

/// Position of the raw text editor relative to the preview.
enum RawEditorPosition { below, right }

/// All configurable settings for the markdown editor.
class MdEditorSettings {
  const MdEditorSettings({
    // Layout
    this.showTree = true,
    this.showToolbar = false,
    this.showStatusBar = true,
    this.showSearchBox = true,
    // Raw editor
    this.rawEditorPosition = RawEditorPosition.below,
    this.allowEditorPositionChange = true,
    this.autoHideEditor = true,
    this.livePreview = true,
    this.livePreviewDebounceMs = MdConstants.defaultLivePreviewDebounceMs,
    // Separators
    this.draggableSeparators = true,
    this.persistSeparatorPositions = false,
    this.treePanelWidthRatio = MdConstants.defaultTreePanelRatio,
    this.rawEditorHeightRatio = MdConstants.defaultRawEditorHeightRatio,
    this.rawEditorWidthRatio = MdConstants.defaultRawEditorWidthRatio,
    this.searchResultsHeightRatio = MdConstants.defaultSearchResultsHeightRatio,
    // Main panel
    this.showLineNumbers = false,
    this.showSectionBorders = true,
    this.highlightCurrentSection = true,
    this.enableSmoothScrolling = true,
    // Tree
    this.expandAllByDefault = true,
    this.showValidationMarkers = true,
    this.enableDragAndDrop = true,
    this.showSectionIcons = false,
    // Search
    this.enableSearch = true,
    this.enableReplace = true,
    this.enableRegexSearch = false,
    // Markdown features
    this.enableMermaid = true,
    this.enableMath = true,
    this.enableFootnotes = true,
    this.enableTaskLists = true,
    this.enableInteractiveTaskLists = true,
    this.enableTables = true,
    this.enableSyntaxHighlighting = true,
    // Code blocks
    this.showCodeBlockLanguage = true,
    this.showCopyCodeButton = true,
    this.showCodeEditButton = true,
    this.enableCodeEditing = true,
    // Tables
    this.showTableEditButton = true,
    this.enableTableEditing = true,
    // Schema
    this.enableSchemaValidation = false,
    this.showSchemaErrors = true,
    this.enableAutoScaffold = false,
    this.showSchemaInfoPanel = false,
    this.enableFormEditor = true,
    this.enableTagSelector = true,
    this.showCharCounter = true,
    this.enableQuickFixes = true,
    this.showValidationPrompts = true,
    this.showSectionTypeTooltips = true,
    this.enablePositionAwareDragDrop = true,
    // Behavior
    this.readOnly = false,
    this.enableUndo = true,
    this.maxUndoHistory = MdConstants.defaultMaxUndoHistory,
    this.confirmDelete = true,
    this.autoSave = false,
    this.autoSaveDebounceMs = MdConstants.defaultAutoSaveDebounceMs,
  });

  /// Standard settings for most use cases.
  factory MdEditorSettings.standard() => const MdEditorSettings();

  /// Minimal read-only viewer settings.
  factory MdEditorSettings.viewer() => const MdEditorSettings(
    showTree: false,
    showToolbar: false,
    showStatusBar: false,
    showSearchBox: false,
    readOnly: true,
    autoHideEditor: true,
  );

  // ── Layout ──
  final bool showTree;
  final bool showToolbar;
  final bool showStatusBar;
  final bool showSearchBox;

  // ── Raw editor ──
  final RawEditorPosition rawEditorPosition;
  final bool allowEditorPositionChange;
  final bool autoHideEditor;
  final bool livePreview;
  final int livePreviewDebounceMs;

  // ── Separators ──
  final bool draggableSeparators;
  final bool persistSeparatorPositions;
  final double treePanelWidthRatio;
  final double rawEditorHeightRatio;
  final double rawEditorWidthRatio;
  final double searchResultsHeightRatio;

  // ── Main panel ──
  final bool showLineNumbers;
  final bool showSectionBorders;
  final bool highlightCurrentSection;
  final bool enableSmoothScrolling;

  // ── Tree ──
  final bool expandAllByDefault;
  final bool showValidationMarkers;
  final bool enableDragAndDrop;
  final bool showSectionIcons;

  // ── Search ──
  final bool enableSearch;
  final bool enableReplace;
  final bool enableRegexSearch;

  // ── Markdown features ──
  final bool enableMermaid;
  final bool enableMath;
  final bool enableFootnotes;
  final bool enableTaskLists;
  final bool enableInteractiveTaskLists;
  final bool enableTables;
  final bool enableSyntaxHighlighting;

  // ── Code blocks ──
  final bool showCodeBlockLanguage;
  final bool showCopyCodeButton;
  final bool showCodeEditButton;
  final bool enableCodeEditing;

  // ── Tables ──
  final bool showTableEditButton;
  final bool enableTableEditing;

  // ── Schema ──
  final bool enableSchemaValidation;
  final bool showSchemaErrors;
  final bool enableAutoScaffold;
  final bool showSchemaInfoPanel;
  final bool enableFormEditor;
  final bool enableTagSelector;
  final bool showCharCounter;
  final bool enableQuickFixes;
  final bool showValidationPrompts;
  final bool showSectionTypeTooltips;
  final bool enablePositionAwareDragDrop;

  // ── Behavior ──
  final bool readOnly;
  final bool enableUndo;
  final int maxUndoHistory;
  final bool confirmDelete;
  final bool autoSave;
  final int autoSaveDebounceMs;

  MdEditorSettings copyWith({
    // Layout
    bool? showTree,
    bool? showToolbar,
    bool? showStatusBar,
    bool? showSearchBox,
    // Raw editor
    RawEditorPosition? rawEditorPosition,
    bool? allowEditorPositionChange,
    bool? autoHideEditor,
    bool? livePreview,
    int? livePreviewDebounceMs,
    // Separators
    bool? draggableSeparators,
    bool? persistSeparatorPositions,
    double? treePanelWidthRatio,
    double? rawEditorHeightRatio,
    double? rawEditorWidthRatio,
    double? searchResultsHeightRatio,
    // Main panel
    bool? showLineNumbers,
    bool? showSectionBorders,
    bool? highlightCurrentSection,
    bool? enableSmoothScrolling,
    // Tree
    bool? expandAllByDefault,
    bool? showValidationMarkers,
    bool? enableDragAndDrop,
    bool? showSectionIcons,
    // Search
    bool? enableSearch,
    bool? enableReplace,
    bool? enableRegexSearch,
    // Markdown features
    bool? enableMermaid,
    bool? enableMath,
    bool? enableFootnotes,
    bool? enableTaskLists,
    bool? enableInteractiveTaskLists,
    bool? enableTables,
    bool? enableSyntaxHighlighting,
    // Code blocks
    bool? showCodeBlockLanguage,
    bool? showCopyCodeButton,
    bool? showCodeEditButton,
    bool? enableCodeEditing,
    // Tables
    bool? showTableEditButton,
    bool? enableTableEditing,
    // Schema
    bool? enableSchemaValidation,
    bool? showSchemaErrors,
    bool? enableAutoScaffold,
    bool? showSchemaInfoPanel,
    bool? enableFormEditor,
    bool? enableTagSelector,
    bool? showCharCounter,
    bool? enableQuickFixes,
    bool? showValidationPrompts,
    bool? showSectionTypeTooltips,
    bool? enablePositionAwareDragDrop,
    // Behavior
    bool? readOnly,
    bool? enableUndo,
    int? maxUndoHistory,
    bool? confirmDelete,
    bool? autoSave,
    int? autoSaveDebounceMs,
  }) {
    return MdEditorSettings(
      // Layout
      showTree: showTree ?? this.showTree,
      showToolbar: showToolbar ?? this.showToolbar,
      showStatusBar: showStatusBar ?? this.showStatusBar,
      showSearchBox: showSearchBox ?? this.showSearchBox,
      // Raw editor
      rawEditorPosition: rawEditorPosition ?? this.rawEditorPosition,
      allowEditorPositionChange:
          allowEditorPositionChange ?? this.allowEditorPositionChange,
      autoHideEditor: autoHideEditor ?? this.autoHideEditor,
      livePreview: livePreview ?? this.livePreview,
      livePreviewDebounceMs:
          livePreviewDebounceMs ?? this.livePreviewDebounceMs,
      // Separators
      draggableSeparators: draggableSeparators ?? this.draggableSeparators,
      persistSeparatorPositions:
          persistSeparatorPositions ?? this.persistSeparatorPositions,
      treePanelWidthRatio: treePanelWidthRatio ?? this.treePanelWidthRatio,
      rawEditorHeightRatio: rawEditorHeightRatio ?? this.rawEditorHeightRatio,
      rawEditorWidthRatio: rawEditorWidthRatio ?? this.rawEditorWidthRatio,
      searchResultsHeightRatio:
          searchResultsHeightRatio ?? this.searchResultsHeightRatio,
      // Main panel
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      showSectionBorders: showSectionBorders ?? this.showSectionBorders,
      highlightCurrentSection:
          highlightCurrentSection ?? this.highlightCurrentSection,
      enableSmoothScrolling:
          enableSmoothScrolling ?? this.enableSmoothScrolling,
      // Tree
      expandAllByDefault: expandAllByDefault ?? this.expandAllByDefault,
      showValidationMarkers:
          showValidationMarkers ?? this.showValidationMarkers,
      enableDragAndDrop: enableDragAndDrop ?? this.enableDragAndDrop,
      showSectionIcons: showSectionIcons ?? this.showSectionIcons,
      // Search
      enableSearch: enableSearch ?? this.enableSearch,
      enableReplace: enableReplace ?? this.enableReplace,
      enableRegexSearch: enableRegexSearch ?? this.enableRegexSearch,
      // Markdown features
      enableMermaid: enableMermaid ?? this.enableMermaid,
      enableMath: enableMath ?? this.enableMath,
      enableFootnotes: enableFootnotes ?? this.enableFootnotes,
      enableTaskLists: enableTaskLists ?? this.enableTaskLists,
      enableInteractiveTaskLists:
          enableInteractiveTaskLists ?? this.enableInteractiveTaskLists,
      enableTables: enableTables ?? this.enableTables,
      enableSyntaxHighlighting:
          enableSyntaxHighlighting ?? this.enableSyntaxHighlighting,
      // Code blocks
      showCodeBlockLanguage:
          showCodeBlockLanguage ?? this.showCodeBlockLanguage,
      showCopyCodeButton: showCopyCodeButton ?? this.showCopyCodeButton,
      showCodeEditButton: showCodeEditButton ?? this.showCodeEditButton,
      enableCodeEditing: enableCodeEditing ?? this.enableCodeEditing,
      // Tables
      showTableEditButton: showTableEditButton ?? this.showTableEditButton,
      enableTableEditing: enableTableEditing ?? this.enableTableEditing,
      // Schema
      enableSchemaValidation:
          enableSchemaValidation ?? this.enableSchemaValidation,
      showSchemaErrors: showSchemaErrors ?? this.showSchemaErrors,
      enableAutoScaffold: enableAutoScaffold ?? this.enableAutoScaffold,
      showSchemaInfoPanel: showSchemaInfoPanel ?? this.showSchemaInfoPanel,
      enableFormEditor: enableFormEditor ?? this.enableFormEditor,
      enableTagSelector: enableTagSelector ?? this.enableTagSelector,
      showCharCounter: showCharCounter ?? this.showCharCounter,
      enableQuickFixes: enableQuickFixes ?? this.enableQuickFixes,
      showValidationPrompts:
          showValidationPrompts ?? this.showValidationPrompts,
      showSectionTypeTooltips:
          showSectionTypeTooltips ?? this.showSectionTypeTooltips,
      enablePositionAwareDragDrop:
          enablePositionAwareDragDrop ?? this.enablePositionAwareDragDrop,
      // Behavior
      readOnly: readOnly ?? this.readOnly,
      enableUndo: enableUndo ?? this.enableUndo,
      maxUndoHistory: maxUndoHistory ?? this.maxUndoHistory,
      confirmDelete: confirmDelete ?? this.confirmDelete,
      autoSave: autoSave ?? this.autoSave,
      autoSaveDebounceMs: autoSaveDebounceMs ?? this.autoSaveDebounceMs,
    );
  }
}
