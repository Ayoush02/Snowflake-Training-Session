# main.py
# ============================================================
# DQ Pipeline Orchestrator
# ============================================================

import uuid
from datetime import datetime, date
from dataclasses import dataclass
from typing import List

# ── DQResult dataclass (returned by every check) ─────────────
@dataclass
class DQResult:
    check_number:    int
    check_name:      str
    check_category:  str          # GATE | THRESHOLD | ADVISORY
    check_status:    str          # PASS | FAIL | WARN | SKIP
    column_name:     str  = None
    threshold_value: str  = None
    actual_value:    str  = None
    severity:        str  = 'HIGH'
    notes:           str  = ''

# ── Stage file listing ───────────────────────────────────────
def list_stage_files(session, stage: str) -> List[dict]:
    rows = session.sql(f'LIST @{stage}').collect()
    files = []
    for r in rows:
        name = r['name'].split('/')[-1]
        if name.endswith('.csv'):
            files.append({'name': name, 'size': r['size']})
    return files

# ── Temp table loader (for content-based checks) ─────────────
def load_to_temp(session, stage: str, fmt: str, file: str) -> str:
    tmp = f'TMP_DQ_{uuid.uuid4().hex[:8].upper()}'
    session.sql(f'''
        CREATE OR REPLACE TEMPORARY TABLE {tmp} AS
        SELECT $1::VARCHAR  AS TRANSACTION_ID,
               $2::VARCHAR  AS CUSTOMER_ID,
               $3::VARCHAR  AS PRODUCT_ID,
               $4::VARCHAR  AS TRANSACTION_DATE,
               $5::VARCHAR  AS AMOUNT,
               $6::VARCHAR  AS QUANTITY,
               $7::VARCHAR  AS STATUS,
               $8::VARCHAR  AS REGION,
               $9::VARCHAR  AS CURRENCY,
               $10::VARCHAR AS CREATED_AT
        FROM @{stage}/{file} (FILE_FORMAT => {fmt})
    ''').collect()
    return tmp

# ── CHECK 1: File Size Gate ───────────────────────────────────
def check_file_size(session, stage, file_name, file_size, cfg):
    threshold = cfg['dq']['min_file_size_bytes']
    status = 'PASS' if file_size >= threshold else 'FAIL'
    return [DQResult(
        check_number=1, check_name='FILE_SIZE_CHECK',
        check_category='GATE', check_status=status,
        threshold_value=str(threshold), actual_value=str(file_size),
        severity='CRITICAL',
        notes=f'File size {file_size} bytes vs threshold {threshold} bytes'
    )]

# ── CHECK 2: Column Count Gate ────────────────────────────────
def check_column_count(session, stage, file_name, cfg):
    threshold = cfg['dq']['min_column_count']
    header_row = session.sql(
        f"SELECT $1 AS HDR FROM @{cfg['stage']['stage_name']}/{file_name}"
        f" (FILE_FORMAT => (TYPE=CSV SKIP_HEADER=0)) LIMIT 1"
    ).collect()
    header = header_row[0]['HDR'] if header_row else ''
    col_count = len(header.split(',')) if header else 0
    status = 'PASS' if col_count >= threshold else 'FAIL'
    return [DQResult(
        check_number=2, check_name='COLUMN_COUNT_CHECK',
        check_category='GATE', check_status=status,
        threshold_value=str(threshold), actual_value=str(col_count),
        severity='CRITICAL',
        notes=f'{col_count} columns found, need >= {threshold}'
    )], col_count, header

# ── CHECK 3: Required Columns Gate ───────────────────────────
def check_required_columns(header: str, cfg: dict):
    required = [c.upper() for c in cfg['dq']['required_columns']]
    actual   = [c.strip().upper().strip('"') for c in header.split(',')]
    missing  = [r for r in required if r not in actual]
    status   = 'PASS' if not missing else 'FAIL'
    return [DQResult(
        check_number=3, check_name='REQUIRED_COLUMNS_CHECK',
        check_category='GATE', check_status=status,
        threshold_value=str(required), actual_value=str(actual),
        severity='CRITICAL',
        notes=f'Missing: {missing}' if missing else 'All required columns present'
    )]

