<?php

date_default_timezone_set('America/Sao_Paulo');

// Only set header if not already set
if (!headers_sent()) {
    header("Content-type: application/json; charset=utf-8");
}

require_once(__DIR__ . "/inc/Conexao.class.php");
$cConexao = new Conexao(INT_MYSQL, "mysql", "lolados_bus", "bus@2013", "lolados_bus");
?>