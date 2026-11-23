import 'dart:io';

import 'md_review_comments.dart';

String? _cached;

/// The comment author for this machine's logged-in user, computed once: the
/// account's full name (`id -F` on macOS, `/etc/passwd` on Linux) in [form],
/// the login where there is none (Windows).
String mdLocalCommentAuthor({
  MdCommentAuthorForm form = MdCommentAuthorForm.first,
}) {
  final cached = _cached;
  if (cached != null) return cached;
  final login =
      Platform.environment['USER'] ?? Platform.environment['USERNAME'] ?? '';
  final full = mdOsUserFullName(
    platform: Platform.operatingSystem,
    login: login,
    runIdF: () => Process.runSync('id', ['-F']).stdout as String,
    readPasswd: () => File('/etc/passwd').readAsStringSync(),
  );
  return _cached = mdCommentAuthorName(form, fullName: full, login: login);
}
