#!/usr/bin/env php
<?php
/**
 * GTFS Data Importer for MySQL Database
 *
 * This script imports GTFS files into a MySQL database using a temp table strategy
 * to ensure data integrity. Old records are only deleted after new data is successfully loaded.
 *
 * Usage:
 *   php import_gtfs.php [options]
 *
 * Options:
 *   --gtfs-dir=PATH      Directory containing GTFS files (default: gtfs_to_import)
 *   --host=HOST          MySQL host (default: localhost)
 *   --port=PORT          MySQL port (default: 3306)
 *   --user=USER          MySQL user (default: lolados_bus)
 *   --password=PASSWORD  MySQL password (default: bus@2013)
 *   --database=DATABASE  MySQL database (default: lolados_bus)
 */

// Increase memory limit for large files
ini_set('memory_limit', '512M');
set_time_limit(0);

// Mapping of database tables to GTFS files
$TABLE_FILE_MAPPING = [
    'sp_calendar' => 'calendar.txt',
    'sp_calendar_dates' => 'calendar_dates.txt',
    'sp_fare_att' => 'fare_attributes.txt',
    'sp_fare_rules' => 'fare_rules.txt',
    'sp_frequencies' => 'frequencies.txt',
    'sp_routes' => 'routes.txt',
    'sp_shapes' => 'shapes.txt',
    'sp_stop' => 'stops.txt',
    'sp_stop_times' => 'stop_times.txt',
    'sp_trip' => 'trips.txt',
];

// Column type hints for specific columns (default is VARCHAR(255))
$COLUMN_TYPES = [
    // calendar.txt
    'monday' => 'TINYINT',
    'tuesday' => 'TINYINT',
    'wednesday' => 'TINYINT',
    'thursday' => 'TINYINT',
    'friday' => 'TINYINT',
    'saturday' => 'TINYINT',
    'sunday' => 'TINYINT',
    'start_date' => 'VARCHAR(8)',
    'end_date' => 'VARCHAR(8)',
    // calendar_dates.txt
    'date' => 'VARCHAR(8)',
    'exception_type' => 'TINYINT',
    // fare_attributes.txt
    'price' => 'DECIMAL(10,6)',
    'payment_method' => 'TINYINT',
    'transfers' => 'VARCHAR(10)',
    'transfer_duration' => 'INT',
    // frequencies.txt
    'headway_secs' => 'INT',
    'start_time' => 'VARCHAR(10)',
    'end_time' => 'VARCHAR(10)',
    // routes.txt
    'route_type' => 'INT',
    // shapes.txt
    'shape_pt_lat' => 'DECIMAL(10,6)',
    'shape_pt_lon' => 'DECIMAL(10,6)',
    'shape_pt_sequence' => 'INT',
    'shape_dist_traveled' => 'DECIMAL(10,2)',
    // stops.txt
    'stop_lat' => 'DECIMAL(10,6)',
    'stop_lon' => 'DECIMAL(10,6)',
    // stop_times.txt
    'arrival_time' => 'VARCHAR(10)',
    'departure_time' => 'VARCHAR(10)',
    'stop_sequence' => 'INT',
    // trips.txt
    'direction_id' => 'TINYINT',
];

/**
 * Logger function
 */
function logMessage($level, $message) {
    $timestamp = date('Y-m-d H:i:s');
    echo "[$timestamp] [$level] $message\n";
    flush();
}

function logInfo($message) {
    logMessage('INFO', $message);
}

function logWarning($message) {
    logMessage('WARNING', $message);
}

function logError($message) {
    logMessage('ERROR', $message);
}

/**
 * Get the MySQL column type for a given column name
 */
function getColumnType($columnName) {
    global $COLUMN_TYPES;
    return isset($COLUMN_TYPES[$columnName]) ? $COLUMN_TYPES[$columnName] : 'VARCHAR(255)';
}

/**
 * Read and return the headers from a CSV file
 */
