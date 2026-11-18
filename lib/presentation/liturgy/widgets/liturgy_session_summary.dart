import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_item_rules.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_timing.dart';
import 'package:louvorja_piano_mobile/core/utils/liturgy_format.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';

class LiturgySessionSummary extends StatefulWidget {
  const LiturgySessionSummary({super.key, required this.state});
  final LiturgyLoaded state;
  @override
  State<LiturgySessionSummary> createState() => _LiturgySessionSummaryState();
}

class _LiturgySessionSummaryState extends State<LiturgySessionSummary> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _pick(bool start) async {
    final bloc = context.read<LiturgyBloc>();
    final current = start ? widget.state.startTime : widget.state.endTime;
    final minutes = LiturgyTiming.minutes(current);
    final time = await showTimePicker(
      context: context,
      initialTime: minutes == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (time == null || !mounted) return;
    final value = LiturgyTiming.hhmm(time.hour * 60 + time.minute);
    bloc.add(
      LiturgySessionTimesChanged(
        startTime: start ? value : widget.state.startTime,
        endTime: start ? widget.state.endTime : value,
      ),
    );
  }

  void _toggle() {
    context.read<LiturgyBloc>().add(
      widget.state.sessionStartedAt == null
          ? LiturgySessionClockStarted()
          : LiturgySessionClockStopped(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.state.items.fold<int>(
      0,
      (sum, item) => sum + LiturgyItemRules.durationMs(item),
    );
    final estimate = LiturgyTiming.estimatedEnd(widget.state.items);
    final remaining =
        widget.state.sessionStartedAt == null || widget.state.endTime == null
        ? null
        : LiturgyTiming.remaining(
            widget.state.endTime!,
            widget.state.sessionStartedAt!,
            DateTime.now(),
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: [
          Text(
            DateFormat('HH:mm:ss').format(DateTime.now()),
            key: const Key('cult-current-clock'),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              TextButton.icon(
                key: const Key('cult-start-time'),
                onPressed: () => _pick(true),
                icon: const Icon(TablerIcons.clock),
                label: Text(
                  widget.state.startTime ?? 'liturgy.parity.realStart'.tr(),
                ),
              ),
              if (widget.state.startTime != null)
                IconButton(
                  tooltip: 'liturgy.parity.clearTime'.tr(),
                  icon: const Icon(TablerIcons.x, size: 16),
                  onPressed: () => context.read<LiturgyBloc>().add(
                    LiturgySessionTimesChanged(endTime: widget.state.endTime),
                  ),
                ),
              TextButton.icon(
                key: const Key('cult-end-time'),
                onPressed: () => _pick(false),
                icon: const Icon(TablerIcons.clockHour12),
                label: Text(
                  widget.state.endTime ?? 'liturgy.parity.plannedEnd'.tr(),
                ),
              ),
              if (widget.state.endTime != null)
                IconButton(
                  tooltip: 'liturgy.parity.clearTime'.tr(),
                  icon: const Icon(TablerIcons.x, size: 16),
                  onPressed: () => context.read<LiturgyBloc>().add(
                    LiturgySessionTimesChanged(
                      startTime: widget.state.startTime,
                    ),
                  ),
                ),
              Text(
                remaining == null
                    ? '—'
                    : LiturgyFormat.formatElapsed(remaining.inMilliseconds),
                key: const Key('cult-timer-display'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: remaining == Duration.zero
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
              IconButton(
                key: const Key('cult-timer-toggle'),
                tooltip:
                    (widget.state.sessionStartedAt == null
                            ? 'liturgy.parity.startCountdown'
                            : 'liturgy.parity.stopCountdown')
                        .tr(),
                onPressed: widget.state.endTime == null ? null : _toggle,
                icon: Icon(
                  widget.state.sessionStartedAt == null
                      ? TablerIcons.playerPlay
                      : TablerIcons.playerStop,
                ),
              ),
            ],
          ),
          Text(
            '${'liturgy.totalDuration'.tr()}: ${LiturgyFormat.formatElapsed(total)}',
          ),
          Text('${'liturgy.parity.estimatedEnd'.tr()}: ${estimate ?? '—'}'),
        ],
      ),
    );
  }
}
