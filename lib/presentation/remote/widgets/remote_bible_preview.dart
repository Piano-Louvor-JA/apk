import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/app/theme/app_spacing.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_player_presence.dart';

/// Prévia do capítulo do desktop, disponível mesmo antes de projetar.
class RemoteBiblePreview extends StatefulWidget {
  const RemoteBiblePreview({
    super.key,
    required this.bible,
    required this.bookName,
    required this.onChanged,
    this.compact = false,
    this.onMinimize,
    this.onExpand,
    this.onClose,
    this.onProject,
  });

  final RemoteBibleState bible;
  final String bookName;
  final ValueChanged<int> onChanged;

  final bool compact;
  final VoidCallback? onMinimize;
  final VoidCallback? onExpand;
  final VoidCallback? onClose;
  final VoidCallback? onProject;
  @override
  State<RemoteBiblePreview> createState() => _RemoteBiblePreviewState();
}

class _RemoteBiblePreviewState extends State<RemoteBiblePreview> {
  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => remoteBiblePresence.update(this, false),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bible = widget.bible;
    final bookName = widget.bookName;
    final onChanged = widget.onChanged;
    final visible =
        !widget.compact &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => remoteBiblePresence.update(this, mounted && visible),
    );
    final theme = Theme.of(context);
    final numbers = bible.verses.keys.where((n) => n > 0).toList()..sort();
    final selected = bible.selectedVerses;
    final current = selected.isEmpty ? 1 : selected.last;
    final position = numbers.indexOf(current);
    final text = selected
        .map((n) => bible.verses[n] ?? '')
        .where((text) => text.isNotEmpty)
        .join('\n\n');
    return Container(
      key: Key(widget.compact ? 'remote-bible-mini' : 'remote-bible-preview'),
      height: widget.compact ? 220 : MediaQuery.sizeOf(context).height * 0.4,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.s3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$bookName ${bible.chapter ?? 1}:${selected.isEmpty ? current : selected.join(', ')}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                if (widget.onMinimize != null)
                  IconButton(
                    key: const Key('remote-bible-minimize'),
                    tooltip: 'common.minimize'.tr(),
                    color: theme.colorScheme.primary,
                    icon: const Icon(TablerIcons.minus),
                    onPressed: widget.onMinimize,
                  ),
                if (widget.onExpand != null)
                  IconButton(
                    key: const Key('remote-bible-expand'),
                    tooltip: 'remote.tabBible'.tr(),
                    color: theme.colorScheme.primary,
                    icon: const Icon(TablerIcons.maximize),
                    onPressed: widget.onExpand,
                  ),
                if (widget.onClose != null)
                  IconButton(
                    key: const Key('remote-bible-mini-close'),
                    tooltip: 'remote.bible.close'.tr(),
                    icon: const Icon(TablerIcons.x),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                IconButton(
                  key: const Key('remote-bible-preview-prev'),
                  tooltip: 'remote.previous'.tr(),
                  icon: const Icon(TablerIcons.chevronLeft),
                  onPressed: position > 0
                      ? () => onChanged(numbers[position - 1])
                      : null,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s3,
                    ),
                    child: Text(
                      text.isEmpty ? 'common.empty'.tr() : text,
                      textAlign: TextAlign.center,
                      style: widget.compact
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('remote-bible-preview-next'),
                  tooltip: 'remote.next'.tr(),
                  icon: const Icon(TablerIcons.chevronRight),
                  onPressed: position >= 0 && position + 1 < numbers.length
                      ? () => onChanged(numbers[position + 1])
                      : null,
                ),
              ],
            ),
          ),
          if (widget.onProject != null)
            IconButton(
              key: const Key('remote-bible-mini-project'),
              tooltip:
                  (bible.isProjecting
                          ? 'remote.bible.close'
                          : 'remote.bible.open')
                      .tr(),
              color: theme.colorScheme.primary,
              icon: Icon(
                bible.isProjecting
                    ? TablerIcons.arrowDown
                    : TablerIcons.arrowUpRight,
              ),
              onPressed: widget.onProject,
            ),
        ],
      ),
    );
  }
}
