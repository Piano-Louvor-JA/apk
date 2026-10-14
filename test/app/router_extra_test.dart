import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/app/router.dart';
import 'package:louvorja_piano_mobile/core/services/settings_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapRouter() {
  return ChangeNotifierProvider<SettingsController>(
    create: (_) => SettingsController(),
    child: MaterialApp.router(routerConfig: appRouter),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (_) async => <String, dynamic>{
        'appName': 'LouvorJA PIANO',
        'packageName': 'com.louvorja.piano.mobile',
        'version': '1.0.0',
        'buildNumber': '1',
        'buildSignature': '',
        'installerStore': null,
      },
    );
  });

  testWidgets('rota /hymns/playlists NÃO casa como álbum (ordem custom-first)',
      (tester) async {
    appRouter.go('/hymns/playlists');
    await tester.pumpWidget(_wrapRouter());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Deve abrir PlaylistsPage (orientação de playlist), não AlbumDetail.
    expect(find.text('Playlists'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rota /hymns/custom abre coletâneas custom', (tester) async {
    appRouter.go('/hymns/custom');
    await tester.pumpWidget(_wrapRouter());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('álbum inválido (não numérico) cai em albumId 0 sem crash', (
    tester,
  ) async {
    appRouter.go('/hymns/notanumber');
    await tester.pumpWidget(_wrapRouter());
    await tester.pump();
    // Queima timers pendentes (debounce/retry do album detail).
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 10));

    expect(tester.takeException(), isNull);
  });

  testWidgets('rota /settings/terms e /settings/privacy resolvem TermsPage', (
    tester,
  ) async {
    appRouter.go('/settings/terms');
    await tester.pumpWidget(_wrapRouter());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    appRouter.go('/settings/privacy');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rota /tools abre Ferramentas', (tester) async {
    appRouter.go('/tools');
    await tester.pumpWidget(_wrapRouter());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });
}
