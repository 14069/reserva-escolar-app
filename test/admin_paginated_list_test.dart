import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_escolar_app/widgets/admin_ui.dart';

void main() {
  testWidgets('Mostra mais itens sob demanda e reinicia ao trocar resetKey', (
    tester,
  ) async {
    Future<void> pumpList({required Object resetKey}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminPaginatedList<int>(
                items: List<int>.generate(5, (index) => index + 1),
                pageSize: 2,
                summaryLabel: 'itens',
                resetKey: resetKey,
                itemBuilder: (context, item) => Text('Item $item'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpList(resetKey: 'primeiro');

    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
    expect(find.text('Item 3'), findsNothing);
    expect(find.text('Exibindo 2 de 5 itens.'), findsOneWidget);

    await tester.tap(find.text('Mostrar mais (3 restantes)'));
    await tester.pumpAndSettle();

    expect(find.text('Item 4'), findsOneWidget);
    expect(find.text('Item 5'), findsNothing);
    expect(find.text('Exibindo 4 de 5 itens.'), findsOneWidget);

    await pumpList(resetKey: 'segundo');

    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
    expect(find.text('Item 3'), findsNothing);
    expect(find.text('Exibindo 2 de 5 itens.'), findsOneWidget);
  });
}
