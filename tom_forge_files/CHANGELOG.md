## 1.0.0

- The editing session of one file over the file-system contract of
  `tom_forge_core`: encoding, byte-order mark and line endings written back as
  read, edits as splices, a save that checks the disk first and never writes
  over a changed file, external-change handling (keep mine, take theirs,
  merge), and a history of its own.
- The tree filter: ordered rules, the last match deciding, with the presets
  *All files*, *Text files* and *Tom quest folder*.
- The `.env` codec: entries, commented-out entries, section comments and
  inline comments, edited one line at a time, with a masked rendering.
