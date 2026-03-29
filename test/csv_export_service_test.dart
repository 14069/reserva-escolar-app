import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_escolar_app/services/csv_export_service.dart';

void main() {
  test('Monta CSV com escape seguro para Excel e LibreOffice', () {
    final csv = CsvExportService.buildCsv(
      headers: const ['Nome', 'Observacoes'],
      rows: const [
        ['Ana', 'Linha 1; "teste"\nLinha 2'],
      ],
    );

    expect(csv, 'Nome;Observacoes\r\nAna;"Linha 1; ""teste""\nLinha 2"');
  });

  test('Sanitiza prefixo do arquivo para nomes seguros', () {
    expect(
      CsvExportService.sanitizeFilePrefix('  relatorios/admin 2026  '),
      'relatorios_admin_2026',
    );
  });
}
