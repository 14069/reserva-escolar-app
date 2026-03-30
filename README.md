# reserva_escolar_app

Aplicativo Flutter para reservas escolares.

## Execucao

O app aceita a URL base da API via `dart-define`.

Para nao precisar repetir o comando inteiro, use o script:

```bash
cp .env.flutter.example .env.flutter.local
./scripts/flutter_with_api.sh run-web
```

Para apontar para a API publicada no Railway, preencha `API_BASE_URL` em `.env.flutter.local` com algo como:

```env
API_BASE_URL=https://api.seudominio.com.br
```

Exemplo para ambiente local:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost/reserva_escolar_api_v2
```

Exemplo para rede local:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.12.102/reserva_escolar_api_v2
```

Se `API_BASE_URL` nao for informada, o app usa o valor padrao definido em [lib/services/api_service.dart](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/lib/services/api_service.dart).

Builds prontos com o script:

```bash
./scripts/flutter_with_api.sh web
./scripts/flutter_with_api.sh apk
./scripts/flutter_with_api.sh appbundle
```

## Producao

O guia de publicacao e endurecimento do projeto esta em [docs/PRODUCAO.md](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/PRODUCAO.md).

Resumo do que ainda precisa ser ajustado antes de publicar:

- trocar a API para dominio real com HTTPS
- remover `root` sem senha da API PHP
- restringir CORS na API
- definir `applicationId` final do Android
- configurar assinatura de release