# ── CHECK 4: Row Count Threshold ─────────────────────────────
def check_row_count(session, tmp_table, cfg):
    threshold = cfg['dq']['min_row_count']
    cnt = session.sql(f'SELECT COUNT(*) AS CNT FROM {tmp_table}').collect()[0]['CNT']
    status = 'PASS' if cnt >= threshold else 'FAIL'
    return [DQResult(
        check_number=4, check_name='ROW_COUNT_CHECK',
        check_category='THRESHOLD', check_status=status,
        threshold_value=str(threshold), actual_value=str(cnt),
        severity='HIGH',
        notes=f'{cnt} rows found, need >= {threshold}'
    )], cnt

# ── CHECK 5: Null % per Column ────────────────────────────────
def check_null_pct(session, tmp_table, cfg):
    threshold = cfg['dq']['max_null_pct']
    columns = list(cfg['dq']['column_dtype_map'].keys())
    results = []
    for col_name in columns:
        row = session.sql(f'''
            SELECT
                COUNT(*) AS TOTAL,
                SUM(CASE WHEN {col_name} IS NULL OR TRIM({col_name})='' THEN 1 ELSE 0 END) AS NULLS
            FROM {tmp_table}
        ''').collect()[0]
        total = row['TOTAL']
        nulls = row['NULLS']
        pct   = round(nulls / total * 100, 1) if total > 0 else 0.0
        status = 'PASS' if pct <= threshold else 'FAIL'
        results.append(DQResult(
            check_number=5, check_name='NULL_COUNT_CHECK',
            check_category='THRESHOLD', check_status=status,
            column_name=col_name,
            threshold_value=f'max {threshold}% null',
            actual_value=f'{pct}% null',
            severity='CRITICAL' if pct > 50 else 'HIGH',
            notes=f'{nulls} of {total} rows have null {col_name}'
        ))
    return results

# ── CHECK 6: Data Type Validation ─────────────────────────────
def check_data_types(session, tmp_table, cfg):
    dtype_map = cfg['dq']['column_dtype_map']
    cast_map  = {
        'float':     lambda c: f'TRY_TO_DOUBLE({c})',
        'int':       lambda c: f'TRY_TO_NUMBER({c})',
        'date':      lambda c: f'TRY_TO_DATE({c})',
        'timestamp': lambda c: f'TRY_TO_TIMESTAMP({c})',
        'string':    lambda c: 'NULL'
    }
    results = []
    for col_name, dtype in dtype_map.items():
        if dtype == 'string':
            results.append(DQResult(
                check_number=6, check_name='DATA_TYPE_CHECK',
                check_category='THRESHOLD', check_status='PASS',
                column_name=col_name, threshold_value=dtype,
                actual_value='string', severity='LOW',
                notes='String columns skip cast check'
            ))
            continue
        cast_expr = cast_map[dtype](col_name)
        row = session.sql(f'''
            SELECT SUM(CASE WHEN {cast_expr} IS NULL
                             AND {col_name} IS NOT NULL
                             AND TRIM({col_name}) != ''
                        THEN 1 ELSE 0 END) AS BAD_CASTS
            FROM {tmp_table}
        ''').collect()[0]
        bad = row['BAD_CASTS'] or 0
        status = 'PASS' if bad == 0 else 'FAIL'
        results.append(DQResult(
            check_number=6, check_name='DATA_TYPE_CHECK',
            check_category='THRESHOLD', check_status=status,
            column_name=col_name, threshold_value=dtype,
            actual_value=f'{bad} non-castable rows',
            severity='HIGH', notes=f'{bad} rows cannot be cast to {dtype}'
        ))
    return results

# ── CHECK 7: Primary Key Uniqueness ──────────────────────────
def check_primary_key(session, tmp_table, cfg):
    pk_cols = cfg['dq']['pk_columns']
    pk_expr = ', '.join(pk_cols)
    row = session.sql(f'''
        SELECT COUNT(*) - COUNT(DISTINCT {pk_expr}) AS DUP_COUNT
        FROM {tmp_table}
    ''').collect()[0]
    dups   = row['DUP_COUNT'] or 0
    status = 'PASS' if dups == 0 else 'FAIL'
    return [DQResult(
        check_number=7, check_name='PK_UNIQUENESS_CHECK',
        check_category='THRESHOLD', check_status=status,
        column_name=pk_expr, threshold_value='0 duplicates',
        actual_value=f'{dups} duplicate PKs', severity='CRITICAL',
        notes=f'{dups} duplicate values in PK columns: {pk_cols}'
    )]

