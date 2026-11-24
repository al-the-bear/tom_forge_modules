/// Puts a saved revision of a file back (`ForgeWorkspaceStateManager`'s
/// revisions): the file is written with the revision's content, the content
/// it replaces is kept as a revision of its own, and an open editor of the
/// file shows the restored content.
///
/// An application offers it by implementing it on its `ForgeKitApi` (the
/// panel shell's `DefaultShellApi` does); a component asks
/// `api is ForgeRevisionRestorer` and offers no restore otherwise.
abstract interface class ForgeRevisionRestorer {
  /// Restores [fileUri] from [revisionId]; answers whether it did.
  Future<bool> restoreFileFromRevision(Uri fileUri, String revisionId);
}
