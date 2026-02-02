<?php
/**
 * SPTrans Olho Vivo API Client
 * PHP 7.3 compatible
 */
class SPTransOlhoVivoClient
{
    private $baseUrl = 'https://api.olhovivo.sptrans.com.br/v2.1';
    private $token;
    private $cookieFile;
    private $authenticated = false;

    public function __construct(string $token, string $cookieFile = null)
    {
        $this->token = $token;
        $this->cookieFile = $cookieFile ?: sys_get_temp_dir() . '/sptrans_cookie.txt';
    }

    /**
     * Authenticate and keep session cookies
     */
    public function authenticate(): bool
    {
        $url = $this->baseUrl . '/Login/Autenticar?token=' . urlencode($this->token);

        $response = $this->request('POST', $url);
        $this->authenticated = ($response === true);
        return true;// $this->authenticated;
    }

    /**
     * Generic HTTP request handler
     */
    private function request(string $method, string $url)
    {
        $ch = curl_init($url);

        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CUSTOMREQUEST  => $method,
            CURLOPT_COOKIEJAR      => $this->cookieFile,
            CURLOPT_COOKIEFILE     => $this->cookieFile,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
        ]);

        $response = curl_exec($ch);
        if ($response === false) {
            throw new RuntimeException(curl_error($ch));
        }

        curl_close($ch);

        $decoded = json_decode($response, true);

        return $decoded !== null ? $decoded : $response;
    }

    private function ensureAuth()
    {
        if (!$this->authenticated) {
            if (!$this->authenticate()) {
                throw new RuntimeException('Authentication failed');
            }
        }
    }

    /* ===================== LINHAS ===================== */

    public function buscarLinhas(string $termos)
    {
        $this->ensureAuth();
        return $this->request('GET', $this->baseUrl . '/Linha/Buscar?termosBusca=' . urlencode($termos));
    }

    public function buscarLinhaSentido(string $termos, int $sentido)
    {
        $this->ensureAuth();
        return $this->request(
            'GET',
            $this->baseUrl . '/Linha/BuscarLinhaSentido?termosBusca=' . urlencode($termos) . '&sentido=' . $sentido
        );
    }

    /* ===================== PARADAS ===================== */

    public function buscarParadas(string $termos)
    {
        $this->ensureAuth();
        return $this->request('GET', $this->baseUrl . '/Parada/Buscar?termosBusca=' . urlencode($termos));
    }

    public function buscarParadasPorLinha(int $codigoLinha)
    {
        $this->ensureAuth();
        return $this->request('GET', $this->baseUrl . '/Parada/BuscarParadasPorLinha?codigoLinha=' . $codigoLinha);
    }

    public function buscarParadasPorCorredor(int $codigoCorredor)
    {
        $this->ensureAuth();
        return $this->request('GET', $this->baseUrl . '/Parada/BuscarParadasPorCorredor?codigoCorredor=' . $codigoCorredor);
    }

    /* ===================== CORREDORES ===================== */

    public function getCorredores()
    {
        $this->ensureAuth();
        return $this->request('GET', $this->baseUrl . '/Corredor');
    }

    /* ===================== EMPRESAS ===================== */

    public function getEmpresas()
    {
        $this->ensureAuth();
        return $this->request('GET', $this->baseUrl . '/Empresa');
    }

    /* ===================== POSIÇÃO ===================== */

    public function getPosicoes()
    {
        $this->ensureAuth();
        return $this->request('GET', $this->baseUrl . '/Posicao');
    }

    public function getPosicaoLinha(int $codigoLinha)
    {
        $this->ensureAuth();
        return $this->request('GET', $this->baseUrl . '/Posicao/Linha?codigoLinha=' . $codigoLinha);
    }

    public function getPosicaoGaragem(int $codigoEmpresa, int $codigoLinha = null)
    {
        $this->ensureAuth();
        $url = $this->baseUrl . '/Posicao/Garagem?codigoEmpresa=' . $codigoEmpresa;
        if ($codigoLinha !== null) {
            $url .= '&codigoLinha=' . $codigoLinha;
        }
        return $this->request('GET', $url);
    }

    /* ===================== PREVISÃO ===================== */

    public function getPrevisao(int $codigoParada, int $codigoLinha)
    {
        $this->ensureAuth();
        return $this->request(
            'GET',
            $this->baseUrl . '/Previsao?codigoParada=' . $codigoParada . '&codigoLinha=' . $codigoLinha
        );
    }

    public function getPrevisaoLinha(int $codigoLinha)
    {
        $this->ensureAuth();
        return $this->request('GET', $this->baseUrl . '/Previsao/Linha?codigoLinha=' . $codigoLinha);
    }

    public function getPrevisaoParada(int $codigoParada)
    {
        $this->ensureAuth();
        return $this->request('GET', $this->baseUrl . '/Previsao/Parada?codigoParada=' . $codigoParada);
    }
}

// ===================== DTOs =====================

class Linha
{
    public $codigo;
    public $circular;
    public $numero;
    public $sentido;
    public $tipo;
    public $destino;
    public $origem;

    public function __construct(array $d)
    {
        $this->codigo   = $d['cl'] ?? null;
        $this->circular = $d['lc'] ?? null;
        $this->numero   = $d['lt'] ?? null;
        $this->sentido  = $d['sl'] ?? null;
        $this->tipo     = $d['tl'] ?? null;
        $this->destino  = $d['tp'] ?? null;
        $this->origem   = $d['ts'] ?? null;
    }
}

class Parada
{
    public $codigo;
    public $nome;
    public $endereco;
    public $lat;
    public $lng;

    public function __construct(array $d)
    {
        $this->codigo   = $d['cp'] ?? null;
        $this->nome     = $d['np'] ?? null;
        $this->endereco = $d['ed'] ?? null;
        $this->lat      = $d['py'] ?? null;
        $this->lng      = $d['px'] ?? null;
    }
}

class Veiculo
{
    public $prefixo;
    public $acessivel;
    public $timestamp;
    public $lat;
    public $lng;

    public function __construct(array $d)
    {
        $this->prefixo    = $d['p'] ?? null;
        $this->acessivel  = $d['a'] ?? null;
        $this->timestamp = $d['ta'] ?? null;
        $this->lat        = $d['py'] ?? null;
        $this->lng        = $d['px'] ?? null;
    }
}

/*
USAGE:
*/

$client = new SPTransOlhoVivoClient('1156131e3fd848c0958048fba8f2e31abb03268cae6f686d6166aa1d1e1e7753');
$linhas = $client->getPrevisaoParada(800016608);

// print_r($linhas);
?>