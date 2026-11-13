import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louvorja_piano_mobile/core/services/liturgy/liturgy_pdf_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'consulta páginas e renderiza a página solicitada sem depender de navegador externo',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('app.louvorja/liturgy-documents'),
            (call) async {
              calls.add(call);
              if (call.method == 'pdfInfo') return 3;
              if (call.method == 'pdfPage')
                return Uint8List.fromList([137, 80, 78, 71]);
              return null;
            },
          );
      final document = LiturgyPdfDocument('/documento.pdf');
      expect(await document.pageCount(), 3);
      expect(await document.render(1), [137, 80, 78, 71]);
      expect(calls.last.arguments, {
        'path': '/documento.pdf',
        'page': 1,
        'width': 1600,
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('app.louvorja/liturgy-documents'),
            null,
          );
    },
  );
}
