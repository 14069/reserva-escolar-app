# Publicacao Play Store

Este documento resume os dados prontos para publicar o app na Google Play.

## Build atual

- Application ID: `com.reservaescolar.app`
- Nome do app: `Reserva Escolar`
- URL da API embutida no bundle: `https://api.reservaescolar.com.br`
- Bundle gerado: [app-release.aab](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/build/app/outputs/bundle/release/app-release.aab)
- Checksum SHA-256 do bundle: `6523e2cbfe0660cce594cc8258d671ead7fa76fc326b3153b87df0ebb72a90ac`

## Certificado de upload

Keystore usada neste build:

- [upload-keystore.jks](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/android/upload-keystore.jks)

Alias:

- `upload`

Fingerprint do certificado:

- SHA-1: `90:D7:E0:73:C5:95:D4:E3:DB:08:6A:25:0F:DE:D9:2F:4B:F3:7E:D0`
- SHA-256: `58:C8:8C:BF:3C:EA:B0:3D:10:46:52:A3:30:44:99:4A:6B:A0:A1:4B:BE:52:CD:B0:33:D2:A8:59:F6:C1:40:08`

## Validacoes feitas

- O bundle foi gerado com sucesso.
- A assinatura do `.aab` foi verificada com `jarsigner`.
- O certificado do upload foi lido com `keytool`.

Observacao:

- O aviso de cadeia invalida no `jarsigner` e esperado aqui porque o certificado de upload e autoassinado.
- Isso nao impede o envio para a Play Store.

## Checklist de envio

1. Acessar a Play Console com a conta do desenvolvedor.
2. Criar o app `Reserva Escolar`, se ele ainda nao existir.
3. Confirmar o pacote `com.reservaescolar.app`.
4. Ativar o `Play App Signing` quando a Play Console solicitar.
5. Enviar o bundle [app-release.aab](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/build/app/outputs/bundle/release/app-release.aab).
6. Preencher descricao curta, descricao completa, icone, banner e screenshots.
   Referencia pronta em [docs/FICHA_LOJA_PLAY.md](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/docs/FICHA_LOJA_PLAY.md)
7. Informar politica de privacidade e classificacao indicativa.
8. Revisar paises, distribuicao e publico-alvo.
9. Publicar primeiro em teste interno ou fechado antes da producao.

## Comando usado

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.reservaescolar.com.br
```

## Cuidados

- Nao versionar `android/key.properties`.
- Nao compartilhar `android/upload-keystore.jks` publicamente.
- Guardar em local seguro as credenciais em:
  - [release-keystore-credentials.local.txt](/home/agacy-junior/RESERVA_ESCOLAR/reserva_escolar_v2_app/android/release-keystore-credentials.local.txt)
- Se perder a keystore de upload, a recuperacao na Play Store fica mais trabalhosa.
