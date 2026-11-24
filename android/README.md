# Due SP — Android

Versão Android do Due SP (Kotlin + Jetpack Compose). Consome a mesma API do iOS: `https://sptrans.lolados.app/api/` (projeto Lolados-server).

Levantamento de funcionalidades, gratuito × Premium e roadmap: [LEVANTAMENTO.md](LEVANTAMENTO.md).

## Abrir e rodar

1. Android Studio → **Open** → selecione esta pasta `android/`.
2. Aguarde o Gradle sync e rode a configuração `app` em um emulador ou aparelho.

Linha de comando (usando o JDK do Android Studio):

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./gradlew :app:assembleDebug :app:testDebugUnitTest
```

## Estrutura

```
app/src/main/java/app/lolados/duesp/
├── DueSPApplication.kt   # AppContainer (injeção manual, como AppDependencies no iOS)
├── MainActivity.kt       # Abas Mapa / Status / Ajustes + navegação
├── data/                 # API (OkHttp + kotlinx.serialization), repositório, favoritos, Premium, localização
├── domain/               # Modelos e cursor de paginação de chegadas
└── ui/                   # Telas Compose: map, search, stop, status, settings
```

## Alertas de interrupção (FCM)

Status → "Alertas de interrupção" permite escolher linhas do Metrô/CPTM. O app usa o mesmo endpoint do iOS (`rail_alert_subscriptions.php`) com `platform: "android"` e `fcmToken`; o servidor envia via FCM HTTP v1 (`inc/FcmSender.class.php` no Lolados-server).

Para ativar:

1. Firebase console → criar projeto → adicionar app Android com o pacote `app.lolados.duesp`.
2. Baixe o `google-services.json` atualizado para o app `app.lolados.duesp` e coloque-o em `android/app/` antes de compilar. O Git ignora esse arquivo. Em um servidor de build, forneça-o pelo armazenamento de segredos do CI e grave-o nesse mesmo caminho antes de executar o Gradle.
3. Firebase → Configurações do projeto → Contas de serviço → gerar chave privada (JSON).
4. No servidor: copiar o JSON para `/var/www/private/sptrans.lolados.app/fcm-service-account.json` (`root:www-data`, `640`) e adicionar `FCM_SERVICE_ACCOUNT_PATH` ao `private-config.php`.

O `google-services.json` configura o Firebase no app e a chave de API é incorporada ao APK/AAB. Restrinja essa chave às APIs Firebase necessárias no Google Cloud. A chave privada da conta de serviço FCM deve ficar no servidor de notificações.

Sem o `google-services.json`, o app compila normalmente e a tela de alertas avisa que as notificações não estão configuradas.

## Publicar no Google Play

1. **Chave de upload** (fica fora do git): `keytool -genkeypair -v -keystore ~/keys/duesp-upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000`, e crie `android/keystore.properties`:
   ```
   storeFile=/Users/<você>/keys/duesp-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```
   Sem esse arquivo o release sai sem assinatura (útil só para testar o R8).
2. **Bundle:** `./gradlew :app:bundleRelease` → `app/build/outputs/bundle/release/app-release.aab`. Ative o Play App Signing no primeiro envio.
3. **Assinaturas** no Play Console → Monetizar → Assinaturas: `app.lolados.data.weekly` e `app.lolados.data.yearly`, cada uma com um plano base (semanal/anual). O app mostra o preço do plano base.
4. **App Links:** Play Console → Integridade do app → Assinatura do app → copie o SHA-256 da *chave de assinatura do app* e adicione em `sptrans.lolados.app/.well-known/assetlinks.json` (mantenha também o de debug).
5. **Política:** Segurança dos dados (localização aproximada/precisa, compras, identificadores de analytics), questionário de classificação, política de privacidade (`https://sptrans.lolados.app/privacy.html`).

## Notas

- Mapa com osmdroid (OpenStreetMap), sem chave de API.
- Premium (`app.lolados.data.weekly` / `app.lolados.data.yearly`) via Google Play Billing (`data/PremiumBilling.kt`). Em builds debug continua o toggle "Simular Premium", que não é sobrescrito quando o Play não tem compras.
- `applicationId` definitivo: `app.lolados.duesp` (não pode mudar depois de publicado no Google Play).