function readCsvHeaders($filePath) {
    $handle = fopen($filePath, 'r');
    if ($handle === false) {
        throw new Exception("Cannot open file: $filePath");
    }

    // Read the first line
    $headers = fgetcsv($handle);
    fclose($handle);

    if ($headers === false) {
        throw new Exception("Cannot read headers from: $filePath");
    }

    // Clean up header names (remove BOM, quotes, spaces)
    $cleanHeaders = [];
    foreach ($headers as $i => $header) {
        // Remove BOM from first header if present
        if ($i === 0) {
            $header = preg_replace('/^\xEF\xBB\xBF/', '', $header);
        }
        $cleanHeaders[] = trim($header, " \t\n\r\0\x0B\"");
    }

    return $cleanHeaders;
}

/**
 * Create a temporary table with the given columns
 */
function createTempTable($mysqli, $tableName, $columns) {
    $tempTable = "{$tableName}_temp";

    // Build column definitions
    $colDefs = [];
    foreach ($columns as $col) {
        $colType = getColumnType($col);
        $colDefs[] = "`$col` $colType";
    }
    $columnsSql = implode(', ', $colDefs);

    // Drop temp table if exists
    $mysqli->query("DROP TABLE IF EXISTS `$tempTable`");

    // Create temp table
    $createSql = "CREATE TABLE `$tempTable` ($columnsSql) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
    if (!$mysqli->query($createSql)) {
        throw new Exception("Failed to create temp table: " . $mysqli->error);
    }

    logInfo("Created temp table: $tempTable");
    return $tempTable;
}

/**
 * Load data from CSV file into the specified table using batch inserts
 */
function loadDataIntoTable($mysqli, $tableName, $filePath, $columns, $batchSize = 1000) {
    $handle = fopen($filePath, 'r');
    if ($handle === false) {
        throw new Exception("Cannot open file: $filePath");
    }

    // Skip header row
    fgetcsv($handle);

    $columnsSql = implode(', ', array_map(function($col) {
        return "`$col`";
    }, $columns));

    $rowCount = 0;
    $batch = [];
    $columnCount = count($columns);

    while (($row = fgetcsv($handle)) !== false) {
        // Ensure row has correct number of columns
        if (count($row) < $columnCount) {
            $row = array_pad($row, $columnCount, '');
        }

        // Clean up values and handle empty strings
        $cleanedRow = [];
        foreach ($row as $value) {
            $value = trim($value, " \t\n\r\0\x0B\"");
            if ($value === '') {
                $cleanedRow[] = null;
            } else {
                $cleanedRow[] = $value;
            }
        }

        $batch[] = $cleanedRow;

        if (count($batch) >= $batchSize) {
            insertBatch($mysqli, $tableName, $columnsSql, $batch, $columnCount);
            $rowCount += count($batch);
            $batch = [];

            if ($rowCount % 10000 === 0) {
                logInfo("  Loaded $rowCount rows...");
            }
        }
    }

    // Insert remaining rows
    if (!empty($batch)) {
        insertBatch($mysqli, $tableName, $columnsSql, $batch, $columnCount);
        $rowCount += count($batch);
    }

    fclose($handle);
    logInfo("  Total rows loaded: $rowCount");
    return $rowCount;
}

/**
 * Insert a batch of rows into the table
 */
function insertBatch($mysqli, $tableName, $columnsSql, $batch, $columnCount) {
    if (empty($batch)) {
        return;
    }

    $valuePlaceholders = [];
    $params = [];
    $types = '';

    foreach ($batch as $row) {
        $rowPlaceholders = array_fill(0, $columnCount, '?');
        $valuePlaceholders[] = '(' . implode(', ', $rowPlaceholders) . ')';

        foreach ($row as $value) {
            $types .= 's'; // All values as strings
            $params[] = $value;
        }
    }

    $sql = "INSERT INTO `$tableName` ($columnsSql) VALUES " . implode(', ', $valuePlaceholders);

    $stmt = $mysqli->prepare($sql);
    if (!$stmt) {
        throw new Exception("Failed to prepare statement: " . $mysqli->error);
    }

    // Bind parameters dynamically
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    if (!$stmt->execute()) {
        throw new Exception("Failed to execute batch insert: " . $stmt->error);
    }

    $stmt->close();
}

/**
 * Swap the temp table with the original table
 */
