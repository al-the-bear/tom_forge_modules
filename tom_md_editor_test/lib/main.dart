import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'package:tom_doc_specs/tom_doc_specs.dart';
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
      home: const DocumentPickerPage(),
    );
  }
}

/// Available test document types.
enum TestDocument {
  demo('Demo Document', 'Comprehensive markdown feature showcase'),
  docspecs('DocSpecs Test', 'Schema validation and structured documents'),
  schemaTest('Schema Test', 'Exercises ALL DocSpecs features for editor testing'),
  empty('Empty Document', 'Start with a blank document'),
  ;

  const TestDocument(this.label, this.description);
  final String label;
  final String description;
}

/// Document picker shown on startup.
class DocumentPickerPage extends StatelessWidget {
  const DocumentPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Document')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tom Markdown Editor',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a document to start editing',
                  style: TextStyle(color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                for (final doc in TestDocument.values) ...[
                  _DocumentCard(document: doc),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document});
  final TestDocument document;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => _openDocument(context, document),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(_iconFor(document), size: 32, color: Colors.blue),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      document.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(TestDocument doc) {
    return switch (doc) {
      TestDocument.demo => Icons.article,
      TestDocument.docspecs => Icons.schema,
      TestDocument.schemaTest => Icons.science,
      TestDocument.empty => Icons.add_circle_outline,
    };
  }

  Future<void> _openDocument(BuildContext context, TestDocument doc) async {
    String markdown;
    String? documentFilename;
    switch (doc) {
      case TestDocument.demo:
        markdown = _demoMarkdown;
      case TestDocument.docspecs:
        markdown = await rootBundle.loadString('assets/docspecs_test_document.md');
      case TestDocument.schemaTest:
        documentFilename = 'schema-test-document.sct.ds.md';
        markdown = await rootBundle.loadString('assets/$documentFilename');
      case TestDocument.empty:
        markdown = '# New Document\n\nStart writing here...\n';
    }

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MdEditorDemoPage(
            initialMarkdown: markdown,
            documentFilename: documentFilename,
          ),
        ),
      );
    }
  }
}

class MdEditorDemoPage extends StatefulWidget {
  const MdEditorDemoPage({
    super.key,
    required this.initialMarkdown,
    this.documentFilename,
  });
  final String initialMarkdown;
  final String? documentFilename;

  @override
  State<MdEditorDemoPage> createState() => _MdEditorDemoPageState();
}

class _MdEditorDemoPageState extends State<MdEditorDemoPage> {
  late MdEditorController _controller;
  bool _darkMode = true;
  bool _readOnly = false;
  bool _showTree = true;
  DocSpecSchema? _schema;
  String? _schemaFolderPath;

  @override
  void initState() {
    super.initState();
    _controller = MdEditorController(initialMarkdown: widget.initialMarkdown);
    // Default schema folder (configurable)
    _schemaFolderPath = _findDefaultSchemaFolder();
    // Auto-load schema for .ds.md documents
    _tryAutoLoadSchema();
  }