# ── CHECK 8: Foreign Key Constraint ──────────────────────────
def check_foreign_keys(session, tmp_table, cfg):
    results = []
    for fk_col, ref in cfg['dq']['fk_checks'].items():
        ref_table = ref.split('(')[0]
        ref_col   = ref.split('(')[1].rstrip(')')
        row = session.sql(f'''
            SELECT COUNT(*) AS ORPHANS
            FROM {tmp_table} t
            LEFT JOIN {ref_table} d ON t.{fk_col} = d.{ref_col}
            WHERE t.{fk_col} IS NOT NULL AND d.{ref_col} IS NULL
        ''').collect()[0]
        orphans = row['ORPHANS'] or 0
        status  = 'PASS' if orphans == 0 else 'FAIL'
        results.append(DQResult(
            check_number=8, check_name='FOREIGN_KEY_CHECK',
            check_category='THRESHOLD', check_status=status,
            column_name=fk_col, threshold_value='0 orphans',
            actual_value=f'{orphans} orphan keys', severity='HIGH',
            notes=f'{orphans} {fk_col} values not found in {ref_table}'
        ))
    return results

# ── CHECK 9: Duplicate Rows (Advisory) ───────────────────────
def check_duplicate_rows(session, tmp_table, cfg):
    threshold = cfg['dq']['max_duplicate_row_pct']
    row = session.sql(f'''
        WITH DUPS AS (
            SELECT COUNT(*) AS DUP_ROWS FROM (
                SELECT *, COUNT(*) AS CNT
                FROM {tmp_table}
                GROUP BY ALL HAVING COUNT(*) > 1
            )
        ), TOTAL AS (SELECT COUNT(*) AS TOT FROM {tmp_table})
        SELECT DUP_ROWS, TOT,
               ROUND(DUP_ROWS / NULLIF(TOT, 0) * 100, 1) AS DUP_PCT
        FROM DUPS, TOTAL
    ''').collect()[0]
    pct    = row['DUP_PCT'] or 0.0
    status = 'PASS' if pct <= threshold else 'WARN'
    return [DQResult(
        check_number=9, check_name='DUPLICATE_ROW_CHECK',
        check_category='ADVISORY', check_status=status,
        threshold_value=f'max {threshold}%',
        actual_value=f'{pct}% duplicates', severity='MEDIUM',
        notes=f'{row["DUP_ROWS"]} of {row["TOT"]} rows are exact duplicates'
    )]

# ── CHECK 10: Date Range (Advisory) ──────────────────────────
def check_date_range(session, tmp_table, cfg):
    results = []
    today = date.today().isoformat()
    for col_name, rng in cfg['dq']['date_range_checks'].items():
        min_d = rng['min']
        max_d = today if rng['max'] == 'today' else rng['max']
        row = session.sql(f'''
            SELECT COUNT(*) AS OUT_OF_RANGE
            FROM {tmp_table}
            WHERE TRY_TO_DATE({col_name}) IS NOT NULL
              AND (TRY_TO_DATE({col_name}) < '{min_d}'
                OR TRY_TO_DATE({col_name}) > '{max_d}')
        ''').collect()[0]
        oor    = row['OUT_OF_RANGE'] or 0
        status = 'PASS' if oor == 0 else 'WARN'
        results.append(DQResult(
            check_number=10, check_name='DATE_RANGE_CHECK',
            check_category='ADVISORY', check_status=status,
            column_name=col_name,
            threshold_value=f'{min_d} to {max_d}',
            actual_value=f'{oor} out-of-range rows', severity='LOW',
            notes=f'{oor} rows have {col_name} outside [{min_d}, {max_d}]'
        ))
    return results

