# reserva_escolar_app

Aplicativo Flutter para reservas escolares.

## Execucao

O app aceita a URL base da API via `dart-define`.

Exemplo para ambiente local:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost/reserva_escolar_api_v2
```

Exemplo para rede local:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.12.102/reserva_escolar_api_v2
```

Se `API_BASE_URL` nao for informada, o app usa o valor padrao definido em [lib/services/api_service.dart](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/lib/services/api_service.dart).

## Producao

O guia de publicacao e endurecimento do projeto esta em [docs/PRODUCAO.md](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/PRODUCAO.md).

Resumo do que ainda precisa ser ajustado antes de publicar:

- trocar a API para dominio real com HTTPS
- remover `root` sem senha da API PHP
- restringir CORS na API
- definir `applicationId` final do Android
- configurar assinatura de release