  /// Attempt to auto-resolve and load a schema based on the document filename.
  Future<void> _tryAutoLoadSchema() async {
    final filename = widget.documentFilename;
    if (filename == null || !SchemaResolver.isDocSpecDocument(filename)) return;

    final wsRoot = _findWorkspaceRoot();
    MdEditorDebug.logger.info(
      'Auto-schema: cwd=${Directory.current.path}, wsRoot=$wsRoot, file=$filename',
    );

    try {
      final schema = await SchemaResolver.resolveByDocumentFilename(
        documentFilename: filename,
        documentText: widget.initialMarkdown,
        workspaceRoot: wsRoot,
      );
      if (schema != null && mounted) {
        setState(() => _schema = schema);
        _controller.setSchema(schema);
        MdEditorDebug.logger.info(
          'Auto-loaded schema: ${schema.fullId}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-loaded schema: ${schema.fullId}'),
              backgroundColor: Colors.green[700],
            ),
          );
        }
      } else {
        MdEditorDebug.logger.warn(
          'Auto-schema: no matching schema found for "$filename"',
        );
      }
    } catch (e) {
      MdEditorDebug.logger.warn('Auto-schema load failed: $e');
    }
  }

  /// Find the workspace root by walking up from cwd looking for `.tom/`.
  String? _findWorkspaceRoot() {
    var dir = Directory.current;
    for (var i = 0; i < 10; i++) {
      final tomDir = Directory(path.join(dir.path, '.tom'));
      if (tomDir.existsSync()) return dir.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// Find the default .tom folder for schemas.
  String? _findDefaultSchemaFolder() {
    // Start from executable directory and look for .tom folder
    var dir = Directory.current;
    for (var i = 0; i < 10; i++) {
      final tomDir = Directory(path.join(dir.path, '.tom', 'docspecs-schema'));
      if (tomDir.existsSync()) {
        return tomDir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to document picker',
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DocumentPickerPage()),
          ),
        ),
        title: const Text('Tom Markdown Editor'),
        actions: [
          // Schema picker button
          IconButton(
            icon: Icon(
              Icons.schema,
              color: _schema != null ? Colors.green : null,
            ),
            tooltip: _schema != null
                ? 'Schema: ${_schema!.fullId}'
                : 'Pick Schema',
            onPressed: _pickSchema,
          ),
          // Skeleton generation button (enabled when schema is loaded)
          if (_schema != null)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Generate skeleton from schema',
              onPressed: _generateSkeleton,
            ),
          const VerticalDivider(width: 16),
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

  /// Pick a schema file and associate it with the document.
  Future<void> _pickSchema() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml'],
      initialDirectory: _schemaFolderPath,
      dialogTitle: 'Select DocSpecs Schema',
    );

    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    try {
      final schema = await SchemaLoader.load(filePath);
      setState(() => _schema = schema);

      // Insert schema comment into the document if not already present
      _insertSchemaComment(schema);

      // Set schema on controller for validation
      _controller.setSchema(schema);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded schema: ${schema.fullId}'),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load schema: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  /// Insert the docspec comment at the start of the document.
  void _insertSchemaComment(DocSpecSchema schema) {
    final markdown = _controller.markdown;
    final schemaComment = '<!-- docspec: ${schema.id}/${schema.version} -->\n';

    // Check if document already has a docspec comment
    final docspecPattern = RegExp(r'<!--\s*docspec:\s*\S+\s*-->\s*\n?');
    if (docspecPattern.hasMatch(markdown)) {
      // Replace existing comment
      final updated = markdown.replaceFirst(docspecPattern, schemaComment);
      _controller.markdown = updated;
    } else {
      // Insert at the beginning
      _controller.markdown = schemaComment + markdown;
    }
  }

  /// Generate a skeleton document from the loaded schema.
  Future<void> _generateSkeleton() async {
    if (_schema == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Skeleton'),
        content: Text(
          'This will replace the current document with a skeleton '
          'based on the "${_schema!.id}" schema.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final skeleton = DocSpecsSkeletonGenerator.generate(_schema!);
    _controller.markdown = skeleton;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skeleton document generated'),
          backgroundColor: Colors.green,
        ),
      );
    }
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

### Supported Language Samples (Extensive)

#### (no language)
```
Plain fenced block with no language tag.
Should keep monospace styling.
Should not apply token colors.
TODO: verify copy/edit overlay still works.
12345 true false "string" key:value # still plain text here
```

#### dart
```dart
import 'dart:math' as math;

class InvoiceItem {
  const InvoiceItem(this.name, this.price, this.qty);
  final String name;
  final double price;
  final int qty;

  double get total => price * qty;
}

double applyDiscount(double subtotal, {double rate = 0.1}) {
  if (subtotal <= 0) return 0;
  final capped = math.min(rate, 0.4);
  return subtotal * (1 - capped);
}

void main() {
  final items = <InvoiceItem>[
    const InvoiceItem('Keyboard', 129.5, 1),
    const InvoiceItem('Cable', 9.99, 3),
  ];
  final subtotal = items.fold<double>(0, (s, i) => s + i.total);
  final total = applyDiscount(subtotal, rate: 0.15);
  print('subtotal=$subtotal total=$total');
}
```

#### yaml
```yaml
project:
  name: tom_md_editor
  version: "0.2.0"
  release: 5
  quality: 9.75
  enabled: true
  deprecated: false
  optional: null
  date: 2026-03-18
  labels: ["editor", "preview", "code"]
  environments:
    dev:
      theme: dark
      timeoutMs: 5000
      features: [live-preview, tree, code-overlay]
    prod:
      theme: light
      timeoutMs: 8000
      features:
        - live-preview
        - audit-log

pipelines:
  - id: test
    steps:
      - run: flutter test
      - run: dart analyze
```

#### json
```json
{
  "name": "tom_md_editor",
  "version": "0.2.0",
  "build": 5,
  "coverage": 97.3,
  "isStable": true,
  "isDeprecated": false,
  "note": null,
  "settings": {
    "readOnly": false,
    "livePreview": true,
    "maxLines": 120,
    "timeoutMs": 3500,
    "plugins": [
      { "id": "mermaid", "enabled": true },
      { "id": "table", "enabled": true },
      { "id": "math", "enabled": true }
    ]
  },
  "recentFiles": [
    "doc/guide.md",
    "doc/changelog.md"
  ]
}
```

#### javascript
```javascript
/** @typedef {{id:number,name:string,tags:string[]}} User */
const users = [
  { id: 1, name: 'Alex', tags: ['admin', 'editor'] },
  { id: 2, name: 'Sam', tags: ['viewer'] }
];

const byRole = role => users.filter(u => u.tags.includes(role));

async function fetchJson(url) {
  const res = await fetch(url, { headers: { 'Accept': 'application/json' } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

console.log(byRole('editor').map(u => u.name).join(', '));
```

#### typescript
```typescript
type Status = 'todo' | 'doing' | 'done';

interface Task {
  id: string;
  title: string;
  status: Status;
  estimateHours?: number;
}

function groupByStatus(tasks: Task[]): Record<Status, Task[]> {
  return tasks.reduce<Record<Status, Task[]>>(
    (acc, t) => ({ ...acc, [t.status]: [...acc[t.status], t] }),
    { todo: [], doing: [], done: [] }
  );
}

const tasks: Task[] = [
  { id: 'T1', title: 'Parser', status: 'done', estimateHours: 4 },
  { id: 'T2', title: 'UI', status: 'doing' }
];

console.log(groupByStatus(tasks));
```

#### python
```python
from dataclasses import dataclass
from typing import Iterable

@dataclass(frozen=True)
class Item:
    name: str
    price: float
    qty: int = 1

def total(items: Iterable[Item]) -> float:
    subtotal = sum(i.price * i.qty for i in items)
    tax = subtotal * 0.2
    return round(subtotal + tax, 2)

if __name__ == "__main__":
    cart = [Item("Mouse", 29.9, 2), Item("Desk", 199.0)]
    print({"total": total(cart), "count": len(cart)})
```

#### c
```c
#include <stdio.h>
#include <string.h>

typedef struct {
  char name[32];
  int score;
} Player;

int max_score(const Player *players, int count) {
  int max = 0;
  for (int i = 0; i < count; i++) {
    if (players[i].score > max) max = players[i].score;
  }
  return max;
}

int main(void) {
  Player players[] = {{"Alex", 42}, {"Sam", 58}};
  printf("max=%d\n", max_score(players, 2));
  return 0;
}
```

#### cpp
```cpp
#include <algorithm>
#include <iostream>
#include <map>
#include <vector>

int main() {
  std::vector<int> values{9, 2, 7, 4, 5};
  std::sort(values.begin(), values.end());

  std::map<std::string, int> counts{{"ok", 3}, {"fail", 1}};
  for (const auto& [k, v] : counts) {
    std::cout << k << " => " << v << "\n";
  }

  auto hasEven = std::any_of(values.begin(), values.end(), [](int n) {
    return n % 2 == 0;
  });
  std::cout << "hasEven=" << std::boolalpha << hasEven << "\n";
}
```

#### java
```java
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

record User(String id, String role) {}

public class Demo {
  public static void main(String[] args) {
    var users = List.of(new User("u1", "admin"), new User("u2", "viewer"));
    Map<String, Long> byRole = users.stream()
      .collect(Collectors.groupingBy(User::role, Collectors.counting()));

    byRole.forEach((k, v) -> System.out.println(k + ": " + v));
  }
}
```

#### kotlin
```kotlin
data class Event(val id: String, val active: Boolean, val tags: List<String>)

fun main() {
    val events = listOf(
        Event("E1", true, listOf("ui", "high")),
        Event("E2", false, listOf("backend"))
    )

    val activeTags = events
        .filter { it.active }
        .flatMap { it.tags }
        .distinct()
        .sorted()

    println(activeTags.joinToString(", "))
}
```

#### swift
```swift
import Foundation

struct Item: Codable {
    let id: Int
    let title: String
    let done: Bool
}

let items = [
    Item(id: 1, title: "Render markdown", done: true),
    Item(id: 2, title: "Fix mermaid", done: false)
]

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

if let data = try? encoder.encode(items),
   let json = String(data: data, encoding: .utf8) {
    print(json)
}
```

#### rust
```rust
use std::collections::HashMap;

#[derive(Debug)]
struct Task<'a> {
    title: &'a str,
    done: bool,
}

fn summarize(tasks: &[Task]) -> HashMap<&str, usize> {
    let mut map = HashMap::new();
    map.insert("done", tasks.iter().filter(|t| t.done).count());
    map.insert("open", tasks.iter().filter(|t| !t.done).count());
    map
}

fn main() {
    let tasks = [Task { title: "Parser", done: true }, Task { title: "UI", done: false }];
    println!("{:?}", summarize(&tasks));
}
```

#### go
```go
package main

import (
    "encoding/json"
    "fmt"
    "strings"
)

type User struct {
    Name  string   `json:"name"`
    Roles []string `json:"roles"`
}

func main() {
    u := User{Name: "Alex", Roles: []string{"admin", "editor"}}
    b, _ := json.MarshalIndent(u, "", "  ")
    fmt.Println(string(b))
    fmt.Println(strings.ToUpper(u.Name))
}
```

#### ruby
```ruby
User = Struct.new(:id, :name, :roles, keyword_init: true)

users = [
  User.new(id: 1, name: 'Alex', roles: %w[admin editor]),
  User.new(id: 2, name: 'Sam', roles: %w[viewer])
]

admins = users.select { |u| u.roles.include?('admin') }
puts admins.map(&:name).join(', ')

begin
  raise 'demo error' if admins.empty?
rescue => e
  warn "error: #{e.message}"
end
```

#### php
```php
<?php
declare(strict_types=1);

final class InvoiceItem {
  public function __construct(
    public string $name,
    public float $price,
    public int $qty = 1,
  ) {}

  public function total(): float {
    return $this->price * $this->qty;
  }
}

$items = [new InvoiceItem('Mouse', 19.9, 2), new InvoiceItem('Cable', 5.5, 3)];
$sum = array_reduce($items, fn($s, $i) => $s + $i->total(), 0.0);
echo json_encode(['sum' => $sum], JSON_PRETTY_PRINT) . PHP_EOL;
```

#### html
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Code Demo</title>
  </head>
  <body>
    <main class="layout">
      <article class="card" data-state="active">
        <h1>Markdown Editor</h1>
        <p>Supports <strong>Mermaid</strong>, tables, and code overlays.</p>
      </article>
    </main>
  </body>
</html>
```

#### css
```css
:root {
  --bg: #111827;
  --surface: #1f2937;
  --text: #e5e7eb;
  --accent: #38bdf8;
}

* { box-sizing: border-box; }

body {
  margin: 0;
  font: 500 16px/1.5 "Segoe UI", sans-serif;
  color: var(--text);
  background: radial-gradient(circle at top, #0f172a, var(--bg));
}

.card {
  max-width: 680px;
  margin: 2rem auto;
  padding: 1.25rem;
  border: 1px solid color-mix(in oklab, var(--accent) 35%, black);
  border-radius: 12px;
  background: var(--surface);
}
```

#### sql
```sql
WITH monthly AS (
  SELECT
    DATE_TRUNC('month', created_at) AS month,
    status,
    COUNT(*) AS cnt
  FROM issues
  WHERE created_at >= CURRENT_DATE - INTERVAL '6 months'
  GROUP BY 1, 2
)
SELECT
  month,
  SUM(CASE WHEN status = 'open' THEN cnt ELSE 0 END) AS open_count,
  SUM(CASE WHEN status = 'closed' THEN cnt ELSE 0 END) AS closed_count
FROM monthly
GROUP BY month
ORDER BY month;
```

#### bash
```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${1:-.}"
echo "Running checks in: $PROJECT_DIR"

pushd "$PROJECT_DIR" >/dev/null
dart analyze
flutter test --no-pub

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Workspace has local changes"
else
  echo "Workspace clean"
fi

popd >/dev/null
```

#### markdown
```markdown
Markdown sample with escaped heading marker: \# Heading 1
Markdown sample with escaped list marker: \- list item

This section tests **bold**, *italic*, `inline code`, and [links](https://example.com).

> A quote block with `code` and **emphasis**.

1. Ordered item with nested list:
   - child item
   - another child

Inline math: $E=mc^2$.

| Feature | Status |
|:--|--:|
| Mermaid | ✅ |
| Syntax Highlighting | ✅ |
```

#### xml
```xml
<?xml version="1.0" encoding="UTF-8"?>
<workspace name="tom_forge">
  <project id="tom_md_editor" language="dart">
    <features>
      <feature enabled="true">preview</feature>
      <feature enabled="true">mermaid</feature>
      <feature enabled="true">syntax-highlighting</feature>
    </features>
    <metadata created="2026-03-18">
      <owner>al-the-bear</owner>
      <status>active</status>
    </metadata>
  </project>
</workspace>
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
