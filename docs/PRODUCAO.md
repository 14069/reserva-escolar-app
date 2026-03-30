# Guia de Producao

Este documento resume o que precisa ser feito para publicar o app Flutter e a API PHP/MySQL com seguranca e previsibilidade.

## Estado atual

- App Flutter:
  - usa `API_BASE_URL` por `--dart-define`
  - fallback atual em [lib/services/api_service.dart](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/lib/services/api_service.dart) aponta para um IP interno de rede
  - tema claro/escuro, cadastro da escola, relatorios e fluxo administrativo ja estao no app
- API real:
  - fica em `/opt/lampp/htdocs/reserva_escolar_api_v2`
  - autenticacao Bearer ativa
  - `response.php` agora usa whitelist de origens, com lista configuravel por ambiente
  - `db.php` agora aceita configuracao por variaveis de ambiente
- Android:
  - `applicationId` atual esta como `com.reservaescolar.app`
  - build `release` ja aceita assinatura real por `android/key.properties`

## Bloqueios antes de publicar

Estes itens devem ser tratados antes de qualquer build final:

1. Trocar a URL da API para um dominio real com HTTPS.
2. Criar usuario proprio do MySQL para a aplicacao.
3. Remover o uso de `root` e senha vazia em `/opt/lampp/htdocs/reserva_escolar_api_v2/db.php`.
4. Restringir CORS em `/opt/lampp/htdocs/reserva_escolar_api_v2/response.php`.
5. Definir os dominios reais de homologacao e producao.
6. Conferir a keystore de release e guardar as credenciais com seguranca.
7. Garantir backup do banco antes da virada.

## Infraestrutura recomendada

## API PHP

- Servidor Linux com Apache ou Nginx + PHP 8.2+
- MySQL 8+
- Dominio dedicado, preferencialmente `api.reservaescolar.com.br`
- HTTPS obrigatorio com certificado valido
- Fuso horario do servidor alinhado com a operacao da escola

## URLs recomendadas

Para este projeto, a convencao sugerida e esta:

- Homologacao da API: `https://api-hml.reservaescolar.com.br`
- Producao da API: `https://api.reservaescolar.com.br`

Com isso, o app vai chamar endpoints neste formato:

- `https://api.reservaescolar.com.br/login.php`
- `https://api.reservaescolar.com.br/register_school.php`
- `https://api.reservaescolar.com.br/get_all_bookings.php`

Observacao:

- use a `baseUrl` sem barra no final
- para o build final da Play Store, gere o app com a URL de producao

## Banco de dados

- banco exclusivo para o sistema
- usuario exclusivo da aplicacao com permissoes minimas
- backup automatico diario
- restauracao testada em ambiente separado

## Configuracao da API

Arquivos e pontos mais sensiveis no ambiente atual:

- [/opt/lampp/htdocs/reserva_escolar_api_v2/db.php](/opt/lampp/htdocs/reserva_escolar_api_v2/db.php)
- [/opt/lampp/htdocs/reserva_escolar_api_v2/response.php](/opt/lampp/htdocs/reserva_escolar_api_v2/response.php)

Checklist:

- trocar host, usuario, senha e nome do banco para valores de producao
- nunca usar `root`
- nunca deixar senha vazia
- restringir `Access-Control-Allow-Origin` ao dominio autorizado
- manter `Authorization` liberado nos headers
- revisar tempo de expiracao do token
- habilitar logs do PHP/Apache
- desabilitar qualquer exibicao de erro para o cliente final

Variaveis de ambiente aceitas pela API real:

- `RESERVA_DB_HOST`
- `RESERVA_DB_PORT`
- `RESERVA_DB_NAME`
- `RESERVA_DB_USERNAME`
- `RESERVA_DB_PASSWORD`
- `RESERVA_ALLOWED_ORIGINS`

Exemplo com Apache `SetEnv`:

```apache
SetEnv RESERVA_DB_HOST localhost
SetEnv RESERVA_DB_PORT 3306
SetEnv RESERVA_DB_NAME reserva_escolar_v2
SetEnv RESERVA_DB_USERNAME reserva_escolar_app
SetEnv RESERVA_DB_PASSWORD troque-esta-senha
SetEnv RESERVA_ALLOWED_ORIGINS https://app-hml.reservaescolar.com.br,https://painel-hml.reservaescolar.com.br
```

Modelo pronto de VirtualHost:

- [docs/infra/apache-api-vhost.example.conf](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/infra/apache-api-vhost.example.conf)

Exemplo de direcao para CORS em producao:

