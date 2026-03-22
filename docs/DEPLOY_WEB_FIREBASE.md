# Deploy Web com Firebase Hosting

Este guia ativa o deploy automatico do Flutter Web para producao usando:

- [firebase.json](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/firebase.json)
- [deploy_web.yml](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/.github/workflows/deploy_web.yml)

## O que este fluxo faz

Quando houver push na branch `main`, o GitHub Actions:

1. instala o Flutter
2. roda `flutter pub get`
3. roda `flutter analyze`
4. roda `flutter test`
5. gera o build web com `API_BASE_URL`
6. publica em Firebase Hosting

## Antes de ativar

Voce precisa ter:

- um projeto Firebase criado
- Hosting ativado no projeto
- um dominio para o web, por exemplo `app.reservaescolar.com.br`
- a API publicada com HTTPS, por exemplo `https://api.reservaescolar.com.br`

## Passo 1: iniciar o Firebase Hosting no projeto

No seu computador:

```bash
npm install -g firebase-tools
firebase login
firebase use --add
```

Escolha o projeto Firebase que vai hospedar o web.

## Passo 2: criar a Service Account do GitHub Actions

O jeito mais simples e recomendado pelo Firebase e rodar:

```bash
firebase init hosting:github
```

Se preferir configurar manualmente, crie uma Service Account com permissao de deploy no projeto Firebase e salve o JSON como segredo no GitHub.

## Passo 3: configurar secrets e variables no GitHub

No repositorio GitHub, configure:

Como o workflow usa `environment: production`, o melhor e criar tudo dentro do environment `production`.

No GitHub:

1. abra o repositorio
2. entre em `Settings`
3. abra `Environments`
4. crie o environment `production`, se ele ainda nao existir
5. entre no environment `production`
6. em `Environment secrets`, cadastre os secrets
7. em `Environment variables`, cadastre as variables

Secrets:

- `FIREBASE_SERVICE_ACCOUNT_RESERVA_ESCOLAR`
  - conteudo JSON completo da Service Account

Variables:

- `FIREBASE_PROJECT_ID`
  - exemplo: `reserva-escolar-prod`
- `API_BASE_URL_PROD`
  - exemplo: `https://api.reservaescolar.com.br`

Resumo esperado pelo workflow:

- [deploy_web.yml](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/.github/workflows/deploy_web.yml)
  - `secrets.FIREBASE_SERVICE_ACCOUNT_RESERVA_ESCOLAR`
  - `vars.FIREBASE_PROJECT_ID`
  - `vars.API_BASE_URL_PROD`

## Passo 4: conectar o dominio customizado

No Firebase Hosting:

1. abra o projeto
2. entre em Hosting
3. adicione o dominio `app.reservaescolar.com.br`
4. configure os registros DNS pedidos
5. aguarde a emissao do certificado HTTPS

## Passo 5: publicar

Depois que as variaveis estiverem configuradas, qualquer push em `main` dispara o deploy automatico do web.

Voce tambem pode disparar manualmente em:

- GitHub
- Actions
- `Deploy Flutter Web`
- `Run workflow`

## Checklist rapido

- `FIREBASE_SERVICE_ACCOUNT_RESERVA_ESCOLAR` configurado
- `FIREBASE_PROJECT_ID` configurado
- `API_BASE_URL_PROD` configurado
- API de producao respondendo com HTTPS
- CORS liberado para `https://app.reservaescolar.com.br`
- dominio do Hosting validado no Firebase

## Observacoes

- O workflow publica apenas o web. A API PHP continua sendo publicada separadamente no VPS.
- O build web usa `--dart-define`, entao a URL da API fica controlada pelo GitHub Actions.
- O `firebase.json` ja esta preparado para SPA com rewrite para `/index.html`.
