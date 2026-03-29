import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_escolar_app/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Gera bytes de PDF validos para tabela exportada', () async {
    final bytes = await PdfExportService.buildPdfBytes(
      title: 'Relatório teste',
      subtitle: 'Período: histórico',
      headers: const ['Nome', 'Status'],
      rows: const [
        ['Ana Souza', 'Ativo'],
        ['Bruno Lima', 'Inativo'],
      ],
    );

    expect(bytes, isNotEmpty);
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
  });
}
