library;

import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Banner nao-intrusivo exibido no topo quando ha uma nova versao.
class UpdateBanner extends StatefulWidget {
  final String version;
  final int? apkSizeBytes;
  final String? releaseNotes;
  final String? downloadUrl;
  final VoidCallback? onUpdate;
  final VoidCallback onDismiss;

  const UpdateBanner({
    super.key,
    required this.version,
    this.apkSizeBytes,
    this.releaseNotes,
    this.downloadUrl,
    this.onUpdate,
    required this.onDismiss,
  });

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  bool _expanded = false;

  String get _sizeLabel {
    final bytes = widget.apkSizeBytes;
    if (bytes == null) return '';
    if (bytes >= 1048576)
      return ' (${(bytes / 1048576).toStringAsFixed(1)} MB)';
    if (bytes >= 1024) return ' (${(bytes / 1024).round()} KB)';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNotes =
        widget.releaseNotes != null && widget.releaseNotes!.trim().isNotEmpty;
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  TablerIcons.refreshAlert,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: hasNotes
                        ? () => setState(() => _expanded = !_expanded)
                        : null,
                    child: Text(
                      'Nova versao ${widget.version}$_sizeLabel'
                      '${hasNotes ? '  ${_expanded ? "▲" : "▼"}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  onPressed: () {
                    if (kIsWeb && widget.downloadUrl != null) {
                      launchUrl(
                        Uri.parse(widget.downloadUrl!),
                        webOnlyWindowName: '_blank',
                      );
                    } else {
                      widget.onUpdate?.call();
                    }
                  },
                  child: const Text('Atualizar'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'common.close'.tr(),
                  icon: const Icon(TablerIcons.x, size: 18),
                  onPressed: widget.onDismiss,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (_expanded && hasNotes) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MarkdownBody(
                  data: widget.releaseNotes!,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    h2: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    h3: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
