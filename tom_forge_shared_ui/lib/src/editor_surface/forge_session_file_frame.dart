import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart'
    show ForgeFileSessionState, ForgeSessionFile;

/// The editor's view with the file's state above it — the kit's
/// [ForgeSessionFile] drawn: loading, not readable, a refusal, a read-only
/// notice, the file deleted on disk (a save writes it again), or a change on
/// disk with the choice between the two texts.
class ForgeSessionFileFrame extends StatelessWidget {
  const ForgeSessionFileFrame({
    super.key,
    required this.file,
    required this.child,
  });

  final ForgeSessionFile file;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: file.changed,
    builder: (context, _, _) {
      final session = file.session;
      switch (session.state) {
        case ForgeFileSessionState.loading:
          return const Center(child: CircularProgressIndicator());
        case ForgeFileSessionState.missing:
          return const Center(child: Text('This file does not exist.'));
        case ForgeFileSessionState.refused:
          return Center(child: Text(session.refusal ?? 'Not opened.'));
        case ForgeFileSessionState.ready:
          break;
      }
      final theme = Theme.of(context);
      final external = session.external;
      final notice = session.readOnlyReason;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(notice, style: theme.textTheme.bodySmall),
            ),
          // The session marks a deleted file with `deletedOnDisk`; its
          // external change stays empty.
          if (session.deletedOnDisk)
            Material(
              key: const Key('forge-file-deleted-on-disk'),
              color: theme.colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'This file was deleted on disk. Saving writes it again.',
                ),
              ),
            ),
          if (external != null)
            Material(
              key: const Key('forge-file-changed-on-disk'),
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        external.deleted
                            ? 'This file was deleted on disk.'
                            : 'This file changed on disk.',
                      ),
                    ),
                    TextButton(
                      onPressed: file.keepMine,
                      child: const Text('Keep mine'),
                    ),
                    if (!external.deleted)
                      TextButton(
                        onPressed: file.takeTheirs,
                        child: const Text('Take theirs'),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(child: child),
        ],
      );
    },
  );
}