function swapTables($mysqli, $originalTable, $tempTable) {
    $backupTable = "{$originalTable}_backup";

    // Check if original table exists
    $result = $mysqli->query("SHOW TABLES LIKE '$originalTable'");
    $originalExists = $result->num_rows > 0;

    if ($originalExists) {
        // Drop backup if exists
        $mysqli->query("DROP TABLE IF EXISTS `$backupTable`");
        // Rename original to backup
        if (!$mysqli->query("RENAME TABLE `$originalTable` TO `$backupTable`")) {
            throw new Exception("Failed to rename original table: " . $mysqli->error);
        }
    }

    // Rename temp to original
    if (!$mysqli->query("RENAME TABLE `$tempTable` TO `$originalTable`")) {
        throw new Exception("Failed to rename temp table: " . $mysqli->error);
    }

    if ($originalExists) {
        // Drop backup
        $mysqli->query("DROP TABLE IF EXISTS `$backupTable`");
    }

    logInfo("Swapped tables: $tempTable -> $originalTable");
}

/**
 * Import a single GTFS file into the database
 */
function importGtfsFile($mysqli, $tableName, $filePath) {
    $fileName = basename($filePath);
    logInfo("Importing $fileName -> $tableName");

    if (!file_exists($filePath)) {
        logWarning("  File not found: $filePath");
        return false;
    }

    // Read headers from CSV
    $columns = readCsvHeaders($filePath);
    logInfo("  Columns: " . implode(', ', $columns));

    // Create temp table
    $tempTable = createTempTable($mysqli, $tableName, $columns);

    // Load data
    loadDataIntoTable($mysqli, $tempTable, $filePath, $columns);

    // Swap tables
    swapTables($mysqli, $tableName, $tempTable);

    return true;
}

/**
 * Parse command line arguments
 */
function parseArgs($argv) {
    $args = [
        'gtfs-dir' => 'gtfs_to_import',
        'host' => 'localhost',
        'port' => 3306,
        'user' => 'lolados_bus',
        'password' => 'bus@2013',
        'database' => 'lolados_bus',
    ];

    foreach ($argv as $arg) {
        if (preg_match('/^--([^=]+)=(.*)$/', $arg, $matches)) {
            $key = $matches[1];
            $value = $matches[2];
            if (isset($args[$key])) {
                $args[$key] = $value;
            }
        }
    }

    return $args;
}

/**
 * Main function
 */
function main($argv) {
    global $TABLE_FILE_MAPPING;

    $args = parseArgs($argv);

    // Resolve GTFS directory
    $scriptDir = dirname(__FILE__);
    $gtfsDir = $scriptDir . '/' . $args['gtfs-dir'];

    if (!is_dir($gtfsDir)) {
        logError("GTFS directory not found: $gtfsDir");
        exit(1);
    }

    logInfo("GTFS directory: $gtfsDir");
    logInfo("Connecting to MySQL: {$args['user']}@{$args['host']}:{$args['port']}/{$args['database']}");

    // Connect to MySQL
    $mysqli = new mysqli(
        $args['host'],
        $args['user'],
        $args['password'],
        $args['database'],
        (int)$args['port']
    );

    if ($mysqli->connect_error) {
        logError("MySQL connection failed: " . $mysqli->connect_error);
        exit(1);
    }

    logInfo("Connected to MySQL successfully");

    // Set charset
    $mysqli->set_charset('utf8mb4');

    // Disable foreign key checks during import
    $mysqli->query("SET FOREIGN_KEY_CHECKS = 0");

    $successCount = 0;
    $failCount = 0;

    foreach ($TABLE_FILE_MAPPING as $tableName => $fileName) {
        $filePath = $gtfsDir . '/' . $fileName;

        try {
            $mysqli->begin_transaction();

            if (importGtfsFile($mysqli, $tableName, $filePath)) {
                $mysqli->commit();
                $successCount++;
            } else {
                $mysqli->rollback();
                $failCount++;
            }
        } catch (Exception $e) {
            logError("Error importing $fileName: " . $e->getMessage());
            $mysqli->rollback();

            // Clean up temp table if it exists
            $mysqli->query("DROP TABLE IF EXISTS `{$tableName}_temp`");
            $failCount++;
        }
    }

    // Re-enable foreign key checks
    $mysqli->query("SET FOREIGN_KEY_CHECKS = 1");

    logInfo("");
    logInfo("Import completed: $successCount succeeded, $failCount failed");

    $mysqli->close();
    logInfo("MySQL connection closed");
}

// Run main function
main($argv);
