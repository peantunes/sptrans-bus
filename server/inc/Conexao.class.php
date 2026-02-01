<?php

define("INT_SQLSERVER", "1");
define("INT_ORACLE", "2");
define("INT_POSTGRE", "3");
define("INT_MYSQL", "4");

class Conexao {
	var $intBanco; 	 // Indica o tipo de banco que será utilizado
	var $strBanco; 	 // Indica o nome do banco ou host
	var $strUsuario; // Indica o usuário que conectará ao banco
	var $strSenha;	 // Indica a senha do Usuário que conecta ao banco
	var $strBase;	 // Indica a base do banco que será utilizada
	var $strConexao; // Indica a string de conexão com o banco (utilizado pelo Oracle)

	var $conexao;	 // Contém a Conexão aberta
	var $cursor;	 // Cursor
	var $parse;		 // Parse (somente Oracle)
	var	$rs;		 // Linha do recordset
	var $cErro;		 // classe que contem os erros de execução da classe




	//Inicializa indicando o tipo de Banco
	function __construct($intBanco1, $strBanco1, $strUsuario1, $strSenha1, $strBase1, $strConexao1=""){
		//Recebe os parametros
		$this->intBanco = $intBanco1;
		$this->strBanco = $strBanco1;
		$this->strUsuario = $strUsuario1;
		$this->strSenha = $strSenha1;
		$this->strBase = $strBase1;
		$this->strConexao = $strConexao1;
	}


	//Inicia uma transação
	function BeginTrans(){
		switch ($this->intBanco){
			case INT_SQLSERVER:
				$this->Executa("begin");
				break;
			case INT_ORACLE:
				break;
			case INT_POSTGRE:
				$this->Executa("begin");
				break;
			case INT_MYSQL:
				$this->Executa("begin");
				break;
		}
	}

	//Completa uma atualização
	function CommitTrans(){
		switch ($this->intBanco){
			case INT_SQLSERVER:
				$this->Executa("commit trans");
				break;
			case INT_ORACLE:
				break;
			case INT_POSTGRE:
				$this->Executa("end");
				break;
			case INT_MYSQL:
				$this->Executa("commit");
				break;
		}
	}

	//Dá RollBack em uma transação iniciada
	function RollBackTrans(){
		switch ($this->intBanco){
			case INT_SQLSERVER:
				$this->Executa("rollback trans");
				break;
			case INT_ORACLE:
				break;
			case INT_POSTGRE:
				$this->Executa("rollback");
				break;
			case INT_MYSQL:
				$this->Executa("rollback");
				break;
		}
	}

	//Efetua conexão com o banco pegando o tipo de banco especificado
	function Conecta(){
		switch ($this->intBanco){
			case INT_SQLSERVER:
				$sBanco = "SQL";
				$this->conexao = mssql_connect($this->strBanco,$this->strUsuario,$this->strSenha) or die;
				mssql_select_db($this->strBase,$this->conexao) or die;
				$this->Executa("set dateformat dmy");
				break;
			case INT_ORACLE:
				$sBanco = "Oracle";
				$this->conexao = ociplogon($this->strUsuario,$this->strSenha,$this->strConexao) or die;
				$this->Executa("ALTER SESSION SET NLS_DATE_FORMAT ='DD/MM/YYYY HH24:MI:SS'");
				break;
			case INT_POSTGRE:
				$sBanco = "Postgres";
				$strCon = "host='$this->strBanco' port=5432 dbname='$this->strBase' user='$this->strUsuario' password='$this->strSenha'";
				$this->conexao = pg_connect($strCon) or die;
				pg_set_client_encoding($this->conexao, "ISO-8859-7");
				break;
			case INT_MYSQL:
				$sBanco = "MySQL";
				$this->conexao = mysqli_connect($this->strBanco, $this->strUsuario, $this->strSenha, $this->strBase);
				if (mysqli_connect_errno()) {
					die("Connection failed: " . mysqli_connect_error());
				}
				mysqli_set_charset($this->conexao, "utf8");
				break;
		}
	}

	//Encerra Conexão com o banco
	function Desconecta(){
		switch ($this->intBanco){
			case INT_SQLSERVER:
				mssql_close($this->conexao);
				break;
			case INT_ORACLE:
				ocilogoff($this->conexao);
				break;
			case INT_POSTGRE:
				pg_close($this->conexao);
				break;
			case INT_MYSQL:
				mysqli_close($this->conexao);
				break;
		}
	}

