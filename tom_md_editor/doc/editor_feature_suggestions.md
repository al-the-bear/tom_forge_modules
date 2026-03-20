# Schema-Based Editor Feature Suggestions

Feature suggestions for the Tom Markdown Editor to make creating and editing documents that follow a DocSpecs schema easier. Organized by priority and grouped by area.

## Current State

The editor already has:
- Schema loading from YAML files
- Schema declaration parsing (`<!-- schema=... -->`)
- Full document validation via `DocSpecsValidator`
- Validation error display (badges, tooltips, error propagation)
- Real-time validation on every edit
- Section type identification via `SchemaSectionHelper`
- Allowed children/top-level section lookup
- Skeleton generation from schema
- Settings flags: `enableSchemaValidation`, `showSchemaErrors`, `enableAutoScaffold`

---

## Priority 1 — Schema-Guided Section Creation

### 1.1 "Add Section" Menu with Only Allowed Types

**What**: When right-clicking a section or using the toolbar "add" button, show only the section types the schema allows at that position — using `SchemaSectionHelper.getAllowedSubsections()` for children and `getAllowedTopLevelSections()` for root.

**Why**: Currently the user can add any section anywhere and only gets an error after the fact. This prevents invalid structures from being created.

**Schema features exercised**: `document.sections`, `subsection-types`, `position` constraints (first/last/any), `max-count-in-document`, `max-subsection-levels`, `min-count`/`max-count`

**Implementation hint**: `SchemaSectionHelper` already provides the API. Wire it into the tree view's context menu and the toolbar's insert button. Grey out types that have reached their `max-count`.

### 1.2 Section Templates from Schema Descriptions

**What**: When inserting a new section of a known type, pre-fill it with a template based on the schema's `description` field for that type. For form-format sections, generate the form field labels. For code-format sections, generate a fenced code block with the allowed language.

**Why**: The user shouldn't need to remember what fields go in an endpoint section or what format a task section uses.

**Schema features exercised**: `description`, `format: form` + `form-type`, `format: code` + code language list, `required-fields`, `text-required`

**Example**: Inserting an "endpoint" type section would pre-fill:
```markdown
### Endpoint Name [endpoint-id]

- Method: 
- Path: 
- Description: 
- Auth: 
```

### 1.3 Auto-Scaffold Missing Required Sections

**What**: A toolbar button or automatic prompt that detects missing required sections (non-optional `document.sections` entries, required subsections with `min-count >= 1`) and offers to scaffold them in the correct position.

**Why**: The skeleton generator already exists but only works for new documents. This extends it to partially-complete documents.

**Schema features exercised**: `document.sections` with `optional: false`, `min-count`, `position` constraints

---

## Priority 2 — Form-Aware Editing

### 2.1 Form Field Editor UI

**What**: When a section has `format: form`, render an inline form in the preview panel instead of raw `Key: Value` lines. Each field gets a proper input widget — text input, dropdown (for fields with known values from `custom-tags`), date picker (for date fields like `due-date`).

**Why**: Forms are a core DocSpecs concept but currently render as plain text. A proper form UI would dramatically improve the editing experience for structured data.

**Schema features exercised**: `format: form`, `form-types` definitions, `custom-tags` (for dropdown values), generator syntax `[[tag;separator]]`

**Example**: A task-form section would render:
| Field      | Widget                                        |
|------------|-----------------------------------------------|
| Assignee   | Text input                                    |
| Priority   | Dropdown: critical, high, medium, low         |
| Status     | Dropdown: not-started, in-progress, blocked, done |
| Due-date   | Date picker                                   |

### 2.2 Form Validation Inline

**What**: Validate form fields as the user types — check that values match `pattern-check-text` patterns and that required form fields are present per `required-fields`.

**Schema features exercised**: `required-fields`, `pattern-check-text`, form-type patterns with generators

---

## Priority 3 — ID and Tag Assistance

### 3.1 Section ID Auto-Complete and Validation

**What**: When creating a section that has `pattern-check-id`, show the expected pattern as a placeholder/hint and validate the ID as the user types. For `for-each` sections linked to a registry, offer auto-complete from the registry's existing IDs.

**Why**: IDs like `TASK-001`, `REQ-003`, `comp-auth` follow strict patterns. Real-time feedback prevents typos and naming mistakes.

**Schema features exercised**: `pattern-check-id`, `for-each` with `link-to-field`, `access-key`

**Example**: When adding a component detail section, the editor shows a dropdown of component IDs from the component registry (`comp-auth`, `comp-api`) and pre-fills the `component-id` required field.

### 3.2 Tag Selector

**What**: When a section type has `allowed-tags`, show a tag picker UI (chips or dropdown) instead of requiring the user to type raw `<!-- tags: ... -->` markup.

**Why**: Tags have a fixed vocabulary defined in the schema. A picker is faster and error-free.

