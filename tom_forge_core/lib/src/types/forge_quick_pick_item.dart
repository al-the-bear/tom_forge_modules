/// An item in a quick pick dialog.
class ForgeQuickPickItem<T> {
  final String label;
  final String? description;
  final String? detail;
  final T value;
  final bool picked;

  const ForgeQuickPickItem({
    required this.label,
    this.description,
    this.detail,
    required this.value,
    this.picked = false,
  });
}