	//Executa uma instrução SQL
	function Executa($strSQL, $recordset1=""){
		static $totConexoes;
		$totConexoes++;
		switch ($this->intBanco){
			case INT_SQLSERVER:
				$this->cursor = mssql_query($strSQL, $this->conexao) or die($this->getErro());
				break;
			case INT_ORACLE:
				$this->parse = ociparse($this->conexao, $strSQL) or die($this->getErro());
				$this->cursor = ocinewcursor($this->conexao);

				if ($recordset1 <> ""){
					ocibindbyname($this->parse, ":V_RESULT", $this->cursor, -1, OCI_B_CURSOR);
					ociexecute($this->parse);
				}
				ociexecute($this->cursor) or die($this->getErro());
				break;
			case INT_POSTGRE:
				$this->cursor = pg_query($this->conexao, $strSQL) or die($this->getErro());
				break;
			case INT_MYSQL:
				$this->cursor = mysqli_query($this->conexao, $strSQL);
				if (!$this->cursor) {
					die(mysqli_error($this->conexao));
				}
				break;
		}
	}

	//Retorna o ID gerado no Insert
	function getId(){
		switch ($this->intBanco){
			case INT_SQLSERVER:
				return "";
			case INT_ORACLE:
				return "";
			case INT_POSTGRE:
				return "";
			case INT_MYSQL:
				return mysqli_insert_id($this->conexao);
		}
	}

	//Retorna uma linha do Recordset
	function Linha(){
		switch ($this->intBanco){
			case INT_SQLSERVER:
				$this->rs = mssql_fetch_array($this->cursor);
				$a1 = $this->rs;
				break;
			case INT_ORACLE:
				$a1 = ocifetchinto($this->cursor, $this->rs, OCI_ASSOC);
				break;
			case INT_POSTGRE:
				$this->rs = pg_fetch_array($this->cursor);
				$a1 = $this->rs;
				break;
			case INT_MYSQL:
				$this->rs = mysqli_fetch_array($this->cursor, MYSQLI_BOTH);
				$a1 = $this->rs;
				break;
		}
		return $a1;
	}

	//Retorna a mensagem de Erro do Banco
	function getErro(){
		$erro = "";
		switch ($this->intBanco){
			case INT_SQLSERVER:
				$erro = mssql_get_last_message();
				break;
			case INT_ORACLE:
				$erro = ocierror();
				break;
			case INT_POSTGRE:
				$erro = pg_last_error($this->conexao);
				break;
			case INT_MYSQL:
				$erro = mysqli_error($this->conexao);
				break;
		}
		return $erro;
	}

	function getAffectedRows(){
		switch ($this->intBanco){
			case INT_SQLSERVER:
				$totRows = mssql_rows_affected($this->conexao);
				break;
			case INT_ORACLE:
				$totRows = ocirowcount($this->cursor);
				break;
			case INT_POSTGRE:
				$totRows = pg_affected_rows($this->cursor);
				break;
			case INT_MYSQL:
				$totRows = mysqli_affected_rows($this->conexao);
				break;
		}
		return $totRows;
	}

	function getNumRows(){
		switch ($this->intBanco){
			case INT_SQLSERVER:
				$totRows = mssql_num_rows($this->cursor);
				break;
			case INT_ORACLE:
				$totRows = oci_num_rows($this->cursor);
				break;
			case INT_POSTGRE:
				$totRows = pg_num_rows($this->cursor);
				break;
			case INT_MYSQL:
				$totRows = mysqli_num_rows($this->cursor);
				break;
		}
		return $totRows;
	}

	/**
	 * Execute a prepared statement with bound parameters (MySQL only)
	 *
	 * @param string $sql SQL query with ? placeholders
	 * @param string $types Type string (s=string, i=integer, d=double, b=blob)
	 * @param array $params Array of parameter values
	 * @return bool Success status
	 */
	function ExecutaPrepared($sql, $types = "", $params = []) {
		if ($this->intBanco != INT_MYSQL) {
			throw new Exception("Prepared statements only supported for MySQL");
		}

		$stmt = mysqli_prepare($this->conexao, $sql);
		if (!$stmt) {
			die("Prepare failed: " . mysqli_error($this->conexao));
		}

		if (!empty($params) && !empty($types)) {
			mysqli_stmt_bind_param($stmt, $types, ...$params);
		}

		$result = mysqli_stmt_execute($stmt);
		if (!$result) {
			die("Execute failed: " . mysqli_stmt_error($stmt));
		}

		$this->cursor = mysqli_stmt_get_result($stmt);
		mysqli_stmt_close($stmt);

		return $result;
	}

