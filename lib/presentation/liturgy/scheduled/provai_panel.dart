import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/widgets/liturgy_web_control_page.dart';
import 'scheduled_bloc.dart';

class ProvaiPanel extends StatefulWidget {
  const ProvaiPanel({super.key, required this.state});
  final ScheduledState state;
  @override
  State<ProvaiPanel> createState() => _ProvaiPanelState();
}

class _ProvaiPanelState extends State<ProvaiPanel> {
  String? _language;
  int _quarter = (DateTime.now().month - 1) ~/ 3 + 1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _language ??=
        (EasyLocalization.of(context)?.locale.languageCode ?? 'pt') == 'es'
        ? 'es'
        : 'pt';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _language,
                items: const [
                  DropdownMenuItem(
                    value: 'pt',
                    child: Text('Provai e Vede (PT)'),
                  ),
                  DropdownMenuItem(
                    value: 'es',
                    child: Text('Probad y Ved (ES)'),
                  ),
                ],
                onChanged: state.busy
                    ? null
                    : (value) => setState(() => _language = value),
              ),
              DropdownButton<int>(
                value: _quarter,
                items: [
                  for (var quarter = 1; quarter <= 4; quarter++)
                    DropdownMenuItem(
                      value: quarter,
                      child: Text('2026 · $quarter'),
                    ),
                ],
                onChanged: state.busy
                    ? null
                    : (value) {
                        if (value != null) setState(() => _quarter = value);
                      },
              ),
              FilledButton(
                onPressed: state.busy
                    ? null
                    : () => context.read<ScheduledBloc>().add(
                        ScheduledProvaiRequested(_language!, 2026, _quarter),
                      ),
                child: Text('liturgy.parity.loadEpisodes'.tr()),
              ),
            ],
          ),
        ),
        if (state.busy) const LinearProgressIndicator(),
        if (state.progress.isNotEmpty) Text(state.progress),
        if (state.episodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton.icon(
              onPressed: state.busy
                  ? null
                  : () => context.read<ScheduledBloc>().add(
                      ScheduledProvaiImported(state.episodes),
                    ),
              icon: const Icon(TablerIcons.download),
              label: Text('liturgy.parity.downloadUpcoming'.tr()),
            ),
          ),
        Expanded(
          child: ListView(
            children: [
              for (final episode in state.episodes)
                ListTile(
                  title: Text(episode.title),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(episode.date)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LiturgyWebControlPage(
                        title: episode.title,
                        url: episode.url,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'liturgy.parity.downloadSchedule'.tr(),
                    icon: const Icon(TablerIcons.download),
                    onPressed: state.busy
                        ? null
                        : () => context.read<ScheduledBloc>().add(
                            ScheduledProvaiImported([
                              episode,
                            ], onlyUpcoming: false),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
