# Due SP — Levantamento para a versão Android

Levantamento feito a partir do app iOS (`sp-trains-bus/`), em 16/11/2026.

## 1. Funcionalidades do app iOS

### Abas principais (`Presentation/TabBar/MainTabView.swift`)

| Aba | Status no iOS | O que faz |
| --- | --- | --- |
| Mapa | Ativa (aba inicial) | Mapa com pontos próximos, filtros Ônibus/Metrô/Trem, malha ferroviária desenhada, carrossel de pontos, acesso ao detalhe do ponto |
| Status | Ativa | Status Metrô + CPTM por linha, card de status geral, alertas de interrupção, analytics |
| Ajustes | Ativa | Sobre/versão, cor de destaque, Premium, avaliar app, gorjeta, site, contato, privacidade, termos |
| Busca / Planejar viagem | Desligada (`FeatureToggles.isSearchEnabled = false`) | Busca de origem/destino e planejamento (`plan.php`) com alternativas e pernas |
| Home | Comentada no código | Saudação, favoritos, pontos próximos, status, clima |

### Detalhe do ponto (`Presentation/StopDetail`)
- Próximas chegadas (`arrivals.php`) com contagem regressiva e card "próximo ônibus".
- Chegadas em tempo real via **Olho Vivo** (SPTrans) quando há `OLHO_VIVO_API_KEY` (`OlhoVivoTransitRepositoryDecorator`).
- Paginação de chegadas anteriores/seguintes e escolha de data/hora → **Premium**.
- Viagem (`trip.php`) com lista de paradas e mapa do trajeto (`shape.php`).
- Favoritar ponto.

### Status ferroviário (`Presentation/SystemStatus`)
- Status atual de cada linha (`metro_cptm.php`).
- Alertas de interrupção por linha via push (`rail_alert_subscriptions.php`, APNs).
- Analytics de status: histórico de 7/30 dias, distribuição, linha do tempo e mudanças (`rail_status_report.php`) → **Premium**.

### Outros
- Favoritos e locais do usuário ("Estudo" e "Personalizado"; Casa/Trabalho estão desligados por toggle).
- Modo de dados local (importação de GTFS para uso offline) em `Settings/LocalData`.
- Clima (WeatherKit), desligado por toggle.
- Widgets iOS: status ferroviário e próxima chegada.
- App do Apple Watch + complicações.
- App Intents / Siri: próximas chegadas, status ferroviário, abrir ponto.
- Deep links `duesp://status?line_id=` e `duesp://stop?stop_id=…`.
- Analytics de uso (`AppAnalyticsService`, analytics.lolados.app).
- Idiomas: pt-BR e en.

## 2. Gratuito x Pago

Fonte: `Infrastructure/Services/PremiumSubscriptionStore.swift` (`PremiumAccessGate`).

| Recurso | Plano |
| --- | --- |
| Mapa, pontos próximos, busca de pontos | Grátis |
| Próximas chegadas de um ponto (horário atual) | Grátis |
| Detalhe da viagem e trajeto no mapa | Grátis |
| Status Metrô/CPTM | Grátis |
| Alertas de interrupção ferroviária (push) | **Grátis** (`hasDisruptionAlertsAccess` retorna `true` desde o commit "notifications open for everyone") |
| Analytics de status ferroviário | **Premium** |
| Data/hora personalizada + chegadas anteriores/seguintes | **Premium** |
| Gorjetas (`app.lolados.sptrans.tip.small/medium/large`) | Opcional, não libera nada |

Assinaturas: `app.lolados.data.weekly` e `app.lolados.data.yearly`, ambas com os mesmos recursos.

> Inconsistência no iOS: a tela Premium e o README ainda listam "Notificações de interrupção" como recurso Premium (`premium.features.alerts`), mas o gate já libera para todos.

## 3. Equivalências no Android

| iOS | Android |
| --- | --- |
| SwiftUI + MVVM + Use Cases | Jetpack Compose + ViewModel + repositório (mesmas camadas) |
| URLSession + Codable | OkHttp + kotlinx.serialization |
| MapKit | osmdroid (OpenStreetMap, sem chave); Google Maps Compose é uma alternativa |
| CoreLocation | Fused Location Provider (play-services-location) |
| UserDefaults / SwiftData | DataStore |
| StoreKit 2 | Google Play Billing (mesmos IDs de produto, configurar no Play Console) |
| APNs | Firebase Cloud Messaging (o backend precisa de suporte a `platform = "android"` e envio FCM) |
| WidgetKit | Glance (App Widgets) |
| App Intents / Siri | App Shortcuts (`shortcuts.xml`) / App Actions |
| Apple Watch | Wear OS (fase futura) |

## 4. Plano de fases

1. **MVP (este commit):** projeto Compose com abas Mapa/Próximos, Status e Ajustes; detalhe do ponto com chegadas; busca de pontos; favoritos; gate Premium preparado (sem cobrança ainda).
2. **Premium:** Google Play Billing, paginação/data-hora de chegadas, tela de analytics.
3. **Alertas:** FCM + mudanças no backend (`rail_alert_subscriptions.php` aceitar `platform=android` e token FCM; envio em `processDisruptionNotifications`).
4. **Detalhe da viagem:** trajeto no mapa (`trip.php` + `shape.php`), malha ferroviária.
5. **Extras:** widgets Glance, Olho Vivo, deep links, analytics, Wear OS.
