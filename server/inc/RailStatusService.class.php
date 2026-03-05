<?php
/**
 * Rail status service (Metro + CPTM).
 *
 * - Fetches status pages
 * - Parses line status
 * - Stores snapshots in MySQL
 * - Reuses cached snapshots newer than 30 minutes
 * - Logs and emails failures (throttled to once/day/source while failing)
 */

class RailStatusLine {
    public $source;
    public $lineNumber;
    public $lineName;
    public $statusText;
    public $statusDetail;
    public $statusColor;
    public $sourceUpdatedAt;
    public $fetchedAt;
}

class RailStatusService {
    const SOURCE_METRO = 'metro';
    const SOURCE_CPTM = 'cptm';
    const NOTIFICATION_TYPE_PROBLEM = 'problem';
    const NOTIFICATION_TYPE_RECOVERY = 'recovery';

    const METRO_URL = 'https://www.metro.sp.gov.br/wp-content/themes/metrosp/direto-metro.php';
    const CPTM_API_URL = 'https://api.cptm.sp.gov.br/AppCPTM/v1/Linhas/ObterStatus';

    const CACHE_TTL_SECONDS = 1800; // 30 minutes
    const EMAIL_RETRY_SECONDS = 86400; // 1 day
    const ALERT_EMAIL = 'peantunes@gmail.com';

    private $con;
    private $timezone;

    public function __construct($con) {
        $this->con = $con;
        $this->timezone = new DateTimeZone('America/Sao_Paulo');
    }

    /**
     * Refreshes stale sources and returns latest stored status for both Metro and CPTM.
     */
    public function getLatestStatus($forceRefresh = false) {
        $this->ensureSchema();

        $sources = [self::SOURCE_METRO, self::SOURCE_CPTM];
        $refreshErrors = [];
        $refreshed = [
            self::SOURCE_METRO => false,
            self::SOURCE_CPTM => false
        ];

        if ($forceRefresh) {
            foreach ($sources as $source) {
                try {
                    $this->refreshSource($source);
                    $refreshed[$source] = true;
                } catch (Throwable $e) {
                    $this->handleFailure($source, $e->getMessage());
                    $refreshErrors[$source] = $e->getMessage();
                }
            }
        }

        $latestBySource = $this->getLatestBySources($sources);
        $metro = $latestBySource[self::SOURCE_METRO];
        $cptm = $latestBySource[self::SOURCE_CPTM];

        if ($forceRefresh) {
            $latestForNotifications = [];
            if (!empty($refreshed[self::SOURCE_METRO])) {
                $latestForNotifications[self::SOURCE_METRO] = $metro;
            }
            if (!empty($refreshed[self::SOURCE_CPTM])) {
                $latestForNotifications[self::SOURCE_CPTM] = $cptm;
            }

            try {
                if (!empty($latestForNotifications)) {
                    $this->processDisruptionNotifications($latestForNotifications);
                }
            } catch (Throwable $e) {
                error_log('[rail-status][notifications] ' . $e->getMessage());
            }
        }

        return [
            'generatedAt' => $this->nowString(),
            'cacheTtlMinutes' => (int)(self::CACHE_TTL_SECONDS / 60),
            'refreshed' => $refreshed,
            'metro' => $metro,
            'cptm' => $cptm,
            'errors' => $refreshErrors
        ];
    }

    /**
     * Script helper: refresh one source (or both) respecting cache staleness unless forced.
     */
    public function refreshForImportScript($source = 'all', $forceRefresh = false) {
        $this->ensureSchema();

        $sources = [self::SOURCE_METRO, self::SOURCE_CPTM];
        if ($source === self::SOURCE_METRO || $source === self::SOURCE_CPTM) {
            $sources = [$source];
        }

        $result = [
            'requestedSource' => $source,
            'forceRefresh' => (bool)$forceRefresh,
            'processedAt' => $this->nowString(),
            'sources' => []
        ];

        foreach ($sources as $src) {
            $didRefresh = false;
            $error = null;

            try {
                if ($forceRefresh || $this->isSourceStale($src)) {
                    $this->refreshSource($src);
                    $didRefresh = true;
                }
            } catch (Throwable $e) {
                $this->handleFailure($src, $e->getMessage());
                $error = $e->getMessage();
            }

            $latest = null;
            $result['sources'][$src] = [
                'refreshed' => $didRefresh,
                'latest' => $latest,
                'error' => $error
            ];
        }

        $latestBySource = $this->getLatestBySources($sources);
        foreach ($sources as $src) {
            $result['sources'][$src]['latest'] = $latestBySource[$src];
        }

        return $result;
    }

    /**
     * Sends one explicit test push notification to an active subscribed device.
     * This does not update disruption dedupe state.
     */
    public function sendTestNotification($installationId = null, $source = null, $lineNumber = null) {
        $this->ensureSchema();

        $normalizedInstallationId = null;
        if ($installationId !== null) {
            $normalizedInstallationId = trim((string)$installationId);
            if ($normalizedInstallationId === '') {
                $normalizedInstallationId = null;
            }
        }

        $normalizedSource = strtolower(trim((string)$source));
        if ($normalizedSource === '') {
            $normalizedSource = null;
        }
        if ($normalizedSource !== null
            && $normalizedSource !== self::SOURCE_METRO
            && $normalizedSource !== self::SOURCE_CPTM) {
            throw new InvalidArgumentException('Invalid source filter for test notification');
        }

        $normalizedLineNumber = trim((string)$lineNumber);
        if ($normalizedLineNumber === '') {
            $normalizedLineNumber = null;
        }

        $apnsConfig = $this->buildApnsConfig();
        if (empty($apnsConfig['ready'])) {
            throw new RuntimeException('APNs config is missing. Check APNS_* settings on server.');
        }

        $subscriptions = $this->fetchActiveAlertSubscriptionsForNotifications($normalizedInstallationId);
        if (empty($subscriptions)) {
            throw new RuntimeException('No active subscriptions available for test push.');
        }

        $latestBySource = $this->getLatestBySources([self::SOURCE_METRO, self::SOURCE_CPTM]);
        $latestIndex = $this->buildLatestStatusIndex($latestBySource);

        $selectedSubscription = null;
        $selectedStatus = null;
        $wantedLineKey = $normalizedLineNumber !== null ? $this->normalizeLineKey($normalizedLineNumber) : null;

        foreach ($subscriptions as $subscription) {
            $subscriptionSource = strtolower(trim((string)($subscription['source'] ?? '')));
            if ($normalizedSource !== null && $subscriptionSource !== $normalizedSource) {
                continue;
            }

            $subscriptionLineKey = $this->normalizeLineKey((string)($subscription['line_number'] ?? ''));
            if ($wantedLineKey !== null && $subscriptionLineKey !== $wantedLineKey) {
                continue;
            }

            $selectedSubscription = $subscription;
            $selectedStatus = $this->resolveLatestStatusForSubscription($subscription, $latestIndex);
            break;
        }

        if ($selectedSubscription === null) {
            throw new RuntimeException('No subscription matched the requested source/line filters.');
        }

        if ($selectedStatus === null) {
            $selectedStatus = [
                'source' => (string)($selectedSubscription['source'] ?? ''),
                'lineNumber' => (string)($selectedSubscription['line_number'] ?? ''),
                'lineName' => (string)($selectedSubscription['line_name'] ?? ''),
                'status' => 'Teste de notificacao',
                'statusDetail' => 'Disparo manual de teste via API',
                'statusColor' => 'FF9500',
                'sourceUpdatedAt' => $this->nowString()
            ];
        } else {
            $currentStatus = $this->normalizeText((string)($selectedStatus['status'] ?? ''));
            $selectedStatus['status'] = 'Teste de notificacao';
            $selectedStatus['statusDetail'] = $currentStatus !== ''
                ? ('Status atual da linha: ' . $currentStatus)
                : 'Disparo manual de teste via API';
        }

        $classification = $this->classifyStatusImpact($selectedStatus['status']);
        $sendResult = $this->sendRailStatusNotification(
            $apnsConfig,
            $selectedSubscription,
            $selectedStatus,
            self::NOTIFICATION_TYPE_PROBLEM,
            $classification
        );

        $this->insertNotificationLog(
            $selectedSubscription,
            $selectedStatus,
            self::NOTIFICATION_TYPE_PROBLEM,
            $classification,
            $sendResult
        );

        return [
            'success' => !empty($sendResult['success']),
            'statusCode' => (int)($sendResult['statusCode'] ?? 0),
            'reason' => (string)($sendResult['reason'] ?? ''),
            'messageId' => $sendResult['messageId'] ?? null,
            'target' => [
                'installationId' => $selectedSubscription['installation_id'] ?? null,
                'source' => $selectedSubscription['source'] ?? null,
                'lineNumber' => $selectedSubscription['line_number'] ?? null,
                'lineName' => $selectedSubscription['line_name'] ?? null
            ]
        ];
    }

    private function refreshSource($source) {
        $url = $this->getSourceUrl($source);
        $rawPayload = '';
        $lines = [];

        if ($source === self::SOURCE_METRO) {
            $rawPayload = $this->fetchHtml($url);
            $lines = $this->parseMetroLinesFromHtml($rawPayload);
        } else {
            $rawPayload = $this->fetchJson($url);
            $lines = $this->parseCptmLinesFromJson($rawPayload);
        }

        if (empty($lines)) {
            throw new RuntimeException("No lines parsed for source: {$source}");
        }

        $this->con->BeginTrans();
        try {
            $sourceUpdatedAt = $this->pickMostRecentSourceUpdatedAt($lines);
            $snapshotId = $this->insertSnapshot($source, $sourceUpdatedAt, $rawPayload, count($lines));
            $this->insertLines($snapshotId, $source, $lines);
            $this->markSourceSuccess($source);
            $this->con->CommitTrans();
        } catch (Throwable $e) {
            $this->con->RollBackTrans();
            throw $e;
        }
    }

    private function getSourceUrl($source) {
        if ($source === self::SOURCE_METRO) {
            return self::METRO_URL;
        }
        if ($source === self::SOURCE_CPTM) {
            return self::CPTM_API_URL;
        }
        throw new InvalidArgumentException("Unsupported source: {$source}");
    }

    private function isSourceStale($source) {
        $this->con->ExecutaPrepared(
            "SELECT MAX(fetched_at) AS latest_fetched_at FROM sp_transit_status_snapshots WHERE source = ?",
            "s",
            [$source]
        );

        $row = $this->con->Linha();
        $latestFetchedAt = $row && isset($row['latest_fetched_at']) ? $row['latest_fetched_at'] : null;

        if (empty($latestFetchedAt)) {
            return true;
        }

        $latestTimestamp = strtotime($latestFetchedAt);
        if ($latestTimestamp === false) {
            return true;
        }

        return (time() - $latestTimestamp) > self::CACHE_TTL_SECONDS;
    }

