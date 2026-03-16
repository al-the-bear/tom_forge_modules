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

### Multi-Line List Items

In Markdown, continuation text belongs to a list item when it is indented
to align with the first text character of that item (typically 2-4 spaces):

- **ItemX**
  ItemX has the meaning of representing the unknown factor
  in a complex equation. It is used widely in examples.
  - **Sub-ItemX-Item**
    Sub-ItemX-Item is even more interesting because it
    demonstrates that continuation text also works on
    nested items — just indent further.

- **Configuration**
  All configuration lives in `tom_project.yaml` at the project root.
  The file is validated against a JSON schema on every build.

  Additional paragraphs that belong to the same list item are separated
  by a blank line but still indented to the item level.

1. **First numbered item**
   This continuation paragraph belongs to item 1.
   It can span multiple lines as long as they are indented.
   1. **Nested numbered**
      Continuation under the nested numbered item works the same way.

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

### Class Diagram

```mermaid
classDiagram
    class Animal {
        +String name
        +int age
        +makeSound() void
    }
    class Dog {
        +String breed
        +fetch() void
    }
    class Cat {
        +bool indoor
        +purr() void
    }
    Animal <|-- Dog
    Animal <|-- Cat
```

### State Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Loading : fetch()
    Loading --> Success : data received
    Loading --> Error : request failed
    Success --> Idle : reset()
    Error --> Loading : retry()
    Error --> Idle : cancel()
```

### Entity-Relationship Diagram

```mermaid
erDiagram
    USER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    PRODUCT ||--o{ LINE_ITEM : "is in"
    USER {
        int id PK
        string name
        string email
    }
    ORDER {
        int id PK
        date created
        string status
    }
    PRODUCT {
        int id PK
        string name
        float price
    }
```

### Journey

```mermaid
journey
    title User Onboarding
    section Sign Up
        Visit landing page: 5: User
        Fill in form: 3: User
        Verify email: 2: User, System
    section First Use
        Complete tutorial: 4: User
        Create first project: 5: User
        Invite team members: 3: User
```

### Git Graph

```mermaid
gitGraph
    commit
    commit
    branch feature
    checkout feature
    commit
    commit
    checkout main
    merge feature
    commit
    branch hotfix
    commit
    checkout main
    merge hotfix
```

### Mindmap

```mermaid
mindmap
    root((Project))
        Frontend
            Flutter
            React
        Backend
            Dart Server
            Node.js
        DevOps
            CI/CD
            Docker
            Kubernetes
```

### Quadrant Chart

```mermaid
quadrantChart
    title Priority Matrix
    x-axis Low Effort --> High Effort
    y-axis Low Impact --> High Impact
    quadrant-1 Do First
    quadrant-2 Schedule
    quadrant-3 Delegate
    quadrant-4 Eliminate
    Feature A: [0.2, 0.8]
    Feature B: [0.7, 0.9]
    Feature C: [0.3, 0.3]
    Feature D: [0.8, 0.2]
```

### XY Chart

```mermaid
xychart-beta
    title "Monthly Revenue"
    x-axis [Jan, Feb, Mar, Apr, May, Jun]
    y-axis "Revenue ($K)" 0 --> 100
    bar [30, 45, 55, 60, 72, 90]
    line [30, 45, 55, 60, 72, 90]
```

## Images

Images are loaded from URLs and displayed inline:

![Dart Logo](https://dart.dev/assets/img/logo/dart-logo-for-shares.png?2)

![Flutter Logo](https://storage.googleapis.com/cms-storage-bucket/0dbfcc7a59cd1cf16282.png)

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
11. **Mermaid diagrams** — flowcharts, sequence, gantt, pie, timeline, class, state, ER, journey, git graph, mindmap, quadrant, xychart
''';
