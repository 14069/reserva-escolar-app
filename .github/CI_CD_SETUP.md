# Flutter CI/CD Setup

Este guia explica como os **GitHub Actions** rodam testes e fazem deploy automático do app Flutter.

## ✅ Status Atual

O app Flutter já tem **CI configurado e deploy automático**!

### Workflows Ativos

1. **CI** (`ci.yml`)
   - Roda em: `push` em qualquer branch + `pull_request`
   - O que faz: `flutter analyze` + `flutter test`

2. **Deploy Web** (`deploy_web.yml`)
   - Roda em: `push` na branch `main`
   - O que faz: Build web + deploy para Firebase Hosting

---

## 🔐 Secrets Necessários

### Já Configurado ✅
- `FIREBASE_SERVICE_ACCOUNT_RESERVA_ESCOLAR` (account JSON)
- `FIREBASE_PROJECT_ID` (app ID)

### Variables ✅
- `API_BASE_URL_PROD` (URL da API em produção)

---

## 🎯 Como Usar

### Testar Mudanças em uma Branch

```bash
# Criar feature branch
git checkout -b feature/nova-feature
flutter pub get
flutter analyze
flutter test

# Push para GitHub
git push origin feature/nova-feature

# Abrir Pull Request no GitHub
# CI rodará automaticamente
```

### Deploy Automático

Sempre que você fizer **push na `main`**, acontece automaticamente:

```bash
# No seu computador:
git checkout main
git pull origin main
git commit -m "Update app"
git push origin main

# No GitHub:
# 1. Deploy Web workflow roda
# 2. App é built com `flutter build web --release`
# 3. Build é enviado para Firebase Hosting
# 4. Seu app fica online em ~2 minutos
```

### Deploy Manual (sem push)

Se quiser fazer deploy sem atualizar código:

1. Vá para: https://github.com/14069/reserva-escolar-app/actions
2. Procure por **"Deploy Flutter Web"**
3. Clique em **Run workflow**
4. Clique **Run workflow** novamente
5. Aguarde o deploy finalizar

---

## 📋 CI Pipeline (O que roda)

### Quando: `push` em qualquer branch ou abrir `pull_request`

```yaml
flutter pub get          # Instala dependências
flutter analyze          # Verifica erros estáticos
flutter test             # Roda testes unitários/widget
```

**Resultado**: Se algum teste falhar, o PR fica com ❌

---

## 📋 Deploy Pipeline (O que roda na main)

### Quando: `push` na branch `main`

```yaml
1. Setup Flutter
2. flutter pub get
3. flutter analyze
4. flutter test
5. flutter build web --release \
   --dart-define=API_BASE_URL="${{ vars.API_BASE_URL_PROD }}"
6. Deploy para Firebase Hosting
```

---

## ✅ Checklist Antes de Fazer Push

E antes de fazer `git push origin main`:

- [ ] Testes passam localmente: `flutter test`
- [ ] Análise está OK: `flutter analyze`
- [ ] Build compila: `flutter build web --release`
- [ ] Testou manualmente no navegador
- [ ] Código foi revisado em PR

---

## 🚨 Se o CI Falhar

### Testes falhando?

```bash
# Rode localmente
flutter test --verbose

# Veja qual teste está falhando
# Corrija o código
git add .
git commit -m "Fix failing test"
git push origin feature/minha-feature
```

### Build falhando?

```bash
# Tente compilar localmente
flutter build web

# Se der erro, mostra onde está o problema
# Corrija e faça push novamente
```

---

## 📊 Acompanhando Deploy

### Via GitHub Actions
1. Repositório → **Actions**
2. Procure por **"Deploy Flutter Web"**
3. Clique no workflow mais recente
4. Veja logs em tempo real

### Via Firebase Console
1. Acesse: https://console.firebase.google.com
2. Projeto: `reserva-escolar`
3. Hosting → Deploy History
4. Veja histórico de deploys

---

## 🔄 Variáveis e Secrets

### `API_BASE_URL_PROD` (Variable)
- Local: GitHub → Settings → Variables → Actions
- Valor: URL base da API em produção
- Exemplo: `https://api.reservaescolar.app.br`

Quando o app é buildado para produção, ele usa essa URL:

```dart
// No app, a API vai chamar:
GET https://api.reservaescolar.app.br/bookings
POST https://api.reservaescolar.app.br/login
```

### `FIREBASE_SERVICE_ACCOUNT_RESERVA_ESCOLAR` (Secret)
- Local: GitHub → Settings → Secrets → Actions
- Valor: JSON da conta de serviço do Firebase
- Usado para autenticar deploy

---

## 🌍 Onde o App Fica Online

Depois de fazer deploy, o app fica disponível em:

- **URL principal**: https://reservaescolar.firebaseapp.com
- **Domínio customizado**: https://app.reservaescolar.com.br (se configurado)

---

## 🆘 Troubleshooting

### "Build failed: lib/main.dart"
→ Erro no código Dart  
→ Verifique logs no GitHub Actions  
→ Corrija e faça push novamente

### "Firebase authentication failed"
→ Secret `FIREBASE_SERVICE_ACCOUNT_RESERVA_ESCOLAR` expirou ou está errado  
→ Gere novo JSON em Firebase → Project Settings → Service Accounts

### "Deploy pending for long time"
→ Firebase pode estar processando  
→ Normalmente leva 1-3 minutos  
→ Acompanhe em Firebase Console → Hosting → Deploy History

---

## 💡 Próximos Passos (Opcionais)

- [ ] Configurar uploads automáticos para APK/AAB (Play Store)
- [ ] Adicionar testes de integração
- [ ] Configurar Sentry para monitorar erros em produção
- [ ] Auto-deploy para staging em branch `develop`
- [ ] Notifications no Slack/Discord quando deploy termina

---

**Resumo**: Seu app é testado e deployado automaticamente! 🚀