    private function fetchHtml($url) {
        if (function_exists('curl_init')) {
            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_MAXREDIRS => 5,
                CURLOPT_CONNECTTIMEOUT => 12,
                CURLOPT_TIMEOUT => 25,
                CURLOPT_ENCODING => '',
                CURLOPT_USERAGENT => 'Mozilla/5.0 (compatible; due-sp/1.0; +https://sptrans.lolados.app)',
                CURLOPT_HTTPHEADER => [
                    'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    'Accept-Language: pt-BR,pt;q=0.9,en;q=0.8'
                ]
            ]);

            $response = curl_exec($ch);
            $httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError = curl_error($ch);
            curl_close($ch);

            if ($response === false || $curlError) {
                throw new RuntimeException("HTTP request failed: {$curlError}");
            }
            if ($httpCode >= 400) {
                throw new RuntimeException("HTTP request failed with status: {$httpCode}");
            }

            return $response;
        }

        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'timeout' => 25,
                'header' => "User-Agent: Mozilla/5.0 (compatible; due-sp/1.0)\r\nAccept-Language: pt-BR,pt;q=0.9,en;q=0.8\r\n"
            ]
        ]);

        $response = @file_get_contents($url, false, $context);
        if ($response === false) {
            throw new RuntimeException("HTTP request failed for URL: {$url}");
        }

        return $response;
    }

    private function fetchJson($url) {
        if (function_exists('curl_init')) {
            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_FOLLOWLOCATION => true,
                CURLOPT_MAXREDIRS => 5,
                CURLOPT_CONNECTTIMEOUT => 12,
                CURLOPT_TIMEOUT => 25,
                CURLOPT_ENCODING => '',
                CURLOPT_USERAGENT => 'Mozilla/5.0 (compatible; due-sp/1.0; +https://sptrans.lolados.app)',
                CURLOPT_HTTPHEADER => [
                    'Accept: application/json, text/plain, */*',
                    'Accept-Language: pt-BR,pt;q=0.9,en;q=0.8'
                ]
            ]);

            $response = curl_exec($ch);
            $httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $curlError = curl_error($ch);
            curl_close($ch);

            if ($response === false || $curlError) {
                throw new RuntimeException("HTTP JSON request failed: {$curlError}");
            }
            if ($httpCode >= 400) {
                throw new RuntimeException("HTTP JSON request failed with status: {$httpCode}");
            }

            return $response;
        }

        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'timeout' => 25,
                'header' => "User-Agent: Mozilla/5.0 (compatible; due-sp/1.0)\r\nAccept: application/json\r\nAccept-Language: pt-BR,pt;q=0.9,en;q=0.8\r\n"
            ]
        ]);

        $response = @file_get_contents($url, false, $context);
        if ($response === false) {
            throw new RuntimeException("HTTP JSON request failed for URL: {$url}");
        }

        return $response;
    }

    private function parseMetroLinesFromHtml($html) {
        if (stripos((string)$html, "verify that you're not a robot") !== false) {
            throw new RuntimeException("Remote Metro source blocked automated access with anti-bot challenge");
        }

        if (!class_exists('DOMDocument')) {
            throw new RuntimeException('DOMDocument extension is not available');
        }

        $dom = new DOMDocument();
        libxml_use_internal_errors(true);
        $loaded = $dom->loadHTML('<?xml encoding="utf-8" ?>' . $html);
        libxml_clear_errors();

        if (!$loaded) {
            throw new RuntimeException("Could not parse Metro HTML");
        }

        $xpath = new DOMXPath($dom);
        $contextNode = null;

        $numberNodes = $this->queryByClass($xpath, 'linha-numero', $contextNode);
        $nameNodes = $this->queryByClass($xpath, 'linha-nome', $contextNode);
        $statusNodes = $this->queryByClass($xpath, 'linha-situacao', $contextNode);
        $infoNodes = $this->queryByClass($xpath, 'linha-info', $contextNode);
        $iconNodes = $this->queryByClass($xpath, 'linha-situacao-icon', $contextNode);

        $lineCount = min($numberNodes->length, $nameNodes->length, $statusNodes->length);
        $lines = [];

        for ($i = 0; $i < $lineCount; $i++) {
            $lineNumber = $this->normalizeText($numberNodes->item($i)->textContent ?? '');
            $lineName = $this->normalizeText($nameNodes->item($i)->textContent ?? '');
            $statusText = $this->normalizeText($statusNodes->item($i)->textContent ?? '');

            if ($lineNumber === '' && $lineName === '' && $statusText === '') {
                continue;
            }

            $infoNode = $i < $infoNodes->length ? $infoNodes->item($i) : null;
            $iconNode = $i < $iconNodes->length ? $iconNodes->item($i) : null;

            $tooltipText = $this->extractInfoTooltipText($infoNode);
            $detailText = $this->extractDetailFromInfo($tooltipText);
            if ($detailText === '') {
                $detailText = $tooltipText;
            }

            $updatedAt = $this->extractUpdatedAt($tooltipText);
            if ($updatedAt === null) {
                $statusTitle = $statusNodes->item($i)->getAttribute('title');
                $updatedAt = $this->extractUpdatedAt($statusTitle);
            }

            $statusColor = $this->extractColorFromNodeStyle($iconNode);
            if ($statusColor === null) {
                $statusColor = $this->extractColorFromNodeStyle($infoNode);
            }

            $line = new RailStatusLine();
            $line->source = self::SOURCE_METRO;
            $line->lineNumber = $lineNumber;
            $line->lineName = $lineName;
            $line->statusText = $statusText;
            $line->statusDetail = $detailText;
            $line->statusColor = $statusColor;
            $line->sourceUpdatedAt = $updatedAt;
            $lines[] = $line;
        }

        if (empty($lines)) {
            throw new RuntimeException("No line entries found in Metro HTML");
        }

        return $lines;
    }

    private function parseCptmLinesFromJson($rawJson) {
        $decoded = json_decode((string)$rawJson, true);
        if (!is_array($decoded)) {
            throw new RuntimeException('Could not decode CPTM JSON payload');
        }

        $records = [];
        $this->collectCptmLineRecords($decoded, $records);
        if (empty($records)) {
            throw new RuntimeException('No CPTM line records found in JSON payload');
        }

        $lines = [];
        foreach ($records as $record) {
            if (!is_array($record)) {
                continue;
            }

            $rawCode = $this->valueByCandidateKeysRecursive($record, [
                'Codigo',
                'CodigoLinha',
                'CdLinha',
                'Linha',
                'SiglaLinha',
                'LinhaCodigo',
                'idLinha',
                'IdLinha'
            ]);
            $lineCode = $this->normalizeCptmLineCode($rawCode);

            $metadata = $this->cptmLineMetadata($lineCode);
            $lineName = $this->normalizeText((string)$this->valueByCandidateKeysRecursive($record, [
                'Nome',
                'NomeLinha',
                'LinhaNome',
                'Descricao',
                'DescLinha'
            ]));

            if ($lineName === '' && $metadata !== null) {
                $lineName = $metadata['name'];
            }
            if ($lineName === '' && $lineCode !== '') {
                $lineName = 'Linha ' . $lineCode;
            }

            $statusText = $this->normalizeText((string)$this->valueByCandidateKeysRecursive($record, [
                'Situacao',
                'Status',
                'StatusDescricao',
                'DescricaoSituacao',
                'SituacaoOperacional',
                'Mensagem'
            ]));

            $statusDetail = $this->normalizeText((string)$this->valueByCandidateKeysRecursive($record, [
                'Descricao',
                'Mensagem',
                'Detalhe',
                'Informacao',
                'Info',
                'Observacao'
            ]));

            $rawColor = $this->valueByCandidateKeysRecursive($record, [
                'Cor',
                'CorLinha',
                'HexCor',
                'LineColor',
                'Color'
            ]);
            $lineColor = $this->normalizeHexColor($rawColor);
            if ($lineColor === null && $metadata !== null) {
                $lineColor = $metadata['color'];
            }

            $rawUpdatedAt = $this->valueByCandidateKeysRecursive($record, [
                'DataHoraAtualizacao',
                'DataAtualizacao',
                'Atualizacao',
                'AtualizadoEm',
                'DataHora',
                'Data'
            ]);
            $updatedAt = $this->parseFlexibleDateTime($rawUpdatedAt);

            if ($lineCode === '' && $lineName === '' && $statusText === '' && $statusDetail === '') {
                continue;
            }

            $line = new RailStatusLine();
            $line->source = self::SOURCE_CPTM;
            $line->lineNumber = $lineCode;
            $line->lineName = $lineName;
            $line->statusText = $statusText;
            $line->statusDetail = $statusDetail;
            $line->statusColor = $lineColor;
            $line->sourceUpdatedAt = $updatedAt;
            $lines[] = $line;
        }

        if (empty($lines)) {
            throw new RuntimeException('No parsed CPTM lines could be built from JSON payload');
        }

        $lines = $this->applyCptmPositionalFallback($lines);
        $lines = $this->deduplicateCptmLines($lines);
        return $lines;
    }

    private function collectCptmLineRecords($node, &$records) {
        if (!is_array($node)) {
            return;
        }

        $isList = $this->isListArray($node);
        if ($isList) {
            $listContainsLineLike = false;
            foreach ($node as $entry) {
                if ($this->looksLikeCptmLineRecord($entry)) {
                    $listContainsLineLike = true;
                    break;
                }
            }

            if ($listContainsLineLike) {
                foreach ($node as $entry) {
                    if ($this->looksLikeCptmLineRecord($entry)) {
                        $records[] = $entry;
                    }
                }
                return;
            }
        }

        foreach ($node as $child) {
            $this->collectCptmLineRecords($child, $records);
        }
    }

    private function isListArray($arr) {
        if (!is_array($arr)) {
            return false;
        }
        return array_keys($arr) === range(0, count($arr) - 1);
    }

    private function looksLikeCptmLineRecord($record) {
        if (!is_array($record)) {
            return false;
        }

        $lineKeys = ['Codigo', 'CodigoLinha', 'CdLinha', 'Linha', 'SiglaLinha', 'LinhaCodigo', 'idLinha', 'IdLinha'];
        $statusKeys = ['Situacao', 'Status', 'StatusDescricao', 'DescricaoSituacao', 'SituacaoOperacional', 'Mensagem'];

        $hasLine = $this->valueByCandidateKeys($record, $lineKeys) !== null;
        $hasStatus = $this->valueByCandidateKeys($record, $statusKeys) !== null;
        return $hasLine || $hasStatus;
    }

    private function valueByCandidateKeys($arr, $candidateKeys) {
        if (!is_array($arr)) {
            return null;
        }

        foreach ($arr as $key => $value) {
            foreach ($candidateKeys as $candidate) {
                if (strcasecmp((string)$key, (string)$candidate) === 0) {
                    return $value;
                }
            }
        }

        return null;
    }

    private function valueByCandidateKeysRecursive($node, $candidateKeys) {
        if (!is_array($node)) {
            return null;
        }

        $direct = $this->valueByCandidateKeys($node, $candidateKeys);
        if ($direct !== null && $direct !== '') {
            return $direct;
        }

        foreach ($node as $key => $value) {
            if (!is_array($value)) {
                continue;
            }

            $childValue = $this->valueByCandidateKeysRecursive($value, $candidateKeys);
            if ($childValue !== null && $childValue !== '') {
                return $childValue;
            }
        }

        return null;
    }

    private function normalizeCptmLineCode($rawCode) {
        $raw = $this->normalizeText((string)$rawCode);
        if ($raw === '') {
            return '';
        }

        preg_match_all('/\d+/', $raw, $matches);
        $groups = $matches[0] ?? [];
        if (!empty($groups)) {
            foreach ($groups as $group) {
                $normalized = ltrim($group, '0');
                if ($normalized === '') {
                    $normalized = '0';
                }
                if ($this->cptmLineMetadata($normalized) !== null) {
                    return $normalized;
                }
            }

            $first = ltrim($groups[0], '0');
            return $first === '' ? '0' : $first;
        }

        return $raw;
    }

    private function cptmLineMetadata($lineCode) {
        $map = [
            '7' => ['name' => 'Rubi', 'color' => '#CA016B'],
            '8' => ['name' => 'Diamante', 'color' => '#97A098'],
            '9' => ['name' => 'Esmeralda', 'color' => '#01A9A7'],
            '10' => ['name' => 'Turquesa', 'color' => '#008B8B'],
            '11' => ['name' => 'Coral', 'color' => '#F04E23'],
            '12' => ['name' => 'Safira', 'color' => '#083D8B'],
            '13' => ['name' => 'Jade', 'color' => '#00B352']
        ];

        $key = (string)$lineCode;
        return isset($map[$key]) ? $map[$key] : null;
    }

    private function normalizeHexColor($rawColor) {
        $value = $this->normalizeText((string)$rawColor);
        if ($value === '') {
            return null;
        }

        if (preg_match('/^#[0-9A-Fa-f]{3,8}$/', $value)) {
            return strtoupper($value);
        }
        if (preg_match('/^[0-9A-Fa-f]{3,8}$/', $value)) {
            return '#' . strtoupper($value);
        }

        return null;
    }

    private function parseFlexibleDateTime($rawValue) {
        if ($rawValue === null) {
            return null;
        }

        $raw = $this->normalizeText((string)$rawValue);
        if ($raw === '') {
            return null;
        }

        if (preg_match('/^\d+$/', $raw)) {
            $timestamp = (int)$raw;
            if ($timestamp > 9999999999) {
                $timestamp = (int)floor($timestamp / 1000);
            }
            if ($timestamp > 0) {
                return (new DateTimeImmutable('@' . $timestamp))
                    ->setTimezone($this->timezone)
                    ->format('Y-m-d H:i:s');
            }
        }

        $formats = [
            'd/m/Y H:i:s',
            'd/m/Y H:i',
            'Y-m-d H:i:s',
            'Y-m-d\TH:i:sP',
            'Y-m-d\TH:i:s.uP'
        ];

        foreach ($formats as $format) {
            $dt = DateTime::createFromFormat($format, $raw, $this->timezone);
            if ($dt instanceof DateTime) {
                return $dt->format('Y-m-d H:i:s');
            }
        }

        $timestamp = strtotime($raw);
        if ($timestamp !== false) {
            return (new DateTimeImmutable('@' . $timestamp))
                ->setTimezone($this->timezone)
                ->format('Y-m-d H:i:s');
        }

        return null;
    }

    private function deduplicateCptmLines($lines) {
        $byCode = [];
        foreach ($lines as $line) {
            $key = trim((string)$line->lineNumber);
            if ($key === '') {
                $key = trim((string)$line->lineName);
            }
            if ($key === '') {
                $byCode[] = $line;
                continue;
            }

            if (!isset($byCode[$key])) {
                $byCode[$key] = $line;
                continue;
            }

            $existing = $byCode[$key];
            $existingTs = $existing->sourceUpdatedAt ? strtotime($existing->sourceUpdatedAt) : false;
            $candidateTs = $line->sourceUpdatedAt ? strtotime($line->sourceUpdatedAt) : false;

            if ($candidateTs !== false && ($existingTs === false || $candidateTs >= $existingTs)) {
                $byCode[$key] = $line;
            }
        }

        $result = array_values($byCode);
        usort($result, function ($a, $b) {
            return strcmp((string)$a->lineNumber, (string)$b->lineNumber);
        });
        return $result;
    }

    private function applyCptmPositionalFallback($lines) {
        if (empty($lines)) {
            return $lines;
        }

        $allWithoutCode = true;
        foreach ($lines as $line) {
            if (trim((string)$line->lineNumber) !== '') {
                $allWithoutCode = false;
                break;
            }
        }

        if (!$allWithoutCode) {
            return $lines;
        }

        // Observed fallback when CPTM payload comes with status-only entries.
        // Keep stable mapping order for 10/11/12/13.
        $fallbackCodes = ['10', '11', '12', '13'];
        $limit = min(count($lines), count($fallbackCodes));

        for ($i = 0; $i < $limit; $i++) {
            $code = $fallbackCodes[$i];
            $metadata = $this->cptmLineMetadata($code);
            if ($metadata === null) {
                continue;
            }

            if (trim((string)$lines[$i]->lineNumber) === '') {
                $lines[$i]->lineNumber = $code;
            }
            if (trim((string)$lines[$i]->lineName) === '') {
                $lines[$i]->lineName = $metadata['name'];
            }
            if (trim((string)$lines[$i]->statusColor) === '') {
                $lines[$i]->statusColor = $metadata['color'];
            }
        }

        return $lines;
    }

    private function queryByClass($xpath, $className, $contextNode = null) {
        $classExpr = "contains(concat(' ', normalize-space(@class), ' '), ' {$className} ')";
        $query = $contextNode ? ".//*[{$classExpr}]" : "//*[{$classExpr}]";
        return $xpath->query($query, $contextNode);
    }

    private function normalizeText($text) {
        $text = html_entity_decode((string)$text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $text = preg_replace('/\s+/u', ' ', trim($text));
        return $text === null ? '' : $text;
    }

    private function extractInfoTooltipText($infoNode) {
        if (!$infoNode) {
            return '';
        }

        $candidates = [
            $infoNode->getAttribute('data-bs-title'),
            $infoNode->getAttribute('title')
        ];

        foreach ($candidates as $candidate) {
            $value = $this->normalizeText(strip_tags((string)$candidate));
            if ($value !== '') {
                return $value;
            }
        }

        return '';
    }

    private function extractDetailFromInfo($text) {
        if ($text === '') {
            return '';
        }

        if (preg_match('/\]\s*(.+?)\s*\(atualizado em/i', $text, $matches)) {
            return $this->normalizeText($matches[1]);
        }

        if (preg_match('/^(?:Metr[oô]|CPTM)\s*[-:]\s*(.+)$/iu', $text, $matches)) {
            return $this->normalizeText($matches[1]);
        }

        return $text;
    }

    private function extractUpdatedAt($text) {
        if ($text === '') {
            return null;
        }

        if (preg_match('/atualizado em\s*([0-9]{2}\/[0-9]{2}\/[0-9]{4})\s*([0-9]{2}:[0-9]{2}:[0-9]{2})/iu', $text, $matches)) {
            $dt = DateTime::createFromFormat('d/m/Y H:i:s', $matches[1] . ' ' . $matches[2], $this->timezone);
            if ($dt instanceof DateTime) {
                return $dt->format('Y-m-d H:i:s');
            }
        }

        return null;
    }

    private function extractColorFromNodeStyle($node) {
        if (!$node) {
            return null;
        }

        $style = (string)$node->getAttribute('style');
        if ($style === '') {
            return null;
        }

        if (preg_match('/background-color\s*:\s*(#[0-9A-Fa-f]{3,8})/i', $style, $matches)) {
            return strtoupper($matches[1]);
        }

        return null;
    }

    private function pickMostRecentSourceUpdatedAt($lines) {
        $latest = null;
        foreach ($lines as $line) {
            if (empty($line->sourceUpdatedAt)) {
                continue;
            }
            if ($latest === null || strtotime($line->sourceUpdatedAt) > strtotime($latest)) {
                $latest = $line->sourceUpdatedAt;
            }
        }
        return $latest;
    }

    private function insertSnapshot($source, $sourceUpdatedAt, $rawHtml, $lineCount) {
        $now = $this->nowString();
        $hash = hash('sha256', (string)$rawHtml);

        $this->con->ExecutaPrepared(
            "INSERT INTO sp_transit_status_snapshots
                (source, fetched_at, source_updated_at, line_count, raw_hash)
             VALUES (?, ?, ?, ?, ?)",
            "sssis",
            [$source, $now, $sourceUpdatedAt, (int)$lineCount, $hash]
        );

        return (int)$this->con->getId();
    }

    private function insertLines($snapshotId, $source, $lines) {
        $insertSql = "INSERT INTO sp_transit_status_lines
            (snapshot_id, source, line_number, line_name, status_text, status_detail, status_color, source_updated_at, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";

        $now = $this->nowString();
        foreach ($lines as $line) {
            $this->con->ExecutaPrepared(
                $insertSql,
                "issssssss",
                [
                    $snapshotId,
                    $source,
                    $line->lineNumber,
                    $line->lineName,
                    $line->statusText,
                    $line->statusDetail,
                    $line->statusColor,
                    $line->sourceUpdatedAt,
                    $now
                ]
            );
        }
    }

    private function markSourceSuccess($source) {
        $now = $this->nowString();
        $this->con->ExecutaPrepared(
            "INSERT INTO sp_transit_status_errors
                (source, first_failed_at, last_failed_at, last_success_at, last_email_sent_at, consecutive_failures, last_error_message)
             VALUES (?, NULL, NULL, ?, NULL, 0, NULL)
             ON DUPLICATE KEY UPDATE
                first_failed_at = NULL,
                last_failed_at = NULL,
                last_success_at = VALUES(last_success_at),
                last_email_sent_at = NULL,
                consecutive_failures = 0,
                last_error_message = NULL",
            "ss",
            [$source, $now]
        );
    }

    public function handleFailure($source, $errorMessage) {
        $errorMessage = $this->normalizeText($errorMessage);
        if ($errorMessage === '') {
            $errorMessage = 'Unknown rail status refresh error';
        }

        $now = $this->nowString();
        $this->con->ExecutaPrepared(
            "INSERT INTO sp_transit_status_errors
                (source, first_failed_at, last_failed_at, last_success_at, last_email_sent_at, consecutive_failures, last_error_message)
             VALUES (?, ?, ?, NULL, NULL, 1, ?)
             ON DUPLICATE KEY UPDATE
                first_failed_at = IFNULL(first_failed_at, VALUES(first_failed_at)),
                last_failed_at = VALUES(last_failed_at),
                consecutive_failures = consecutive_failures + 1,
                last_error_message = VALUES(last_error_message)",
            "ssss",
            [$source, $now, $now, $errorMessage]
        );

        $this->con->ExecutaPrepared(
            "SELECT first_failed_at, last_failed_at, last_email_sent_at, consecutive_failures, last_error_message
             FROM sp_transit_status_errors
             WHERE source = ?",
            "s",
            [$source]
        );
        $row = $this->con->Linha();

        error_log("[rail-status][{$source}] {$errorMessage}");

        $lastEmailSentAt = $row && isset($row['last_email_sent_at']) ? $row['last_email_sent_at'] : null;
        if ($this->shouldSendEmail($lastEmailSentAt)) {
            $subject = "[due-sp] Rail status fetch error: {$source}";
            $bodyLines = [
                "Source: {$source}",
                "Error: {$errorMessage}",
                "First failure: " . ($row['first_failed_at'] ?? $now),
                "Last failure: " . ($row['last_failed_at'] ?? $now),
                "Consecutive failures: " . ((int)($row['consecutive_failures'] ?? 1)),
                "Server time: {$now}"
            ];
            $body = implode("\n", $bodyLines);
            $headers = "From: no-reply@sptrans.lolados.app\r\nContent-Type: text/plain; charset=UTF-8";

            $sent = @mail(self::ALERT_EMAIL, $subject, $body, $headers);
            if ($sent) {
                $this->con->ExecutaPrepared(
                    "UPDATE sp_transit_status_errors SET last_email_sent_at = ? WHERE source = ?",
                    "ss",
                    [$now, $source]
                );
            } else {
                error_log("[rail-status][{$source}] Email notification failed");
            }
        }
    }

    private function shouldSendEmail($lastEmailSentAt) {
        if (empty($lastEmailSentAt)) {
            return true;
        }
        $lastSent = strtotime($lastEmailSentAt);
        if ($lastSent === false) {
            return true;
        }
        return (time() - $lastSent) >= self::EMAIL_RETRY_SECONDS;
    }

    private function getLatestBySource($source) {
        $batch = $this->getLatestBySources([$source]);
        return isset($batch[$source]) ? $batch[$source] : [
            'source' => $source,
            'available' => false,
            'count' => 0,
            'lastFetchedAt' => null,
            'lastSourceUpdatedAt' => null,
            'lines' => []
        ];
    }

    private function getLatestBySources($sources) {
        $normalized = [];
        foreach ((array)$sources as $source) {
            $value = strtolower(trim((string)$source));
            if ($value !== self::SOURCE_METRO && $value !== self::SOURCE_CPTM) {
                continue;
            }
            $normalized[$value] = true;
        }

        $sourcesList = array_keys($normalized);
        if (empty($sourcesList)) {
            return [];
        }

        $resultBySource = [];
        foreach ($sourcesList as $source) {
            $resultBySource[$source] = [
                'source' => $source,
                'available' => false,
                'count' => 0,
                'lastFetchedAt' => null,
                'lastSourceUpdatedAt' => null,
                'lines' => []
            ];
        }

        $placeholders = implode(', ', array_fill(0, count($sourcesList), '?'));
        $types = str_repeat('s', count($sourcesList));

        $this->con->ExecutaPrepared(
            "SELECT s.snapshot_id,
                    s.source,
                    s.fetched_at,
                    s.source_updated_at,
                    l.line_number,
                    l.line_name,
                    l.status_text,
                    l.status_detail,
                    l.status_color,
                    l.source_updated_at AS line_source_updated_at
             FROM sp_transit_status_snapshots s
             INNER JOIN (
                 SELECT source, MAX(snapshot_id) AS snapshot_id
                 FROM sp_transit_status_snapshots
                 WHERE source IN ({$placeholders})
                 GROUP BY source
             ) latest ON latest.snapshot_id = s.snapshot_id
             LEFT JOIN sp_transit_status_lines l ON l.snapshot_id = s.snapshot_id
             ORDER BY s.source, l.line_number, l.line_name",
            $types,
            $sourcesList
        );

        $snapshotSeen = [];

        while ($rs = $this->con->Linha()) {
            $source = strtolower(trim((string)($rs['source'] ?? '')));
            if ($source === '' || !isset($resultBySource[$source])) {
                continue;
            }

            if (!isset($snapshotSeen[$source])) {
                $snapshotSeen[$source] = true;
                $resultBySource[$source]['available'] = true;
                $resultBySource[$source]['lastFetchedAt'] = $rs['fetched_at'] ?? null;
                $resultBySource[$source]['lastSourceUpdatedAt'] = $rs['source_updated_at'] ?? null;
            }

            if (!isset($rs['line_number']) || $rs['line_number'] === null) {
                continue;
            }

            $resultBySource[$source]['lines'][] = [
                'lineNumber' => $rs['line_number'] ?? '',
                'lineName' => $rs['line_name'] ?? '',
                'status' => $rs['status_text'] ?? '',
                'statusDetail' => $rs['status_detail'] ?? '',
                'statusColor' => $rs['status_color'] ?? '',
                'sourceUpdatedAt' => $rs['line_source_updated_at'] ?? null
            ];
        }

        foreach ($resultBySource as $sourceKey => $payload) {
            $resultBySource[$sourceKey]['count'] = count($payload['lines']);
        }

        return $resultBySource;
    }

    /**
     * Returns historical report data for rail line statuses.
     *
     * @param int $periodDays Allowed values: 7, 14, 30
     * @param string|null $sourceFilter Optional: metro|cptm
     * @param string|null $lineNumberFilter Optional line number filter
     * @return array
     */
    public function getHistoricalReport($periodDays = 7, $sourceFilter = null, $lineNumberFilter = null) {
        $this->ensureSchema();

        $days = $this->normalizePeriodDays($periodDays);

        $source = strtolower(trim((string)$sourceFilter));
        if ($source === '') {
            $source = null;
        }
        if ($source !== null && $source !== self::SOURCE_METRO && $source !== self::SOURCE_CPTM) {
            throw new InvalidArgumentException('Invalid source filter. Allowed values: metro, cptm');
        }

        $lineNumber = trim((string)$lineNumberFilter);
        if ($lineNumber === '') {
            $lineNumber = null;
        }

        $endAt = new DateTimeImmutable('now', $this->timezone);
        $startAt = $endAt->sub(new DateInterval('P' . $days . 'D'));

        $rows = $this->fetchHistoricalRows(
            $startAt->format('Y-m-d H:i:s'),
            $source,
            $lineNumber
        );

        return $this->buildHistoricalReportPayload(
            $rows,
            $days,
            $startAt,
            $endAt,
            $source,
            $lineNumber
        );
    }

    private function normalizePeriodDays($periodDays) {
        $days = (int)$periodDays;
        if (!in_array($days, [7, 14, 30], true)) {
            throw new InvalidArgumentException('Invalid period_days. Allowed values: 7, 14, 30');
        }
        return $days;
    }

    private function fetchHistoricalRows($periodStartAt, $sourceFilter = null, $lineNumberFilter = null) {
        $sql = "
            SELECT
                l.line_id,
                l.source,
                l.line_number,
                l.line_name,
                l.status_text,
                l.status_detail,
                l.status_color,
                l.source_updated_at,
                s.fetched_at
            FROM sp_transit_status_lines l
            INNER JOIN sp_transit_status_snapshots s ON s.snapshot_id = l.snapshot_id
            WHERE s.fetched_at >= ?
        ";
        $types = 's';
        $params = [$periodStartAt];

        if ($sourceFilter !== null) {
            $sql .= " AND l.source = ?";
            $types .= 's';
            $params[] = $sourceFilter;
        }

        if ($lineNumberFilter !== null) {
            $sql .= " AND l.line_number = ?";
            $types .= 's';
            $params[] = $lineNumberFilter;
        }

        $sql .= " ORDER BY l.source, l.line_number, l.line_name, s.fetched_at ASC, l.line_id ASC";

        $this->con->ExecutaPrepared($sql, $types, $params);

        $rows = [];
        while ($row = $this->con->Linha()) {
            $rows[] = $row;
        }

        return $rows;
    }

    private function buildHistoricalReportPayload(
        $rows,
        $days,
        $startAt,
        $endAt,
        $sourceFilter = null,
        $lineNumberFilter = null
    ) {
        $linesByKey = [];
        $totals = [
            'sampleCount' => 0,
            'impactSampleCount' => 0,
            'changeCount' => 0
        ];
        $statusCatalog = [];

        foreach ($rows as $row) {
            $source = strtolower(trim((string)($row['source'] ?? '')));
            if ($source === '') {
                continue;
            }

            $lineNumber = trim((string)($row['line_number'] ?? ''));
            $lineName = $this->normalizeText((string)($row['line_name'] ?? ''));
            $statusText = $this->normalizeText((string)($row['status_text'] ?? ''));
            if ($statusText === '') {
                $statusText = 'Status indisponível';
            }

            $statusDetail = $this->normalizeText((string)($row['status_detail'] ?? ''));
            $statusColor = $this->normalizeHexColor((string)($row['status_color'] ?? ''));
            $eventAt = $row['source_updated_at'] ?? null;
            if (empty($eventAt)) {
                $eventAt = $row['fetched_at'] ?? null;
            }
            if (empty($eventAt)) {
                continue;
            }

            $lineKey = $source . '|' . $lineNumber . '|' . $lineName;
            if (!isset($linesByKey[$lineKey])) {
                $lineIdSlug = $lineNumber !== '' ? $lineNumber : preg_replace('/[^a-z0-9]+/i', '-', strtolower($lineName));
                $lineIdSlug = trim((string)$lineIdSlug, '-');
                if ($lineIdSlug === '') {
                    $lineIdSlug = 'unknown';
                }

                $linesByKey[$lineKey] = [
                    'lineId' => $source . '-' . $lineIdSlug,
                    'source' => $source,
                    'lineNumber' => $lineNumber,
                    'lineName' => $lineName,
                    'lineColor' => $this->lineColorHex($source, $lineNumber, $statusColor),
                    'sampleCount' => 0,
                    'impactSampleCount' => 0,
                    'impactRatio' => 0.0,
                    'changeCount' => 0,
                    'currentStatus' => null,
                    'statusDistribution' => [],
                    'dailyTimeline' => [],
                    'statusChanges' => [],
                    '_statusCounts' => [],
                    '_daily' => [],
                    '_lastStatusNormalized' => null,
                    '_lastStatusText' => null
                ];
            }

            $classification = $this->classifyStatusImpact($statusText);
            $day = substr((string)$eventAt, 0, 10);

            $line = &$linesByKey[$lineKey];
            $line['sampleCount']++;
            $totals['sampleCount']++;

            if ($classification['impactingUser']) {
                $line['impactSampleCount']++;
                $totals['impactSampleCount']++;
            }

            if (!isset($line['_statusCounts'][$statusText])) {
                $line['_statusCounts'][$statusText] = [
                    'status' => $statusText,
                    'count' => 0,
                    'impactingUser' => $classification['impactingUser'],
                    'impactLevel' => $classification['impactLevel'],
                    'impactScore' => $classification['impactScore']
                ];
            }
            $line['_statusCounts'][$statusText]['count']++;

            if (!isset($statusCatalog[$statusText])) {
                $statusCatalog[$statusText] = [
                    'status' => $statusText,
                    'count' => 0,
                    'impactingUser' => $classification['impactingUser'],
                    'impactLevel' => $classification['impactLevel'],
                    'impactScore' => $classification['impactScore']
                ];
            }
            $statusCatalog[$statusText]['count']++;

            if ($day !== '') {
                if (!isset($line['_daily'][$day])) {
                    $line['_daily'][$day] = [
                        'date' => $day,
                        'sampleCount' => 0,
                        'impactSampleCount' => 0,
                        'impactRatio' => 0.0,
                        'changeCount' => 0,
                        'dominantStatus' => '',
                        '_statusCounts' => []
                    ];
                }

                $line['_daily'][$day]['sampleCount']++;
                if ($classification['impactingUser']) {
                    $line['_daily'][$day]['impactSampleCount']++;
                }
                if (!isset($line['_daily'][$day]['_statusCounts'][$statusText])) {
                    $line['_daily'][$day]['_statusCounts'][$statusText] = 0;
                }
                $line['_daily'][$day]['_statusCounts'][$statusText]++;
            }

            $isStatusChanged = $line['_lastStatusNormalized'] !== null
                && $line['_lastStatusNormalized'] !== $classification['normalizedStatus'];

            if ($isStatusChanged) {
                $line['changeCount']++;
                $totals['changeCount']++;

                $line['statusChanges'][] = [
                    'at' => $eventAt,
                    'fromStatus' => $line['_lastStatusText'],
                    'toStatus' => $statusText,
                    'impactingUser' => $classification['impactingUser'],
                    'impactLevel' => $classification['impactLevel'],
                    'impactScore' => $classification['impactScore']
                ];

                if ($day !== '' && isset($line['_daily'][$day])) {
                    $line['_daily'][$day]['changeCount']++;
                }
            }

            $line['_lastStatusNormalized'] = $classification['normalizedStatus'];
            $line['_lastStatusText'] = $statusText;
            $line['currentStatus'] = [
                'status' => $statusText,
                'statusDetail' => $statusDetail,
                'statusColor' => $statusColor !== null ? ltrim($statusColor, '#') : '',
                'at' => $eventAt,
                'impactingUser' => $classification['impactingUser'],
                'impactLevel' => $classification['impactLevel'],
                'impactScore' => $classification['impactScore']
            ];
            unset($line);
        }

        $lines = array_values($linesByKey);
        foreach ($lines as &$line) {
            if ($line['sampleCount'] > 0) {
                $line['impactRatio'] = round($line['impactSampleCount'] / $line['sampleCount'], 4);
            }

            $distribution = array_values($line['_statusCounts']);
            usort($distribution, function ($a, $b) {
                if ((int)$a['count'] === (int)$b['count']) {
                    return strcmp((string)$a['status'], (string)$b['status']);
                }
                return ((int)$b['count'] <=> (int)$a['count']);
            });
            foreach ($distribution as &$entry) {
                $entry['ratio'] = $line['sampleCount'] > 0 ? round($entry['count'] / $line['sampleCount'], 4) : 0.0;
            }
            unset($entry);
            $line['statusDistribution'] = $distribution;

            $daily = array_values($line['_daily']);
            usort($daily, function ($a, $b) {
                return strcmp((string)$a['date'], (string)$b['date']);
            });
            foreach ($daily as &$dayEntry) {
                $dayEntry['impactRatio'] = $dayEntry['sampleCount'] > 0
                    ? round($dayEntry['impactSampleCount'] / $dayEntry['sampleCount'], 4)
                    : 0.0;

                $dominantStatus = '';
                $dominantCount = -1;
                foreach ($dayEntry['_statusCounts'] as $status => $count) {
                    if ((int)$count > $dominantCount) {
                        $dominantStatus = (string)$status;
                        $dominantCount = (int)$count;
                    }
                }
                $dayEntry['dominantStatus'] = $dominantStatus;
                unset($dayEntry['_statusCounts']);
            }
            unset($dayEntry);
            $line['dailyTimeline'] = $daily;

            unset($line['_statusCounts']);
            unset($line['_daily']);
            unset($line['_lastStatusNormalized']);
            unset($line['_lastStatusText']);
        }
        unset($line);

        usort($lines, function ($a, $b) {
            if ((float)$a['impactRatio'] === (float)$b['impactRatio']) {
                if ((int)$a['changeCount'] === (int)$b['changeCount']) {
                    if ((string)$a['source'] === (string)$b['source']) {
                        $lineA = (string)$a['lineNumber'];
                        $lineB = (string)$b['lineNumber'];
                        $numA = preg_replace('/\D+/', '', $lineA);
                        $numB = preg_replace('/\D+/', '', $lineB);
                        if ($numA !== '' && $numB !== '' && (int)$numA !== (int)$numB) {
                            return ((int)$numA <=> (int)$numB);
                        }
                        return strcmp($lineA, $lineB);
                    }
                    return strcmp((string)$a['source'], (string)$b['source']);
                }
                return ((int)$b['changeCount'] <=> (int)$a['changeCount']);
            }
            return ((float)$b['impactRatio'] <=> (float)$a['impactRatio']);
        });

        $catalog = array_values($statusCatalog);
        usort($catalog, function ($a, $b) {
            if ((int)$a['count'] === (int)$b['count']) {
                return strcmp((string)$a['status'], (string)$b['status']);
            }
            return ((int)$b['count'] <=> (int)$a['count']);
        });

        $impactRatio = $totals['sampleCount'] > 0
            ? round($totals['impactSampleCount'] / $totals['sampleCount'], 4)
            : 0.0;

        return [
            'generatedAt' => $this->nowString(),
            'periodDays' => $days,
            'startAt' => $startAt->format('Y-m-d H:i:s'),
            'endAt' => $endAt->format('Y-m-d H:i:s'),
            'filters' => [
                'source' => $sourceFilter,
                'lineNumber' => $lineNumberFilter
            ],
            'totals' => [
                'sampleCount' => $totals['sampleCount'],
                'impactSampleCount' => $totals['impactSampleCount'],
                'impactRatio' => $impactRatio,
                'changeCount' => $totals['changeCount'],
                'lineCount' => count($lines)
            ],
            'statusCatalog' => $catalog,
            'lines' => $lines
        ];
    }

    private function lineColorHex($source, $lineNumber, $fallbackHex = null) {
        $normalizedLine = trim((string)$lineNumber);

        $metroMap = [
            '1' => '0455A1',
            '2' => '007E5E',
            '3' => 'EE372F',
            '4' => 'FFD700',
            '5' => '9B3894',
            '15' => 'A9A9A9'
        ];

        $cptmMap = [
            '7' => 'CA016B',
            '8' => '97A098',
            '9' => '01A9A7',
            '10' => '008B8B',
            '11' => 'F04E23',
            '12' => '083D8B',
            '13' => '00B352'
        ];

        if ($source === self::SOURCE_METRO && isset($metroMap[$normalizedLine])) {
            return $metroMap[$normalizedLine];
        }
        if ($source === self::SOURCE_CPTM && isset($cptmMap[$normalizedLine])) {
            return $cptmMap[$normalizedLine];
        }

        $normalizedFallback = $this->normalizeHexColor((string)$fallbackHex);
        if ($normalizedFallback !== null) {
            return ltrim($normalizedFallback, '#');
        }

        return '64748B';
    }

    private function normalizeStatusForMatch($statusText) {
        $normalized = $this->normalizeText((string)$statusText);
        if ($normalized === '') {
            return '';
        }

        $ascii = @iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $normalized);
        if ($ascii !== false) {
            $normalized = $ascii;
        }

        $normalized = strtolower($normalized);
        $normalized = preg_replace('/\s+/u', ' ', $normalized);
        return trim((string)$normalized);
    }

    private function classifyStatusImpact($statusText) {
        $normalized = $this->normalizeStatusForMatch($statusText);

        $exactMap = [
            'operacao normal' => ['impactingUser' => false, 'impactLevel' => 'none', 'impactScore' => 0],
            'operacao encerrada' => ['impactingUser' => false, 'impactLevel' => 'none', 'impactScore' => 0],
            'operacoes encerradas' => ['impactingUser' => false, 'impactLevel' => 'none', 'impactScore' => 0],
            'operacao especial' => ['impactingUser' => false, 'impactLevel' => 'none', 'impactScore' => 0],
            'paralisada' => ['impactingUser' => true, 'impactLevel' => 'high', 'impactScore' => 2],
            'velocidade reduzida' => ['impactingUser' => true, 'impactLevel' => 'low', 'impactScore' => 1]
        ];

        if (isset($exactMap[$normalized])) {
            return array_merge(['normalizedStatus' => $normalized], $exactMap[$normalized]);
        }

        $highImpactTerms = [
            'paralisad', 'interrompid', 'suspens', 'inoperante', 'sem operacao',
            'indisponivel', 'falha grave', 'fora de servico'
        ];
        foreach ($highImpactTerms as $term) {
            if (strpos($normalized, $term) !== false) {
                return [
                    'normalizedStatus' => $normalized,
                    'impactingUser' => true,
                    'impactLevel' => 'high',
                    'impactScore' => 2
                ];
            }
        }

        $lowImpactTerms = [
            'velocidade reduzida', 'atencao', 'parcial', 'restricao', 'lento', 'lentidao',
            'desvio', 'intermitente', 'manutencao', 'interferencia', 'oscilacao',
            'atraso', 'monitorad', 'alerta'
        ];
        foreach ($lowImpactTerms as $term) {
            if (strpos($normalized, $term) !== false) {
                return [
                    'normalizedStatus' => $normalized,
                    'impactingUser' => true,
                    'impactLevel' => 'low',
                    'impactScore' => 1
                ];
            }
        }

        $nonImpactTerms = ['normal', 'encerrad', 'operacao especial', 'especial'];
        foreach ($nonImpactTerms as $term) {
            if (strpos($normalized, $term) !== false) {
                return [
                    'normalizedStatus' => $normalized,
                    'impactingUser' => false,
                    'impactLevel' => 'none',
                    'impactScore' => 0
                ];
            }
        }

        return [
            'normalizedStatus' => $normalized,
            'impactingUser' => true,
            'impactLevel' => 'low',
            'impactScore' => 1
        ];
    }

    private function processDisruptionNotifications($latestBySource) {
        $subscriptions = $this->fetchActiveAlertSubscriptionsForNotifications();
        if (empty($subscriptions)) {
            return;
        }

        $apnsConfig = $this->buildApnsConfig();
        if (!$apnsConfig['ready']) {
            error_log('[rail-status][notifications] APNs configuration is missing or invalid; skipping sends');
            return;
        }

        $latestIndex = $this->buildLatestStatusIndex($latestBySource);
        if (empty($latestIndex['byNumber']) && empty($latestIndex['byName'])) {
            return;
        }

        foreach ($subscriptions as $subscription) {
            $statusRow = $this->resolveLatestStatusForSubscription($subscription, $latestIndex);
            if ($statusRow === null) {
                continue;
            }

            $classification = $this->classifyStatusImpact($statusRow['status']);
            $now = $this->nowString();

            $isProblemOpen = ((int)($subscription['is_problem_open'] ?? 0)) === 1;
            $problemNotifiedAt = $subscription['problem_notified_at'] ?? null;
            $lastRecoverySentAt = $subscription['last_recovery_sent_at'] ?? null;
            $lastProblemStatus = $subscription['last_problem_status_text'] ?? null;
            $lastProblemNormalized = $subscription['last_problem_normalized'] ?? null;

            if (!empty($classification['impactingUser'])) {
                if ($isProblemOpen) {
                    $this->upsertDeliveryState([
                        'deviceId' => (int)$subscription['device_id'],
                        'lineIdKey' => (string)$subscription['line_id_key'],
                        'lastStatusText' => $statusRow['status'],
                        'lastStatusNormalized' => $classification['normalizedStatus'],
                        'isProblemOpen' => 1,
                        'lastProblemStatus' => $lastProblemStatus,
                        'lastProblemNormalized' => $lastProblemNormalized,
                        'problemNotifiedAt' => $problemNotifiedAt,
                        'lastRecoverySentAt' => $lastRecoverySentAt
                    ]);
                    continue;
                }

                $sendResult = $this->sendRailStatusNotification(
                    $apnsConfig,
                    $subscription,
                    $statusRow,
                    self::NOTIFICATION_TYPE_PROBLEM,
                    $classification
                );

                $this->insertNotificationLog(
                    $subscription,
                    $statusRow,
                    self::NOTIFICATION_TYPE_PROBLEM,
                    $classification,
                    $sendResult
                );

                if (!empty($sendResult['success'])) {
                    $this->upsertDeliveryState([
                        'deviceId' => (int)$subscription['device_id'],
                        'lineIdKey' => (string)$subscription['line_id_key'],
                        'lastStatusText' => $statusRow['status'],
                        'lastStatusNormalized' => $classification['normalizedStatus'],
                        'isProblemOpen' => 1,
                        'lastProblemStatus' => $statusRow['status'],
                        'lastProblemNormalized' => $classification['normalizedStatus'],
                        'problemNotifiedAt' => $now,
                        'lastRecoverySentAt' => $lastRecoverySentAt
                    ]);
                } else {
                    if ($this->isApnsInvalidTokenReason($sendResult['reason'] ?? null)) {
                        $this->disableDevicePushForInvalidToken((int)$subscription['device_id']);
                    }
                    $this->upsertDeliveryState([
                        'deviceId' => (int)$subscription['device_id'],
                        'lineIdKey' => (string)$subscription['line_id_key'],
                        'lastStatusText' => $statusRow['status'],
                        'lastStatusNormalized' => $classification['normalizedStatus'],
                        'isProblemOpen' => 0,
                        'lastProblemStatus' => null,
                        'lastProblemNormalized' => null,
                        'problemNotifiedAt' => null,
                        'lastRecoverySentAt' => $lastRecoverySentAt
                    ]);
                }
                continue;
            }

            if (!$isProblemOpen) {
                $this->upsertDeliveryState([
                    'deviceId' => (int)$subscription['device_id'],
                    'lineIdKey' => (string)$subscription['line_id_key'],
                    'lastStatusText' => $statusRow['status'],
                    'lastStatusNormalized' => $classification['normalizedStatus'],
                    'isProblemOpen' => 0,
                    'lastProblemStatus' => null,
                    'lastProblemNormalized' => null,
                    'problemNotifiedAt' => null,
                    'lastRecoverySentAt' => $lastRecoverySentAt
                ]);
                continue;
            }

            $canSendRecovery = $this->shouldSendRecoveryNotification($problemNotifiedAt, $now);
            if ($canSendRecovery) {
                $sendResult = $this->sendRailStatusNotification(
                    $apnsConfig,
                    $subscription,
                    $statusRow,
                    self::NOTIFICATION_TYPE_RECOVERY,
                    $classification
                );

                $this->insertNotificationLog(
                    $subscription,
                    $statusRow,
                    self::NOTIFICATION_TYPE_RECOVERY,
                    $classification,
                    $sendResult
                );

                if (!empty($sendResult['success'])) {
                    $this->upsertDeliveryState([
                        'deviceId' => (int)$subscription['device_id'],
                        'lineIdKey' => (string)$subscription['line_id_key'],
                        'lastStatusText' => $statusRow['status'],
                        'lastStatusNormalized' => $classification['normalizedStatus'],
                        'isProblemOpen' => 0,
                        'lastProblemStatus' => null,
                        'lastProblemNormalized' => null,
                        'problemNotifiedAt' => null,
                        'lastRecoverySentAt' => $now
                    ]);
                } else {
                    $this->upsertDeliveryState([
                        'deviceId' => (int)$subscription['device_id'],
                        'lineIdKey' => (string)$subscription['line_id_key'],
                        'lastStatusText' => $statusRow['status'],
                        'lastStatusNormalized' => $classification['normalizedStatus'],
                        'isProblemOpen' => 1,
                        'lastProblemStatus' => $lastProblemStatus,
                        'lastProblemNormalized' => $lastProblemNormalized,
                        'problemNotifiedAt' => $problemNotifiedAt,
                        'lastRecoverySentAt' => $lastRecoverySentAt
                    ]);
                }
                continue;
            }

            // Out-of-day or orphaned open incident: close silently without sending "normal".
            $this->upsertDeliveryState([
                'deviceId' => (int)$subscription['device_id'],
                'lineIdKey' => (string)$subscription['line_id_key'],
                'lastStatusText' => $statusRow['status'],
                'lastStatusNormalized' => $classification['normalizedStatus'],
                'isProblemOpen' => 0,
                'lastProblemStatus' => null,
                'lastProblemNormalized' => null,
                'problemNotifiedAt' => null,
                'lastRecoverySentAt' => $lastRecoverySentAt
            ]);
        }
    }

    private function fetchActiveAlertSubscriptionsForNotifications($installationId = null) {
        $sql = "
            SELECT
                s.device_id,
                s.line_id_key,
                s.source,
                s.line_number,
                s.line_name,
                d.installation_id,
                d.apns_token,
                d.notifications_enabled,
                d.authorization_status,
                st.is_problem_open,
                st.problem_notified_at,
                st.last_problem_status_text,
                st.last_problem_normalized,
                st.last_recovery_sent_at
            FROM sp_transit_alert_line_subscriptions s
            INNER JOIN sp_transit_alert_devices d
                ON d.device_id = s.device_id
            LEFT JOIN sp_transit_alert_delivery_state st
                ON st.device_id = s.device_id
               AND st.line_id_key = s.line_id_key
            WHERE s.is_active = 1
              AND d.notifications_enabled = 1
              AND d.platform = 'ios'
              AND d.apns_token IS NOT NULL
              AND d.apns_token <> ''
              AND (d.authorization_status IS NULL OR d.authorization_status <> 'denied')
        ";
        $params = [];
        $types = '';
        $normalizedInstallationId = $installationId !== null ? trim((string)$installationId) : '';
        if ($normalizedInstallationId !== '') {
            $sql .= " AND d.installation_id = ?";
            $types .= 's';
            $params[] = $normalizedInstallationId;
        }
        $sql .= " ORDER BY s.device_id, s.source, s.line_number, s.line_name";

        if (!empty($params)) {
            $this->con->ExecutaPrepared($sql, $types, $params);
        } else {
            $this->con->Executa($sql);
        }

        $rows = [];
        while ($row = $this->con->Linha()) {
            $rows[] = $row;
        }
        return $rows;
    }

    private function buildLatestStatusIndex($latestBySource) {
        $index = [
            'byNumber' => [],
            'byName' => []
        ];

        $sources = [self::SOURCE_METRO, self::SOURCE_CPTM];
        foreach ($sources as $source) {
            $sourcePayload = is_array($latestBySource) && isset($latestBySource[$source]) && is_array($latestBySource[$source])
                ? $latestBySource[$source]
                : null;

            if (!$sourcePayload || empty($sourcePayload['lines']) || !is_array($sourcePayload['lines'])) {
                continue;
            }

            foreach ($sourcePayload['lines'] as $line) {
                if (!is_array($line)) {
                    continue;
                }

                $lineNumber = trim((string)($line['lineNumber'] ?? ''));
                $lineName = $this->normalizeText((string)($line['lineName'] ?? ''));
                $statusText = $this->normalizeText((string)($line['status'] ?? ''));
                $statusDetail = $this->normalizeText((string)($line['statusDetail'] ?? ''));
                $statusColor = $this->normalizeHexColor((string)($line['statusColor'] ?? ''));
                $sourceUpdatedAt = $line['sourceUpdatedAt'] ?? null;

                if ($statusText === '') {
                    continue;
                }

                $entry = [
                    'source' => $source,
                    'lineNumber' => $lineNumber,
                    'lineName' => $lineName,
                    'status' => $statusText,
                    'statusDetail' => $statusDetail,
                    'statusColor' => $statusColor !== null ? ltrim($statusColor, '#') : '',
                    'sourceUpdatedAt' => $sourceUpdatedAt
                ];

                $numberKey = $this->normalizeLineKey($lineNumber);
                if ($numberKey !== '') {
                    $index['byNumber'][$source . '|' . $numberKey] = $entry;
                }

                $nameKey = $this->normalizeStatusForMatch($lineName);
                if ($nameKey !== '') {
                    $index['byName'][$source . '|' . $nameKey] = $entry;
                }
            }
        }

        return $index;
    }

    private function resolveLatestStatusForSubscription($subscription, $latestIndex) {
        $source = strtolower(trim((string)($subscription['source'] ?? '')));
        if ($source !== self::SOURCE_METRO && $source !== self::SOURCE_CPTM) {
            return null;
        }

        $lineNumberKey = $this->normalizeLineKey((string)($subscription['line_number'] ?? ''));
        if ($lineNumberKey !== '') {
            $mapKey = $source . '|' . $lineNumberKey;
            if (isset($latestIndex['byNumber'][$mapKey])) {
                return $latestIndex['byNumber'][$mapKey];
            }
        }

        $lineNameKey = $this->normalizeStatusForMatch((string)($subscription['line_name'] ?? ''));
        if ($lineNameKey !== '') {
            $mapKey = $source . '|' . $lineNameKey;
            if (isset($latestIndex['byName'][$mapKey])) {
                return $latestIndex['byName'][$mapKey];
            }
        }

        return null;
    }

    private function normalizeLineKey($value) {
        $normalized = $this->normalizeStatusForMatch($value);
        if ($normalized === '') {
            return '';
        }
        $normalized = preg_replace('/[^a-z0-9]+/', '', $normalized);
        return trim((string)$normalized);
    }

    private function shouldSendRecoveryNotification($problemNotifiedAt, $now) {
        if (empty($problemNotifiedAt) || empty($now)) {
            return false;
        }
        return $this->isSameLocalDay($problemNotifiedAt, $now);
    }

    private function isSameLocalDay($firstDateTime, $secondDateTime) {
        if (empty($firstDateTime) || empty($secondDateTime)) {
            return false;
        }
        return substr((string)$firstDateTime, 0, 10) === substr((string)$secondDateTime, 0, 10);
    }

    private function upsertDeliveryState($state) {
        $deviceId = (int)($state['deviceId'] ?? 0);
        $lineIdKey = trim((string)($state['lineIdKey'] ?? ''));
        if ($deviceId <= 0 || $lineIdKey === '') {
            return;
        }

        $now = $this->nowString();

        $this->con->ExecutaPrepared(
            "INSERT INTO sp_transit_alert_delivery_state
                (device_id, line_id_key, last_status_text, last_status_normalized, is_problem_open, last_problem_status_text, last_problem_normalized, problem_notified_at, last_recovery_sent_at, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE
                last_status_text = VALUES(last_status_text),
                last_status_normalized = VALUES(last_status_normalized),
                is_problem_open = VALUES(is_problem_open),
                last_problem_status_text = VALUES(last_problem_status_text),
                last_problem_normalized = VALUES(last_problem_normalized),
                problem_notified_at = VALUES(problem_notified_at),
                last_recovery_sent_at = VALUES(last_recovery_sent_at),
                updated_at = VALUES(updated_at)",
            "isssissssss",
            [
                $deviceId,
                $lineIdKey,
                $state['lastStatusText'] ?? null,
                $state['lastStatusNormalized'] ?? null,
                (int)($state['isProblemOpen'] ?? 0),
                $state['lastProblemStatus'] ?? null,
                $state['lastProblemNormalized'] ?? null,
                $state['problemNotifiedAt'] ?? null,
                $state['lastRecoverySentAt'] ?? null,
                $now,
                $now
            ]
        );
    }

    private function insertNotificationLog($subscription, $statusRow, $notificationType, $classification, $sendResult) {
        $statusCode = isset($sendResult['statusCode']) ? (int)$sendResult['statusCode'] : 0;

        $this->con->ExecutaPrepared(
            "INSERT INTO sp_transit_alert_notification_log
                (device_id, line_id_key, source, line_number, line_name, notification_type, status_text, status_detail, impact_level, sent_success, provider_response_code, provider_response_reason, provider_message_id, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            "issssssssiisss",
            [
                (int)($subscription['device_id'] ?? 0),
                (string)($subscription['line_id_key'] ?? ''),
                (string)($subscription['source'] ?? ''),
                (string)($subscription['line_number'] ?? ''),
                (string)($subscription['line_name'] ?? ''),
                (string)$notificationType,
                (string)($statusRow['status'] ?? ''),
                (string)($statusRow['statusDetail'] ?? ''),
                (string)($classification['impactLevel'] ?? 'none'),
                !empty($sendResult['success']) ? 1 : 0,
                $statusCode,
                isset($sendResult['reason']) ? (string)$sendResult['reason'] : null,
                isset($sendResult['messageId']) ? (string)$sendResult['messageId'] : null,
                $this->nowString()
            ]
        );
    }

    private function sendRailStatusNotification($apnsConfig, $subscription, $statusRow, $notificationType, $classification) {
        if (empty($apnsConfig['ready'])) {
            return [
                'success' => false,
                'statusCode' => 0,
                'reason' => 'APNS_CONFIG_MISSING',
                'messageId' => null
            ];
        }
        if (!function_exists('curl_init')) {
            return [
                'success' => false,
                'statusCode' => 0,
                'reason' => 'CURL_NOT_AVAILABLE',
                'messageId' => null
            ];
        }

        $apnsToken = preg_replace('/\s+/', '', (string)($subscription['apns_token'] ?? ''));
        $apnsToken = trim((string)$apnsToken, '<>');
        if ($apnsToken === '') {
            return [
                'success' => false,
                'statusCode' => 0,
                'reason' => 'MISSING_DEVICE_TOKEN',
                'messageId' => null
            ];
        }

        $jwt = $this->buildApnsJwt($apnsConfig);
        if ($jwt === null) {
            return [
                'success' => false,
                'statusCode' => 0,
                'reason' => 'FAILED_TO_BUILD_APNS_JWT',
                'messageId' => null
            ];
        }

        $lineNumber = trim((string)($statusRow['lineNumber'] ?? ($subscription['line_number'] ?? '')));
        $lineName = trim((string)($statusRow['lineName'] ?? ($subscription['line_name'] ?? '')));
        $lineLabel = $lineNumber !== '' ? ('Linha ' . $lineNumber) : 'Linha';
        if ($lineName !== '') {
            $lineLabel .= ' - ' . $lineName;
        }

        $statusText = $this->normalizeText((string)($statusRow['status'] ?? ''));
        $statusDetail = $this->normalizeText((string)($statusRow['statusDetail'] ?? ''));
        $source = strtolower(trim((string)($subscription['source'] ?? '')));
        $messageId = $this->generateUuidV4();

        if ($notificationType === self::NOTIFICATION_TYPE_RECOVERY) {
            $title = $lineLabel . ' normalizada';
            $body = 'A linha voltou ao status normal.';
        } else {
            $title = 'Disrupcao em ' . $lineLabel;
            $body = $statusText !== '' ? ('Status: ' . $statusText . '.') : 'Foi detectado um problema na operacao.';
            if ($statusDetail !== '') {
                $body .= ' ' . $statusDetail;
            }
        }

        $payload = [
            'aps' => [
                'alert' => [
                    'title' => $title,
                    'body' => $body
                ],
                'sound' => 'default'
            ],
            'type' => 'rail_status_' . $notificationType,
            'source' => $source,
            'lineId' => (string)($subscription['line_id_key'] ?? ''),
            'lineNumber' => $lineNumber,
            'lineName' => $lineName,
            'status' => $statusText,
            'statusDetail' => $statusDetail,
            'impactLevel' => (string)($classification['impactLevel'] ?? 'none'),
            'impactScore' => (int)($classification['impactScore'] ?? 0),
            'updatedAt' => $statusRow['sourceUpdatedAt'] ?? null
        ];

        $bodyJson = json_encode($payload, JSON_UNESCAPED_UNICODE);
        if (!is_string($bodyJson) || $bodyJson === '') {
            return [
                'success' => false,
                'statusCode' => 0,
                'reason' => 'INVALID_PAYLOAD_JSON',
                'messageId' => $messageId
            ];
        }

        $lineCollapse = $source . '-' . $this->normalizeLineKey($lineNumber !== '' ? $lineNumber : $lineName);
        if ($lineCollapse === $source . '-') {
            $lineCollapse = $source . '-rail';
        }

        $url = 'https://' . $apnsConfig['host'] . '/3/device/' . rawurlencode($apnsToken);
        $headers = [
            'apns-topic: ' . $apnsConfig['topic'],
            'apns-push-type: alert',
            'apns-priority: 10',
            'apns-id: ' . $messageId,
            'apns-collapse-id: ' . substr($lineCollapse, 0, 64),
            'authorization: bearer ' . $jwt,
            'content-type: application/json'
        ];

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $bodyJson,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 10,
            CURLOPT_TIMEOUT => 20,
            CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_2_0
        ]);

        $responseBody = curl_exec($ch);
        $statusCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);

        if ($responseBody === false || $curlError !== '') {
            return [
                'success' => false,
                'statusCode' => $statusCode,
                'reason' => $curlError !== '' ? $curlError : 'APNS_CURL_FAILED',
                'messageId' => $messageId
            ];
        }

        $reason = null;
        $decoded = json_decode((string)$responseBody, true);
        if (is_array($decoded) && isset($decoded['reason'])) {
            $reason = (string)$decoded['reason'];
        }
        if ($reason === null || $reason === '') {
            $reason = $statusCode === 200 ? 'OK' : ('HTTP_' . $statusCode);
        }

        return [
            'success' => $statusCode === 200,
            'statusCode' => $statusCode,
            'reason' => $reason,
            'messageId' => $messageId
        ];
    }

    private function buildApnsConfig() {
        $keyPath = $this->readConfigValue('APNS_AUTH_KEY_PATH') ?? '../../../keys/AuthKey_6D4W4NCU46.p8';
        $keyId = $this->readConfigValue('APNS_KEY_ID') ?? '6D4W4NCU46';
        $teamId = $this->readConfigValue('APNS_TEAM_ID') ?? '666GZ2659S';
        $topic = $this->readConfigValue('APNS_BUNDLE_ID') ?? 'com.lolados.sp.Sao-Paulo-Onibus';
        $sandboxRaw = strtolower(trim((string)$this->readConfigValue('APNS_USE_SANDBOX')));
        $useSandbox = true; //in_array($sandboxRaw, ['1', 'true', 'yes', 'on'], true);

        if ($keyPath !== null && $keyPath !== '' && $keyPath[0] !== '/') {
            $candidate = realpath(__DIR__ . '/../' . $keyPath);
            if ($candidate !== false) {
                $keyPath = $candidate;
            }
        }

        $ready = true;
        if ($keyPath === null || $keyPath === '' || !is_file($keyPath)) {
            $ready = false;
        }
        if ($keyId === null || $keyId === '' || $teamId === null || $teamId === '' || $topic === null || $topic === '') {
            $ready = false;
        }
        if (!function_exists('openssl_sign')) {
            $ready = false;
        }

        return [
            'ready' => $ready,
            'keyPath' => $keyPath,
            'keyId' => $keyId,
            'teamId' => $teamId,
            'topic' => $topic,
            'host' => $useSandbox ? 'api.sandbox.push.apple.com' : 'api.push.apple.com'
        ];
    }

    private function readConfigValue($key) {
        $value = getenv($key);
        if ($value !== false && $value !== null) {
            $trimmed = trim((string)$value);
            if ($trimmed !== '') {
                return $trimmed;
            }
        }

        if (isset($_ENV[$key])) {
            $trimmed = trim((string)$_ENV[$key]);
            if ($trimmed !== '') {
                return $trimmed;
            }
        }

        if (isset($_SERVER[$key])) {
            $trimmed = trim((string)$_SERVER[$key]);
            if ($trimmed !== '') {
                return $trimmed;
            }
        }

        return null;
    }

    private function buildApnsJwt($apnsConfig) {
        static $cachedJwt = [
            'cacheKey' => null,
            'token' => null,
            'issuedAt' => 0
        ];

        $cacheKey = implode('|', [
            (string)($apnsConfig['keyPath'] ?? ''),
            (string)($apnsConfig['keyId'] ?? ''),
            (string)($apnsConfig['teamId'] ?? '')
        ]);

        $nowTs = time();
        if ($cachedJwt['cacheKey'] === $cacheKey
            && !empty($cachedJwt['token'])
            && ($nowTs - (int)$cachedJwt['issuedAt']) < 3000) {
            return (string)$cachedJwt['token'];
        }

        $keyPath = (string)($apnsConfig['keyPath'] ?? '');
        $privateKeyContents = @file_get_contents($keyPath);
        if (!is_string($privateKeyContents) || $privateKeyContents === '') {
            return null;
        }

        $privateKey = openssl_pkey_get_private($privateKeyContents);
        if ($privateKey === false) {
            return null;
        }

        $header = ['alg' => 'ES256', 'kid' => (string)$apnsConfig['keyId']];
        $payload = ['iss' => (string)$apnsConfig['teamId'], 'iat' => $nowTs];

        $encodedHeader = $this->base64UrlEncode(json_encode($header));
        $encodedPayload = $this->base64UrlEncode(json_encode($payload));
        if ($encodedHeader === '' || $encodedPayload === '') {
            return null;
        }

        $unsigned = $encodedHeader . '.' . $encodedPayload;
        $signature = '';
        $signed = openssl_sign($unsigned, $signature, $privateKey, OPENSSL_ALGO_SHA256);
        if (function_exists('openssl_pkey_free')) {
            openssl_pkey_free($privateKey);
        }
        if (!$signed) {
            return null;
        }

        $token = $unsigned . '.' . $this->base64UrlEncode($signature);
        $cachedJwt['cacheKey'] = $cacheKey;
        $cachedJwt['token'] = $token;
        $cachedJwt['issuedAt'] = $nowTs;

        return $token;
    }

    private function base64UrlEncode($value) {
        $encoded = base64_encode((string)$value);
        $encoded = str_replace(['+', '/', '='], ['-', '_', ''], $encoded);
        return (string)$encoded;
    }

    private function generateUuidV4() {
        if (function_exists('random_bytes')) {
            $bytes = random_bytes(16);
            $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
            $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);
            return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($bytes), 4));
        }

        $hash = md5(uniqid((string)mt_rand(), true));
        return substr($hash, 0, 8) . '-' . substr($hash, 8, 4) . '-' . substr($hash, 12, 4) . '-' . substr($hash, 16, 4) . '-' . substr($hash, 20, 12);
    }

    private function isApnsInvalidTokenReason($reason) {
        $normalized = strtolower(trim((string)$reason));
        if ($normalized === '') {
            return false;
        }

        $invalidReasons = [
            'baddevicetoken',
            'devicetokennotfortopic',
            'unregistered',
            'badtopic',
            'topicdisallowed'
        ];

        return in_array($normalized, $invalidReasons, true);
    }

    private function disableDevicePushForInvalidToken($deviceId) {
        $deviceId = (int)$deviceId;
        if ($deviceId <= 0) {
            return;
        }

        $this->con->ExecutaPrepared(
            "UPDATE sp_transit_alert_devices
             SET apns_token = NULL,
                 notifications_enabled = 0,
                 authorization_status = 'invalid_token',
                 updated_at = ?
             WHERE device_id = ?",
            "si",
            [$this->nowString(), $deviceId]
        );
    }

    private function nowString() {
        $dt = new DateTimeImmutable('now', $this->timezone);
        return $dt->format('Y-m-d H:i:s');
    }

    private function ensureSchema() {
        $this->con->Executa("
            CREATE TABLE IF NOT EXISTS sp_transit_status_snapshots (
                snapshot_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                source ENUM('metro','cptm') NOT NULL,
                fetched_at DATETIME NOT NULL,
                source_updated_at DATETIME NULL,
                line_count INT UNSIGNED NOT NULL DEFAULT 0,
                raw_hash CHAR(64) NULL,
                PRIMARY KEY (snapshot_id),
                KEY idx_status_snapshots_source_fetched (source, fetched_at),
                KEY idx_status_snapshots_source_id (source, snapshot_id),
                KEY idx_status_snapshots_source_updated (source, source_updated_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");

        $this->con->Executa("
            CREATE TABLE IF NOT EXISTS sp_transit_status_lines (
                line_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                snapshot_id BIGINT UNSIGNED NOT NULL,
                source ENUM('metro','cptm') NOT NULL,
                line_number VARCHAR(32) NOT NULL,
                line_name VARCHAR(128) NOT NULL,
                status_text VARCHAR(255) NOT NULL,
                status_detail VARCHAR(512) NULL,
                status_color VARCHAR(16) NULL,
                source_updated_at DATETIME NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (line_id),
                KEY idx_status_lines_snapshot (snapshot_id),
                KEY idx_status_lines_snapshot_order (snapshot_id, line_number, line_name),
                KEY idx_status_lines_source_line (source, line_number),
                CONSTRAINT fk_status_lines_snapshot
                    FOREIGN KEY (snapshot_id) REFERENCES sp_transit_status_snapshots(snapshot_id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");

        $this->con->Executa("
            CREATE TABLE IF NOT EXISTS sp_transit_status_errors (
                source ENUM('metro','cptm') NOT NULL,
                first_failed_at DATETIME NULL,
                last_failed_at DATETIME NULL,
                last_success_at DATETIME NULL,
                last_email_sent_at DATETIME NULL,
                consecutive_failures INT UNSIGNED NOT NULL DEFAULT 0,
                last_error_message TEXT NULL,
                PRIMARY KEY (source)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");

        $this->con->Executa("
            CREATE TABLE IF NOT EXISTS sp_transit_alert_devices (
                device_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                installation_id VARCHAR(64) NOT NULL,
                platform VARCHAR(16) NOT NULL DEFAULT 'ios',
                apns_token VARCHAR(255) NULL,
                notifications_enabled TINYINT(1) NOT NULL DEFAULT 0,
                authorization_status VARCHAR(32) NULL,
                locale VARCHAR(16) NULL,
                timezone VARCHAR(64) NULL,
                app_version VARCHAR(32) NULL,
                build_version VARCHAR(32) NULL,
                last_seen_at DATETIME NOT NULL,
                created_at DATETIME NOT NULL,
                updated_at DATETIME NOT NULL,
                PRIMARY KEY (device_id),
                UNIQUE KEY uniq_alert_devices_installation (installation_id),
                KEY idx_alert_devices_apns_token (apns_token),
                KEY idx_alert_devices_platform (platform)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");

        $this->con->Executa("
            CREATE TABLE IF NOT EXISTS sp_transit_alert_line_subscriptions (
                subscription_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                device_id BIGINT UNSIGNED NOT NULL,
                line_id_key VARCHAR(128) NOT NULL,
                source ENUM('metro','cptm') NOT NULL,
                line_number VARCHAR(32) NOT NULL,
                line_name VARCHAR(128) NOT NULL,
                is_active TINYINT(1) NOT NULL DEFAULT 1,
                created_at DATETIME NOT NULL,
                updated_at DATETIME NOT NULL,
                PRIMARY KEY (subscription_id),
                UNIQUE KEY uniq_alert_device_line (device_id, line_id_key),
                KEY idx_alert_line_source_number (source, line_number),
                KEY idx_alert_line_active (is_active),
                CONSTRAINT fk_alert_line_device
                    FOREIGN KEY (device_id) REFERENCES sp_transit_alert_devices(device_id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");

        $this->con->Executa("
            CREATE TABLE IF NOT EXISTS sp_transit_alert_delivery_state (
                device_id BIGINT UNSIGNED NOT NULL,
                line_id_key VARCHAR(128) NOT NULL,
                last_status_text VARCHAR(255) NULL,
                last_status_normalized VARCHAR(255) NULL,
                is_problem_open TINYINT(1) NOT NULL DEFAULT 0,
                last_problem_status_text VARCHAR(255) NULL,
                last_problem_normalized VARCHAR(255) NULL,
                problem_notified_at DATETIME NULL,
                last_recovery_sent_at DATETIME NULL,
                created_at DATETIME NOT NULL,
                updated_at DATETIME NOT NULL,
                PRIMARY KEY (device_id, line_id_key),
                KEY idx_alert_delivery_open (is_problem_open),
                KEY idx_alert_delivery_problem_at (problem_notified_at),
                CONSTRAINT fk_alert_delivery_device
                    FOREIGN KEY (device_id) REFERENCES sp_transit_alert_devices(device_id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");

        $this->con->Executa("
            CREATE TABLE IF NOT EXISTS sp_transit_alert_notification_log (
                notification_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                device_id BIGINT UNSIGNED NOT NULL,
                line_id_key VARCHAR(128) NOT NULL,
                source ENUM('metro','cptm') NOT NULL,
                line_number VARCHAR(32) NOT NULL,
                line_name VARCHAR(128) NOT NULL,
                notification_type ENUM('problem','recovery') NOT NULL,
                status_text VARCHAR(255) NOT NULL,
                status_detail VARCHAR(512) NULL,
                impact_level VARCHAR(16) NOT NULL DEFAULT 'none',
                sent_success TINYINT(1) NOT NULL DEFAULT 0,
                provider_response_code SMALLINT NULL,
                provider_response_reason VARCHAR(255) NULL,
                provider_message_id VARCHAR(64) NULL,
                created_at DATETIME NOT NULL,
                PRIMARY KEY (notification_id),
                KEY idx_alert_notification_device_line (device_id, line_id_key),
                KEY idx_alert_notification_created (created_at),
                CONSTRAINT fk_alert_notification_device
                    FOREIGN KEY (device_id) REFERENCES sp_transit_alert_devices(device_id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ");

        $this->ensureIndexExists(
            'sp_transit_status_snapshots',
            'idx_status_snapshots_source_id',
            'ALTER TABLE sp_transit_status_snapshots ADD INDEX idx_status_snapshots_source_id (source, snapshot_id)'
        );
        $this->ensureIndexExists(
            'sp_transit_status_lines',
            'idx_status_lines_snapshot_order',
            'ALTER TABLE sp_transit_status_lines ADD INDEX idx_status_lines_snapshot_order (snapshot_id, line_number, line_name)'
        );
    }

    private function ensureIndexExists($tableName, $indexName, $createSql) {
        $table = trim((string)$tableName);
        $index = trim((string)$indexName);
        $sql = trim((string)$createSql);

        if ($table === '' || $index === '' || $sql === '') {
            return;
        }

        $this->con->ExecutaPrepared(
            "SELECT COUNT(*) AS total
             FROM information_schema.statistics
             WHERE table_schema = DATABASE()
               AND table_name = ?
               AND index_name = ?",
            'ss',
            [$table, $index]
        );

        $row = $this->con->Linha();
        $exists = (int)($row['total'] ?? 0) > 0;
        if ($exists) {
            return;
        }

        $this->con->Executa($sql);
    }
}
