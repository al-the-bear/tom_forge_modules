## Unreleased

* Reviews: guarded line edits (`MdLineEdit`, `applyLineEdit`), CriticMarkup
  marks decided through `tom_som_dart_runtime` (`decideReviewMark`,
  `decideAllReviewChanges`), review comments with ids and author
  (`addReviewComment`, `editReviewComment`, `mdLocalCommentAuthor`).
* Browsing: `MdLinkResolver`, `MdNavigationHistory`, `MdBrowserNavigator`,
  `MdFollowTail`, `MdFileFollower` and `MdEditorSettings.followTail`.
* Front matter: a file's leading YAML front matter (`---` … `---`) is shown
  verbatim in the rendered view instead of as a rule and a setext heading,
  and is no section (`MdFrontMatter`); a schema comment after it is found.
* Editing a section keeps everything before the first heading: the parsed
  document holds it as `MdDocument.preamble`, which `MdParser.toMarkdown`
  writes back. Before, a section edit rewrote the file without its front
  matter, its schema comment and any introductory text.

## 0.0.1

* TODO: Describe initial release.
