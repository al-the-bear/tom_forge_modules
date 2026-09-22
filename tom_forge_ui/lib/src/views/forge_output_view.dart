import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../components/forge_component.dart';
import '../components/forge_view.dart';
import '../defaults/default_output_manager.dart';
import '../services/forge_output_channel_manager.dart';

/// Output view with channel dropdown and monospace log display.
///
/// Takes [ForgeOutputChannelManager] and shows the active channel's output.
/// Supports auto-scroll when the user is at the bottom. Lines are rendered in
/// the channel's own uniform `[HH:MM:SS] [TYPE] text` form — there is no
/// timestamp toggle, because the format is unconditional at the source.
class ForgeOutputView extends ForgeView {
  final ForgeOutputChannelManager channelManager;

  final _title = ValueNotifier<String>('Output');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeOutputView({required this.channelManager});

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.terminal;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        preferredSize: Size(400, 200),
      );

  @override
  Widget buildMain(BuildContext context) {
    return _OutputContent(channelManager: channelManager);
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _OutputContent extends StatefulWidget {
  final ForgeOutputChannelManager channelManager;

  const _OutputContent({required this.channelManager});

  @override
  State<_OutputContent> createState() => _OutputContentState();
}

class _OutputContentState extends State<_OutputContent> {
  String? _selectedChannel;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _subscription;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  /// Track whether the user has scrolled away from the bottom.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 20;
    if (_autoScroll != atBottom) {
      setState(() => _autoScroll = atBottom);
    }
  }

  void _subscribeToChannel(DefaultOutputChannel channel) {
    _subscription?.cancel();
    _subscription = channel.onDidAppend.listen((_) {
      if (mounted) {
        setState(() {});
        if (_autoScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = widget.channelManager.channels;
    if (channels.isEmpty) {
      return Center(
        child: Text(
          'No output channels',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
        ),
      );
    }

    _selectedChannel ??= channels.first.name;
    final active = widget.channelManager.get(_selectedChannel!);

    // Subscribe to the selected channel for live updates.
    if (active is DefaultOutputChannel) {
      _subscribeToChannel(active);
    }

    return Column(
      children: [
        _buildToolbar(context, channels),
        Expanded(child: _buildOutputText(context, active)),
      ],
    );
  }

  Widget _buildToolbar(
      BuildContext context, List<ForgeOutputChannel> channels) {
    final theme = Theme.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          SizedBox(
            height: 26,
            child: DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(4),
                  color: theme.colorScheme.surfaceContainerLow,
                ),
                child: DropdownButton<String>(
                  value: _selectedChannel,
                  onChanged: (value) => setState(() {
                    _selectedChannel = value;
                    _subscription?.cancel();
                    _autoScroll = true;
                  }),
                  isDense: true,
                  style: theme.textTheme.bodySmall,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  items: [
                    for (final ch in channels)
                      DropdownMenuItem(
                        value: ch.name,
                        child: Text(ch.name, style: theme.textTheme.bodySmall),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          // Auto-scroll indicator / toggle.
          IconButton(
            icon: Icon(
              Icons.vertical_align_bottom,
              size: 14,
              color: _autoScroll
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() => _autoScroll = !_autoScroll);
              if (_autoScroll) _scrollToBottom();
            },
            tooltip: _autoScroll ? 'Auto-scroll: on' : 'Auto-scroll: off',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              final channel = widget.channelManager.get(_selectedChannel!);
              channel?.clear();
              setState(() {});
            },
            tooltip: 'Clear',
          ),
        ],
      ),
    );
  }

  Widget _buildOutputText(
      BuildContext context, ForgeOutputChannel? channel) {
    if (channel == null) return const SizedBox.expand();

    final contents =
        channel is DefaultOutputChannel ? channel.contents : '';

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: SizedBox(
          width: double.infinity,
          child: SelectableText(
            contents,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
