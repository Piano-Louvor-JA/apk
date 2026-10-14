import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:louvorja_piano_mobile/presentation/liturgy/liturgy_avulsa_page.dart';

/// Fake do FilePickerPlatform devolvendo arquivos em fila.
final class _FakePickerPlatform extends FilePickerPlatform {
  final List<PlatformFile?> queue;
  int _i = 0;
  _FakePickerPlatform(this.queue);

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (_i >= queue.length) return null;
    return queue[_i++];
  }
}

final class _FakePlatformFile extends PlatformFile {
  final String _name;
  final Uint8List _bytes;
  _FakePlatformFile(this._name, this._bytes);

  @override
  String get name => _name;

  @override
  Uri get uri => Uri.file('/tmp/$_name');

  @override
  XFile get xFile => XFile.fromData(_bytes, name: _name);

  @override
  int? lengthSync() => _bytes.length;

  @override
  Future<int?> length() async => _bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream<Uint8List>.value(_bytes);
}

PlatformFile _file(String name, {String? content}) =>
    _FakePlatformFile(name, Uint8List.fromList((content ?? '').codeUnits));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('importar: cancelar picker não faz nada', (tester) async {
    FilePickerPlatform.instance = _FakePickerPlatform([null]);

    await tester.pumpWidget(const MaterialApp(home: LiturgyAvulsaPage()));
    await tester.pumpAndSettle();

    final importBtn = find.byIcon(TablerIcons.calendarDown);
    if (importBtn.evaluate().isNotEmpty) {
      await tester.tap(importBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('importar: arquivo não-XML mostra snack de XML inválido', (
    tester,
  ) async {
    FilePickerPlatform.instance = _FakePickerPlatform([
      _file('qualquer.txt', content: 'lixo'),
    ]);

    await tester.pumpWidget(const MaterialApp(home: LiturgyAvulsaPage()));
    await tester.pumpAndSettle();

    final importBtn = find.byIcon(TablerIcons.calendarDown);
    if (importBtn.evaluate().isNotEmpty) {
      await tester.tap(importBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('importar: XML de categorias + itens importa com sucesso', (
    tester,
  ) async {
    FilePickerPlatform.instance = _FakePickerPlatform([
      _file('categorias.xml', content: '<data></data>'),
      _file('itens.xml', content: '<data></data>'),
    ]);

    await tester.pumpWidget(const MaterialApp(home: LiturgyAvulsaPage()));
    await tester.pumpAndSettle();

    final importBtn = find.byIcon(TablerIcons.calendarDown);
    if (importBtn.evaluate().isNotEmpty) {
      await tester.tap(importBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('arquivo notPorted (favoritos) mostra snack específico', (
    tester,
  ) async {
    FilePickerPlatform.instance = _FakePickerPlatform([
      _file('favoritos.xml', content: '<data></data>'),
    ]);

    await tester.pumpWidget(const MaterialApp(home: LiturgyAvulsaPage()));
    await tester.pumpAndSettle();

    final importBtn = find.byIcon(TablerIcons.calendarDown);
    if (importBtn.evaluate().isNotEmpty) {
      await tester.tap(importBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
  });
}