# ── CHECK 11: Numeric Range (Advisory) ───────────────────────
def check_numeric_range(session, tmp_table, cfg):
    results = []
    for col_name, rng in cfg['dq']['numeric_range_checks'].items():
        min_v, max_v = rng['min'], rng['max']
        row = session.sql(f'''
            SELECT COUNT(*) AS OUT_OF_RANGE
            FROM {tmp_table}
            WHERE TRY_TO_DOUBLE({col_name}) IS NOT NULL
              AND (TRY_TO_DOUBLE({col_name}) < {min_v}
                OR TRY_TO_DOUBLE({col_name}) > {max_v})
        ''').collect()[0]
        oor    = row['OUT_OF_RANGE'] or 0
        status = 'PASS' if oor == 0 else 'WARN'
        results.append(DQResult(
            check_number=11, check_name='NUMERIC_RANGE_CHECK',
            check_category='ADVISORY', check_status=status,
            column_name=col_name,
            threshold_value=f'{min_v} to {max_v}',
            actual_value=f'{oor} out-of-range rows', severity='MEDIUM',
            notes=f'{oor} {col_name} values outside [{min_v}, {max_v}]'
        ))
    return results

# ── CHECK 12: Allowed Values (Advisory) ──────────────────────
def check_allowed_values(session, tmp_table, cfg):
    results = []
    for col_name, allowed in cfg['dq']['allowed_values'].items():
        allowed_sql = ', '.join(f"'{v}'" for v in allowed)
        row = session.sql(f'''
            SELECT COUNT(*) AS BAD_VALS
            FROM {tmp_table}
            WHERE {col_name} IS NOT NULL
              AND UPPER(TRIM({col_name})) NOT IN ({allowed_sql})
        ''').collect()[0]
        bad    = row['BAD_VALS'] or 0
        status = 'PASS' if bad == 0 else 'WARN'
        results.append(DQResult(
            check_number=12, check_name='ALLOWED_VALUES_CHECK',
            check_category='ADVISORY', check_status=status,
            column_name=col_name,
            threshold_value=str(allowed),
            actual_value=f'{bad} invalid rows', severity='LOW',
            notes=f'{bad} {col_name} values not in allowed list'
        ))
    return results

# ── Audit Logger ──────────────────────────────────────────────
def log_file_result(session, cfg, run_id, file_name, file_size,
                    row_count, col_count, status, reasons, rows_loaded):
    mon = cfg['monitoring']
    db  = mon['database']
    sch = mon['schema']
    tbl = mon['file_processing_table']
    reasons_sql = reasons.replace("'", "''")
    session.sql(f'''
        INSERT INTO {db}.{sch}.{tbl}
            (PIPELINE_RUN_ID, FILE_NAME, FILE_SIZE_BYTES, ROW_COUNT,
             COLUMN_COUNT, PROCESSING_STATUS, REJECTION_REASONS,
             ROWS_LOADED, TEAM_NAME)
        VALUES
            ('{run_id}', '{file_name}', {file_size}, {row_count},
             {col_count}, '{status}', '{reasons_sql}',
             {rows_loaded}, '{cfg["notification"]["team_name"]}')
    ''').collect()
    log_id = session.sql(f'''
        SELECT MAX(LOG_ID) AS LID FROM {db}.{sch}.{tbl}
        WHERE PIPELINE_RUN_ID = '{run_id}' AND FILE_NAME = '{file_name}'
    ''').collect()[0]['LID']
    return log_id

def log_dq_results(session, cfg, run_id, file_name, log_id,
                   results: List[DQResult]):
    mon = cfg['monitoring']
    db  = mon['database']
    sch = mon['schema']
    tbl = mon['dq_metrics_table']
    for r in results:
        col_name  = r.column_name  or 'N/A'
        thr_val   = (r.threshold_value or '').replace("'", "''")
        act_val   = (r.actual_value   or '').replace("'", "''")
        notes_sql = (r.notes or '').replace("'", "''")
        session.sql(f'''
            INSERT INTO {db}.{sch}.{tbl}
                (LOG_ID, PIPELINE_RUN_ID, FILE_NAME, CHECK_NUMBER,
                 CHECK_NAME, CHECK_CATEGORY, CHECK_STATUS, COLUMN_NAME,
                 THRESHOLD_VALUE, ACTUAL_VALUE, SEVERITY, NOTES)
            VALUES
                ({log_id}, '{run_id}', '{file_name}', {r.check_number},
                 '{r.check_name}', '{r.check_category}', '{r.check_status}',
                 '{col_name}', '{thr_val}', '{act_val}',
                 '{r.severity}', '{notes_sql}')
        ''').collect()

