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

        foreach ($sources as $source) {
            if ($forceRefresh || $this->isSourceStale($source)) {
                try {
                    $this->refreshSource($source);
                    $refreshed[$source] = true;
                } catch (Throwable $e) {
                    $this->handleFailure($source, $e->getMessage());
                    $refreshErrors[$source] = $e->getMessage();
                }
            }
        }

        $metro = $this->getLatestBySource(self::SOURCE_METRO);
        $cptm = $this->getLatestBySource(self::SOURCE_CPTM);

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

            $latest = $this->getLatestBySource($src);
            $result['sources'][$src] = [
                'refreshed' => $didRefresh,
                'latest' => $latest,
                'error' => $error
            ];
        }

        return $result;
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
        $this->con->ExecutaPrepared(
            "SELECT snapshot_id, source, fetched_at, source_updated_at, line_count
             FROM sp_transit_status_snapshots
             WHERE source = ?
             ORDER BY snapshot_id DESC
             LIMIT 1",
            "s",
            [$source]
        );
        $snapshot = $this->con->Linha();

        if (!$snapshot) {
            return [
                'source' => $source,
                'available' => false,
                'count' => 0,
                'lastFetchedAt' => null,
                'lastSourceUpdatedAt' => null,
                'lines' => []
            ];
        }

        $snapshotId = (int)$snapshot['snapshot_id'];

        $this->con->ExecutaPrepared(
            "SELECT line_number, line_name, status_text, status_detail, status_color, source_updated_at
             FROM sp_transit_status_lines
             WHERE snapshot_id = ?
             ORDER BY line_number, line_name",
            "i",
            [$snapshotId]
        );

        $lines = [];
        while ($rs = $this->con->Linha()) {
            $lines[] = [
                'lineNumber' => $rs['line_number'] ?? '',
                'lineName' => $rs['line_name'] ?? '',
                'status' => $rs['status_text'] ?? '',
                'statusDetail' => $rs['status_detail'] ?? '',
                'statusColor' => $rs['status_color'] ?? '',
                'sourceUpdatedAt' => $rs['source_updated_at'] ?? null
            ];
        }

        return [
            'source' => $source,
            'available' => true,
            'count' => count($lines),
            'lastFetchedAt' => $snapshot['fetched_at'] ?? null,
            'lastSourceUpdatedAt' => $snapshot['source_updated_at'] ?? null,
            'lines' => $lines
        ];
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
    }
}
