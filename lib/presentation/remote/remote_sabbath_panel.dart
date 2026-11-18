import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import '../../core/services/remote/remote_protocol.dart';
import '../../core/services/remote/remote_session.dart';

class RemoteSabbathPanel extends StatefulWidget {
  const RemoteSabbathPanel({super.key, this.state, this.send});
  final RemoteSabbathState? state;
  final Future<void> Function(RemoteCommand command)? send;
  @override
  State<RemoteSabbathPanel> createState() => _RemoteSabbathPanelState();
}

class _RemoteSabbathPanelState extends State<RemoteSabbathPanel> {
  double? _audioVolume, _videoVolume, _seek;
  Future<void> _send(
    RemoteAction action, {
    int? index,
    int? volume,
    int? durationMs,
    String? mode,
    String? name,
    String? targetId,
    bool? enabled,
  }) => (widget.send ?? RemoteSession.instance.send)(
    RemoteCommand(
      id: 'ss${DateTime.now().microsecondsSinceEpoch}',
      action: action,
      index: index,
      volume: volume,
      durationMs: durationMs,
      mode: mode,
      name: name,
      targetId: targetId,
      enabled: enabled,
    ),
  );
  @override
  void didUpdateWidget(covariant RemoteSabbathPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state?.audioVolume != widget.state?.audioVolume) {
      _audioVolume = null;
    }
    if (oldWidget.state?.videoVolume != widget.state?.videoVolume) {
      _videoVolume = null;
    }
    if (oldWidget.state?.remainingMs != widget.state?.remainingMs) _seek = null;
  }

  String _fmt(int ms) {
    final seconds = (ms.clamp(0, 86400000) ~/ 1000);
    final minutes = seconds ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  int? _duration(String? raw) {
    final parts = (raw ?? '').trim().split(':');
    if (parts.isEmpty ||
        parts.length > 3 ||
        parts.any((p) => int.tryParse(p) == null || int.parse(p) < 0)) {
      return null;
    }
    final numbers = parts.map(int.parse).toList();
    if (parts.length == 1) return numbers[0] * 60000;
    if (numbers.last > 59 || (parts.length == 3 && numbers[1] > 59)) {
      return null;
    }
    return (parts.length == 3
            ? numbers[0] * 3600000 + numbers[1] * 60000
            : numbers[0] * 60000) +
        numbers.last * 1000;
  }

  Future<String?> _ask(
    String title,
    String initial,
    String? Function(String?) validator,
  ) async {
    final form = GlobalKey<FormState>();
    var value = initial;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: initial,
            autofocus: true,
            onChanged: (text) => value = text,
            validator: validator,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, value);
            },
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _editDuration(RemoteSabbathState m) async {
    final value = await _ask(
      'remote.sabbath.duration'.tr(),
      _fmt(m.scheduleDurationMs),
      (raw) {
        final ms = _duration(raw);
        return ms == null || ms < m.minDurationMs || ms < 1000 || ms > 86400000
            ? 'remote.sabbath.invalidDuration'.tr(args: [_fmt(m.minDurationMs)])
            : null;
      },
    );
    if (value != null) {
      await _send(
        RemoteAction.sabbathSetSchedule,
        mode: 'duration',
        durationMs: _duration(value),
      );
    }
  }

  Future<void> _editEnd(RemoteSabbathState m) async {
    final value = await _ask(
      'remote.sabbath.endTime'.tr(),
      m.endTime,
      (raw) => RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(raw ?? '')
          ? null
          : 'remote.sabbath.invalidTime'.tr(),
    );
    if (value != null) {
      await _send(
        RemoteAction.sabbathSetSchedule,
        mode: 'endOnly',
        name: value,
      );
    }
  }

  Future<void> _finalMinutes(RemoteSabbathState m) async {
    if (!m.idle && !m.rehearsing) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('remote.sabbath.finalMinutes'.tr()),
          content: Text('remote.sabbath.replaceConfirm'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('common.start'.tr()),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await _send(RemoteAction.sabbathToggleFinalMinutes);
  }

  Future<void> _editMarker(
    RemoteSabbathState m,
    RemoteSabbathMarker? marker,
  ) async {
    final value = await _ask(
      'remote.sabbath.markerTime'.tr(),
      _fmt(marker?.offsetMs ?? 180000),
      (raw) {
        final ms = _duration(raw);
        return ms == null ||
                ms > 86400000 ||
                m.markers.any(
                  (other) => other.id != marker?.id && other.offsetMs == ms,
                )
            ? 'remote.sabbath.invalidMarker'.tr()
            : null;
      },
    );
    if (value == null) return;
    await _send(
      marker == null
          ? RemoteAction.sabbathAddMarker
          : RemoteAction.sabbathSetMarker,
      targetId: marker?.id,
      index: _duration(value),
      name: marker == null ? 'beep' : null,
    );
  }

  Widget _editableTimeField({
    required Key fieldKey,
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: theme.colorScheme.primary),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
    );
    return Padding(
      key: fieldKey,
      padding: const EdgeInsets.only(top: 16),
      child: TextFormField(
        key: ValueKey('$label-$value'),
        initialValue: value,
        readOnly: true,
        showCursor: false,
        enableInteractiveSelection: false,
        onTap: onTap,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          helperText: 'remote.sabbath.tapToEdit'.tr(),
          helperMaxLines: 2,
          filled: true,
          fillColor: theme.colorScheme.primary.withValues(alpha: 0.08),
          prefixIcon: Icon(icon, color: theme.colorScheme.primary),
          suffixIcon: Icon(
            TablerIcons.pencil,
            color: theme.colorScheme.primary,
          ),
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  String _presetLabel(RemoteSabbathPreset preset) => preset.name.isNotEmpty
      ? preset.name
      : 'remote.sabbath.presets.${preset.id}'.tr();
  List<RemoteSabbathPreset> _presets(RemoteSabbathState m, String selected) {
    final options = {for (final preset in m.presets) preset.id: preset};
    if (options.isEmpty) {
      for (final id in [
        'none',
        'beep',
        'chime',
        'gong',
        'abertura_es',
        '5min_es',
        '1min_es',
      ]) {
        options[id] = RemoteSabbathPreset(id: id);
      }
    }
    options.putIfAbsent(selected, () => RemoteSabbathPreset(id: selected));
    return options.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.state;
    if (m == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'remote.sabbath.unavailable'.tr(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card([
          Text(
            'remote.sabbath.title'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _fmt(m.remainingMs),
            key: const Key('sabbath-remaining'),
            textAlign: TextAlign.center,
            style: theme.textTheme.displayLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (m.finished)
            Text('timer.finished'.tr(), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton.filled(
                key: const Key('sabbath-play'),
                iconSize: 32,
                tooltip: (m.running ? 'common.pause' : 'common.start').tr(),
                icon: Icon(
                  m.running ? TablerIcons.playerPause : TablerIcons.playerPlay,
                ),
                onPressed: m.running || m.canStart
                    ? () => _send(
                        m.running
                            ? RemoteAction.sabbathPause
                            : RemoteAction.sabbathStart,
                      )
                    : null,
              ),
              IconButton(
                key: const Key('sabbath-stop'),
                tooltip: 'common.stop'.tr(),
                icon: const Icon(TablerIcons.square),
                onPressed: () => _send(RemoteAction.sabbathStop),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              TextButton.icon(
                key: const Key('sabbath-minus-minute'),
                onPressed: !m.idle && !m.videoActive
                    ? () => _send(RemoteAction.sabbathAdjustTime, index: -60000)
                    : null,
                icon: const Icon(TablerIcons.minus),
                label: const Text('1 min'),
              ),
              TextButton.icon(
                key: const Key('sabbath-plus-minute'),
                onPressed: !m.idle && !m.videoActive
                    ? () => _send(RemoteAction.sabbathAdjustTime, index: 60000)
                    : null,
                icon: const Icon(TablerIcons.plus),
                label: const Text('1 min'),
              ),
            ],
          ),
          OutlinedButton.icon(
            key: const Key('sabbath-projection'),
            onPressed: () => _send(RemoteAction.sabbathToggleProjection),
            icon: Icon(
              m.isProjecting ? TablerIcons.square : TablerIcons.deviceTv,
            ),
            label: Text(
              (m.isProjecting ? 'remote.stopProjection' : 'remote.project')
                  .tr(),
            ),
          ),
          if (m.videoActive && m.durationMs > 0)
            Slider(
              key: const Key('sabbath-video-seek'),
              value: (_seek ?? (m.durationMs - m.remainingMs).toDouble()).clamp(
                0,
                m.durationMs.toDouble(),
              ),
              max: m.durationMs.toDouble(),
              onChanged: m.idle
                  ? null
                  : (value) => setState(() => _seek = value),
              onChangeEnd: (value) =>
                  _send(RemoteAction.sabbathSeekVideo, index: value.round()),
            ),
        ]),
        const SizedBox(height: 12),
        _card([
          DropdownButtonFormField<String>(
            key: ValueKey('sabbath-mode-${m.scheduleMode}'),
            initialValue: m.scheduleMode,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'remote.sabbath.schedule'.tr(),
            ),
            items: [
              for (final mode in ['duration', 'endOnly', 'video'])
                DropdownMenuItem(
                  value: mode,
                  enabled: mode != 'video' || m.videoName != null,
                  child: Text('remote.sabbath.modes.$mode'.tr()),
                ),
            ],
            onChanged: (mode) {
              if (mode != null) {
                _send(
                  RemoteAction.sabbathSetSchedule,
                  mode: mode,
                  durationMs: m.scheduleDurationMs,
                  name: m.endTime,
                );
              }
            },
          ),
          if (m.scheduleMode == 'duration')
            _editableTimeField(
              fieldKey: const Key('sabbath-duration'),
              label: 'remote.sabbath.duration'.tr(),
              value: _fmt(m.scheduleDurationMs),
              icon: TablerIcons.hourglass,
              onTap: () => _editDuration(m),
            ),
          if (m.scheduleMode == 'endOnly')
            _editableTimeField(
              fieldKey: const Key('sabbath-end-time'),
              label: 'remote.sabbath.endTime'.tr(),
              value: m.endTime,
              icon: TablerIcons.clock,
              onTap: () => _editEnd(m),
            ),
          if (m.scheduleMode == 'video' && m.videoName != null)
            Text(m.videoName!),
          if (m.scheduleMode == 'video' && m.videoName == null)
            Text(
              'remote.sabbath.videoHint'.tr(),
              style: theme.textTheme.bodySmall,
            ),
        ]),
        const SizedBox(height: 12),
        _card([
          Text('remote.sabbath.audio'.tr(), style: theme.textTheme.titleMedium),
          if (m.scheduleMode != 'video') ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('sabbath-opening'),
                  onPressed: m.hasOpening
                      ? () => _send(RemoteAction.sabbathToggleOpening)
                      : null,
                  icon: Icon(
                    m.openingPlayback == 'playing'
                        ? TablerIcons.playerPause
                        : TablerIcons.playerPlay,
                  ),
                  label: Text('remote.sabbath.opening'.tr()),
                ),
                OutlinedButton.icon(
                  key: const Key('sabbath-final-minutes'),
                  onPressed: () => _finalMinutes(m),
                  icon: Icon(
                    m.rehearsing && m.running
                        ? TablerIcons.playerPause
                        : TablerIcons.playerPlay,
                  ),
                  label: Text('remote.sabbath.finalMinutes'.tr()),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  key: const Key('sabbath-muted'),
                  tooltip: 'remote.random.audioMute'.tr(),
                  icon: Icon(
                    m.audioMuted ? TablerIcons.volumeOff : TablerIcons.volume,
                  ),
                  isSelected: m.audioMuted,
                  onPressed: () => _send(
                    RemoteAction.sabbathSetMuted,
                    enabled: !m.audioMuted,
                  ),
                ),
                Expanded(
                  child: Slider(
                    key: const Key('sabbath-volume'),
                    value: _audioVolume ?? m.audioVolume.toDouble(),
                    max: 100,
                    onChanged: (value) => setState(() => _audioVolume = value),
                    onChangeEnd: (value) => _send(
                      RemoteAction.sabbathSetVolume,
                      volume: value.round(),
                    ),
                  ),
                ),
                Text('${(_audioVolume ?? m.audioVolume).round()}%'),
              ],
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('sabbath-language-${m.audioLang}'),
              initialValue: m.audioLang,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'remote.sabbath.language'.tr(),
              ),
              items: [
                for (final lang in ['auto', 'pt-BR', 'en', 'es', 'fr'])
                  DropdownMenuItem(
                    value: lang,
                    child: Text('remote.sabbath.languages.$lang'.tr()),
                  ),
              ],
              onChanged: (lang) {
                if (lang != null) {
                  _send(RemoteAction.sabbathSetAudioLang, name: lang);
                }
              },
            ),
          ] else
            Row(
              children: [
                IconButton(
                  key: const Key('sabbath-video-muted'),
                  tooltip: 'remote.random.audioMute'.tr(),
                  icon: Icon(
                    m.videoMuted ? TablerIcons.volumeOff : TablerIcons.volume,
                  ),
                  onPressed: () => _send(
                    RemoteAction.sabbathSetVideoMuted,
                    enabled: !m.videoMuted,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _videoVolume ?? m.videoVolume.toDouble(),
                    max: 100,
                    onChanged: (value) => setState(() => _videoVolume = value),
                    onChangeEnd: (value) => _send(
                      RemoteAction.sabbathSetVideoVolume,
                      volume: value.round(),
                    ),
                  ),
                ),
                Text('${(_videoVolume ?? m.videoVolume).round()}%'),
              ],
            ),
        ]),
        if (m.scheduleMode != 'video') ...[
          const SizedBox(height: 12),
          _card([
            Text(
              'remote.sabbath.markers'.tr(),
              style: theme.textTheme.titleMedium,
            ),
            for (final marker in m.markers) ...[
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _editMarker(m, marker),
                      child: Text(
                        marker.offsetMs == 0
                            ? 'remote.sabbath.opening'.tr()
                            : '${'remote.sabbath.markerTime'.tr()} ${_fmt(marker.offsetMs)}',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'common.delete'.tr(),
                    icon: const Icon(TablerIcons.trash),
                    onPressed: () => _send(
                      RemoteAction.sabbathRemoveMarker,
                      targetId: marker.id,
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('sabbath-marker-${marker.id}-${marker.preset}'),
                initialValue: marker.preset,
                isExpanded: true,
                items: _presets(m, marker.preset)
                    .map(
                      (preset) => DropdownMenuItem(
                        value: preset.id,
                        child: Text(
                          _presetLabel(preset),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (preset) {
                  if (preset != null) {
                    _send(
                      RemoteAction.sabbathSetMarker,
                      targetId: marker.id,
                      name: preset,
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
            TextButton.icon(
              key: const Key('sabbath-add-marker'),
              onPressed: () => _editMarker(m, null),
              icon: const Icon(TablerIcons.plus),
              label: Text('remote.sabbath.addMarker'.tr()),
            ),
          ]),
        ],
      ],
    );
  }
}