	//Retorna as colunas do recordset
	function &getColunas(){
		$templist = array();
		switch ($this->intBanco){
			case INT_SQLSERVER:
				$numcols = mssql_num_fields($this->cursor);
				for ($column = 0; $column < $numcols; $column++) {
					$colname = trim(mssql_field_name($this->cursor, $column));
					$templist[$column] = $colname;
				}
				break;
			case INT_ORACLE:
				$numcols = ocinumcols($this->parse);
				for ($column = 0; $column < $numcols; $column++){
					$colname = trim(ocicolumnname($this->cursor, $column));
					$templist[$column] = $colname;
				}
				break;
			case INT_POSTGRE:
				$numcols = pg_num_fields($this->cursor);
				for ($column = 0; $column < $numcols; $column++) {
					$colname = trim(pg_field_name($this->cursor, $column));
					$templist[$column] = $colname;
				}
				break;
			case INT_MYSQL:
				$numcols = mysqli_num_fields($this->cursor);
				for ($column = 0; $column < $numcols; $column++) {
					$field = mysqli_fetch_field_direct($this->cursor, $column);
					$templist[$column] = trim($field->name);
				}
				break;
		}
		return $templist;
	}

	function &getColunaInfo($coluna1){
		$arrayColuna = array();
		switch ($this->intBanco){
			case INT_SQLSERVER:
				if ($coluna1 < mssql_num_fields($this->cursor)){
					$arrayColuna["nome"] = trim(mssql_field_name($this->cursor, $coluna1));
					$arrayColuna["tipo"] = trim(mssql_field_type($this->cursor, $coluna1));
					$arrayColuna["tamanho"] = mssql_field_length($this->cursor, $coluna1);
					$arrayColuna["bytes"] = 0;
					$arrayColuna["decimal"] = 0;
					$arrayColuna["ordem"] = $coluna1;
				}
				break;
			case INT_ORACLE:
				$coluna1 = $coluna1 + 1;
				if ($coluna1 <= ocinumcols($this->cursor)){
					$arrayColuna["nome"] = trim(ocicolumnname($this->cursor, $coluna1));
					$arrayColuna["tipo"] = trim(ocicolumntype($this->cursor, $coluna1));
					$arrayColuna["tamanho"] = ocicolumnsize($this->cursor, $coluna1);
					$arrayColuna["bytes"] = ocicolumnscale($this->cursor, $coluna1);
					$arrayColuna["decimal"] = ocicolumnprecision($this->cursor, $coluna1);
					$arrayColuna["ordem"] = $coluna1;
				}
				break;
			case INT_POSTGRE:
				if ($coluna1 < pg_num_fields($this->cursor)){
					$arrayColuna["nome"] = trim(pg_field_name($this->cursor, $coluna1));
					$arrayColuna["tipo"] = trim(pg_field_type($this->cursor, $coluna1));
					$arrayColuna["tamanho"] = pg_field_size($this->cursor, $coluna1);
					$arrayColuna["bytes"] = pg_field_prtlen($this->cursor, $coluna1);
					$arrayColuna["decimal"] = 0;
					$arrayColuna["ordem"] = $coluna1;
				}
				break;
			case INT_MYSQL:
				if ($coluna1 < mysqli_num_fields($this->cursor)){
					$field = mysqli_fetch_field_direct($this->cursor, $coluna1);
					$arrayColuna["nome"] = trim($field->name);
					$arrayColuna["tipo"] = $this->getMySQLFieldType($field->type);
					$arrayColuna["tamanho"] = $field->length;
					$arrayColuna["bytes"] = 0;
					$arrayColuna["decimal"] = $field->decimals;
					$arrayColuna["ordem"] = $coluna1;
				}
				break;
		}
		return $arrayColuna;
	}