**Schema features exercised**: `allowed-tags`, `custom-tags` groups

---

## Priority 4 — Validation UX Enhancements

### 4.1 Per-Section Validation Status in Tree

**What**: Each tree node shows a small icon: green check (valid), yellow warning, red error. Errors propagate upward — a parent shows error if any child has one. Clicking the icon shows the relevant error details.

**Why**: The validation infrastructure exists (`ErrorPropagator` in `tom_editors_shared`) but the tree UI binding may not fully surface per-section markers yet.

**Schema features exercised**: All validation rules — `min-text-length`, `max-text-length`, `text-required`, `pattern-check-id`, structure rules, count limits

### 4.2 Quick-Fix Actions

**What**: For certain validation errors, offer one-click fixes:
- "Missing required section X" → Insert section template
- "Section ID doesn't match pattern `^TASK-[0-9]{3}$`" → Show pattern, offer to rename
- "Text too short (min 50 chars)" → Highlight the section, show character count
- "Max count exceeded" → Offer to delete or merge
- "Section not allowed here" → Offer to move to valid position

**Why**: Errors alone tell the user what's wrong but not how to fix it. Quick-fixes close the loop.

**Schema features exercised**: All validation rules with actionable fixes

### 4.3 Character Count Indicator

**What**: When editing a section with `min-text-length` or `max-text-length` constraints, show a live character counter in the text editor status area (e.g., `127 / 50–2000 chars`).

**Schema features exercised**: `min-text-length`, `max-text-length`, `text-required`

---

## Priority 5 — Schema Browsing and Discovery

### 5.1 Schema Info Panel

**What**: A collapsible panel (or tooltip on the schema badge) showing: schema name/version, description, list of all section types with their constraints, custom-tags, form-types. Gives the user a reference without needing to open the YAML file.

**Why**: Users need to understand what the schema expects. Currently this requires reading raw YAML.

**Schema features exercised**: All schema metadata — `document`, `section-types`, `custom-tags`, `form-types`, descriptions

### 5.2 Schema Picker with Preview

**What**: When creating a new document, show a list of available schemas (from workspace `.tom/docspecs-schema/` and user `~/.tom/docspecs-schema/`) with a preview of what each schema expects — section count, complexity indicator, description.

**Why**: The test app already has `_pickSchema()` but it's a raw file dialog. A proper picker would show schema metadata.

### 5.3 Section Type Tooltip

**What**: Hovering over a section in the tree or preview shows a tooltip with: section type name, description, constraints (min/max text, required fields, allowed tags, allowed children).

**Schema features exercised**: Section type `description`, constraints

---

## Priority 6 — Advanced Schema Features

### 6.1 For-Each Section Sync

**What**: When a schema uses `for-each` (e.g., components section linked to component-registry), adding/removing an entry in the registry automatically offers to create/remove the corresponding detail section.

**Schema features exercised**: `for-each`, `link-to-field`, `access-key`, registry pattern

### 6.2 Position-Aware Drag-and-Drop

**What**: During drag-and-drop in the tree, only highlight valid drop targets. If a section type has `position: first`, it can't be dropped below other children. If `position: last`, it must stay at the bottom.

**Schema features exercised**: `position` constraints (first, last, any, required)

### 6.3 Validation Prompt Display

**What**: Show the schema's `validation-prompt` text as a hint banner at the top of a section when editing it. This gives the user human-readable guidance from the schema author about what the section should contain.

**Schema features exercised**: `validation-prompt` (type-level and section-level overrides), `subsection-validation-prompt`, `${parent.id}` interpolation

### 6.4 Code Block Language Enforcement

**What**: When a section has `format: code` with a language list (e.g., `dart|typescript|python|sql`), the code editor should default to one of those languages and only allow switching between them.

**Schema features exercised**: `format: code`, code block language list

---

## Summary — Implementation Roadmap

| Phase | Features | Effort |
|-------|----------|--------|
| **Phase 1** | 1.1 Guided section creation, 1.2 Section templates, 1.3 Auto-scaffold | Medium — `SchemaSectionHelper` API exists |
| **Phase 2** | 2.1 Form field editor, 2.2 Form validation | High — new UI component needed |
| **Phase 3** | 3.1 ID auto-complete, 3.2 Tag selector | Medium — uses existing schema data |
| **Phase 4** | 4.1 Tree validation, 4.2 Quick-fixes, 4.3 Char counter | Medium — validation infra exists |
| **Phase 5** | 5.1 Schema info, 5.2 Schema picker, 5.3 Type tooltips | Low-Medium — display only |
| **Phase 6** | 6.1 For-each sync, 6.2 Position drag-drop, 6.3 Validation prompts, 6.4 Code language | Medium-High — advanced features |

**Test schema to use**: `schema-test/schema-test.1.0` exercises ALL of these features — it's the ideal integration test target for every phase.
