#!/usr/bin/env python3
"""
GTFS Data Importer for MySQL Database

This script imports GTFS files into a MySQL database using a temp table strategy
to ensure data integrity. Old records are only deleted after new data is successfully loaded.

Usage:
    python import_gtfs.py [--gtfs-dir PATH] [--host HOST] [--user USER] [--password PASSWORD] [--database DATABASE]
"""

import csv
import os
import sys
import argparse
import logging
from pathlib import Path

import mysql.connector
from mysql.connector import Error

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Mapping of database tables to GTFS files
TABLE_FILE_MAPPING = {
    'sp_calendar': 'calendar.txt',
    'sp_fare_att': 'fare_attributes.txt',
    'sp_fare_rules': 'fare_rules.txt',
    'sp_frequencies': 'frequencies.txt',
    'sp_routes': 'routes.txt',
    'sp_shapes': 'shapes.txt',
    'sp_stop': 'stops.txt',
    'sp_stop_times': 'stop_times.txt',
    'sp_trip': 'trips.txt',
}

# Column type hints for specific columns (default is VARCHAR(255))
COLUMN_TYPES = {
    # calendar.txt
    'monday': 'TINYINT',
    'tuesday': 'TINYINT',
    'wednesday': 'TINYINT',
    'thursday': 'TINYINT',
    'friday': 'TINYINT',
    'saturday': 'TINYINT',
    'sunday': 'TINYINT',
    'start_date': 'VARCHAR(8)',
    'end_date': 'VARCHAR(8)',
    # fare_attributes.txt
    'price': 'DECIMAL(10,6)',
    'payment_method': 'TINYINT',
    'transfers': 'VARCHAR(10)',
    'transfer_duration': 'INT',
    # frequencies.txt
    'headway_secs': 'INT',
    'start_time': 'VARCHAR(10)',
    'end_time': 'VARCHAR(10)',
    # routes.txt
    'route_type': 'INT',
    # shapes.txt
    'shape_pt_lat': 'DECIMAL(10,6)',
    'shape_pt_lon': 'DECIMAL(10,6)',
    'shape_pt_sequence': 'INT',
    'shape_dist_traveled': 'DECIMAL(10,2)',
    # stops.txt
    'stop_lat': 'DECIMAL(10,6)',
    'stop_lon': 'DECIMAL(10,6)',
    # stop_times.txt
    'arrival_time': 'VARCHAR(10)',
    'departure_time': 'VARCHAR(10)',
    'stop_sequence': 'INT',
    # trips.txt
    'direction_id': 'TINYINT',
}


def get_column_type(column_name: str) -> str:
    """Get the MySQL column type for a given column name."""
    return COLUMN_TYPES.get(column_name, 'VARCHAR(255)')