# ── Email Notifier ────────────────────────────────────────────
def send_alert(session, cfg, run_id, file_name, file_size,
               row_count, status, failed: List[DQResult]):
    if status not in cfg['notification']['send_on']:
        return
    mon = cfg['monitoring']
    recipients = session.sql(f'''
        SELECT EMAIL_ADDRESS FROM
        {mon['database']}.{mon['schema']}.{mon['email_recipient_table']}
        WHERE IS_ACTIVE = TRUE
          AND TEAM_NAME = '{cfg["notification"]["team_name"]}'
          AND NOTIFICATION_TYPE IN ('FAILURE', 'ALL')
    ''').collect()
    if not recipients:
        return
    to_list = ', '.join(r['EMAIL_ADDRESS'] for r in recipients)
    ts      = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    subject = f"{cfg['notification']['subject_prefix']} — {file_name} — {ts}"
    failed_block = ''
    for f in failed:
        failed_block += f'Check #{f.check_number} — {f.check_name} [{f.severity}]\n'
        if f.column_name:     failed_block += f'  Column    : {f.column_name}\n'
        if f.threshold_value: failed_block += f'  Threshold : {f.threshold_value}\n'
        if f.actual_value:    failed_block += f'  Actual    : {f.actual_value}\n'
        if f.notes:           failed_block += f'  Notes     : {f.notes}\n'
        failed_block += '\n'
    body = (
        f'Pipeline Run ID : {run_id}\n'
        f'Team            : {cfg["notification"]["team_name"]}\n'
        f'File            : {file_name}\n'
        f'File Size       : {file_size:,} bytes\n'
        f'Row Count       : {row_count}\n'
        f'Status          : REJECTED\n\n'
        f'FAILED CHECKS\n'
        f'{"=" * 60}\n'
        f'{failed_block}\n'
        f'ACTION: File quarantined. Review and re-deliver corrected data.\n\n'
        f'Audit SQL:\n'
        f'  SELECT * FROM ANALYTICS_DB.DQ_MONITORING.DQ_METRICS_LOG\n'
        f'  WHERE FILE_NAME = \'{file_name}\' ORDER BY CHECK_NUMBER;\n'
    )
    body_escaped    = body.replace("'", "''")
    subject_escaped = subject.replace("'", "''")
    session.sql(f'''
        CALL SYSTEM$SEND_EMAIL(
            '{mon["notification_integration"]}',
            '{to_list}',
            '{subject_escaped}',
            '{body_escaped}'
        )
    ''').collect()

# ── File mover ───────────────────────────────────────────────
def move_file(session, stage_base, file_name, dest_folder):
    try:
        session.sql(f'''
            COPY FILES
            INTO @{stage_base}_{dest_folder.upper()}/{file_name}
            FROM @{stage_base}/{file_name}
        ''').collect()
        session.sql(f"REMOVE @{stage_base}/{file_name}").collect()
    except Exception as e:
        print(f'  [WARN] Could not move file {file_name}: {e}')

# ── COPY INTO RAW.TRANSACTION ─────────────────────────────────
def copy_into_raw(session, cfg, stage, fmt, file_name, run_id) -> int:
    target = cfg['target']['full_path']
    result = session.sql(f'''
        COPY INTO {target}
            (TRANSACTION_ID, CUSTOMER_ID, PRODUCT_ID,
             TRANSACTION_DATE, AMOUNT, QUANTITY,
             STATUS, REGION, CURRENCY,
             _DQ_PIPELINE_RUN_ID, _SOURCE_FILE_NAME)
        FROM (
            SELECT
                $1::VARCHAR,  $2::VARCHAR,  $3::VARCHAR,
                $4::DATE,     $5::FLOAT,    $6::INT,
                $7::VARCHAR,  $8::VARCHAR,  $9::VARCHAR,
                '{run_id}', '{file_name}'
            FROM @{stage}/{file_name} (FILE_FORMAT => {fmt})
        )
        FORCE = FALSE
        ON_ERROR = ABORT_STATEMENT
    ''').collect()
    rows_loaded = result[0]['rows_loaded'] if result else 0
    return rows_loaded