	// Helper function to convert mysqli field type constants to string
	private function getMySQLFieldType($typeCode) {
		$types = array(
			MYSQLI_TYPE_DECIMAL => 'decimal',
			MYSQLI_TYPE_TINY => 'tinyint',
			MYSQLI_TYPE_SHORT => 'smallint',
			MYSQLI_TYPE_LONG => 'int',
			MYSQLI_TYPE_FLOAT => 'float',
			MYSQLI_TYPE_DOUBLE => 'double',
			MYSQLI_TYPE_NULL => 'null',
			MYSQLI_TYPE_TIMESTAMP => 'timestamp',
			MYSQLI_TYPE_LONGLONG => 'bigint',
			MYSQLI_TYPE_INT24 => 'mediumint',
			MYSQLI_TYPE_DATE => 'date',
			MYSQLI_TYPE_TIME => 'time',
			MYSQLI_TYPE_DATETIME => 'datetime',
			MYSQLI_TYPE_YEAR => 'year',
			MYSQLI_TYPE_NEWDATE => 'date',
			MYSQLI_TYPE_ENUM => 'enum',
			MYSQLI_TYPE_SET => 'set',
			MYSQLI_TYPE_TINY_BLOB => 'tinyblob',
			MYSQLI_TYPE_MEDIUM_BLOB => 'mediumblob',
			MYSQLI_TYPE_LONG_BLOB => 'longblob',
			MYSQLI_TYPE_BLOB => 'blob',
			MYSQLI_TYPE_VAR_STRING => 'varchar',
			MYSQLI_TYPE_STRING => 'char',
			MYSQLI_TYPE_GEOMETRY => 'geometry'
		);
		return isset($types[$typeCode]) ? $types[$typeCode] : 'unknown';
	}

	function converteTipoData($tipoData){
		$tipoData = strtolower($tipoData);
		$tiposSQL = array(
			"binary" => "binario",
			"bit" => "binario",
			"char" => "varchar",
			"datetime" => "date",
			"decimal" => "numeric",
			"float" => "numeric",
			"image" => "",
			"int" => "numeric",
			"money" => "numeric",
			"nchar" => "varchar",
			"ntext" => "",
			"numeric" => "numeric",
			"nvarchar" => "varchar",
			"real" => "numeric",
			"smalldatetime" => "date",
			"smallint" => "numeric",
			"smallmoney" => "numeric",
			"sysname" => "",
			"text" => "",
			"timestamp" => "date",
			"tinyint" => "numeric",
			"uniqueidentifier" => "numeric",
			"varbinary" => "binario",
			"varchar" => "varchar"
		);

		$tiposOracle = array(
			"char" => "varchar",
			"date" => "date",
			"float" => "numeric",
			"integer" => "numeric",
			"long" => "",
			"long raw" => "",
			"number" => "numeric",
			"raw" => "binario",
			"rowid" => "",
			"varchar2" => "varchar",
			"varchar" => "varchar"
		);

		$tiposPostgres = array(
			"abstime" => "date",
			"anyarray" => "",
			"array" => "",
			"bigint" => "numeric",
			"bit" => "binario",
			"boolean" => "boolean",
			"bytea" => "numeric",
			"\"char\"" => "varchar",
			"character" => "varchar",
			"character varying" => "varchar",
			"int2vector" => "numeric",
			"integer" => "numeric",
			"name" => "numeric",
			"numeric" => "numeric",
			"oid" => "numeric",
			"oidvector" => "numeric",
			"real" => "numeric",
			"regproc" => "",
			"smallint" => "numeric",
			"text" => "",
			"timestamp without time zone" => "date",
			"timestamp with time zone" => "date",
			"xid" => "numeric"
		);

		switch ($this->intBanco){
			case INT_SQLSERVER:
				return isset($tiposSQL[$tipoData]) ? $tiposSQL[$tipoData] : "";
			case INT_ORACLE:
				return isset($tiposOracle[$tipoData]) ? $tiposOracle[$tipoData] : "";
			case INT_POSTGRE:
				return isset($tiposPostgres[$tipoData]) ? $tiposPostgres[$tipoData] : "";
			case INT_MYSQL:
				return isset($tiposSQL[$tipoData]) ? $tiposSQL[$tipoData] : "";
		}
	}

}

?>