def read_csv_headers(file_path: Path) -> list:
    """Read and return the headers from a CSV file."""
    with open(file_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        headers = next(reader)
        # Clean up header names (remove quotes, spaces)
        return [h.strip().strip('"') for h in headers]


def create_temp_table(cursor, table_name: str, columns: list) -> str:
    """Create a temporary table with the given columns."""
    temp_table = f"{table_name}_temp"

    # Build column definitions
    col_defs = []
    for col in columns:
        col_type = get_column_type(col)
        col_defs.append(f"`{col}` {col_type}")

    columns_sql = ', '.join(col_defs)

    # Drop temp table if exists
    cursor.execute(f"DROP TABLE IF EXISTS `{temp_table}`")

    # Create temp table
    create_sql = f"CREATE TABLE `{temp_table}` ({columns_sql}) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    cursor.execute(create_sql)
    logger.info(f"Created temp table: {temp_table}")

    return temp_table


def load_data_into_table(cursor, table_name: str, file_path: Path, columns: list, batch_size: int = 1000):
    """Load data from CSV file into the specified table."""
    placeholders = ', '.join(['%s'] * len(columns))
    columns_sql = ', '.join([f'`{col}`' for col in columns])
    insert_sql = f"INSERT INTO `{table_name}` ({columns_sql}) VALUES ({placeholders})"

    row_count = 0
    batch = []

    with open(file_path, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        next(reader)  # Skip header row

        for row in reader:
            # Clean up values and handle empty strings
            cleaned_row = []
            for i, value in enumerate(row):
                value = value.strip().strip('"')
                if value == '':
                    cleaned_row.append(None)
                else:
                    cleaned_row.append(value)

            batch.append(cleaned_row)

            if len(batch) >= batch_size:
                cursor.executemany(insert_sql, batch)
                row_count += len(batch)
                batch = []
                if row_count % 10000 == 0:
                    logger.info(f"  Loaded {row_count} rows...")

        # Insert remaining rows
        if batch:
            cursor.executemany(insert_sql, batch)
            row_count += len(batch)

    logger.info(f"  Total rows loaded: {row_count}")
    return row_count


def swap_tables(cursor, original_table: str, temp_table: str):
    """Swap the temp table with the original table."""
    backup_table = f"{original_table}_backup"

    # Check if original table exists
    cursor.execute(f"SHOW TABLES LIKE '{original_table}'")
    original_exists = cursor.fetchone() is not None

    if original_exists:
        # Drop backup if exists
        cursor.execute(f"DROP TABLE IF EXISTS `{backup_table}`")
        # Rename original to backup
        cursor.execute(f"RENAME TABLE `{original_table}` TO `{backup_table}`")

    # Rename temp to original
    cursor.execute(f"RENAME TABLE `{temp_table}` TO `{original_table}`")

    if original_exists:
        # Drop backup
        cursor.execute(f"DROP TABLE IF EXISTS `{backup_table}`")

    logger.info(f"Swapped tables: {temp_table} -> {original_table}")


def import_gtfs_file(cursor, table_name: str, file_path: Path):
    """Import a single GTFS file into the database."""
    logger.info(f"Importing {file_path.name} -> {table_name}")

    if not file_path.exists():
        logger.warning(f"  File not found: {file_path}")
        return False

    # Read headers from CSV
    columns = read_csv_headers(file_path)
    logger.info(f"  Columns: {', '.join(columns)}")

    # Create temp table
    temp_table = create_temp_table(cursor, table_name, columns)

    # Load data
    load_data_into_table(cursor, temp_table, file_path, columns)

    # Swap tables
    swap_tables(cursor, table_name, temp_table)

    return True


def main():
    parser = argparse.ArgumentParser(description='Import GTFS files into MySQL database')
    parser.add_argument('--gtfs-dir', type=str, default='gtfs_to_import',
                        help='Directory containing GTFS files (default: gtfs_to_import)')
    parser.add_argument('--host', type=str, default='localhost',
                        help='MySQL host (default: localhost)')
    parser.add_argument('--port', type=int, default=3306,
                        help='MySQL port (default: 3306)')
    parser.add_argument('--user', type=str, default='lolados_bus',
                        help='MySQL user (default: lolados_bus)')
    parser.add_argument('--password', type=str, default='bus@2013',
                        help='MySQL password')
    parser.add_argument('--database', type=str, default='lolados_bus',
                        help='MySQL database (default: lolados_bus)')

    args = parser.parse_args()

    # Resolve GTFS directory
    script_dir = Path(__file__).parent
    gtfs_dir = script_dir / args.gtfs_dir

    if not gtfs_dir.exists():
        logger.error(f"GTFS directory not found: {gtfs_dir}")
        sys.exit(1)

    logger.info(f"GTFS directory: {gtfs_dir}")
    logger.info(f"Connecting to MySQL: {args.user}@{args.host}:{args.port}/{args.database}")

    try:
        # Connect to MySQL
        connection = mysql.connector.connect(
            host=args.host,
            port=args.port,
            user=args.user,
            password=args.password,
            database=args.database,
            charset='utf8mb4',
            use_pure=True
        )

        if connection.is_connected():
            logger.info("Connected to MySQL successfully")
            cursor = connection.cursor()

            # Disable foreign key checks during import
            cursor.execute("SET FOREIGN_KEY_CHECKS = 0")

            success_count = 0
            fail_count = 0

            for table_name, file_name in TABLE_FILE_MAPPING.items():
                file_path = gtfs_dir / file_name
                try:
                    if import_gtfs_file(cursor, table_name, file_path):
                        connection.commit()
                        success_count += 1
                    else:
                        fail_count += 1
                except Exception as e:
                    logger.error(f"Error importing {file_name}: {e}")
                    connection.rollback()
                    fail_count += 1

            # Re-enable foreign key checks
            cursor.execute("SET FOREIGN_KEY_CHECKS = 1")

            logger.info(f"\nImport completed: {success_count} succeeded, {fail_count} failed")

            cursor.close()
            connection.close()
            logger.info("MySQL connection closed")

    except Error as e:
        logger.error(f"MySQL Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