# ══════════════════════════════════════════════════════════════
# MAIN ENTRY POINT — called by Snowflake Python Worksheet
# session is auto-injected by Snowflake; no login needed
# ══════════════════════════════════════════════════════════════
def main(session):

    # ── Hardcoded config (replaces config.py) ─────────────────
    cfg = {
        'stage': {
            'stage_name':       'S3_TRANSACTION_STAGE',
            'file_format_name': 'CSV_FORMAT'
        },
        'target': {
            'full_path': 'ANALYTICS_DB.RAW.TRANSACTION'
        },
        'monitoring': {
            'database':                 'ANALYTICS_DB',
            'schema':                   'DQ_MONITORING',
            'file_processing_table':    'FILE_PROCESSING_LOG',
            'dq_metrics_table':         'DQ_METRICS_LOG',
            'email_recipient_table':    'EMAIL_RECIPIENT_LOG',
            'notification_integration': 'EMAIL_NOTIFICATION_INTEGRATION'
        },
        'dq': {
            'min_file_size_bytes': 100,          # SET TO 1048576 FOR PRODUCTION
            'min_column_count':    7,
            'required_columns': [
                'TRANSACTION_ID', 'CUSTOMER_ID', 'PRODUCT_ID',
                'TRANSACTION_DATE', 'AMOUNT', 'QUANTITY',
                'STATUS', 'REGION', 'CURRENCY'
            ],
            'min_row_count': 10,
            'max_null_pct':  30.0,
            'column_dtype_map': {
                'TRANSACTION_ID':   'string',
                'CUSTOMER_ID':      'string',
                'PRODUCT_ID':       'string',
                'TRANSACTION_DATE': 'date',
                'AMOUNT':           'float',
                'QUANTITY':         'int',
                'STATUS':           'string',
                'REGION':           'string',
                'CURRENCY':         'string'
            },
            'pk_columns': ['TRANSACTION_ID'],
            'fk_checks': {
                'CUSTOMER_ID': 'ANALYTICS_DB.DIM.CUSTOMERS(CUSTOMER_ID)',
                'PRODUCT_ID':  'ANALYTICS_DB.DIM.PRODUCTS(PRODUCT_ID)'
            },
            'max_duplicate_row_pct': 5.0,
            'allowed_values': {
                'STATUS':   ['COMPLETED', 'PENDING', 'CANCELLED', 'REFUNDED'],
                'CURRENCY': ['USD', 'INR', 'EUR', 'GBP', 'AED']
            },
            'numeric_range_checks': {
                'AMOUNT':   {'min': 0.01, 'max': 1000000.0},
                'QUANTITY': {'min': 1,    'max': 10000}
            },
            'date_range_checks': {
                'TRANSACTION_DATE': {'min': '2000-01-01', 'max': 'today'}
            }
        },
        'notification': {
            'sender_email':   'dq-pipeline@yourcompany.com',
            'subject_prefix': '[DQ ALERT] Data Quality Failure',
            'send_on':        ['FAILURE'],
            'team_name':      'DATA_ENGINEERING'
        }
    }
    # ──────────────────────────────────────────────────────────

    run_id = str(uuid.uuid4())
    stage  = cfg['stage']['stage_name']
    fmt    = cfg['stage']['file_format_name']

    print(f'Pipeline Run ID: {run_id}')

    files = list_stage_files(session, stage)
    print(f'Found {len(files)} CSV files in stage')

    summary = {'total': len(files), 'passed': 0, 'rejected': 0, 'rows_loaded': 0}

    for f in files:
        file_name = f['name']
        file_size = f['size']
        print(f'\n  Processing: {file_name} ({file_size:,} bytes)')

        all_results   = []
        failed_checks = []
        row_count     = 0
        col_count     = 0

        try:
            # ── GATE CHECKS ──────────────────────────────────
            r1 = check_file_size(session, stage, file_name, file_size, cfg)
            all_results.extend(r1)
            if any(r.check_status == 'FAIL' for r in r1):
                failed_checks.extend([r for r in r1 if r.check_status == 'FAIL'])
                raise StopIteration('File size gate failed')

            r2, col_count, header = check_column_count(session, stage, file_name, cfg)
            all_results.extend(r2)
            if any(r.check_status == 'FAIL' for r in r2):
                failed_checks.extend([r for r in r2 if r.check_status == 'FAIL'])
                raise StopIteration('Column count gate failed')

            r3 = check_required_columns(header, cfg)
            all_results.extend(r3)
            if any(r.check_status == 'FAIL' for r in r3):
                failed_checks.extend([r for r in r3 if r.check_status == 'FAIL'])
                raise StopIteration('Required columns gate failed')

            # ── Load to temp for content checks ──────────────
            tmp = load_to_temp(session, stage, fmt, file_name)

            # ── THRESHOLD CHECKS ─────────────────────────────
            r4, row_count = check_row_count(session, tmp, cfg)
            all_results.extend(r4)
            if any(r.check_status == 'FAIL' for r in r4):
                failed_checks.extend([r for r in r4 if r.check_status == 'FAIL'])
                raise StopIteration('Row count threshold failed')

            r5 = check_null_pct(session, tmp, cfg)
            all_results.extend(r5)
            if any(r.check_status == 'FAIL' for r in r5):
                failed_checks.extend([r for r in r5 if r.check_status == 'FAIL'])
                raise StopIteration('Null pct threshold failed')

            r6 = check_data_types(session, tmp, cfg)
            all_results.extend(r6)
            if any(r.check_status == 'FAIL' for r in r6):
                failed_checks.extend([r for r in r6 if r.check_status == 'FAIL'])
                raise StopIteration('Data type check failed')

            r7 = check_primary_key(session, tmp, cfg)
            all_results.extend(r7)
            if any(r.check_status == 'FAIL' for r in r7):
                failed_checks.extend([r for r in r7 if r.check_status == 'FAIL'])
                raise StopIteration('PK uniqueness check failed')

            r8 = check_foreign_keys(session, tmp, cfg)
            all_results.extend(r8)
            if any(r.check_status == 'FAIL' for r in r8):
                failed_checks.extend([r for r in r8 if r.check_status == 'FAIL'])
                raise StopIteration('FK constraint check failed')

            # ── ADVISORY CHECKS ───────────────────────────────
            all_results.extend(check_duplicate_rows(session, tmp, cfg))
            all_results.extend(check_date_range(session, tmp, cfg))
            all_results.extend(check_numeric_range(session, tmp, cfg))
            all_results.extend(check_allowed_values(session, tmp, cfg))

            # ── PASS: Load to RAW ─────────────────────────────
            rows_loaded = copy_into_raw(session, cfg, stage, fmt, file_name, run_id)
            log_id = log_file_result(session, cfg, run_id, file_name,
                                     file_size, row_count, col_count,
                                     'PASSED', '', rows_loaded)
            log_dq_results(session, cfg, run_id, file_name, log_id, all_results)
            move_file(session, stage, file_name, 'processed')
            summary['passed']      += 1
            summary['rows_loaded'] += rows_loaded
            print(f'    STATUS: PASSED | {rows_loaded} rows loaded')

        except StopIteration as e:
            reasons = ' | '.join(
                f'Check{r.check_number}:{r.check_name}' for r in failed_checks
            )
            log_id = log_file_result(session, cfg, run_id, file_name,
                                     file_size, row_count, col_count,
                                     'REJECTED', reasons, 0)
            log_dq_results(session, cfg, run_id, file_name, log_id, all_results)
            send_alert(session, cfg, run_id, file_name, file_size,
                       row_count, 'FAILURE', failed_checks)
            move_file(session, stage, file_name, 'quarantine')
            summary['rejected'] += 1
            print(f'    STATUS: REJECTED | {e}')

        except Exception as ex:
            print(f'    [ERROR] Unexpected error processing {file_name}: {ex}')
            summary['rejected'] += 1

    print(f'\n{"=" * 60}')
    print(f'Pipeline Complete — Run ID: {run_id}')
    print(f'Total   : {summary["total"]}')
    print(f'Passed  : {summary["passed"]}')
    print(f'Rejected: {summary["rejected"]}')
    print(f'Rows Loaded: {summary["rows_loaded"]}')

    return session.create_dataframe(
        [[run_id, summary['total'], summary['passed'],
          summary['rejected'], summary['rows_loaded']]],
        schema=['RUN_ID', 'TOTAL_FILES', 'PASSED', 'REJECTED', 'ROWS_LOADED']
    )