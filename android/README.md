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
2. Baixar `google-services.json` para `android/app/` (o plugin só é aplicado se o arquivo existir; não commite se preferir mantê-lo privado).
3. Firebase → Configurações do projeto → Contas de serviço → gerar chave privada (JSON).
4. No servidor: copiar o JSON para `/var/www/private/sptrans.lolados.app/fcm-service-account.json` (`root:www-data`, `640`) e adicionar `FCM_SERVICE_ACCOUNT_PATH` ao `private-config.php`.

Sem o `google-services.json`, o app compila normalmente e a tela de alertas avisa que as notificações não estão configuradas.

## Notas

- Mapa com osmdroid (OpenStreetMap), sem chave de API.
- Premium (`app.lolados.data.weekly` / `app.lolados.data.yearly`) ainda sem Google Play Billing; em builds debug há o toggle "Simular Premium" na tela Premium.
- `applicationId` provisório: `app.lolados.duesp`. Confirme antes de publicar, pois não dá para mudar depois.
