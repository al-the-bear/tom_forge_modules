# tom_website_editor_core

Pure-Dart core for the `tom_website_editor` Tom Forge module. It loads and
validates the `tom.website-editor.yaml` config (§2 of the specification) and
resolves the `{placeholder}` templates it contains (§3). It has **no Forge or
Flutter dependencies**, so it can be unit-tested and reused on its own.

This package implements **step 1** of the implementation plan in
`tom_website_editor_specification.md`.

## What it provides

| API | Purpose |
| --- | --- |
| `loadWebsiteEditorConfig(yaml, {source})` | Parse + validate YAML into a `WebsiteEditorConfig`; returns a `ConfigLoadResult` carrying the config (or `null`) and every `ConfigIssue`. |
| `validateWebsiteEditorConfig(decoded)` | Validate an already-decoded document (plain maps/lists) and return the issues. |
| `WebsiteEditorConfig` / `ConfigDefaults` / `WebsiteEntry` | The immutable, validated config model. |
| `PlaceholderResolver` (+ `.forWebsite`) | Resolve `{placeholder}` templates against the config. |
| `websiteEditorJsonSchema()` / `websiteEditorJsonSchemaString()` | The generated draft-07 JSON Schema, derived from the same field-spec as the validator. |
| `websiteEditorConfigSpec` / `FieldSpec` | The declarative field-spec model (single source of truth). |

Loading never throws on malformed input: YAML parse errors and validation
violations are returned as `ConfigIssue`s so the editor can render them.
`ConfigLoadResult.isValid` is `true` only when there are no error-severity
issues (and `config` is non-null).

## Config format (§2)

```yaml
version: 1                       # required, currently always 1
defaults:                        # optional
  shell: [bash, -lc]             # argv prefix for command templates
  placeholders:                  # workspace-wide placeholder values
    repos: "~/Desktop/Code/second_wind"
    port: "8080"
websites:                        # required, at least one entry
  - id: enterprise_flutter_web   # required, unique across the file
    label: Enterprise Flutter Web
    paths:                       # required, must include websiteRoot
      websiteRoot: "{repos}/enterprise_flutter/website"
      builtDir: "{websiteRoot}/build/jaspr"
    preview:
      devUrl: "http://localhost:{port}"
    cwd: "{websiteRoot}"         # defaults to {websiteRoot} when omitted
    commands:                    # action name → external command template
      build: "jaspr build"
```

Unknown keys are rejected (typo guard) except within `paths`/`preview`
(which accept extra string leaves). The optional `content:` block (§6a) has a
fixed key set — `dir` (required) plus `components`, `copy` (§16), `areas` (§17),
`site`, `pages`, `editableFields`, `manualPin` — and likewise rejects unknown
keys:

```yaml
content:
  dir:            "{websiteRoot}/content"
  components:     "components/*.yaml"   # mechanical catalog records
  copy:           "copy/*.md"           # editorial copy (one md per node)
  areas:          "areas/*.md"          # auto-discovered area definitions
  site:           "site.yaml"           # nav, categories, featured
  pages:          "pages/*.md"          # standalone pages
  editableFields: [tagline, summary, enables]   # unsuffixed §16 copy-file front-matter; overview is the body
  manualPin:      "# @manual"
```

## Placeholders (§3)

Templates use bare `{name}` tokens. Resolution priority, highest first:

1. **per-website** keys — `paths`, `preview`, `cwd`, `id`;
2. **`defaults.placeholders`** from the config;
3. **built-ins** supplied by the host (e.g. `{port}`, `{browser}`).

Computed tokens:

- `{home}` and a leading `~` expand to the home directory;
- `{env:VAR}` reads the process environment (unset → error);
- `{date}` → `YYYY-MM-DD`, `{time}` → `HH:MM:SS`.

Values expand **recursively** with **cycle detection** and a **max-depth**
guard. An unknown token, an unset `{env:VAR}`, a cycle, or exceeding the depth
limit throws a `PlaceholderException` carrying the offending `token` and the
`location` of the failing template.

```dart
final result = loadWebsiteEditorConfig(yamlSource);
if (!result.isValid) {
  for (final issue in result.issues) print(issue);
  return;
}
final config = result.config!;
final website = config.websiteById('enterprise_flutter_web')!;
final resolver = PlaceholderResolver.forWebsite(
  config,
  website,
  builtins: {'port': '8080', 'browser': 'open'},
);
print(resolver.resolve('{builtDir}')); // fully-expanded absolute path
```

## JSON Schema (single source of truth)

The field-spec tree in `lib/src/config/config_schema.dart` drives **both** the
runtime validator **and** the published JSON Schema, so the two can never
disagree. The committed schema lives in the Tom root's `.tom` (the
`al_the_bear` repository), the root being the nearest folder above the package
that holds `.tom/tom_root.yaml` (`tool/schema_location.dart`):

```text
<tom root>/.tom/json-schema/website-editor/tom.website-editor.schema.json
```

A workspace folder's own `.tom` holds no schemas. Regenerate the file after
changing the field-spec, then commit it in the root's repository:

```bash
dart run tool/write_schema.dart
```

The `json_schema_test.dart` sync test fails if the committed file drifts from
the generated output.

## Testing

```bash
dart test          # or: testkit :test
dart analyze
```
