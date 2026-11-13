import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/remote/remote_protocol.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';
import 'package:louvorja_piano_mobile/domain/entities/liturgy_item.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/bloc/liturgy_bloc.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/liturgy_page.dart';
import 'package:louvorja_piano_mobile/presentation/liturgy/player/local_liturgy_session.dart';

void main() {
  testWidgets(
    'selecionar abre controles sem marcar e o botão adicionar não cobre o player',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = LiturgyRepository(await SharedPreferences.getInstance());
      await repo.saveItems(LiturgyWeekday.sunday, [
        const LiturgyItem(
          id: 'a',
          type: LiturgyItemType.annotation,
          name: 'Anotação',
        ),
      ]);
      final bloc = LiturgyBloc(repo)
        ..add(const LiturgyLoadRequested(LiturgyWeekday.sunday));
      await bloc.stream.first;
      await tester.pumpWidget(MaterialApp(home: LiturgyPage(testBloc: bloc)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('liturgy-add-moment')), findsOneWidget);
      await tester.tap(find.text('Anotação'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('remote-play-button')), findsOneWidget);
      expect(find.byKey(const Key('liturgy-add-moment')), findsNothing);
      expect(localLiturgyPlayer.state.hasOpenMedia, false);
      expect(localLiturgyPlayer.pending?.id, 'a');
      expect((bloc.state as LiturgyLoaded).items.single.done, false);
      await tester.runAsync(
        () => localLiturgyPlayer.send(
          RemoteCommand(id: 'cleanup', action: RemoteAction.stop),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(bloc.close);
    },
  );
}
