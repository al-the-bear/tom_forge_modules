import 'package:flutter/material.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

void main() {
  MdEditorDebug.enabled = true;
  runApp(const MdEditorDemoApp());
}

class MdEditorDemoApp extends StatelessWidget {
  const MdEditorDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tom Markdown Editor Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MdEditorDemoPage(),
    );
  }
}

class MdEditorDemoPage extends StatefulWidget {
  const MdEditorDemoPage({super.key});

  @override
  State<MdEditorDemoPage> createState() => _MdEditorDemoPageState();
}

class _MdEditorDemoPageState extends State<MdEditorDemoPage> {
  late MdEditorController _controller;
  bool _darkMode = true;
  bool _readOnly = false;
  bool _showTree = true;

  @override
  void initState() {
    super.initState();
    _controller = MdEditorController(initialMarkdown: _demoMarkdown);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _darkMode ? MdEditorTheme.dark() : MdEditorTheme.light();
    final settings = MdEditorSettings.standard().copyWith(
      readOnly: _readOnly,
      showTree: _showTree,
      autoHideEditor: false,
      livePreview: true,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tom Markdown Editor'),
        actions: [
          _toggle('Dark', _darkMode, (v) => setState(() => _darkMode = v)),
          _toggle(
            'Read-only',
            _readOnly,
            (v) => setState(() => _readOnly = v),
          ),
          _toggle('Tree', _showTree, (v) => setState(() => _showTree = v)),
          const SizedBox(width: 8),
        ],
      ),
      body: MdEditor(
        controller: _controller,
        theme: theme,
        settings: settings,
        onLinkTap: (url) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Link: $url')));
        },
        onSectionSelected: (section) {
          MdEditorDebug.logger.info('Selected: ${section.headline}');
        },
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Comprehensive demo markdown document ──

const _demoMarkdown = r'''# Tom Markdown Editor Demo

This document exercises **all** major features of the Tom Markdown Editor.

## Formatting

### Inline Styles

This paragraph has **bold**, *italic*, ***bold-italic***, ~~strikethrough~~,
and `inline code`. You can also use [links](https://example.com "Example") and
auto-links like https://flutter.dev.

### Block Quotes

> This is a block quote.
> It can span multiple lines.
>
> > Nested block quotes are also supported.

### Horizontal Rule

---

## Lists

### Unordered List

- Item one
- Item two
  - Nested item A
  - Nested item B
    - Deeply nested
- Item three

### Ordered List

1. First step
2. Second step
3. Third step
   1. Sub-step A
   2. Sub-step B

### Task List

- [x] Implement parser
- [x] Create controller
- [ ] Build preview panel
- [ ] Write tests
- [ ] Publish package

## Code

### Inline Code

Use `MdEditorController` to manage state. Call `controller.undo()` to revert.

### Fenced Code Blocks

```dart
import 'package:tom_md_editor/tom_md_editor.dart';

void main() {
  final controller = MdEditorController(
    markdown: '# Hello World',
  );
  print(controller.document.title);
}
```

```json
{
  "name": "tom_md_editor",
  "version": "0.1.0",
  "description": "A markdown editor for Flutter"
}
```

```python
def greet(name: str) -> str:
    """Return a greeting."""
    return f"Hello, {name}!"
```

## Tables

| Feature | Status | Priority |
|---------|--------|----------|
| Tree view | Done | High |
| Preview | Done | High |
| Raw editor | Done | Medium |
| Code overlay | Done | Medium |
| Table overlay | Done | Low |

### Alignment

| Left | Center | Right |
|:-----|:------:|------:|
| A    | B      | C     |
| D    | E      | F     |

## Mermaid Diagrams

### Flowchart

```mermaid
graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[OK]
    B -->|No| D[Cancel]
    C --> E[End]
    D --> E
```

### Sequence Diagram

```mermaid
sequenceDiagram
    participant A as Alice
    participant B as Bob
    participant C as Charlie
    A->>B: Hello Bob
    B->>C: Hello Charlie
    C-->>B: Hi Bob
    B-->>A: Hi Alice
    A->>B: How are you?
    B->>A: I'm good, thanks!
```

### Gantt Chart

```mermaid
gantt
    title Project Schedule
    dateFormat  YYYY-MM-DD
    section Design
    Wireframes     :a1, 2025-01-01, 10d
    Mockups        :a2, after a1, 7d
    section Development
    Backend        :b1, 2025-01-15, 20d
    Frontend       :b2, after b1, 15d
    section Testing
    QA Testing     :c1, after b2, 10d
```

### Pie Chart

```mermaid
pie title Language Usage
    "Dart" : 45
    "TypeScript" : 25
    "Python" : 15
    "Other" : 15
```

### Timeline

```mermaid
timeline
    title Project Milestones
    2025-01 : Project kickoff
            : Team formed
    2025-03 : Alpha release
    2025-06 : Beta release
            : Public testing
    2025-09 : Version 1.0
```

### Flowchart (Left to Right)

```mermaid
graph LR
    Input[User Input] --> Validate{Valid?}
    Validate -->|Yes| Process[Process Data]
    Validate -->|No| Error[Show Error]
    Process --> Store[(Database)]
    Store --> Response[Send Response]
    Error --> Input
```

## Images

Images are rendered as their alt text in this editor:

![Flutter Logo](https://flutter.dev/assets/images/shared/brand/flutter/logo/flutter-lockup.png)

## Math (LaTeX)

Inline math: $E = mc^2$

Display math:

$$
\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}
$$

## Headings Hierarchy

### Level 3 Section

Content under H3.

#### Level 4 Section

Content under H4.

##### Level 5 Section

Content under H5.

###### Level 6 Section

Content under H6.

## Special Content

### Footnotes

This has a footnote[^1].

[^1]: This is the footnote content.

### Definition List

Term 1
: Definition for term 1.

Term 2
: Definition for term 2.

### Abbreviation

The HTML specification is maintained by the W3C.

*[HTML]: Hyper Text Markup Language
*[W3C]: World Wide Web Consortium

## Long Section for Scrolling

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu
fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.

Curabitur pretium tincidunt lacus. Nulla gravida orci a odio. Nullam varius,
turpis et commodo pharetra, est eros bibendum elit, nec luctus magna felis
sollicitudin mauris.

## Summary

This document covers:

1. **Formatting** — bold, italic, strikethrough, inline code
2. **Block quotes** — single and nested
3. **Lists** — unordered, ordered, task lists
4. **Code blocks** — fenced with language tags
5. **Tables** — with alignment
6. **Headings** — H1 through H6
7. **Special content** — footnotes, definitions, abbreviations
8. **Math** — inline and display LaTeX
9. **Links and images**
10. **Horizontal rules**
11. **Mermaid diagrams** — flowcharts, sequence, gantt, pie, timeline
''';