```php
$allowedOrigin = 'https://app-hml.reservaescolar.com.br';
if (!empty($_SERVER['HTTP_ORIGIN']) && $_SERVER['HTTP_ORIGIN'] === $allowedOrigin) {
    header("Access-Control-Allow-Origin: $allowedOrigin");
}
```

## Configuracao do app Flutter

O app ja aceita a URL da API por `dart-define`. Em producao, sempre publique com a URL final:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.reservaescolar.com.br
```

Para simplificar o fluxo com a API hospedada no Railway, o projeto agora inclui:

- [.env.flutter.example](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/.env.flutter.example)
- [scripts/flutter_with_api.sh](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/scripts/flutter_with_api.sh)

Uso recomendado:

```bash
cp .env.flutter.example .env.flutter.local
```

Depois defina:

```env
API_BASE_URL=https://api.seudominio.com.br
```

E gere o build:

```bash
./scripts/flutter_with_api.sh web
./scripts/flutter_with_api.sh apk
./scripts/flutter_with_api.sh appbundle
```

Se forem gerar `appbundle` para Play Store:

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.reservaescolar.com.br
```

Para iOS:

```bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.reservaescolar.com.br
```

## Ajustes pendentes no Android

Arquivo atual: [android/app/build.gradle.kts](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/android/app/build.gradle.kts)

Antes da publicacao:

1. Trocar `appNamespace`, `appApplicationId` e `appDisplayName` em [android/gradle.properties](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/android/gradle.properties).
2. Criar `android/key.properties` a partir de [android/key.properties.example](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/android/key.properties.example).
3. Preencher a keystore real de release no `key.properties`.
4. Atualizar `versionName` e `versionCode`.
5. Revisar nome exibido e icone final do aplicativo.

Observacao:

- se `android/key.properties` nao existir, o build `release` ainda cai para a chave de debug para nao travar o ambiente atual
- para publicar em loja, configure a keystore real antes do build final

## Ajustes pendentes no iOS

Arquivo de referencia: [ios/Runner/Info.plist](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/ios/Runner/Info.plist)

Antes da publicacao:

1. Definir `PRODUCT_BUNDLE_IDENTIFIER` final.
2. Configurar assinatura e time no Xcode.
3. Revisar nome exibido do app.
4. Validar politicas e permissoes, se novas funcionalidades forem adicionadas.

## Sequencia recomendada de deploy

1. Preparar um ambiente de homologacao com copia da API e banco.
2. Ajustar `db.php` e `response.php` para o padrao de producao.
3. Criar backup completo do banco atual.
4. Publicar a API no dominio final com HTTPS.
5. Testar endpoints principais fora do app.
6. Gerar build do Flutter apontando para `API_BASE_URL` final.
7. Executar teste de ponta a ponta com uma escola real.
8. So depois disso liberar a build para uso.

## Teste de fumaca

Executar pelo menos estes fluxos apos o deploy:

1. Cadastrar escola.
2. Fazer login do tecnico.
3. Cadastrar professor, turma, disciplina, recurso e horarios.
4. Criar reserva.
5. Consultar minhas reservas.
6. Consultar reservas administrativas.
7. Abrir relatorios.
8. Trocar tema claro/escuro.
9. Fazer logout e novo login.

## Operacao

- manter backup diario e um backup manual antes de qualquer alteracao estrutural
- registrar mudancas de schema
- monitorar erros 401, 403 e 500
- documentar rollback
- manter um tecnico administrador de contingencia

## Comandos uteis

Conferir versao do Flutter usada no ambiente atual:

```bash
flutter --version
```

Build Android de exemplo:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.reservaescolar.com.br
```

Build Android para homologacao:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api-hml.reservaescolar.com.br
```

Build Play Store recomendado:

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.reservaescolar.com.br
```

Analise estatica:

```bash
flutter analyze
```

Checklist de publicacao:

- [docs/PUBLICACAO_PLAY_STORE.md](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/PUBLICACAO_PLAY_STORE.md)
- [docs/DEPLOY_WEB_FIREBASE.md](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/DEPLOY_WEB_FIREBASE.md)

## Proximo passo recomendado

O proximo passo mais seguro e efetivo para este projeto e configurar o servidor de homologacao com valores reais de ambiente:

1. Definir `RESERVA_DB_HOST`, `RESERVA_DB_PORT`, `RESERVA_DB_NAME`, `RESERVA_DB_USERNAME` e `RESERVA_DB_PASSWORD`.
2. Definir `RESERVA_ALLOWED_ORIGINS` com os dominios autorizados.
3. Validar login, cadastro da escola, reservas e relatorios contra a API de homologacao.
