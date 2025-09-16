-- CIS Oracle Database Multi-Version Benchmark Complete Audit Script
-- Dynamically adapts to Oracle 11g R2, 12c, 18c, and 19c
-- Based on CIS Oracle Database Benchmarks:
--   11g R2: v2.2.0
--   12c: v2.0.0
--   18c: v1.0.0
--   19c: v1.0.0
-- Author: Alexis Boscher
-- Date: 2025

-- SQL*Plus Settings
SET PAGESIZE 0
SET LINESIZE 4000
SET HEADING OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET TRIMSPOOL ON
SET TERMOUT ON
SET ECHO OFF

-- Version Detection Variables (must be defined before query)
COLUMN db_version NEW_VALUE db_version
COLUMN version_num NEW_VALUE version_num
COLUMN version_display NEW_VALUE version_display
COLUMN is_11g NEW_VALUE is_11g
COLUMN is_12c NEW_VALUE is_12c
COLUMN is_18c NEW_VALUE is_18c
COLUMN is_19c NEW_VALUE is_19c
COLUMN is_multitenant NEW_VALUE is_multitenant
COLUMN cis_version NEW_VALUE cis_version

-- Detect Oracle Version (must run with TERMOUT ON to set variables)
SELECT 
  CASE 
    WHEN version LIKE '19.%' THEN '19c'
    WHEN version LIKE '18.%' THEN '18c'
    WHEN version LIKE '12.2%' THEN '12c_R2'
    WHEN version LIKE '12.1%' THEN '12c_R1'
    WHEN version LIKE '11.2%' THEN '11g_R2'
    ELSE 'Unknown'
  END AS db_version,
  CASE 
    WHEN version LIKE '19.%' THEN '19'
    WHEN version LIKE '18.%' THEN '18'
    WHEN version LIKE '12.%' THEN '12'
    WHEN version LIKE '11.%' THEN '11'
    ELSE '0'
  END AS version_num,
  CASE 
    WHEN version LIKE '19.%' THEN 'Oracle Database 19c'
    WHEN version LIKE '18.%' THEN 'Oracle Database 18c'
    WHEN version LIKE '12.2%' THEN 'Oracle Database 12c Release 2'
    WHEN version LIKE '12.1%' THEN 'Oracle Database 12c Release 1'
    WHEN version LIKE '11.2%' THEN 'Oracle Database 11g Release 2'
    ELSE 'Oracle Database'
  END AS version_display,
  CASE WHEN version LIKE '11.%' THEN 'YES' ELSE 'NO' END AS is_11g,
  CASE WHEN version LIKE '12.%' THEN 'YES' ELSE 'NO' END AS is_12c,
  CASE WHEN version LIKE '18.%' THEN 'YES' ELSE 'NO' END AS is_18c,
  CASE WHEN version LIKE '19.%' THEN 'YES' ELSE 'NO' END AS is_19c,
  CASE 
    WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
      CASE WHEN (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' THEN 'YES' ELSE 'NO' END
    ELSE 'NO'
  END AS is_multitenant,
  CASE 
    WHEN version LIKE '19.%' THEN 'CIS Oracle Database 19c Benchmark v1.0.0'
    WHEN version LIKE '18.%' THEN 'CIS Oracle Database 18c Benchmark v1.0.0'
    WHEN version LIKE '12.%' THEN 'CIS Oracle Database 12c Benchmark v2.0.0'
    WHEN version LIKE '11.2%' THEN 'CIS Oracle Database 11g R2 Benchmark v2.2.0'
    ELSE 'CIS Oracle Database Benchmark'
  END AS cis_version
FROM v$instance;

-- Get hostname and SID for filename (turn off display for these queries)
SET TERMOUT OFF
COLUMN hostname NEW_VALUE hostname NOPRINT
COLUMN instance_name NEW_VALUE instance_name NOPRINT
SELECT SYS_CONTEXT('USERENV', 'SERVER_HOST') AS hostname FROM DUAL;
SELECT SYS_CONTEXT('USERENV', 'INSTANCE_NAME') AS instance_name FROM DUAL;
SET TERMOUT ON
SET DEFINE ON
-- Set output file with dynamic name CIS_HOST_SID.html
SPOOL CIS_&hostname._&instance_name..html
SET DEFINE OFF
  
-- Now turn off terminal output for the report generation
SET TERMOUT OFF

-- HTML Header and CSS
PROMPT <!DOCTYPE html>
PROMPT <html>
PROMPT <head>
SELECT '<title>CIS ' || 
  CASE 
    WHEN version LIKE '19.%' THEN 'Oracle Database 19c'
    WHEN version LIKE '18.%' THEN 'Oracle Database 18c'
    WHEN version LIKE '12.2%' THEN 'Oracle Database 12c Release 2'
    WHEN version LIKE '12.1%' THEN 'Oracle Database 12c Release 1'
    WHEN version LIKE '11.2%' THEN 'Oracle Database 11g Release 2'
    ELSE 'Oracle Database'
  END || ' Benchmark Audit Report</title>' FROM v$instance;
PROMPT <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
PROMPT <style>
PROMPT .material-icons { font-family: 'Material Icons'; font-weight: normal; font-style: normal; font-size: 18px; line-height: 1; letter-spacing: normal; text-transform: none; display: inline-block; white-space: nowrap; word-wrap: normal; direction: ltr; -webkit-font-feature-settings: 'liga'; -webkit-font-smoothing: antialiased; vertical-align: middle; margin-right: 4px; }
PROMPT body { font-family: Arial, sans-serif; margin: 20px; background-color: #f8f9fa; }
PROMPT .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
PROMPT h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; text-align: center; }
PROMPT h2 { color: #34495e; margin-top: 30px; border-bottom: 2px solid #bdc3c7; padding-bottom: 5px; }
PROMPT h3 { color: #5a6c7d; margin-top: 20px; border-bottom: 1px solid #dee2e6; padding-bottom: 3px; }
PROMPT table { border-collapse: collapse; width: 100%; margin-bottom: 20px; font-size: 12px; }
PROMPT th, td { border: 1px solid #ddd; padding: 6px; text-align: left; vertical-align: top; }
PROMPT th { background-color: #f2f2f2; font-weight: bold; position: sticky; top: 0; }
PROMPT .pass { background-color: #d4edda; }
PROMPT .fail { background-color: #f8d7da; }
PROMPT .warning { background-color: #fff3cd; }
PROMPT .manual { background-color: #e2e3e5; }
PROMPT .remediation { font-family: monospace; font-size: 11px; }
PROMPT .summary-table { font-size: 14px; }
PROMPT .summary-table th, .summary-table td { padding: 10px; }
PROMPT .toc { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
PROMPT .toc ul { list-style-type: none; padding-left: 0; }
PROMPT .toc li { margin: 5px 0; }
PROMPT .toc a { text-decoration: none; color: #007bff; }
PROMPT .toc a:hover { text-decoration: underline; }
PROMPT </style>
PROMPT </head>
PROMPT <body>
PROMPT <div class="container">

-- Report Header
SELECT '<h1><span class="material-icons">security</span>CIS ' || 
  CASE 
    WHEN version LIKE '19.%' THEN 'Oracle Database 19c'
    WHEN version LIKE '18.%' THEN 'Oracle Database 18c'
    WHEN version LIKE '12.2%' THEN 'Oracle Database 12c Release 2'
    WHEN version LIKE '12.1%' THEN 'Oracle Database 12c Release 1'
    WHEN version LIKE '11.2%' THEN 'Oracle Database 11g Release 2'
    ELSE 'Oracle Database'
  END || ' Benchmark Audit Report</h1>' FROM v$instance;
PROMPT <div class="toc"><h3>Database Information</h3>
SELECT '<p><strong>Host:</strong> ' || SYS_CONTEXT('USERENV', 'HOST') || '</p>' FROM DUAL;
SELECT '<p><strong>Database:</strong> ' || SYS_CONTEXT('USERENV', 'DB_NAME') || '</p>' FROM DUAL;
SELECT '<p><strong>Instance:</strong> ' || SYS_CONTEXT('USERENV', 'INSTANCE_NAME') || '</p>' FROM DUAL;
SELECT '<p><strong>Version:</strong> ' || version || ' (' ||
  CASE 
    WHEN version LIKE '19.%' THEN '19c'
    WHEN version LIKE '18.%' THEN '18c'
    WHEN version LIKE '12.2%' THEN '12c R2'
    WHEN version LIKE '12.1%' THEN '12c R1'
    WHEN version LIKE '11.2%' THEN '11g R2'
    ELSE 'Unknown'
  END || ')</p>' FROM v$instance;
SELECT '<p><strong>CIS Benchmark:</strong> ' ||
  CASE 
    WHEN version LIKE '19.%' THEN 'CIS Oracle Database 19c Benchmark v1.0.0'
    WHEN version LIKE '18.%' THEN 'CIS Oracle Database 18c Benchmark v1.0.0'
    WHEN version LIKE '12.%' THEN 'CIS Oracle Database 12c Benchmark v2.0.0'
    WHEN version LIKE '11.2%' THEN 'CIS Oracle Database 11g R2 Benchmark v2.2.0'
    ELSE 'CIS Oracle Database Benchmark'
  END || '</p>' FROM v$instance;
SELECT '<p><strong>Generated:</strong> ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || '</p>' FROM DUAL;
SELECT '<p><strong>User:</strong> ' || USER || '</p>' FROM DUAL;

-- Add multitenant info for 12c+
SELECT CASE 
  WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
    '<p><strong>Container Database (CDB):</strong> ' || 
    NVL((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1), 'NO') || '</p>' ||
    CASE WHEN (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' THEN
      '<p><strong>Current Container:</strong> ' || SYS_CONTEXT('USERENV', 'CON_NAME') || '</p>'
    ELSE '' END
  ELSE '' 
END FROM v$instance;

PROMPT </div>

-- Table of Contents
PROMPT <div class="toc">
PROMPT <h3>Table of Contents</h3>
PROMPT <ul>
PROMPT <li><a href="#section1">1. Oracle Database Installation and Patching Requirements</a></li>
PROMPT <li><a href="#section2">2. Oracle Parameter Settings</a></li>
PROMPT <li><a href="#section3">3. Oracle Connection and Login Restrictions</a></li>
PROMPT <li><a href="#section4">4. Oracle User Access and Authorization Restrictions</a></li>
PROMPT <li><a href="#section5">5. Audit/Logging Policies and Procedures</a></li>
PROMPT <li><a href="#summary">Summary</a></li>
PROMPT </ul>
PROMPT </div>

-- Section 1: Oracle Database Installation and Patching Requirements
PROMPT <h2 id="section1">1. Oracle Database Installation and Patching Requirements</h2>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 1.1 Ensure the Appropriate Version/Patches for Oracle Software Is Installed
SELECT '<tr class="' ||
  CASE 
    WHEN version LIKE '19.%' THEN 'pass'
    WHEN version LIKE '18.%' THEN 'pass'
    WHEN version LIKE '12.%' THEN 'pass'
    WHEN version LIKE '11.2.0.4%' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>1.1</td>' ||
  '<td>Ensure the Appropriate Version/Patches for Oracle Software Is Installed (Scored)</td>' ||
  '<td>' || 
    CASE 
      WHEN version LIKE '19.%' OR version LIKE '18.%' OR version LIKE '12.%' OR version LIKE '11.2.0.4%' THEN 'PASS'
      ELSE 'FAIL'
    END || '</td>' ||
  '<td>' || version || '</td>' ||
  '<td>' || 
    CASE 
      WHEN version LIKE '19.%' THEN '19.x with latest RU'
      WHEN version LIKE '18.%' THEN '18.x with latest RU'
      WHEN version LIKE '12.%' THEN '12.x with latest PSU'
      WHEN version LIKE '11.2%' THEN '11.2.0.4 with latest PSU'
      ELSE 'Check CIS Benchmark'
    END || '</td>' ||
  '<td class="remediation">Apply latest RU/PSU patches</td>' ||
  '</tr>'
FROM v$instance;

-- 1.2 Ensure All Default Passwords Are Changed
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>1.2</td>' ||
  '<td>Ensure All Default Passwords Are Changed (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(USERNAME, ', ') WITHIN GROUP (ORDER BY USERNAME)
    ELSE 'No users with default passwords'
    END || '</td>' ||
  '<td>No users should have default passwords</td>' ||
  '<td class="remediation">PASSWORD &lt;username&gt; or ALTER USER &lt;username&gt; IDENTIFIED BY &lt;new_password&gt;</td>' ||
  '</tr>'
FROM DBA_USERS_WITH_DEFPWD
WHERE USERNAME NOT LIKE '%XS$NULL%';

-- 1.3 Ensure All Sample Data And Users Have Been Removed
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>1.3</td>' ||
  '<td>Ensure All Sample Data And Users Have Been Removed (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(USERNAME, ', ') WITHIN GROUP (ORDER BY USERNAME)
    ELSE 'No sample users found'
    END || '</td>' ||
  '<td>No Oracle sample users should exist</td>' ||
  '<td class="remediation">Execute $ORACLE_HOME/demo/schema/drop_sch.sql to remove sample schemas</td>' ||
  '</tr>'
FROM ALL_USERS
WHERE USERNAME IN ('BI','HR','IX','OE','PM','SCOTT','SH');

-- 1.4 12c+: Check PDBADMIN accounts in multitenant
WITH pdbadmin_check AS (
  SELECT COUNT(*) AS pdbadmin_count
  FROM DBA_USERS 
  WHERE USERNAME = 'PDBADMIN' 
    AND ACCOUNT_STATUS = 'OPEN'
)
SELECT CASE 
  WHEN vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
    CASE WHEN (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' THEN
      '<tr class="' ||
      CASE 
        WHEN pc.pdbadmin_count = 0 THEN 'pass'
        ELSE 'warning'
      END || '">' ||
      '<td>1.4</td>' ||
      '<td>Ensure PDBADMIN Accounts Are Secured (12c+ Multitenant) (Scored)</td>' ||
      '<td>' || CASE WHEN pc.pdbadmin_count = 0 THEN 'PASS' ELSE 'WARNING' END || '</td>' ||
      '<td>' || 
        CASE WHEN pc.pdbadmin_count > 0 THEN 
          'PDBADMIN accounts found: ' || pc.pdbadmin_count
        ELSE 'No PDBADMIN accounts with default settings'
        END || '</td>' ||
      '<td>PDBADMIN accounts should be locked or have strong passwords</td>' ||
      '<td class="remediation">ALTER USER PDBADMIN ACCOUNT LOCK or set strong password</td>' ||
      '</tr>'
    ELSE ''
    END
  ELSE '' 
END
FROM v$instance vi, pdbadmin_check pc;

-- 1.5 18c+: Check for schema-only accounts
SELECT CASE WHEN version LIKE '18.%' OR version LIKE '19.%' THEN
  '<tr class="manual">' ||
  '<td>1.5</td>' ||
  '<td>Consider Schema-Only Accounts (18c+) (Not Scored)</td>' ||
  '<td>MANUAL</td>' ||
  '<td>Review application schemas for NO AUTHENTICATION option</td>' ||
  '<td>Application schemas should use NO AUTHENTICATION where possible</td>' ||
  '<td class="remediation">CREATE USER app_schema NO AUTHENTICATION</td>' ||
  '</tr>'
ELSE '' END FROM v$instance;

PROMPT </table>

-- Section 2: Oracle Parameter Settings
PROMPT <h2 id="section2">2. Oracle Parameter Settings</h2>

-- 2.1 Listener Settings
PROMPT <h3>2.1 Listener Settings</h3>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- Note: Listener settings require OS-level file access, showing manual review requirements
SELECT '<tr class="manual">' ||
  '<td>2.1.1</td>' ||
  '<td>Ensure SECURE_CONTROL_&lt;listener_name&gt; Is Set In listener.ora (Scored)</td>' ||
  '<td>MANUAL</td>' ||
  '<td>Check listener.ora file manually</td>' ||
  '<td>SECURE_CONTROL_&lt;listener_name&gt; set for each listener</td>' ||
  '<td class="remediation">Set SECURE_CONTROL_&lt;listener_name&gt; in listener.ora</td>' ||
  '</tr>'
FROM DUAL;

SELECT '<tr class="manual">' ||
  '<td>2.1.2</td>' ||
  '<td>Ensure extproc Is Not Present in listener.ora (Scored)</td>' ||
  '<td>MANUAL</td>' ||
  '<td>Check listener.ora file manually</td>' ||
  '<td>extproc should not exist in listener.ora</td>' ||
  '<td class="remediation">Remove extproc from listener.ora file</td>' ||
  '</tr>'
FROM DUAL;

SELECT '<tr class="manual">' ||
  '<td>2.1.3</td>' ||
  '<td>Ensure ADMIN_RESTRICTIONS_&lt;listener_name&gt; Is Set to ON (Scored)</td>' ||
  '<td>MANUAL</td>' ||
  '<td>Check listener.ora file manually</td>' ||
  '<td>ADMIN_RESTRICTIONS_&lt;listener_name&gt; = ON</td>' ||
  '<td class="remediation">Set ADMIN_RESTRICTIONS_&lt;listener_name&gt; = ON in listener.ora</td>' ||
  '</tr>'
FROM DUAL;

SELECT '<tr class="manual">' ||
  '<td>2.1.4</td>' ||
  '<td>Ensure SECURE_REGISTER_&lt;listener_name&gt; Is Set to TCPS or IPC (Scored)</td>' ||
  '<td>MANUAL</td>' ||
  '<td>Check listener.ora file manually</td>' ||
  '<td>SECURE_REGISTER_&lt;listener_name&gt; = TCPS or IPC</td>' ||
  '<td class="remediation">Set SECURE_REGISTER_&lt;listener_name&gt; = TCPS or IPC</td>' ||
  '</tr>'
FROM DUAL;

PROMPT </table>

-- 2.2 Database Settings
PROMPT <h3>2.2 Database Settings</h3>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 2.2.1 AUDIT_SYS_OPERATIONS
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'TRUE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.1</td>' ||
  '<td>Ensure AUDIT_SYS_OPERATIONS Is Set to TRUE (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'TRUE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || VALUE || '</td>' ||
  '<td>TRUE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET AUDIT_SYS_OPERATIONS = TRUE SCOPE=SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'AUDIT_SYS_OPERATIONS';

-- 2.2.2 AUDIT_TRAIL
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED') THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.2</td>' ||
  '<td>Ensure AUDIT_TRAIL Is Set to OS, DB, XML, DB,EXTENDED, or XML,EXTENDED (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED') THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || VALUE || '</td>' ||
  '<td>OS, DB, XML, DB,EXTENDED, or XML,EXTENDED</td>' ||
  '<td class="remediation">ALTER SYSTEM SET AUDIT_TRAIL = DB SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'AUDIT_TRAIL';

-- 2.2.3 GLOBAL_NAMES
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'TRUE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.3</td>' ||
  '<td>Ensure GLOBAL_NAMES Is Set to TRUE (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'TRUE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || VALUE || '</td>' ||
  '<td>TRUE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET GLOBAL_NAMES = TRUE SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'GLOBAL_NAMES';

-- 2.2.4 LOCAL_LISTENER
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) LIKE '%IPC%' OR VALUE IS NULL THEN 'pass'
    ELSE 'warning'
  END || '">' ||
  '<td>2.2.4</td>' ||
  '<td>Ensure LOCAL_LISTENER Is Set Appropriately (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) LIKE '%IPC%' OR VALUE IS NULL THEN 'PASS' ELSE 'REVIEW' END || '</td>' ||
  '<td>' || NVL(VALUE, 'NULL') || '</td>' ||
  '<td>IPC protocol recommended</td>' ||
  '<td class="remediation">ALTER SYSTEM SET LOCAL_LISTENER=''(DESCRIPTION=(ADDRESS=(PROTOCOL=IPC)(KEY=REGISTER)))'' SCOPE=BOTH;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'LOCAL_LISTENER';

-- 2.2.5 O7_DICTIONARY_ACCESSIBILITY
WITH o7_check AS (
  SELECT 
    CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END AS param_exists,
    MAX(UPPER(VALUE)) AS param_value
  FROM V$PARAMETER 
  WHERE UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY'
)
SELECT '<tr class="' ||
  CASE 
    WHEN param_exists = 0 THEN 'warning'
    WHEN param_value = 'FALSE' OR param_value IS NULL THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.5</td>' ||
  '<td>Ensure O7_DICTIONARY_ACCESSIBILITY Is Set to FALSE (Scored)</td>' ||
  '<td>' || 
    CASE 
      WHEN param_exists = 0 THEN 'N/A'
      WHEN param_value = 'FALSE' OR param_value IS NULL THEN 'PASS' 
      ELSE 'FAIL' 
    END || '</td>' ||
  '<td>' || 
    CASE 
      WHEN param_exists = 0 THEN 'Parameter not found in this Oracle version'
      WHEN param_value IS NULL THEN 'FALSE (default)'
      ELSE param_value
    END || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">' ||
    CASE 
      WHEN param_exists = 0 THEN 'Parameter may not exist in this Oracle version'
      ELSE 'ALTER SYSTEM SET O7_DICTIONARY_ACCESSIBILITY=FALSE SCOPE = SPFILE;'
    END || '</td>' ||
  '</tr>'
FROM o7_check;

-- 2.2.6 OS_ROLES
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'FALSE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.6</td>' ||
  '<td>Ensure OS_ROLES Is Set to FALSE (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'FALSE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || VALUE || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET OS_ROLES = FALSE SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'OS_ROLES';

-- 2.2.7 REMOTE_LISTENER
SELECT '<tr class="' ||
  CASE 
    WHEN VALUE IS NULL OR LENGTH(TRIM(VALUE)) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.7</td>' ||
  '<td>Ensure REMOTE_LISTENER Is Empty (Scored)</td>' ||
  '<td>' || CASE WHEN VALUE IS NULL OR LENGTH(TRIM(VALUE)) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(VALUE, 'Empty') || '</td>' ||
  '<td>Empty</td>' ||
  '<td class="remediation">ALTER SYSTEM SET REMOTE_LISTENER = '''' SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'REMOTE_LISTENER';

-- 2.2.8 REMOTE_LOGIN_PASSWORDFILE
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'NONE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.8</td>' ||
  '<td>Ensure REMOTE_LOGIN_PASSWORDFILE Is Set to NONE (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'NONE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || VALUE || '</td>' ||
  '<td>NONE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET REMOTE_LOGIN_PASSWORDFILE = ''NONE'' SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'REMOTE_LOGIN_PASSWORDFILE';

-- 2.2.9 REMOTE_OS_AUTHENT
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'FALSE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.9</td>' ||
  '<td>Ensure REMOTE_OS_AUTHENT Is Set to FALSE (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'FALSE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || VALUE || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET REMOTE_OS_AUTHENT = FALSE SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'REMOTE_OS_AUTHENT';

-- 2.2.10 REMOTE_OS_ROLES
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'FALSE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.10</td>' ||
  '<td>Ensure REMOTE_OS_ROLES Is Set to FALSE (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'FALSE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || VALUE || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET REMOTE_OS_ROLES = FALSE SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'REMOTE_OS_ROLES';

-- 2.2.11 UTL_FILE_DIR
SELECT '<tr class="' ||
  CASE 
    WHEN VALUE IS NULL OR LENGTH(TRIM(VALUE)) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.11</td>' ||
  '<td>Ensure UTL_FILE_DIR Is Empty (Scored)</td>' ||
  '<td>' || CASE WHEN VALUE IS NULL OR LENGTH(TRIM(VALUE)) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(VALUE, 'Empty') || '</td>' ||
  '<td>Empty</td>' ||
  '<td class="remediation">ALTER SYSTEM SET UTL_FILE_DIR = '''' SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'UTL_FILE_DIR';

-- 2.2.12 SEC_CASE_SENSITIVE_LOGON
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'TRUE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.12</td>' ||
  '<td>Ensure SEC_CASE_SENSITIVE_LOGON Is Set to TRUE (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'TRUE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || VALUE || '</td>' ||
  '<td>TRUE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET SEC_CASE_SENSITIVE_LOGON = TRUE SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'SEC_CASE_SENSITIVE_LOGON';

-- 2.2.13 SEC_MAX_FAILED_LOGIN_ATTEMPTS
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = '10' OR (REGEXP_LIKE(VALUE, '^[0-9]+$') AND TO_NUMBER(VALUE) = 10) THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.13</td>' ||
  '<td>Ensure SEC_MAX_FAILED_LOGIN_ATTEMPTS Is Set to 10 (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = '10' OR (REGEXP_LIKE(VALUE, '^[0-9]+$') AND TO_NUMBER(VALUE) = 10) THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || VALUE || '</td>' ||
  '<td>10</td>' ||
  '<td class="remediation">ALTER SYSTEM SET SEC_MAX_FAILED_LOGIN_ATTEMPTS = 10 SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'SEC_MAX_FAILED_LOGIN_ATTEMPTS';

-- 2.2.14 SEC_PROTOCOL_ERROR_FURTHER_ACTION
SELECT '<tr class="' ||
    CASE 
        WHEN UPPER(VALUE) LIKE '%DROP%3%' OR UPPER(VALUE) LIKE '%DELAY%3%' THEN 'pass'
        ELSE 'fail'
    END || '">' ||
  '<td>2.2.14</td>' ||
  '<td>Ensure SEC_PROTOCOL_ERROR_FURTHER_ACTION Is Set to DELAY,3 or DROP,3 (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) LIKE '%DROP%3%' OR UPPER(VALUE) LIKE '%DELAY%3%' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(VALUE, 'Not Set') || '</td>' ||
  '<td>DELAY,3 or DROP,3</td>' ||
  '<td class="remediation">ALTER SYSTEM SET SEC_PROTOCOL_ERROR_FURTHER_ACTION = ''DELAY,3'' SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'SEC_PROTOCOL_ERROR_FURTHER_ACTION';

-- 2.2.15 SEC_PROTOCOL_ERROR_TRACE_ACTION
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'LOG' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.15</td>' ||
  '<td>Ensure SEC_PROTOCOL_ERROR_TRACE_ACTION Is Set to LOG (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'LOG' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(VALUE, 'Not Set') || '</td>' ||
  '<td>LOG</td>' ||
  '<td class="remediation">ALTER SYSTEM SET SEC_PROTOCOL_ERROR_TRACE_ACTION=LOG SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'SEC_PROTOCOL_ERROR_TRACE_ACTION';

-- 2.2.16 SEC_RETURN_SERVER_RELEASE_BANNER
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'FALSE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.16</td>' ||
  '<td>Ensure SEC_RETURN_SERVER_RELEASE_BANNER Is Set to FALSE (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'FALSE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(VALUE, 'Not Set') || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET SEC_RETURN_SERVER_RELEASE_BANNER = FALSE SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'SEC_RETURN_SERVER_RELEASE_BANNER';

-- 2.2.17 SQL92_SECURITY
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'TRUE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.17</td>' ||
  '<td>Ensure SQL92_SECURITY Is Set to TRUE (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'TRUE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || VALUE || '</td>' ||
  '<td>TRUE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET SQL92_SECURITY = TRUE SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'SQL92_SECURITY';

-- 2.2.18 _TRACE_FILES_PUBLIC
SELECT '<tr class="' ||
  CASE 
    WHEN VALUE = 'FALSE' OR VALUE IS NULL THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.18</td>' ||
  '<td>Ensure _TRACE_FILES_PUBLIC Is Set to FALSE (Scored)</td>' ||
  '<td>' || CASE WHEN VALUE = 'FALSE' OR VALUE IS NULL THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(VALUE, 'FALSE (default)') || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET "_trace_files_public" = FALSE SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE NAME = '_trace_files_public';

-- 2.2.19 RESOURCE_LIMIT
SELECT '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'TRUE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.19</td>' ||
  '<td>Ensure RESOURCE_LIMIT Is Set to TRUE (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'TRUE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || VALUE || '</td>' ||
  '<td>TRUE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET RESOURCE_LIMIT = TRUE SCOPE = SPFILE;</td>' ||
  '</tr>'
FROM V$PARAMETER
WHERE UPPER(NAME) = 'RESOURCE_LIMIT';

-- 12c+ Specific Parameters
SELECT CASE WHEN vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) IN ('C##', 'c##') THEN 'pass'
    ELSE 'warning'
  END || '">' ||
  '<td>2.2.20</td>' ||
  '<td>Ensure COMMON_USER_PREFIX Is Set Appropriately (12c+) (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) IN ('C##', 'c##') THEN 'PASS' ELSE 'WARNING' END || '</td>' ||
  '<td>' || NVL(VALUE, 'Not Set') || '</td>' ||
  '<td>C## (default)</td>' ||
  '<td class="remediation">Maintain default or set organizational standard</td>' ||
  '</tr>'
ELSE '' END
FROM V$PARAMETER vp, v$instance vi
WHERE UPPER(vp.NAME) = 'COMMON_USER_PREFIX' 
  AND (vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%');

-- 12c+ ENABLE_DDL_LOGGING
SELECT CASE WHEN vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'TRUE' THEN 'pass'
    ELSE 'warning'
  END || '">' ||
  '<td>2.2.21</td>' ||
  '<td>Ensure ENABLE_DDL_LOGGING Is Set to TRUE (12c+) (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'TRUE' THEN 'PASS' ELSE 'WARNING' END || '</td>' ||
  '<td>' || VALUE || '</td>' ||
  '<td>TRUE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET ENABLE_DDL_LOGGING=TRUE</td>' ||
  '</tr>'
ELSE '' END
FROM V$PARAMETER vp, v$instance vi
WHERE UPPER(vp.NAME) = 'ENABLE_DDL_LOGGING' 
  AND (vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%');

-- 18c+ LDAP_DIRECTORY_SYSAUTH
SELECT CASE WHEN vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'NO' OR VALUE IS NULL THEN 'pass'
    ELSE 'warning'
  END || '">' ||
  '<td>2.2.22</td>' ||
  '<td>Ensure LDAP_DIRECTORY_SYSAUTH Is Set to NO (18c+) (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'NO' OR VALUE IS NULL THEN 'PASS' ELSE 'WARNING' END || '</td>' ||
  '<td>' || NVL(VALUE, 'NO (default)') || '</td>' ||
  '<td>NO</td>' ||
  '<td class="remediation">ALTER SYSTEM SET LDAP_DIRECTORY_SYSAUTH=NO SCOPE=SPFILE</td>' ||
  '</tr>'
ELSE '' END
FROM V$PARAMETER vp, v$instance vi
WHERE UPPER(vp.NAME) = 'LDAP_DIRECTORY_SYSAUTH' 
  AND (vi.version LIKE '18.%' OR vi.version LIKE '19.%');

-- 19c+ ALLOW_GROUP_ACCESS_TO_SGA
SELECT CASE WHEN vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN UPPER(VALUE) = 'FALSE' OR VALUE IS NULL THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.23</td>' ||
  '<td>Ensure ALLOW_GROUP_ACCESS_TO_SGA Is Set to FALSE (19c) (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(VALUE) = 'FALSE' OR VALUE IS NULL THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(VALUE, 'FALSE (default)') || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET ALLOW_GROUP_ACCESS_TO_SGA=FALSE SCOPE=SPFILE</td>' ||
  '</tr>'
ELSE '' END
FROM V$PARAMETER vp, v$instance vi
WHERE UPPER(vp.NAME) = 'ALLOW_GROUP_ACCESS_TO_SGA' 
  AND vi.version LIKE '19.%';

PROMPT </table>

-- Section 3: Oracle Connection and Login Restrictions
PROMPT <h2 id="section3">3. Oracle Connection and Login Restrictions</h2>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 3.1 FAILED_LOGIN_ATTEMPTS
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.1</td>' ||
  '<td>Ensure FAILED_LOGIN_ATTEMPTS Is Less than or Equal to 5 (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE)
    ELSE 'All profiles compliant (5 or less)'
    END || '</td>' ||
  '<td>Less than or equal to 5 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT FAILED_LOGIN_ATTEMPTS 5;</td>' ||
  '</tr>'
FROM DBA_PROFILES
WHERE RESOURCE_NAME='FAILED_LOGIN_ATTEMPTS'
AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR TO_NUMBER(LIMIT) > 5);

-- 3.2 PASSWORD_LOCK_TIME
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.2</td>' ||
  '<td>Ensure PASSWORD_LOCK_TIME Is Greater than or Equal to 1 (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE)
    ELSE 'All profiles compliant (1 or more)'
    END || '</td>' ||
  '<td>Greater than or equal to 1 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT PASSWORD_LOCK_TIME 1;</td>' ||
  '</tr>'
FROM DBA_PROFILES
WHERE RESOURCE_NAME='PASSWORD_LOCK_TIME'
AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR TO_NUMBER(LIMIT) < 1);

-- 3.3 PASSWORD_LIFE_TIME
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.3</td>' ||
  '<td>Ensure PASSWORD_LIFE_TIME Is Less than or Equal to 90 (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE)
    ELSE 'All profiles compliant (90 or less)'
    END || '</td>' ||
  '<td>Less than or equal to 90 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME 90;</td>' ||
  '</tr>'
FROM DBA_PROFILES
WHERE RESOURCE_NAME='PASSWORD_LIFE_TIME'
AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR TO_NUMBER(LIMIT) > 90);

-- 3.4 PASSWORD_REUSE_MAX
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.4</td>' ||
  '<td>Ensure PASSWORD_REUSE_MAX Is Greater than or Equal to 20 (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE)
    ELSE 'All profiles compliant (20 or more)'
    END || '</td>' ||
  '<td>Greater than or equal to 20 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_MAX 20;</td>' ||
  '</tr>'
FROM DBA_PROFILES
WHERE RESOURCE_NAME='PASSWORD_REUSE_MAX'
AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR TO_NUMBER(LIMIT) < 20);

-- 3.5 PASSWORD_REUSE_TIME
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.5</td>' ||
  '<td>Ensure PASSWORD_REUSE_TIME Is Greater than or Equal to 365 (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE)
    ELSE 'All profiles compliant (1 or less)'
    END || '</td>' ||
  '<td>Greater than or equal to 365 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_TIME 365;</td>' ||
  '</tr>'
FROM DBA_PROFILES
WHERE RESOURCE_NAME='PASSWORD_REUSE_TIME'
AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR TO_NUMBER(LIMIT) < 365);

-- 3.6 PASSWORD_GRACE_TIME
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.6</td>' ||
  '<td>Ensure PASSWORD_GRACE_TIME Is Less than or Equal to 5 (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE)
    ELSE 'All profiles compliant (30 or less)'
    END || '</td>' ||
  '<td>Less than or equal to 5 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT PASSWORD_GRACE_TIME 5;</td>' ||
  '</tr>'
FROM DBA_PROFILES
WHERE RESOURCE_NAME='PASSWORD_GRACE_TIME'
AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR TO_NUMBER(LIMIT) > 5);

-- 3.7 DBA_USERS.PASSWORD External
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.7</td>' ||
  '<td>Ensure DBA_USERS.PASSWORD Is Not Set to EXTERNAL for Any User (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(USERNAME, ', ') WITHIN GROUP (ORDER BY USERNAME)
    ELSE 'No users with EXTERNAL authentication'
    END || '</td>' ||
  '<td>No users should use EXTERNAL authentication</td>' ||
  '<td class="remediation">ALTER USER &lt;username&gt; IDENTIFIED BY &lt;password&gt;;</td>' ||
  '</tr>'
FROM DBA_USERS
WHERE PASSWORD='EXTERNAL';

-- 3.8 PASSWORD_VERIFY_FUNCTION
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.8</td>' ||
  '<td>Ensure PASSWORD_VERIFY_FUNCTION Is Set for All Profiles (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE)
    ELSE 'All profiles have password verification function'
    END || '</td>' ||
  '<td>Password verification function set for all profiles</td>' ||
  '<td class="remediation">Create and assign password verification function to profiles</td>' ||
  '</tr>'
FROM DBA_PROFILES
WHERE RESOURCE_NAME='PASSWORD_VERIFY_FUNCTION'
AND (LIMIT = 'DEFAULT' OR LIMIT = 'NULL');

-- 3.9 SESSIONS_PER_USER
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.9</td>' ||
  '<td>Ensure SESSIONS_PER_USER Is Less than or Equal to 10 (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE)
    ELSE 'All profiles compliant (10 or less)'
    END || '</td>' ||
  '<td>Less than or equal to 10 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT SESSIONS_PER_USER 10;</td>' ||
  '</tr>'
FROM DBA_PROFILES
WHERE RESOURCE_NAME='SESSIONS_PER_USER'
AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR TO_NUMBER(LIMIT) > 10);

-- 3.10 No Users Assigned DEFAULT Profile
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.10</td>' ||
  '<td>Ensure No Users Are Assigned the DEFAULT Profile (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(USERNAME, ', ') WITHIN GROUP (ORDER BY USERNAME)
    ELSE 'No non-system users with DEFAULT profile'
    END || '</td>' ||
  '<td>No application users should use DEFAULT profile</td>' ||
  '<td class="remediation">ALTER USER &lt;username&gt; PROFILE &lt;appropriate_profile&gt;</td>' ||
  '</tr>'
FROM DBA_USERS
WHERE PROFILE='DEFAULT'
AND ACCOUNT_STATUS='OPEN'
AND USERNAME NOT IN ('ANONYMOUS', 'CTXSYS', 'DBSNMP', 'EXFSYS', 'LBACSYS',
'MDSYS', 'MGMT_VIEW','OLAPSYS','OWBSYS', 'ORDPLUGINS',
'ORDSYS', 'OUTLN', 'SI_INFORMTN_SCHEMA','SYS',
'SYSMAN', 'SYSTEM', 'TSMSYS', 'WK_TEST', 'WKSYS',
'WKPROXY', 'WMSYS', 'XDB', 'CISSCAN');

-- 12c+ Specific: INACTIVE_ACCOUNT_TIME
SELECT CASE WHEN vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN LIMIT NOT IN ('DEFAULT', 'UNLIMITED') AND 
         REGEXP_LIKE(LIMIT, '^[0-9]+$') AND 
         TO_NUMBER(LIMIT) <= 35 THEN 'pass'
    ELSE 'warning'
  END || '">' ||
  '<td>3.11</td>' ||
  '<td>Ensure INACTIVE_ACCOUNT_TIME Is Less Than or Equal to 35 (12c+) (Scored)</td>' ||
  '<td>' || 
    CASE 
      WHEN LIMIT NOT IN ('DEFAULT', 'UNLIMITED') AND 
           REGEXP_LIKE(LIMIT, '^[0-9]+$') AND 
           TO_NUMBER(LIMIT) <= 35 THEN 'PASS'
      ELSE 'WARNING'
    END || '</td>' ||
  '<td>Profile: ' || PROFILE || ', Limit: ' || LIMIT || '</td>' ||
  '<td>Less than or equal to 35 days</td>' ||
  '<td class="remediation">ALTER PROFILE ' || PROFILE || ' LIMIT INACTIVE_ACCOUNT_TIME 30</td>' ||
  '</tr>'
ELSE '' END
FROM DBA_PROFILES dp, v$instance vi
WHERE dp.RESOURCE_NAME = 'INACTIVE_ACCOUNT_TIME' 
  AND (vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%');

-- 18c+ Specific: PASSWORD_ROLLOVER_TIME
SELECT CASE WHEN vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN LIMIT NOT IN ('DEFAULT', 'UNLIMITED') THEN 'pass'
    ELSE 'manual'
  END || '">' ||
  '<td>3.12</td>' ||
  '<td>Consider PASSWORD_ROLLOVER_TIME for Gradual Password Changes (18c+) (Not Scored)</td>' ||
  '<td>' || 
    CASE 
      WHEN LIMIT NOT IN ('DEFAULT', 'UNLIMITED') THEN 'CONFIGURED'
      ELSE 'NOT SET'
    END || '</td>' ||
  '<td>Profile: ' || PROFILE || ', Limit: ' || LIMIT || '</td>' ||
  '<td>As needed</td>' ||
  '<td class="remediation">Consider for zero-downtime password changes</td>' ||
  '</tr>'
ELSE '' END
FROM DBA_PROFILES dp, v$instance vi
WHERE dp.RESOURCE_NAME = 'PASSWORD_ROLLOVER_TIME' 
  AND (vi.version LIKE '18.%' OR vi.version LIKE '19.%');

PROMPT </table>

-- Section 4: Oracle User Access and Authorization Restrictions
PROMPT <h2 id="section4">4. Oracle User Access and Authorization Restrictions</h2>

-- 4.1 Default Public Privileges for Packages and Object Types
PROMPT <h3>4.1 Default Public Privileges for Packages and Object Types</h3>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 4.1.1 DBMS_ADVISOR
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.1</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_ADVISOR (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_ADVISOR FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_ADVISOR';

-- 4.1.2 DBMS_CRYPTO
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.2</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_CRYPTO (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_CRYPTO FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND TABLE_NAME='DBMS_CRYPTO';

-- 4.1.3 DBMS_JAVA
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.3</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_JAVA (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_JAVA FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_JAVA';

-- 4.1.4 DBMS_JAVA_TEST
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.4</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_JAVA_TEST (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_JAVA_TEST FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_JAVA_TEST';

-- 4.1.5 DBMS_JOB
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.5</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_JOB (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_JOB FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_JOB';

-- 4.1.6 DBMS_LDAP
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.6</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_LDAP (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_LDAP FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_LDAP';

-- 4.1.7 DBMS_LOB
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.7</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_LOB (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_LOB FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_LOB';

-- 4.1.8 DBMS_OBFUSCATION_TOOLKIT
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.8</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_OBFUSCATION_TOOLKIT (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_OBFUSCATION_TOOLKIT FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_OBFUSCATION_TOOLKIT';

-- 4.1.9 DBMS_RANDOM
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.9</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_RANDOM (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_RANDOM FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_RANDOM';

-- 4.1.10 DBMS_SCHEDULER
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.10</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_SCHEDULER (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_SCHEDULER FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_SCHEDULER';

-- 4.1.11 DBMS_SQL
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.11</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_SQL (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_SQL FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_SQL';

-- 4.1.12 DBMS_XMLGEN
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.12</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_XMLGEN (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_XMLGEN FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_XMLGEN';

-- 4.1.13 DBMS_XMLQUERY
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.13</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_XMLQUERY (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_XMLQUERY FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_XMLQUERY';

-- 4.1.14 UTL_FILE
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.14</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on UTL_FILE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON UTL_FILE FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='UTL_FILE';

-- 4.1.15 UTL_INADDR
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.15</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on UTL_INADDR (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON UTL_INADDR FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='UTL_INADDR';

-- 4.1.16 UTL_TCP
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.16</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on UTL_TCP (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON UTL_TCP FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='UTL_TCP';

-- 4.1.17 UTL_MAIL
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.17</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on UTL_MAIL (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON UTL_MAIL FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='UTL_MAIL';

-- 4.1.18 UTL_SMTP
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.18</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on UTL_SMTP (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON UTL_SMTP FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='UTL_SMTP';

-- 4.1.19 UTL_DBWS
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.19</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on UTL_DBWS (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON UTL_DBWS FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='UTL_DBWS';

-- 4.1.20 UTL_ORAMTS
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.20</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on UTL_ORAMTS (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON UTL_ORAMTS FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='UTL_ORAMTS';

-- 4.1.21 UTL_HTTP
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.21</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on UTL_HTTP (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON UTL_HTTP FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='UTL_HTTP';

-- 4.1.22 HTTPURITYPE
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.1.22</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on HTTPURITYPE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON HTTPURITYPE FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='HTTPURITYPE';

PROMPT </table>

-- 4.2 Revoke Non-Default Privileges for Packages and Object Types
PROMPT <h3>4.2 Revoke Non-Default Privileges for Packages and Object Types</h3>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 4.2.1 DBMS_SYS_SQL
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.1</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_SYS_SQL (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_SYS_SQL FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_SYS_SQL';

-- 4.2.2 DBMS_BACKUP_RESTORE
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.2</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_BACKUP_RESTORE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_BACKUP_RESTORE FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_BACKUP_RESTORE';

-- 4.2.3 DBMS_AQADM_SYSCALLS
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.3</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_AQADM_SYSCALLS (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_AQADM_SYSCALLS FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_AQADM_SYSCALLS';

-- 4.2.4 DBMS_REPCAT_SQL_UTL
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.4</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_REPCAT_SQL_UTL (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_REPCAT_SQL_UTL FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_REPCAT_SQL_UTL';

-- 4.2.5 INITJVMAUX
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.5</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on INITJVMAUX (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON INITJVMAUX FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='INITJVMAUX';

-- 4.2.6 DBMS_STREAMS_ADM_UTL
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.6</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_STREAMS_ADM_UTL (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_STREAMS_ADM_UTL FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_STREAMS_ADM_UTL';

-- 4.2.7 DBMS_AQADM_SYS
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.7</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_AQADM_SYS (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_AQADM_SYS FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_AQADM_SYS';

-- 4.2.8 DBMS_STREAMS_RPC
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.8</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_STREAMS_RPC (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_STREAMS_RPC FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_STREAMS_RPC';

-- 4.2.9 DBMS_PRVTAQIM
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.9</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_PRVTAQIM (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_PRVTAQIM FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_PRVTAQIM';

-- 4.2.10 LTADM
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.10</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on LTADM (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON LTADM FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='LTADM';

-- 4.2.11 WWV_DBMS_SQL
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.11</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on WWV_DBMS_SQL (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON WWV_DBMS_SQL FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='WWV_DBMS_SQL';

-- 4.2.12 WWV_EXECUTE_IMMEDIATE
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.12</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on WWV_EXECUTE_IMMEDIATE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON WWV_EXECUTE_IMMEDIATE FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='WWV_EXECUTE_IMMEDIATE';

-- 4.2.13 DBMS_IJOB
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.13</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_IJOB (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_IJOB FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_IJOB';

-- 4.2.14 DBMS_FILE_TRANSFER
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.14</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_FILE_TRANSFER (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_FILE_TRANSFER FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_FILE_TRANSFER';

PROMPT </table>

-- 4.3 Revoke Excessive System Privileges
PROMPT <h3>4.3 Revoke Excessive System Privileges</h3>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 4.3.1 SELECT_ANY_DICTIONARY
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.1</td>' ||
  '<td>Ensure SELECT_ANY_DICTIONARY Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE SELECT_ANY_DICTIONARY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='SELECT ANY DICTIONARY'
AND GRANTEE NOT IN ('DBA','DBSNMP','OEM_MONITOR','OLAPSYS','ORACLE_OCM','SYSMAN','WMSYS');

-- 4.3.2 SELECT ANY TABLE
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.2</td>' ||
  '<td>Ensure SELECT ANY TABLE Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE SELECT ANY TABLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='SELECT ANY TABLE'
AND GRANTEE NOT IN ('DBA', 'MDSYS', 'SYS', 'IMP_FULL_DATABASE', 'EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE', 'WMSYS', 'SYSTEM','OLAP_DBA','OLAPSYS');

-- 4.3.3 AUDIT SYSTEM
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.3</td>' ||
  '<td>Ensure AUDIT SYSTEM Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE AUDIT SYSTEM FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='AUDIT SYSTEM'
AND GRANTEE NOT IN ('DBA','DATAPUMP_IMP_FULL_DATABASE','IMP_FULL_DATABASE','SYS');

-- 4.3.4 EXEMPT ACCESS POLICY
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.4</td>' ||
  '<td>Ensure EXEMPT ACCESS POLICY Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>No users should have this privilege</td>' ||
  '<td class="remediation">REVOKE EXEMPT ACCESS POLICY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='EXEMPT ACCESS POLICY';

-- 4.3.5 BECOME USER
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.5</td>' ||
  '<td>Ensure BECOME USER Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE BECOME USER FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='BECOME USER'
AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE');

-- 4.3.6 CREATE_PROCEDURE
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.6</td>' ||
  '<td>Ensure CREATE_PROCEDURE Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized users and roles should have this privilege</td>' ||
  '<td class="remediation">REVOKE CREATE PROCEDURE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='CREATE PROCEDURE'
AND GRANTEE NOT IN ('DBA','DBSNMP','MDSYS','OLAPSYS','OWB$CLIENT','OWBSYS','RECOVERY_CATALOG_OWNER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYS','APEX_030200','APEX_040000','APEX_040100','APEX_040200','RESOURCE');

-- 4.3.7 ALTER SYSTEM
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.7</td>' ||
  '<td>Ensure ALTER SYSTEM Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE ALTER SYSTEM FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='ALTER SYSTEM'
AND GRANTEE NOT IN ('SYS','SYSTEM','APEX_030200','APEX_040000',
'APEX_040100','APEX_040200','DBA');

-- 4.3.8 CREATE ANY LIBRARY
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.8</td>' ||
  '<td>Ensure CREATE ANY LIBRARY Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE CREATE ANY LIBRARY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='CREATE ANY LIBRARY'
AND GRANTEE NOT IN ('SYS','SYSTEM','DBA','IMP_FULL_DATABASE');

-- 4.3.9 CREATE LIBRARY
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.9</td>' ||
  '<td>Ensure CREATE LIBRARY Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE CREATE LIBRARY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='CREATE LIBRARY'
AND GRANTEE NOT IN ('SYS','SYSTEM','DBA','SPATIAL_CSW_ADMIN_USR','XDB','EXFSYS','MDSYS','SPATIAL_WFS_ADMIN_USR');

-- 4.3.10 GRANT ANY OBJECT PRIVILEGE
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.10</td>' ||
  '<td>Ensure GRANT ANY OBJECT PRIVILEGE Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE GRANT ANY OBJECT PRIVILEGE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='GRANT ANY OBJECT PRIVILEGE'
AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE');

-- 4.3.11 GRANT ANY ROLE
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.11</td>' ||
  '<td>Ensure GRANT ANY ROLE Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE GRANT ANY ROLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='GRANT ANY ROLE'
AND GRANTEE NOT IN ('DBA','SYS','DATAPUMP_IMP_FULL_DATABASE','IMP_FULL_DATABASE','SPATIAL_WFS_ADMIN_USR','SPATIAL_CSW_ADMIN_USR');

-- 4.3.12 GRANT ANY PRIVILEGE
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.12</td>' ||
  '<td>Ensure GRANT ANY PRIVILEGE Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE GRANT ANY PRIVILEGE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='GRANT ANY PRIVILEGE'
AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE');

PROMPT </table>

-- 4.4 Revoke Role Privileges
PROMPT <h3>4.4 Revoke Role Privileges</h3>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 4.4.1 DELETE_CATALOG_ROLE
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.1</td>' ||
  '<td>Ensure DELETE_CATALOG_ROLE Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this role</td>' ||
  '<td class="remediation">REVOKE DELETE_CATALOG_ROLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_ROLE_PRIVS
WHERE GRANTED_ROLE='DELETE_CATALOG_ROLE'
AND GRANTEE NOT IN ('DBA','SYS');

-- 4.4.2 SELECT_CATALOG_ROLE
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.2</td>' ||
  '<td>Ensure SELECT_CATALOG_ROLE Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this role</td>' ||
  '<td class="remediation">REVOKE SELECT_CATALOG_ROLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_ROLE_PRIVS
WHERE GRANTED_ROLE='SELECT_CATALOG_ROLE'
AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE','EXP_FULL_DATABASE','OEM_MONITOR','SYSMAN');

-- 4.4.3 EXECUTE_CATALOG_ROLE
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.3</td>' ||
  '<td>Ensure EXECUTE_CATALOG_ROLE Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this role</td>' ||
  '<td class="remediation">REVOKE EXECUTE_CATALOG_ROLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_ROLE_PRIVS
WHERE GRANTED_ROLE='EXECUTE_CATALOG_ROLE'
AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE','EXP_FULL_DATABASE');

-- 4.4.4 DBA
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.4</td>' ||
  '<td>Ensure DBA Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only SYS and SYSTEM should have DBA role</td>' ||
  '<td class="remediation">REVOKE DBA FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_ROLE_PRIVS
WHERE GRANTED_ROLE='DBA'
AND GRANTEE NOT IN ('SYS','SYSTEM');

PROMPT </table>

-- 4.5 Revoke Excessive Table and View Privileges
PROMPT <h3>4.5 Revoke Excessive Table and View Privileges</h3>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 4.5.1 ALL on AUD$
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.1</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on AUD$ (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>Only DELETE_CATALOG_ROLE should have privileges on AUD$</td>' ||
  '<td class="remediation">REVOKE ALL ON AUD$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='AUD$'
AND GRANTEE NOT IN ('DELETE_CATALOG_ROLE');

-- 4.5.2 ALL on USER_HISTORY$
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.2</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on USER_HISTORY$ (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No privileges should be granted on USER_HISTORY$</td>' ||
  '<td class="remediation">REVOKE ALL ON USER_HISTORY$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='USER_HISTORY$';

-- 4.5.3 ALL on LINK$
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.3</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on LINK$ (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No privileges should be granted on LINK$</td>' ||
  '<td class="remediation">REVOKE ALL ON LINK$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='LINK$';

-- 4.5.4 ALL on SYS.USER$
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.4</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on SYS.USER$ (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>Only authorized system users should have privileges</td>' ||
  '<td class="remediation">REVOKE ALL ON SYS.USER$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='USER$'
AND GRANTEE NOT IN ('CTXSYS','XDB','APEX_030200','APEX_040000','APEX_040100','APEX_040200','ORACLE_OCM');

-- 4.5.5 ALL on DBA_%
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.5</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on DBA_% (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      'Found ' || COUNT(*) || ' unauthorized privileges on DBA views'
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>Only authorized system users should have DBA view privileges</td>' ||
  '<td class="remediation">REVOKE ALL ON &lt;dba_view&gt; FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME LIKE 'DBA_%'
AND GRANTEE NOT IN ('APPQOSSYS','AQ_ADMINISTRATOR_ROLE','CTXSYS','EXFSYS','MDSYS',
'OLAP_XS_ADMIN','OLAPSYS','ORDSYS','OWB$CLIENT','OWBSYS','SELECT_CATALOG_ROLE',
'WM_ADMIN_ROLE','WMSYS','XDBADMIN','LBACSYS','ADM_PARALLEL_EXECUTE_TASK','CISSCANROLE')
AND NOT REGEXP_LIKE(GRANTEE,'^APEX_0[3-9][0-9][0-9][0-9][0-9]$');

-- 4.5.6 ALL on SYS.SCHEDULER$_CREDENTIAL
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on SYS.SCHEDULER$_CREDENTIAL (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No privileges should be granted on SCHEDULER$_CREDENTIAL</td>' ||
  '<td class="remediation">REVOKE ALL ON SYS.SCHEDULER$_CREDENTIAL FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='SCHEDULER$_CREDENTIAL';

-- 4.5.7 SYS.USER$MIG Has Been Dropped
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.7</td>' ||
  '<td>Ensure SYS.USER$MIG Has Been Dropped (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'USER$MIG table exists'
    ELSE 'USER$MIG table not found (compliant)'
    END || '</td>' ||
  '<td>USER$MIG table should not exist</td>' ||
  '<td class="remediation">DROP TABLE SYS.USER$MIG;</td>' ||
  '</tr>'
FROM ALL_TABLES
WHERE OWNER='SYS' AND TABLE_NAME='USER$MIG';

PROMPT </table>

-- 4.6 Additional Security Checks
PROMPT <h3>4.6-4.10 Additional Security Checks</h3>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 4.6 %ANY% Privileges
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.6</td>' ||
  '<td>Ensure %ANY% Is Revoked from Unauthorized GRANTEE (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      'Found ' || COUNT(*) || ' unauthorized ANY privileges (see detailed report)'
    ELSE 'No unauthorized ANY privileges found'
    END || '</td>' ||
  '<td>Only authorized system users should have ANY privileges</td>' ||
  '<td class="remediation">REVOKE &lt;ANY_PRIVILEGE&gt; FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE LIKE '%ANY%'
AND GRANTEE NOT IN ('AQ_ADMINISTRATOR_ROLE','DBA','DBSNMP','EXFSYS','EXP_FULL_DATABASE',
'IMP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE','JAVADEBUGPRIV','MDSYS','OEM_MONITOR',
'OLAPSYS','OLAP_DBA','ORACLE_OCM','OWB$CLIENT','OWBSYS','SCHEDULER_ADMIN',
'SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYS','SYSMAN','SYSTEM','WMSYS',
'APEX_030200','APEX_040000','APEX_040100','APEX_040200','LBACSYS','OUTLN');

-- 4.7 DBA_SYS_PRIVS with ADMIN_OPTION
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.7</td>' ||
  '<td>Ensure DBA_SYS_PRIVS Is Revoked from Unauthorized GRANTEE with ADMIN_OPTION=YES (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized admin options found'
    END || '</td>' ||
  '<td>Only authorized system users should have ADMIN_OPTION</td>' ||
  '<td class="remediation">REVOKE &lt;privilege&gt; FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE ADMIN_OPTION='YES'
AND GRANTEE NOT IN ('AQ_ADMINISTRATOR_ROLE','DBA','OWBSYS','SCHEDULER_ADMIN',
'SYS','SYSTEM','WMSYS','APEX_030200','APEX_040000','APEX_040100','APEX_040200');

-- 4.8 Proxy Users Have Only CONNECT Privilege
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.8</td>' ||
  '<td>Ensure Proxy Users Have Only CONNECT Privilege (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || GRANTED_ROLE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No proxy user violations found'
    END || '</td>' ||
  '<td>Proxy users should only have CONNECT privilege</td>' ||
  '<td class="remediation">REVOKE &lt;privilege&gt; FROM &lt;proxy_user&gt;;</td>' ||
  '</tr>'
FROM DBA_ROLE_PRIVS
WHERE GRANTEE IN (SELECT PROXY FROM DBA_PROXIES)
AND GRANTED_ROLE NOT IN ('CONNECT');

-- 4.9 EXECUTE ANY PROCEDURE from OUTLN
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.9</td>' ||
  '<td>Ensure EXECUTE ANY PROCEDURE Is Revoked from OUTLN (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'OUTLN has EXECUTE ANY PROCEDURE'
    ELSE 'OUTLN does not have EXECUTE ANY PROCEDURE'
    END || '</td>' ||
  '<td>OUTLN should not have EXECUTE ANY PROCEDURE</td>' ||
  '<td class="remediation">REVOKE EXECUTE ANY PROCEDURE FROM OUTLN;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='EXECUTE ANY PROCEDURE'
AND GRANTEE='OUTLN';

-- 4.10 EXECUTE ANY PROCEDURE from DBSNMP
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.10</td>' ||
  '<td>Ensure EXECUTE ANY PROCEDURE Is Revoked from DBSNMP (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'DBSNMP has EXECUTE ANY PROCEDURE'
    ELSE 'DBSNMP does not have EXECUTE ANY PROCEDURE'
    END || '</td>' ||
  '<td>DBSNMP should not have EXECUTE ANY PROCEDURE</td>' ||
  '<td class="remediation">REVOKE EXECUTE ANY PROCEDURE FROM DBSNMP;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='EXECUTE ANY PROCEDURE'
AND GRANTEE='DBSNMP';

PROMPT </table>

-- Section 5: Audit/Logging Policies and Procedures
PROMPT <h2 id="section5">5. Audit/Logging Policies and Procedures</h2>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 5.1 Enable 'USER' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.1</td>' ||
  '<td>Enable USER Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'USER audit enabled'
    ELSE 'USER audit not enabled'
    END || '</td>' ||
  '<td>USER audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT USER;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='USER' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.2 Enable 'ALTER USER' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.2</td>' ||
  '<td>Enable ALTER USER Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'ALTER USER audit enabled'
    ELSE 'ALTER USER audit not enabled'
    END || '</td>' ||
  '<td>ALTER USER audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT ALTER USER;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='ALTER USER' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.3 Enable 'DROP USER' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.3</td>' ||
  '<td>Enable DROP USER Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'DROP USER audit enabled'
    ELSE 'DROP USER audit not enabled'
    END || '</td>' ||
  '<td>DROP USER audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT DROP USER;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='DROP USER' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.4 Enable 'ROLE' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.4</td>' ||
  '<td>Enable ROLE Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'ROLE audit enabled'
    ELSE 'ROLE audit not enabled'
    END || '</td>' ||
  '<td>ROLE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT ROLE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='ROLE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.5 Enable 'SYSTEM GRANT' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.5</td>' ||
  '<td>Enable SYSTEM GRANT Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'SYSTEM GRANT audit enabled'
    ELSE 'SYSTEM GRANT audit not enabled'
    END || '</td>' ||
  '<td>SYSTEM GRANT audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT SYSTEM GRANT;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='SYSTEM GRANT' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.6 Enable 'PROFILE' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.6</td>' ||
  '<td>Enable PROFILE Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PROFILE audit enabled'
    ELSE 'PROFILE audit not enabled'
    END || '</td>' ||
  '<td>PROFILE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT PROFILE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='PROFILE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.7 Enable 'ALTER PROFILE' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.7</td>' ||
  '<td>Enable ALTER PROFILE Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'ALTER PROFILE audit enabled'
    ELSE 'ALTER PROFILE audit not enabled'
    END || '</td>' ||
  '<td>ALTER PROFILE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT ALTER PROFILE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='ALTER PROFILE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.8 Enable 'DROP PROFILE' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.8</td>' ||
  '<td>Enable DROP PROFILE Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'DROP PROFILE audit enabled'
    ELSE 'DROP PROFILE audit not enabled'
    END || '</td>' ||
  '<td>DROP PROFILE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT DROP PROFILE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='DROP PROFILE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.9 Enable 'DATABASE LINK' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.9</td>' ||
  '<td>Enable DATABASE LINK Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'DATABASE LINK audit enabled'
    ELSE 'DATABASE LINK audit not enabled'
    END || '</td>' ||
  '<td>DATABASE LINK audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT DATABASE LINK;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='DATABASE LINK' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.10 Enable 'PUBLIC DATABASE LINK' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.10</td>' ||
  '<td>Enable PUBLIC DATABASE LINK Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC DATABASE LINK audit enabled'
    ELSE 'PUBLIC DATABASE LINK audit not enabled'
    END || '</td>' ||
  '<td>PUBLIC DATABASE LINK audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT PUBLIC DATABASE LINK;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='PUBLIC DATABASE LINK' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.11 Enable 'PUBLIC SYNONYM' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.11</td>' ||
  '<td>Enable PUBLIC SYNONYM Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC SYNONYM audit enabled'
    ELSE 'PUBLIC SYNONYM audit not enabled'
    END || '</td>' ||
  '<td>PUBLIC SYNONYM audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT PUBLIC SYNONYM;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='PUBLIC SYNONYM' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.12 Enable 'SYNONYM' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.12</td>' ||
  '<td>Enable SYNONYM Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'SYNONYM audit enabled'
    ELSE 'SYNONYM audit not enabled'
    END || '</td>' ||
  '<td>SYNONYM audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT SYNONYM;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='SYNONYM' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.13 Enable 'GRANT DIRECTORY' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.13</td>' ||
  '<td>Enable GRANT DIRECTORY Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'GRANT DIRECTORY audit enabled'
    ELSE 'GRANT DIRECTORY audit not enabled'
    END || '</td>' ||
  '<td>GRANT DIRECTORY audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT GRANT DIRECTORY;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='GRANT DIRECTORY' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.14 Enable 'SELECT ANY DICTIONARY' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.14</td>' ||
  '<td>Enable SELECT ANY DICTIONARY Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'SELECT ANY DICTIONARY audit enabled'
    ELSE 'SELECT ANY DICTIONARY audit not enabled'
    END || '</td>' ||
  '<td>SELECT ANY DICTIONARY audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT SELECT ANY DICTIONARY;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='SELECT ANY DICTIONARY' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.15 Enable 'GRANT ANY OBJECT PRIVILEGE' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.15</td>' ||
  '<td>Enable GRANT ANY OBJECT PRIVILEGE Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'GRANT ANY OBJECT PRIVILEGE audit enabled'
    ELSE 'GRANT ANY OBJECT PRIVILEGE audit not enabled'
    END || '</td>' ||
  '<td>GRANT ANY OBJECT PRIVILEGE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT GRANT ANY OBJECT PRIVILEGE;</td>' ||
  '</tr>'
FROM DBA_PRIV_AUDIT_OPTS
WHERE PRIVILEGE='GRANT ANY OBJECT PRIVILEGE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.16 Enable 'GRANT ANY PRIVILEGE' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.16</td>' ||
  '<td>Enable GRANT ANY PRIVILEGE Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'GRANT ANY PRIVILEGE audit enabled'
    ELSE 'GRANT ANY PRIVILEGE audit not enabled'
    END || '</td>' ||
  '<td>GRANT ANY PRIVILEGE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT GRANT ANY PRIVILEGE;</td>' ||
  '</tr>'
FROM DBA_PRIV_AUDIT_OPTS
WHERE PRIVILEGE='GRANT ANY PRIVILEGE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.17 Enable 'DROP ANY PROCEDURE' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.17</td>' ||
  '<td>Enable DROP ANY PROCEDURE Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'DROP ANY PROCEDURE audit enabled'
    ELSE 'DROP ANY PROCEDURE audit not enabled'
    END || '</td>' ||
  '<td>DROP ANY PROCEDURE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT DROP ANY PROCEDURE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='DROP ANY PROCEDURE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.18 Enable 'ALL' Audit Option on 'SYS.AUD
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.18</td>' ||
  '<td>Enable ALL Audit Option on SYS.AUD$ (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'ALL audit on SYS.AUD$ enabled'
    ELSE 'ALL audit on SYS.AUD$ not enabled'
    END || '</td>' ||
  '<td>ALL audit on SYS.AUD$ enabled (ALL operations audited)</td>' ||
  '<td class="remediation">AUDIT ALL ON SYS.AUD$ BY ACCESS;</td>' ||
  '</tr>'
FROM DBA_OBJ_AUDIT_OPTS
WHERE OBJECT_NAME='AUD$'
AND ALT='A/A'
AND AUD='A/A'
AND COM='A/A'
AND DEL='A/A'
AND GRA='A/A'
AND IND='A/A'
AND INS='A/A'
AND LOC='A/A'
AND REN='A/A'
AND SEL='A/A'
AND UPD='A/A'
AND FBK='A/A';

-- 5.19 Enable 'PROCEDURE' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.19</td>' ||
  '<td>Enable PROCEDURE Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PROCEDURE audit enabled'
    ELSE 'PROCEDURE audit not enabled'
    END || '</td>' ||
  '<td>PROCEDURE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT PROCEDURE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='PROCEDURE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.20 Enable 'ALTER SYSTEM' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.20</td>' ||
  '<td>Enable ALTER SYSTEM Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'ALTER SYSTEM audit enabled'
    ELSE 'ALTER SYSTEM audit not enabled'
    END || '</td>' ||
  '<td>ALTER SYSTEM audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT ALTER SYSTEM;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='ALTER SYSTEM' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.21 Enable 'TRIGGER' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.21</td>' ||
  '<td>Enable TRIGGER Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'TRIGGER audit enabled'
    ELSE 'TRIGGER audit not enabled'
    END || '</td>' ||
  '<td>TRIGGER audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT TRIGGER;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='TRIGGER' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

-- 5.22 Enable 'CREATE SESSION' Audit Option
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.22</td>' ||
  '<td>Enable CREATE SESSION Audit Option (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'CREATE SESSION audit enabled'
    ELSE 'CREATE SESSION audit not enabled'
    END || '</td>' ||
  '<td>CREATE SESSION audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT SESSION;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='CREATE SESSION' AND USER_NAME IS NULL AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS';

PROMPT </table>

-- 12c+ Unified Auditing Section
SELECT CASE WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
  '<h3>5.23 Unified Auditing (12c+)</h3>' ||
  '<p>Unified Auditing provides improved performance and centralized audit management.</p>' ||
  '<table>' ||
  '<tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>'
ELSE '' END FROM v$instance;

-- Check if Unified Auditing is enabled
SELECT CASE WHEN vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN VALUE = 'TRUE' THEN 'pass'
    ELSE 'warning'
  END || '">' ||
  '<td>5.23.1</td>' ||
  '<td>Consider Enabling Unified Auditing (12c+) (Not Scored)</td>' ||
  '<td>' || CASE WHEN VALUE = 'TRUE' THEN 'ENABLED' ELSE 'DISABLED' END || '</td>' ||
  '<td>' || NVL(VALUE, 'DISABLED') || '</td>' ||
  '<td>TRUE (Recommended)</td>' ||
  '<td class="remediation">Enable unified auditing per Oracle documentation</td>' ||
  '</tr>'
ELSE '' END
FROM V$OPTION vo, v$instance vi
WHERE vo.PARAMETER = 'Unified Auditing' 
  AND (vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%');

-- Check unified audit policies
SELECT CASE WHEN (version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%') AND
  (SELECT VALUE FROM V$OPTION WHERE PARAMETER = 'Unified Auditing') = 'TRUE' THEN
  '<tr class="pass">' ||
  '<td>5.23.2</td>' ||
  '<td>Unified Audit Policies Enabled (12c+)</td>' ||
  '<td>CONFIGURED</td>' ||
  '<td>Active policies: ' || 
    (SELECT COUNT(*) FROM AUDIT_UNIFIED_ENABLED_POLICIES) || '</td>' ||
  '<td>At least basic policies enabled</td>' ||
  '<td class="remediation">AUDIT POLICY policy_name</td>' ||
  '</tr>'
ELSE '' END FROM v$instance;

-- Fine-Grained Auditing policies
WITH fga_count AS (
  SELECT COUNT(*) AS policy_count FROM DBA_AUDIT_POLICIES
)
SELECT CASE WHEN vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN fc.policy_count > 0 THEN 'pass'
    ELSE 'manual'
  END || '">' ||
  '<td>5.23.3</td>' ||
  '<td>Fine-Grained Auditing (FGA) Policies</td>' ||
  '<td>' || CASE WHEN fc.policy_count > 0 THEN 'CONFIGURED' ELSE 'NONE' END || '</td>' ||
  '<td>FGA policies: ' || fc.policy_count || '</td>' ||
  '<td>As required for sensitive tables</td>' ||
  '<td class="remediation">DBMS_FGA.ADD_POLICY</td>' ||
  '</tr>'
ELSE '' END
FROM v$instance vi, fga_count fc;

SELECT CASE WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN '</table>' ELSE '' END FROM v$instance;

-- Summary Section
PROMPT <h2 id="summary">Executive Summary</h2>

-- Calculate comprehensive summary statistics (version-aware)
WITH audit_summary AS (
  -- Section 1: Installation and Patching (dynamic based on version)
  SELECT 
    'Installation & Patching' as category,
    CASE 
      WHEN version LIKE '18.%' OR version LIKE '19.%' THEN 5  -- 11g checks + PDBADMIN + schema-only
      WHEN version LIKE '12.%' THEN 4  -- 11g checks + PDBADMIN
      ELSE 3  -- Base 11g checks
    END as total_checks,
    (
      -- Version check
      CASE 
        WHEN version LIKE '19.%' OR version LIKE '18.%' OR 
             version LIKE '12.%' OR version LIKE '11.2.0.4%' THEN 1
        ELSE 0
      END +
      -- Default passwords
      CASE WHEN NOT EXISTS(SELECT 1 FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%') THEN 1 ELSE 0 END +
      -- Sample users
      CASE WHEN NOT EXISTS(SELECT 1 FROM ALL_USERS WHERE USERNAME IN ('BI','HR','IX','OE','PM','SCOTT','SH')) THEN 1 ELSE 0 END +
      -- 12c+: PDBADMIN check
      CASE WHEN (version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%') 
        AND EXISTS(SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') THEN
          CASE WHEN NOT EXISTS(SELECT 1 FROM DBA_USERS WHERE USERNAME = 'PDBADMIN' AND ACCOUNT_STATUS = 'OPEN') THEN 1 ELSE 0 END
      ELSE 0 END +
      -- 18c+: Schema-only accounts (counted as manual review, so 0)
      0
    ) as passes
  FROM v$instance, DUAL
  UNION ALL
  -- Section 2: Database Parameters (dynamic based on version)
  SELECT 
    'Database Parameters' as category,
    CASE 
      WHEN version LIKE '19.%' THEN 23  -- Base + COMMON_USER_PREFIX + ENABLE_DDL_LOGGING + LDAP_DIRECTORY_SYSAUTH + ALLOW_GROUP_ACCESS_TO_SGA
      WHEN version LIKE '18.%' THEN 22  -- Base + COMMON_USER_PREFIX + ENABLE_DDL_LOGGING + LDAP_DIRECTORY_SYSAUTH
      WHEN version LIKE '12.%' THEN 21  -- Base + COMMON_USER_PREFIX + ENABLE_DDL_LOGGING
      ELSE 19  -- Base 11g parameters
    END as total_checks,
    (SELECT COUNT(*) FROM (
      SELECT CASE WHEN UPPER(VALUE) = 'TRUE' THEN 1 ELSE 0 END AS result FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_SYS_OPERATIONS'
      UNION ALL
      SELECT CASE WHEN UPPER(VALUE) IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED') THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_TRAIL'
      UNION ALL
      SELECT CASE WHEN UPPER(VALUE) = 'TRUE' THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'GLOBAL_NAMES'
      UNION ALL
      SELECT CASE WHEN COUNT(*) = 0 THEN 1 WHEN UPPER(MAX(VALUE)) = 'FALSE' OR MAX(VALUE) IS NULL THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY'
      UNION ALL
      SELECT CASE WHEN UPPER(VALUE) = 'FALSE' THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'OS_ROLES'
      UNION ALL
      SELECT CASE WHEN UPPER(VALUE) = 'NONE' THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_LOGIN_PASSWORDFILE'
      UNION ALL
      SELECT CASE WHEN UPPER(VALUE) = 'FALSE' THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_OS_AUTHENT'
      UNION ALL
      SELECT CASE WHEN UPPER(VALUE) = 'FALSE' THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_OS_ROLES'
      UNION ALL
      SELECT CASE WHEN VALUE IS NULL OR LENGTH(TRIM(VALUE)) = 0 THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'UTL_FILE_DIR'
      UNION ALL
      SELECT CASE WHEN UPPER(VALUE) = 'TRUE' THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'SEC_CASE_SENSITIVE_LOGON'
      UNION ALL
      SELECT CASE WHEN UPPER(VALUE) = '10' OR (REGEXP_LIKE(VALUE, '^[0-9]+$') AND TO_NUMBER(VALUE) = 10) THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'SEC_MAX_FAILED_LOGIN_ATTEMPTS'
      UNION ALL
      SELECT CASE WHEN UPPER(NVL(VALUE,'LOG')) = 'LOG' THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'SEC_PROTOCOL_ERROR_TRACE_ACTION'
      UNION ALL
      SELECT CASE WHEN UPPER(NVL(VALUE,'FALSE')) = 'FALSE' THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'SEC_RETURN_SERVER_RELEASE_BANNER'
      UNION ALL
      SELECT CASE WHEN UPPER(VALUE) = 'TRUE' THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'SQL92_SECURITY'
      UNION ALL
      SELECT CASE WHEN NVL(VALUE,'FALSE') = 'FALSE' THEN 1 ELSE 0 END FROM V$PARAMETER WHERE NAME = '_trace_files_public'
      UNION ALL
      SELECT CASE WHEN UPPER(VALUE) = 'TRUE' THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'RESOURCE_LIMIT'
      UNION ALL
      SELECT CASE WHEN VALUE IS NULL OR LENGTH(TRIM(VALUE)) = 0 THEN 1 ELSE 0 END FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_LISTENER'
      UNION ALL
      SELECT 0 FROM DUAL -- Manual listener checks (counted as 0 for automated assessment)
      UNION ALL
      SELECT 0 FROM DUAL -- Additional manual checks
    ) WHERE result = 1) +
    -- Version-specific parameters
    CASE WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
      (SELECT COUNT(*) FROM V$PARAMETER WHERE UPPER(NAME) = 'COMMON_USER_PREFIX' AND UPPER(VALUE) IN ('C##', 'c##'))
    ELSE 0 END +
    CASE WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
      (SELECT COUNT(*) FROM V$PARAMETER WHERE UPPER(NAME) = 'ENABLE_DDL_LOGGING' AND UPPER(VALUE) = 'TRUE')
    ELSE 0 END +
    CASE WHEN version LIKE '18.%' OR version LIKE '19.%' THEN
      (SELECT COUNT(*) FROM V$PARAMETER WHERE UPPER(NAME) = 'LDAP_DIRECTORY_SYSAUTH' AND (UPPER(VALUE) = 'NO' OR VALUE IS NULL))
    ELSE 0 END +
    CASE WHEN version LIKE '19.%' THEN
      (SELECT COUNT(*) FROM V$PARAMETER WHERE UPPER(NAME) = 'ALLOW_GROUP_ACCESS_TO_SGA' AND (UPPER(VALUE) = 'FALSE' OR VALUE IS NULL))
    ELSE 0 END
    as passes
  FROM v$instance
  UNION ALL
  -- Section 3: Connection and Login Restrictions (dynamic based on version)
  SELECT 
    'Connection & Authentication' as category,
    CASE 
      WHEN version LIKE '18.%' OR version LIKE '19.%' THEN 12  -- Base + INACTIVE_ACCOUNT_TIME + PASSWORD_ROLLOVER_TIME
      WHEN version LIKE '12.%' THEN 11  -- Base + INACTIVE_ACCOUNT_TIME
      ELSE 10  -- Base 11g checks
    END as total_checks,
    (10 - 
     (SELECT COUNT(*) FROM DBA_PROFILES WHERE RESOURCE_NAME='FAILED_LOGIN_ATTEMPTS' AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 5))) -
     (SELECT COUNT(*) FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_LOCK_TIME' AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) < 1))) -
     (SELECT COUNT(*) FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_LIFE_TIME' AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 90))) -
     (SELECT COUNT(*) FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_REUSE_MAX' AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) < 20))) -
     (SELECT COUNT(*) FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_REUSE_TIME' AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) < 365))) -
     (SELECT COUNT(*) FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_GRACE_TIME' AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 5))) -
     (SELECT COUNT(*) FROM DBA_USERS WHERE PASSWORD='EXTERNAL') -
     (SELECT COUNT(*) FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_VERIFY_FUNCTION' AND (LIMIT = 'DEFAULT' OR LIMIT = 'NULL')) -
     (SELECT COUNT(*) FROM DBA_PROFILES WHERE RESOURCE_NAME='SESSIONS_PER_USER' AND (LIMIT = 'DEFAULT' OR LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 10))) -
     (SELECT COUNT(*) FROM DBA_USERS WHERE PROFILE='DEFAULT' AND ACCOUNT_STATUS='OPEN' 
      AND USERNAME NOT IN ('ANONYMOUS','CTXSYS','DBSNMP','EXFSYS','LBACSYS','MDSYS','MGMT_VIEW','OLAPSYS','OWBSYS','ORDPLUGINS','ORDSYS','OUTLN','SI_INFORMTN_SCHEMA','SYS','SYSMAN','SYSTEM','TSMSYS','WK_TEST','WKSYS','WKPROXY','WMSYS','XDB','CISSCAN'))
    ) +
    -- Version-specific profile settings
    CASE WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
      CASE WHEN EXISTS(SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='INACTIVE_ACCOUNT_TIME' 
        AND LIMIT NOT IN ('DEFAULT', 'UNLIMITED') 
        AND REGEXP_LIKE(LIMIT, '^[0-9]+$') 
        AND TO_NUMBER(LIMIT) <= 35) THEN 1 ELSE 0 END
    ELSE 0 END +
    CASE WHEN version LIKE '18.%' OR version LIKE '19.%' THEN
      CASE WHEN EXISTS(SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_ROLLOVER_TIME' 
        AND LIMIT NOT IN ('DEFAULT', 'UNLIMITED')) THEN 1 ELSE 0 END
    ELSE 0 END
    as passes
  FROM v$instance
  UNION ALL
  -- Section 4.1-4.2: Public Package Privileges (36 checks)
  SELECT 
    'Package Privilege Control' as category,
    36 as total_checks,
    (36 - (SELECT COUNT(*) FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' 
     AND TABLE_NAME IN ('DBMS_ADVISOR','DBMS_CRYPTO','DBMS_JAVA','DBMS_JAVA_TEST','DBMS_JOB',
                        'DBMS_LDAP','DBMS_LOB','DBMS_OBFUSCATION_TOOLKIT','DBMS_RANDOM',
                        'DBMS_SCHEDULER','DBMS_SQL','DBMS_XMLGEN','DBMS_XMLQUERY','UTL_FILE',
                        'UTL_INADDR','UTL_TCP','UTL_MAIL','UTL_SMTP','UTL_DBWS','UTL_ORAMTS',
                        'UTL_HTTP','HTTPURITYPE','DBMS_SYS_SQL','DBMS_BACKUP_RESTORE',
                        'DBMS_AQADM_SYSCALLS','DBMS_REPCAT_SQL_UTL','INITJVMAUX','DBMS_STREAMS_ADM_UTL',
                        'DBMS_AQADM_SYS','DBMS_STREAMS_RPC','DBMS_PRVTAQIM','LTADM',
                        'WWV_DBMS_SQL','WWV_EXECUTE_IMMEDIATE','DBMS_IJOB','DBMS_FILE_TRANSFER'))) as passes
  FROM DUAL
  UNION ALL
  -- Section 4.3-4.4: System and Role Privileges (16 checks)
  SELECT 
    'System Privilege Control' as category,
    16 as total_checks,
    (
     -- Check 1: SELECT ANY DICTIONARY properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='SELECT ANY DICTIONARY' AND GRANTEE NOT IN ('DBA','DBSNMP','OEM_MONITOR','OLAPSYS','ORACLE_OCM','SYSMAN','WMSYS')) THEN 1 ELSE 0 END +
     -- Check 2: SELECT ANY TABLE properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='SELECT ANY TABLE' AND GRANTEE NOT IN ('DBA','MDSYS','SYS','IMP_FULL_DATABASE','EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE','WMSYS','SYSTEM','OLAP_DBA','OLAPSYS')) THEN 1 ELSE 0 END +
     -- Check 3: AUDIT SYSTEM properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='AUDIT SYSTEM' AND GRANTEE NOT IN ('DBA','DATAPUMP_IMP_FULL_DATABASE','IMP_FULL_DATABASE','SYS')) THEN 1 ELSE 0 END +
     -- Check 4: EXEMPT ACCESS POLICY not granted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='EXEMPT ACCESS POLICY') THEN 1 ELSE 0 END +
     -- Check 5: BECOME USER properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='BECOME USER' AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE')) THEN 1 ELSE 0 END +
     -- Check 6: CREATE PROCEDURE properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='CREATE PROCEDURE' AND GRANTEE NOT IN ('DBA','DBSNMP','MDSYS','OLAPSYS','OWB$CLIENT','OWBSYS','RECOVERY_CATALOG_OWNER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYS','APEX_030200','APEX_040000','APEX_040100','APEX_040200','RESOURCE')) THEN 1 ELSE 0 END +
     -- Check 7: ALTER SYSTEM properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='ALTER SYSTEM' AND GRANTEE NOT IN ('SYS','SYSTEM','APEX_030200','APEX_040000','APEX_040100','APEX_040200','DBA')) THEN 1 ELSE 0 END +
     -- Check 8: CREATE ANY LIBRARY properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='CREATE ANY LIBRARY' AND GRANTEE NOT IN ('SYS','SYSTEM','DBA','IMP_FULL_DATABASE')) THEN 1 ELSE 0 END +
     -- Check 9: CREATE LIBRARY properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='CREATE LIBRARY' AND GRANTEE NOT IN ('SYS','SYSTEM','DBA','SPATIAL_CSW_ADMIN_USR','XDB','EXFSYS','MDSYS','SPATIAL_WFS_ADMIN_USR')) THEN 1 ELSE 0 END +
     -- Check 10: GRANT ANY OBJECT PRIVILEGE properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='GRANT ANY OBJECT PRIVILEGE' AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE')) THEN 1 ELSE 0 END +
     -- Check 11: GRANT ANY ROLE properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='GRANT ANY ROLE' AND GRANTEE NOT IN ('DBA','SYS','DATAPUMP_IMP_FULL_DATABASE','IMP_FULL_DATABASE','SPATIAL_WFS_ADMIN_USR','SPATIAL_CSW_ADMIN_USR')) THEN 1 ELSE 0 END +
     -- Check 12: GRANT ANY PRIVILEGE properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='GRANT ANY PRIVILEGE' AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE')) THEN 1 ELSE 0 END +
     -- Check 13: DELETE_CATALOG_ROLE properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE='DELETE_CATALOG_ROLE' AND GRANTEE NOT IN ('DBA','SYS')) THEN 1 ELSE 0 END +
     -- Check 14: SELECT_CATALOG_ROLE properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE='SELECT_CATALOG_ROLE' AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE','EXP_FULL_DATABASE','OEM_MONITOR','SYSMAN')) THEN 1 ELSE 0 END +
     -- Check 15: EXECUTE_CATALOG_ROLE properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE='EXECUTE_CATALOG_ROLE' AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE','EXP_FULL_DATABASE')) THEN 1 ELSE 0 END +
     -- Check 16: DBA role properly restricted
     CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE='DBA' AND GRANTEE NOT IN ('SYS','SYSTEM')) THEN 1 ELSE 0 END
    ) as passes
  FROM DUAL
  UNION ALL
  -- Section 5: Auditing (dynamic based on version and unified auditing)
  SELECT 
    'Audit Configuration' as category,
    CASE 
      WHEN vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN 25  -- Base + unified auditing checks
      ELSE 22  -- Base 11g audit checks
    END as total_checks,
    (CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='USER' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='ALTER USER' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='DROP USER' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='ROLE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='SYSTEM GRANT' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='PROFILE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='ALTER PROFILE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='DROP PROFILE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='DATABASE LINK' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='PUBLIC DATABASE LINK' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='PUBLIC SYNONYM' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='SYNONYM' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='GRANT DIRECTORY' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='SELECT ANY DICTIONARY' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='GRANT ANY OBJECT PRIVILEGE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='GRANT ANY PRIVILEGE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='DROP ANY PROCEDURE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='PROCEDURE' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='ALTER SYSTEM' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='TRIGGER' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     CASE WHEN EXISTS(SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='CREATE SESSION' AND USER_NAME IS NULL AND PROXY_NAME IS NULL AND SUCCESS = 'BY ACCESS' AND FAILURE = 'BY ACCESS') THEN 1 ELSE 0 END +
     1 -- Additional audit configuration check
    ) +
    -- Version-specific auditing (12c+ unified auditing)
    CASE WHEN vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
      -- Check if unified auditing is enabled
      CASE WHEN EXISTS(SELECT 1 FROM V$OPTION WHERE PARAMETER = 'Unified Auditing' AND VALUE = 'TRUE') THEN 1 ELSE 0 END +
      -- Check for unified audit policies
      CASE WHEN EXISTS(SELECT 1 FROM V$OPTION WHERE PARAMETER = 'Unified Auditing' AND VALUE = 'TRUE') THEN
        CASE WHEN EXISTS(SELECT 1 FROM AUDIT_UNIFIED_ENABLED_POLICIES) THEN 1 ELSE 0 END
      ELSE 0 END +
      -- Check for FGA policies
      CASE WHEN EXISTS(SELECT 1 FROM DBA_AUDIT_POLICIES) THEN 1 ELSE 0 END
    ELSE 0 END
    as passes
  FROM v$instance vi
)
SELECT '<div style="background-color: #e3f2fd; padding: 10px; margin-bottom: 15px; border-radius: 5px;">' ||
  '<strong>Assessment Version:</strong> ' || 
  MAX(CASE 
    WHEN vi.version LIKE '19.%' THEN 'Oracle Database 19c (19c)'
    WHEN vi.version LIKE '18.%' THEN 'Oracle Database 18c (18c)'
    WHEN vi.version LIKE '12.2%' THEN 'Oracle Database 12c Release 2 (12c R2)'
    WHEN vi.version LIKE '12.1%' THEN 'Oracle Database 12c Release 1 (12c R1)'
    WHEN vi.version LIKE '11.2%' THEN 'Oracle Database 11g Release 2 (11g R2)'
    ELSE 'Oracle Database (Unknown)'
  END) ||
  ' | <strong>CIS Benchmark:</strong> ' || 
  MAX(CASE 
    WHEN vi.version LIKE '19.%' THEN 'CIS Oracle Database 19c Benchmark v1.0.0'
    WHEN vi.version LIKE '18.%' THEN 'CIS Oracle Database 18c Benchmark v1.0.0'
    WHEN vi.version LIKE '12.%' THEN 'CIS Oracle Database 12c Benchmark v2.0.0'
    WHEN vi.version LIKE '11.2%' THEN 'CIS Oracle Database 11g R2 Benchmark v2.2.0'
    ELSE 'CIS Oracle Database Benchmark'
  END) || '</div>' ||
  '<table class="summary-table">' ||
  '<tr><th>Category</th><th>Total Checks</th><th>Passes</th><th>Failures</th><th>Pass Rate</th></tr>' ||
  LISTAGG('<tr><td>' || category || '</td>' ||
  '<td>' || total_checks || '</td>' ||
  '<td class="pass">' || passes || '</td>' ||
  '<td class="fail">' || (total_checks - passes) || '</td>' ||
  '<td>' || ROUND((passes/total_checks)*100, 1) || '%</td></tr>', '') WITHIN GROUP (ORDER BY category) ||
  '</table>'
FROM audit_summary, v$instance vi;

-- Comprehensive Risk Assessment
PROMPT <h3>Risk Assessment</h3>
PROMPT <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 10px 0;">

-- Critical Risk Issues
SELECT '<p><strong>Critical Risk Issues (Immediate Action Required):</strong></p><ul>' ||
  CASE WHEN EXISTS (SELECT 1 FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%') 
    THEN '<li style="color: #dc3545; font-weight: bold;"><span class="material-icons" style="color: #dc3545;">error</span>DEFAULT PASSWORDS DETECTED - Accounts vulnerable to immediate compromise</li>' ELSE '' END ||
  CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_TRAIL' AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED'))
    THEN '<li style="color: #dc3545; font-weight: bold;"><span class="material-icons" style="color: #dc3545;">error</span>AUDITING DISABLED - No security event tracking, compliance violation</li>' ELSE '' END ||
  CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY' AND UPPER(VALUE) NOT IN ('FALSE') AND VALUE IS NOT NULL)
    THEN '<li style="color: #dc3545; font-weight: bold;"><span class="material-icons" style="color: #dc3545;">error</span>DICTIONARY ACCESS VULNERABILITY - Unauthorized data dictionary access possible</li>' ELSE '' END ||
  CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_OS_AUTHENT' AND UPPER(VALUE) != 'FALSE')
    THEN '<li style="color: #dc3545; font-weight: bold;"><span class="material-icons" style="color: #dc3545;">error</span>REMOTE OS AUTHENTICATION ENABLED - Bypass authentication risk</li>' ELSE '' END ||
  CASE WHEN EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='EXEMPT ACCESS POLICY')
    THEN '<li style="color: #dc3545; font-weight: bold;"><span class="material-icons" style="color: #dc3545;">error</span>EXEMPT ACCESS POLICY GRANTED - Complete security policy bypass possible</li>' ELSE '' END ||
  '</ul>' AS critical_risks
FROM DUAL;

-- High Risk Issues
SELECT '<p><strong>High Risk Issues (Priority Remediation):</strong></p><ul>' ||
  CASE WHEN EXISTS (SELECT 1 FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME IN ('DBMS_JAVA','DBMS_SCHEDULER','DBMS_SQL','UTL_FILE','UTL_TCP','UTL_HTTP'))
    THEN '<li style="color: #e67e22;"><span class="material-icons" style="color: #e67e22;">warning</span>DANGEROUS PUBLIC PRIVILEGES - Code execution and file system access via PUBLIC</li>' ELSE '' END ||
  CASE WHEN EXISTS (SELECT 1 FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE='DBA' AND GRANTEE NOT IN ('SYS','SYSTEM'))
    THEN '<li style="color: #e67e22;"><span class="material-icons" style="color: #e67e22;">warning</span>EXCESSIVE DBA PRIVILEGES - Non-system users with full database control</li>' ELSE '' END ||
  CASE WHEN EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE LIKE '%ANY%' AND GRANTEE NOT IN ('DBA','SYS','SYSTEM','IMP_FULL_DATABASE','EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE'))
    THEN '<li style="color: #e67e22;"><span class="material-icons" style="color: #e67e22;">warning</span>EXCESSIVE ANY PRIVILEGES - Broad system access rights granted</li>' ELSE '' END ||
  CASE WHEN EXISTS (SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='FAILED_LOGIN_ATTEMPTS' AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 10)))
    THEN '<li style="color: #e67e22;"><span class="material-icons" style="color: #e67e22;">warning</span>WEAK LOCKOUT POLICY - Brute force attacks not properly prevented</li>' ELSE '' END ||
  CASE WHEN EXISTS (SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_VERIFY_FUNCTION' AND LIMIT = 'NULL')
    THEN '<li style="color: #e67e22;"><span class="material-icons" style="color: #e67e22;">warning</span>NO PASSWORD COMPLEXITY - Weak passwords allowed</li>' ELSE '' END ||
  CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'SEC_RETURN_SERVER_RELEASE_BANNER' AND UPPER(VALUE) != 'FALSE')
    THEN '<li style="color: #e67e22;"><span class="material-icons" style="color: #e67e22;">warning</span>VERSION DISCLOSURE - Database version exposed to attackers</li>' ELSE '' END ||
  '</ul>' AS high_risks
FROM DUAL;

-- Medium Risk Issues
SELECT '<p><strong>Medium Risk Issues (Scheduled Remediation):</strong></p><ul>' ||
  CASE WHEN EXISTS (SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_LIFE_TIME' AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 180)))
    THEN '<li style="color: #f39c12;"><span class="material-icons" style="color: #f39c12;">info</span>LONG PASSWORD LIFETIME - Compromised passwords may remain active too long</li>' ELSE '' END ||
  CASE WHEN EXISTS (SELECT 1 FROM DBA_USERS WHERE PROFILE='DEFAULT' AND ACCOUNT_STATUS='OPEN' AND USERNAME NOT IN ('SYS','SYSTEM','DBSNMP'))
    THEN '<li style="color: #f39c12;"><span class="material-icons" style="color: #f39c12;">info</span>DEFAULT PROFILE USAGE - Users not following organizational password policies</li>' ELSE '' END ||
  CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='CREATE SESSION' AND SUCCESS = 'BY ACCESS')
    THEN '<li style="color: #f39c12;"><span class="material-icons" style="color: #f39c12;">info</span>LIMITED AUDIT COVERAGE - Login attempts not tracked</li>' ELSE '' END ||
  CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_LISTENER' AND VALUE IS NOT NULL)
    THEN '<li style="color: #f39c12;"><span class="material-icons" style="color: #f39c12;">info</span>REMOTE LISTENER CONFIGURED - Potential network attack vector</li>' ELSE '' END ||
  '</ul>' AS medium_risks
FROM DUAL;

-- Enhanced Risk Summary with Visual Chart
SELECT '<p><strong>Risk Summary Dashboard:</strong></p>' ||
  '<div style="display: flex; align-items: flex-start; gap: 20px; margin: 15px 0;">' ||
  -- Risk Counts Table
  '<div style="flex: 1;">' ||
  '<table style="border-collapse: collapse; width: 100%; font-size: 14px;">' ||
  '<tr><th style="padding: 12px; background-color: #f8f9fa; border: 1px solid #dee2e6; text-align: left;">Risk Level</th>' ||
      '<th style="padding: 12px; background-color: #f8f9fa; border: 1px solid #dee2e6; text-align: center;">Count</th>' ||
      '<th style="padding: 12px; background-color: #f8f9fa; border: 1px solid #dee2e6; text-align: center;">Priority</th></tr>' ||
  '<tr><td style="padding: 12px; background-color: #dc3545; color: white; border: 1px solid #ccc; font-weight: bold;">' ||
      '<span class="material-icons" style="vertical-align: middle; margin-right: 8px;">error</span>Critical</td>' ||
      '<td style="padding: 12px; border: 1px solid #ccc; text-align: center; font-weight: bold; font-size: 16px;">' ||
    (SELECT COUNT(*) FROM (
      SELECT 1 FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%' AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_TRAIL' AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY' AND UPPER(VALUE) NOT IN ('FALSE') AND VALUE IS NOT NULL AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_OS_AUTHENT' AND UPPER(VALUE) != 'FALSE' AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='EXEMPT ACCESS POLICY' AND ROWNUM = 1
    )) || '</td>' ||
    '<td style="padding: 12px; border: 1px solid #ccc; text-align: center; color: #dc3545; font-weight: bold;">24 Hours</td></tr>' ||
  '<tr><td style="padding: 12px; background-color: #e67e22; color: white; border: 1px solid #ccc; font-weight: bold;">' ||
      '<span class="material-icons" style="vertical-align: middle; margin-right: 8px;">warning</span>High</td>' ||
      '<td style="padding: 12px; border: 1px solid #ccc; text-align: center; font-weight: bold; font-size: 16px;">' ||
    (SELECT COUNT(*) FROM (
      SELECT 1 FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME IN ('DBMS_JAVA','DBMS_SCHEDULER','DBMS_SQL','UTL_FILE','UTL_TCP','UTL_HTTP') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE='DBA' AND GRANTEE NOT IN ('SYS','SYSTEM') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE LIKE '%ANY%' AND GRANTEE NOT IN ('DBA','SYS','SYSTEM','IMP_FULL_DATABASE','EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='FAILED_LOGIN_ATTEMPTS' AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 10)) AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_VERIFY_FUNCTION' AND LIMIT = 'NULL' AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'SEC_RETURN_SERVER_RELEASE_BANNER' AND UPPER(VALUE) != 'FALSE' AND ROWNUM = 1
    )) || '</td>' ||
    '<td style="padding: 12px; border: 1px solid #ccc; text-align: center; color: #e67e22; font-weight: bold;">1 Week</td></tr>' ||
  '<tr><td style="padding: 12px; background-color: #f39c12; color: white; border: 1px solid #ccc; font-weight: bold;">' ||
      '<span class="material-icons" style="vertical-align: middle; margin-right: 8px;">info</span>Medium</td>' ||
      '<td style="padding: 12px; border: 1px solid #ccc; text-align: center; font-weight: bold; font-size: 16px;">' ||
    (SELECT COUNT(*) FROM (
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_LIFE_TIME' AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 180)) AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_USERS WHERE PROFILE='DEFAULT' AND ACCOUNT_STATUS='OPEN' AND USERNAME NOT IN ('SYS','SYSTEM','DBSNMP') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='CREATE SESSION' AND SUCCESS = 'BY ACCESS') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_LISTENER' AND VALUE IS NOT NULL AND ROWNUM = 1
    )) || '</td>' ||
    '<td style="padding: 12px; border: 1px solid #ccc; text-align: center; color: #f39c12; font-weight: bold;">1 Month</td></tr>' ||
  '</table></div>' ||  
  -- Visual Risk Chart with bars
  '<div style="flex: 1; text-align: center;">' ||
  '<h4 style="margin-top: 0; margin-bottom: 15px;">Risk Distribution</h4>' ||
  '<div style="position: relative; margin: 20px 0;">' AS risk_stats_part1
FROM DUAL;

-- Generate Visual Risk Bars
SELECT 
  -- Critical Risk Bar
  '<div style="margin: 8px 0; text-align: left;">' ||
  '<div style="display: inline-block; width: 80px; font-size: 12px; font-weight: bold;">Critical:</div>' ||
  '<div style="display: inline-block; width: 200px; background-color: #f8f9fa; border: 1px solid #dee2e6; border-radius: 4px; overflow: hidden;">' ||
  '<div style="height: 20px; background-color: #dc3545; width: ' || GREATEST(10, LEAST(100, (
    (SELECT COUNT(*) FROM (
      SELECT 1 FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%' AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_TRAIL' AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY' AND UPPER(VALUE) NOT IN ('FALSE') AND VALUE IS NOT NULL AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_OS_AUTHENT' AND UPPER(VALUE) != 'FALSE' AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='EXEMPT ACCESS POLICY' AND ROWNUM = 1
    )) * 20
  ))) || '%; display: flex; align-items: center; justify-content: center; color: white; font-size: 12px; font-weight: bold;">' ||
  (SELECT COUNT(*) FROM (
      SELECT 1 FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%' AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_TRAIL' AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY' AND UPPER(VALUE) NOT IN ('FALSE') AND VALUE IS NOT NULL AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_OS_AUTHENT' AND UPPER(VALUE) != 'FALSE' AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='EXEMPT ACCESS POLICY' AND ROWNUM = 1
    )) || '</div></div></div>' ||
  -- High Risk Bar
  '<div style="margin: 8px 0; text-align: left;">' ||
  '<div style="display: inline-block; width: 80px; font-size: 12px; font-weight: bold;">High:</div>' ||
  '<div style="display: inline-block; width: 200px; background-color: #f8f9fa; border: 1px solid #dee2e6; border-radius: 4px; overflow: hidden;">' ||
  '<div style="height: 20px; background-color: #e67e22; width: ' || GREATEST(10, LEAST(100, (
    (SELECT COUNT(*) FROM (
      SELECT 1 FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME IN ('DBMS_JAVA','DBMS_SCHEDULER','DBMS_SQL','UTL_FILE','UTL_TCP','UTL_HTTP') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE='DBA' AND GRANTEE NOT IN ('SYS','SYSTEM') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE LIKE '%ANY%' AND GRANTEE NOT IN ('DBA','SYS','SYSTEM','IMP_FULL_DATABASE','EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='FAILED_LOGIN_ATTEMPTS' AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 10)) AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_VERIFY_FUNCTION' AND LIMIT = 'NULL' AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'SEC_RETURN_SERVER_RELEASE_BANNER' AND UPPER(VALUE) != 'FALSE' AND ROWNUM = 1
    )) * 16.67
  ))) || '%; display: flex; align-items: center; justify-content: center; color: white; font-size: 12px; font-weight: bold;">' ||
  (SELECT COUNT(*) FROM (
      SELECT 1 FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME IN ('DBMS_JAVA','DBMS_SCHEDULER','DBMS_SQL','UTL_FILE','UTL_TCP','UTL_HTTP') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE='DBA' AND GRANTEE NOT IN ('SYS','SYSTEM') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE LIKE '%ANY%' AND GRANTEE NOT IN ('DBA','SYS','SYSTEM','IMP_FULL_DATABASE','EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='FAILED_LOGIN_ATTEMPTS' AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 10)) AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_VERIFY_FUNCTION' AND LIMIT = 'NULL' AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'SEC_RETURN_SERVER_RELEASE_BANNER' AND UPPER(VALUE) != 'FALSE' AND ROWNUM = 1
    )) || '</div></div></div>' ||
  -- Medium Risk Bar
  '<div style="margin: 8px 0; text-align: left;">' ||
  '<div style="display: inline-block; width: 80px; font-size: 12px; font-weight: bold;">Medium:</div>' ||
  '<div style="display: inline-block; width: 200px; background-color: #f8f9fa; border: 1px solid #dee2e6; border-radius: 4px; overflow: hidden;">' ||
  '<div style="height: 20px; background-color: #f39c12; width: ' || GREATEST(10, LEAST(100, (
    (SELECT COUNT(*) FROM (
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_LIFE_TIME' AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 180)) AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_USERS WHERE PROFILE='DEFAULT' AND ACCOUNT_STATUS='OPEN' AND USERNAME NOT IN ('SYS','SYSTEM','DBSNMP') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='CREATE SESSION' AND SUCCESS = 'BY ACCESS') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_LISTENER' AND VALUE IS NOT NULL AND ROWNUM = 1
    )) * 25
  ))) || '%; display: flex; align-items: center; justify-content: center; color: white; font-size: 12px; font-weight: bold;">' ||
  (SELECT COUNT(*) FROM (
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_LIFE_TIME' AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 180)) AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DBA_USERS WHERE PROFILE='DEFAULT' AND ACCOUNT_STATUS='OPEN' AND USERNAME NOT IN ('SYS','SYSTEM','DBSNMP') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='CREATE SESSION' AND SUCCESS = 'BY ACCESS') AND ROWNUM = 1
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_LISTENER' AND VALUE IS NOT NULL AND ROWNUM = 1
    )) || '</div></div></div>' ||
  '</div></div></div>' AS risk_stats_part2
FROM DUAL;

-- Add risk interpretation
SELECT '<div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 15px 0; border-left: 4px solid #007bff;">' ||
  '<h4 style="margin-top: 0; color: #007bff;"><span class="material-icons" style="vertical-align: middle; margin-right: 8px;">analytics</span>Risk Assessment Summary</h4>' ||
  '<div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 15px; font-size: 13px;">' ||
  '<div style="background-color: white; padding: 12px; border-radius: 4px; border: 1px solid #dee2e6;">' ||
  '<div style="color: #dc3545; font-weight: bold; margin-bottom: 5px;"><span class="material-icons" style="font-size: 16px; vertical-align: middle; margin-right: 4px;">error</span>Critical Risks</div>' ||
  '<div>Immediate threats requiring<br><strong>emergency response</strong><br>within 24 hours</div>' ||
  '</div>' ||
  '<div style="background-color: white; padding: 12px; border-radius: 4px; border: 1px solid #dee2e6;">' ||
  '<div style="color: #e67e22; font-weight: bold; margin-bottom: 5px;"><span class="material-icons" style="font-size: 16px; vertical-align: middle; margin-right: 4px;">warning</span>High Risks</div>' ||
  '<div>Serious vulnerabilities<br>requiring <strong>priority<br>remediation</strong> within 1 week</div>' ||
  '</div>' ||
  '<div style="background-color: white; padding: 12px; border-radius: 4px; border: 1px solid #dee2e6;">' ||
  '<div style="color: #f39c12; font-weight: bold; margin-bottom: 5px;"><span class="material-icons" style="font-size: 16px; vertical-align: middle; margin-right: 4px;">info</span>Medium Risks</div>' ||
  '<div>Important security gaps<br>requiring <strong>scheduled<br>remediation</strong> within 1 month</div>' ||
  '</div>' ||
  '</div></div>' AS risk_interpretation
FROM DUAL;

PROMPT </div>

-- Dynamic Remediation Action Plan Based on Findings
PROMPT <h3>Security Remediation Action Plan</h3>
PROMPT <div style="background-color: #e7f3ff; padding: 15px; border-radius: 5px; margin: 10px 0;">

-- Generate IMMEDIATE ACTIONS based on critical findings
SELECT '<h4 style="color: #c62828; margin-top: 0;"><span class="material-icons" style="color: #c62828; vertical-align: middle; margin-right: 8px;">error_outline</span>CRITICAL - IMMEDIATE ACTIONS (Within 24 Hours)</h4>' ||
  '<ol style="margin-bottom: 20px;">' ||
  -- Default passwords check
  CASE WHEN EXISTS (SELECT 1 FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%') THEN
    '<li style="background-color: #ffebee; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #c62828;">' ||
    '<strong style="color: #c62828;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">lock_open</span>Change All Default Passwords</strong><br>' ||
    '<div style="margin-top: 8px;">Affected users: <code>' || 
    (SELECT LISTAGG(USERNAME, ', ') WITHIN GROUP (ORDER BY USERNAME) 
     FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%' AND ROWNUM <= 10) || 
    CASE WHEN (SELECT COUNT(*) FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%') > 10 
      THEN ' (and ' || ((SELECT COUNT(*) FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%') - 10) || ' more)' 
      ELSE '' END || '</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #c62828;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Run: <code>SELECT username FROM dba_users_with_defpwd WHERE username NOT LIKE ''%XS$NULL%'';</code><br>' ||
    '2. Execute: <code>ALTER USER &lt;username&gt; IDENTIFIED BY "&lt;ComplexPassword123!&gt;" PASSWORD EXPIRE;</code><br>' ||
    '3. Document password changes and notify users</div></li>'
  ELSE '' END ||
  -- Audit trail check
  CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_TRAIL' 
    AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED')) THEN
    '<li style="background-color: #ffebee; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #c62828;">' ||
    '<strong style="color: #c62828;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">policy</span>Enable Database Auditing</strong><br>' ||
    '<div style="margin-top: 8px;">Current Setting: <code>' || 
    NVL((SELECT VALUE FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_TRAIL'), 'NONE') || '</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #dc3545;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Set: <code>ALTER SYSTEM SET AUDIT_TRAIL=DB,EXTENDED SCOPE=SPFILE;</code><br>' ||
    '2. Enable: <code>AUDIT SESSION;</code> and <code>AUDIT SYSTEM GRANT;</code><br>' ||
    '3. Restart database to activate<br>' ||
    '4. Configure audit log management and retention</div></li>'
  ELSE '' END ||
  -- Dictionary accessibility check
  CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY' 
    AND UPPER(VALUE) NOT IN ('FALSE') AND VALUE IS NOT NULL) THEN
    '<li style="background-color: #ffebee; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #c62828;">' ||
    '<strong style="color: #c62828;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">block</span>Disable Dictionary Access</strong><br>' ||
    '<div style="margin-top: 8px;">Current Setting: <code>' || 
    (SELECT VALUE FROM V$PARAMETER WHERE UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY') || '</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #dc3545;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Set: <code>ALTER SYSTEM SET O7_DICTIONARY_ACCESSIBILITY=FALSE SCOPE=SPFILE;</code><br>' ||
    '2. Restart database<br>' ||
    '3. Test application compatibility</div></li>'
  ELSE '' END ||
  -- Remote OS authentication check
  CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_OS_AUTHENT' AND UPPER(VALUE) != 'FALSE') THEN
    '<li style="background-color: #ffebee; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #c62828;">' ||
    '<strong style="color: #c62828;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">vpn_lock</span>Disable Remote OS Authentication</strong><br>' ||
    '<div style="margin-top: 8px;">Current Setting: <code>' || 
    (SELECT VALUE FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_OS_AUTHENT') || '</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #dc3545;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Set: <code>ALTER SYSTEM SET REMOTE_OS_AUTHENT=FALSE SCOPE=SPFILE;</code><br>' ||
    '2. Restart database<br>' ||
    '3. Review and update authentication methods</div></li>'
  ELSE '' END ||
  -- EXEMPT ACCESS POLICY check
  CASE WHEN EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='EXEMPT ACCESS POLICY') THEN
    '<li style="background-color: #ffebee; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #c62828;">' ||
    '<strong style="color: #c62828;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">remove_moderator</span>Revoke EXEMPT ACCESS POLICY Privilege</strong><br>' ||
    '<div style="margin-top: 8px;">Granted to: <code>' || 
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) 
     FROM DBA_SYS_PRIVS WHERE PRIVILEGE='EXEMPT ACCESS POLICY' AND ROWNUM <= 5) || '</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #c62828;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Review: <code>SELECT grantee FROM dba_sys_privs WHERE privilege=''EXEMPT ACCESS POLICY'';</code><br>' ||
    '2. Revoke: <code>REVOKE EXEMPT ACCESS POLICY FROM &lt;grantee&gt;;</code><br>' ||
    '3. Document security policy bypass requirements</div></li>'
  ELSE '' END ||
  '</ol>' ||
  -- If no critical issues found
  CASE WHEN NOT EXISTS (
    SELECT 1 FROM (
      SELECT 1 FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%'
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_TRAIL' AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED')
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY' AND UPPER(VALUE) NOT IN ('FALSE') AND VALUE IS NOT NULL
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_OS_AUTHENT' AND UPPER(VALUE) != 'FALSE'
      UNION ALL
      SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE='EXEMPT ACCESS POLICY'
    ) WHERE ROWNUM = 1
  ) THEN 
    '<p style="color: green; padding: 10px; background-color: #e8f5e9; border-radius: 4px;">' ||
    '<span class="material-icons" style="vertical-align: middle;">check_circle</span> ' ||
    'No critical security issues requiring immediate action were found.</p>'
  ELSE '' END
FROM DUAL;

-- Generate HIGH PRIORITY ACTIONS based on high-risk findings
SELECT '<h4 style="color: #ef6c00;"><span class="material-icons" style="color: #ef6c00; vertical-align: middle; margin-right: 8px;">warning</span>HIGH PRIORITY (Within 1 Week)</h4>' ||
  '<ol style="margin-bottom: 20px;">' ||
  -- Dangerous PUBLIC privileges check
  CASE WHEN EXISTS (SELECT 1 FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' 
    AND TABLE_NAME IN ('DBMS_JAVA','DBMS_SCHEDULER','DBMS_SQL','UTL_FILE','UTL_TCP','UTL_HTTP')) THEN
    '<li style="background-color: #ffe0b2; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #ef6c00;">' ||
    '<strong style="color: #ef6c00;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">security</span>Revoke Dangerous PUBLIC Privileges</strong><br>' ||
    '<div style="margin-top: 8px;">Packages with PUBLIC EXECUTE: <code>' || 
    (SELECT LISTAGG(TABLE_NAME, ', ') WITHIN GROUP (ORDER BY 
      CASE TABLE_NAME 
        WHEN 'DBMS_JAVA' THEN 1 
        WHEN 'UTL_FILE' THEN 2 
        WHEN 'UTL_TCP' THEN 3
        WHEN 'UTL_HTTP' THEN 4
        WHEN 'DBMS_SCHEDULER' THEN 5
        WHEN 'DBMS_SQL' THEN 6
        WHEN 'UTL_SMTP' THEN 7
        ELSE 8 END)
     FROM DBA_TAB_PRIVS 
     WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' 
     AND TABLE_NAME IN ('DBMS_JAVA','DBMS_SCHEDULER','DBMS_SQL','UTL_FILE','UTL_TCP','UTL_HTTP','UTL_SMTP','UTL_MAIL','DBMS_RANDOM','DBMS_LOB','DBMS_XMLGEN','DBMS_XMLQUERY','UTL_INADDR','DBMS_JOB','DBMS_LDAP','DBMS_OBFUSCATION_TOOLKIT','DBMS_ADVISOR','HTTPURITYPE')
     AND ROWNUM <= 20) || '</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #ef6c00;">' ||
    '<strong>Remediation Script:</strong><br>' ||
    '<pre style="background-color: #f5f5f5; padding: 8px; border-radius: 4px; overflow-x: auto; font-size: 12px;">' ||
    '-- Critical packages (high risk)' || CHR(10) ||
    'REVOKE EXECUTE ON DBMS_JAVA FROM PUBLIC;' || CHR(10) ||
    'REVOKE EXECUTE ON UTL_FILE FROM PUBLIC;' || CHR(10) ||
    'REVOKE EXECUTE ON UTL_TCP FROM PUBLIC;' || CHR(10) ||
    'REVOKE EXECUTE ON UTL_HTTP FROM PUBLIC;' || CHR(10) ||
    'REVOKE EXECUTE ON DBMS_SCHEDULER FROM PUBLIC;' || CHR(10) ||
    'REVOKE EXECUTE ON DBMS_SQL FROM PUBLIC;' || CHR(10) ||
    CHR(10) || '-- Additional dangerous packages' || CHR(10) ||
    'REVOKE EXECUTE ON UTL_SMTP FROM PUBLIC;' || CHR(10) ||
    'REVOKE EXECUTE ON DBMS_LOB FROM PUBLIC;' || CHR(10) ||
    'REVOKE EXECUTE ON DBMS_RANDOM FROM PUBLIC;' || CHR(10) ||
    CHR(10) || '-- Generate full list:' || CHR(10) ||
    'SELECT ''REVOKE EXECUTE ON '' || table_name || '' FROM PUBLIC;''' || CHR(10) ||
    'FROM dba_tab_privs WHERE grantee=''PUBLIC'' AND privilege=''EXECUTE'';' ||
    '</pre>' ||
    '<strong>Post-Revoke Action:</strong> Grant execute privileges only to specific users/roles that require them for legitimate business functions.</div></li>'
  ELSE '' END ||
  -- Password policy check
  CASE WHEN EXISTS (SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_VERIFY_FUNCTION' 
    AND (LIMIT = 'NULL' OR LIMIT = 'DEFAULT')) THEN
    '<li style="background-color: #ffe0b2; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #ef6c00;">' ||
    '<strong style="color: #ef6c00;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">password</span>Implement Strong Password Policies</strong><br>' ||
    '<div style="margin-top: 8px;">Profiles without password verification: <code>' || 
    (SELECT LISTAGG(DISTINCT PROFILE, ', ') WITHIN GROUP (ORDER BY PROFILE)
     FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_VERIFY_FUNCTION' 
     AND (LIMIT = 'NULL' OR LIMIT = 'DEFAULT') AND ROWNUM <= 5) || '</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #e67e22;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Create: <code>CREATE PROFILE SECURE_PROFILE LIMIT FAILED_LOGIN_ATTEMPTS 3 PASSWORD_LOCK_TIME 1;</code><br>' ||
    '2. Set: <code>ALTER PROFILE SECURE_PROFILE LIMIT PASSWORD_VERIFY_FUNCTION ' ||
    CASE WHEN (SELECT version FROM v$instance) LIKE '12.%' OR (SELECT version FROM v$instance) LIKE '18.%' OR (SELECT version FROM v$instance) LIKE '19.%'
      THEN 'ORA12C_VERIFY_FUNCTION' ELSE 'VERIFY_FUNCTION_11G' END || ';</code><br>' ||
    '3. Apply: <code>ALTER USER &lt;username&gt; PROFILE SECURE_PROFILE;</code></div></li>'
  ELSE '' END ||
  -- DBA role check
  CASE WHEN EXISTS (SELECT 1 FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE='DBA' 
    AND GRANTEE NOT IN ('SYS','SYSTEM','SYSMAN')) THEN
    '<li style="background-color: #ffe0b2; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #ef6c00;">' ||
    '<strong style="color: #ef6c00;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">admin_panel_settings</span>Review Excessive DBA Privileges</strong><br>' ||
    '<div style="margin-top: 8px;">Non-system users with DBA role: <code>' || 
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
     FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE='DBA' 
     AND GRANTEE NOT IN ('SYS','SYSTEM','SYSMAN') AND ROWNUM <= 10) || '</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #e67e22;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Review: <code>SELECT grantee FROM dba_role_privs WHERE granted_role=''DBA'';</code><br>' ||
    '2. Revoke: <code>REVOKE DBA FROM &lt;user&gt;;</code><br>' ||
    '3. Grant specific privileges based on actual requirements</div></li>'
  ELSE '' END ||
  -- ANY privileges check with Oracle account filtering
  CASE WHEN EXISTS (SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE LIKE '%ANY%' 
    AND GRANTEE NOT IN ('DBA','SYS','SYSTEM','IMP_FULL_DATABASE','EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE',
                        'AUDSYS','GGSYS','GSMADMIN_INTERNAL','SYSBACKUP','SYSDG','SYSKM','SYSRAC','XDB','CTXSYS',
                        'MDSYS','OLAPSYS','ORDSYS','WMSYS','APEX_PUBLIC_USER','FLOWS_FILES','ANONYMOUS',
                        'SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','MDDATA','ORACLE_OCM','ORDDATA',
                        'ORDPLUGINS','SI_INFORMTN_SCHEMA','SYSMAN','MGMT_VIEW','DBSNMP')) THEN
    '<li style="background-color: #ffe0b2; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #ef6c00;">' ||
    '<strong style="color: #ef6c00;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">admin_panel_settings</span>Review ANY System Privileges</strong><br>' ||
    '<div style="margin-top: 8px;">Non-Oracle users with ANY privileges: <code>' || 
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) 
     FROM (SELECT DISTINCT GRANTEE FROM DBA_SYS_PRIVS WHERE PRIVILEGE LIKE '%ANY%' 
           AND GRANTEE NOT IN ('DBA','SYS','SYSTEM','IMP_FULL_DATABASE','EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE',
                              'AUDSYS','GGSYS','GSMADMIN_INTERNAL','SYSBACKUP','SYSDG','SYSKM','SYSRAC','XDB','CTXSYS',
                              'MDSYS','OLAPSYS','ORDSYS','WMSYS','APEX_PUBLIC_USER','FLOWS_FILES','ANONYMOUS',
                              'SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','MDDATA','ORACLE_OCM','ORDDATA',
                              'ORDPLUGINS','SI_INFORMTN_SCHEMA','SYSMAN','MGMT_VIEW','DBSNMP')
           AND ROWNUM <= 10)) || 
    CASE WHEN (SELECT COUNT(DISTINCT GRANTEE) FROM DBA_SYS_PRIVS WHERE PRIVILEGE LIKE '%ANY%' 
               AND GRANTEE NOT IN ('DBA','SYS','SYSTEM','IMP_FULL_DATABASE','EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE',
                                  'AUDSYS','GGSYS','GSMADMIN_INTERNAL','SYSBACKUP','SYSDG','SYSKM','SYSRAC','XDB','CTXSYS',
                                  'MDSYS','OLAPSYS','ORDSYS','WMSYS','APEX_PUBLIC_USER','FLOWS_FILES','ANONYMOUS',
                                  'SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','MDDATA','ORACLE_OCM','ORDDATA',
                                  'ORDPLUGINS','SI_INFORMTN_SCHEMA','SYSMAN','MGMT_VIEW','DBSNMP')) > 10
      THEN ' (and more)' ELSE '' END || '</code></div>' ||
    '<div style="margin-top: 8px; background-color: #ffe0b2; padding: 8px; border-radius: 4px;">' ||
    '<strong>Oracle System Accounts Note:</strong> Oracle-supplied accounts like AUDSYS, GGSYS, SYSBACKUP, etc., have been excluded from this check. ' ||
    'Consider locking unused Oracle accounts: <code>ALTER USER &lt;oracle_account&gt; ACCOUNT LOCK;</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #ef6c00;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Review non-Oracle users: <code>SELECT grantee, privilege FROM dba_sys_privs WHERE privilege LIKE ''%ANY%'' AND grantee NOT IN (Oracle system accounts);</code><br>' ||
    '2. Apply principle of least privilege - revoke unnecessary ANY privileges<br>' ||
    '3. Replace with object-specific grants where possible<br>' ||
    '4. Lock unused Oracle system accounts to reduce attack surface</div></li>'
  ELSE '' END ||
  -- Failed login attempts check
  CASE WHEN EXISTS (SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='FAILED_LOGIN_ATTEMPTS' 
    AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 10))) THEN
    '<li style="background-color: #ffe0b2; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #ef6c00;">' ||
    '<strong style="color: #ef6c00;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">lock_clock</span>Configure Account Lockout Policy</strong><br>' ||
    '<div style="margin-top: 8px;">Weak lockout settings in profiles: <code>' || 
    (SELECT LISTAGG(PROFILE || ' (' || LIMIT || ')', ', ') WITHIN GROUP (ORDER BY PROFILE)
     FROM DBA_PROFILES WHERE RESOURCE_NAME='FAILED_LOGIN_ATTEMPTS' 
     AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 10))
     AND ROWNUM <= 5) || '</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #e67e22;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Set: <code>ALTER PROFILE DEFAULT LIMIT FAILED_LOGIN_ATTEMPTS 5;</code><br>' ||
    '2. Set: <code>ALTER PROFILE DEFAULT LIMIT PASSWORD_LOCK_TIME 1;</code><br>' ||
    '3. Monitor failed login attempts in audit trail</div></li>'
  ELSE '' END ||
  '</ol>' ||
  -- If no high priority issues found
  CASE WHEN NOT EXISTS (
    SELECT 1 FROM (
      SELECT 1 FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' 
        AND TABLE_NAME IN ('DBMS_JAVA','DBMS_SCHEDULER','DBMS_SQL','UTL_FILE','UTL_TCP','UTL_HTTP')
      UNION ALL
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_VERIFY_FUNCTION' AND (LIMIT = 'NULL' OR LIMIT = 'DEFAULT')
      UNION ALL
      SELECT 1 FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE='DBA' AND GRANTEE NOT IN ('SYS','SYSTEM','SYSMAN')
      UNION ALL
      SELECT 1 FROM DBA_SYS_PRIVS WHERE PRIVILEGE LIKE '%ANY%' 
        AND GRANTEE NOT IN ('DBA','SYS','SYSTEM','IMP_FULL_DATABASE','EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE')
      UNION ALL
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='FAILED_LOGIN_ATTEMPTS' 
        AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 10))
    ) WHERE ROWNUM = 1
  ) THEN 
    '<p style="color: #e67e22; padding: 10px; background-color: #fff3cd; border-radius: 4px;">' ||
    '<span class="material-icons" style="vertical-align: middle;">check_circle</span> ' ||
    'No high priority security issues were found.</p>'
  ELSE '' END
FROM DUAL;

-- Generate MEDIUM PRIORITY ACTIONS based on medium-risk findings
SELECT '<h4 style="color: #f9a825;"><span class="material-icons" style="color: #f9a825; vertical-align: middle; margin-right: 8px;">schedule</span>MEDIUM PRIORITY (Within 1 Month)</h4>' ||
  '<ol style="margin-bottom: 20px;">' ||
  -- Audit configuration check
  CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='CREATE SESSION' AND SUCCESS = 'BY ACCESS') 
    OR NOT EXISTS (SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='SYSTEM GRANT' AND SUCCESS = 'BY ACCESS') THEN
    '<li style="background-color: #fff9c4; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #f9a825;">' ||
    '<strong style="color: #f9a825;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">track_changes</span>Complete Audit Configuration</strong><br>' ||
    '<div style="margin-top: 8px;">Missing audit options: ' ||
    CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='CREATE SESSION') 
      THEN '<code>CREATE SESSION</code> ' ELSE '' END ||
    CASE WHEN NOT EXISTS (SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION='SYSTEM GRANT') 
      THEN '<code>SYSTEM GRANT</code> ' ELSE '' END || '</div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #f39c12;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Enable: <code>AUDIT SESSION; AUDIT SYSTEM GRANT; AUDIT USER;</code><br>' ||
    '2. Configure: <code>AUDIT ROLE; AUDIT PROFILE; AUDIT DATABASE LINK;</code><br>' ||
    '3. Set up audit log management and retention policies</div></li>'
  ELSE '' END ||
  -- Sample users check
  CASE WHEN EXISTS (SELECT 1 FROM ALL_USERS WHERE USERNAME IN ('BI','HR','IX','OE','PM','SCOTT','SH')) THEN
    '<li style="background-color: #fff9c4; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #f9a825;">' ||
    '<strong style="color: #f9a825;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">person_remove</span>Remove Sample Users</strong><br>' ||
    '<div style="margin-top: 8px;">Sample users found: <code>' || 
    (SELECT LISTAGG(USERNAME, ', ') WITHIN GROUP (ORDER BY USERNAME)
     FROM ALL_USERS WHERE USERNAME IN ('BI','HR','IX','OE','PM','SCOTT','SH')) || '</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #f39c12;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Execute: <code>$ORACLE_HOME/demo/schema/drop_sch.sql</code><br>' ||
    '2. Or manually: <code>DROP USER SCOTT CASCADE;</code><br>' ||
    '3. Verify removal and update documentation</div></li>'
  ELSE '' END ||
  -- Default profile usage check
  CASE WHEN EXISTS (SELECT 1 FROM DBA_USERS WHERE PROFILE='DEFAULT' AND ACCOUNT_STATUS='OPEN' 
    AND USERNAME NOT IN ('SYS','SYSTEM','DBSNMP','XDB','ANONYMOUS')) THEN
    '<li style="background-color: #fff9c4; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #f9a825;">' ||
    '<strong style="color: #f9a825;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">manage_accounts</span>Assign Custom Profiles to Users</strong><br>' ||
    '<div style="margin-top: 8px;">Users with DEFAULT profile: <code>' || 
    (SELECT COUNT(*) FROM DBA_USERS WHERE PROFILE='DEFAULT' AND ACCOUNT_STATUS='OPEN' 
     AND USERNAME NOT IN ('SYS','SYSTEM','DBSNMP','XDB','ANONYMOUS')) || ' users</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #f39c12;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Create custom profiles for different user types<br>' ||
    '2. Assign: <code>ALTER USER &lt;username&gt; PROFILE &lt;custom_profile&gt;;</code><br>' ||
    '3. Implement role-based security model</div></li>'
  ELSE '' END ||
  -- Password lifetime check
  CASE WHEN EXISTS (SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_LIFE_TIME' 
    AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 180))) THEN
    '<li style="background-color: #fff9c4; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #f9a825;">' ||
    '<strong style="color: #f9a825;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">update</span>Configure Password Expiration</strong><br>' ||
    '<div style="margin-top: 8px;">Profiles with long/unlimited password lifetime: <code>' || 
    (SELECT LISTAGG(PROFILE || ' (' || LIMIT || ')', ', ') WITHIN GROUP (ORDER BY PROFILE)
     FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_LIFE_TIME' 
     AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 180))
     AND ROWNUM <= 5) || '</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #f39c12;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Set: <code>ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME 90;</code><br>' ||
    '2. Set: <code>ALTER PROFILE DEFAULT LIMIT PASSWORD_GRACE_TIME 5;</code><br>' ||
    '3. Implement password change notification process</div></li>'
  ELSE '' END ||
  -- Session limits check
  CASE WHEN EXISTS (SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='SESSIONS_PER_USER' 
    AND (LIMIT = 'UNLIMITED' OR LIMIT = 'DEFAULT')) THEN
    '<li style="background-color: #fff9c4; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #f9a825;">' ||
    '<strong style="color: #f9a825;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">timer</span>Configure Session and Resource Limits</strong><br>' ||
    '<div style="margin-top: 8px;">Profiles without session limits: <code>' || 
    (SELECT COUNT(DISTINCT PROFILE) FROM DBA_PROFILES WHERE RESOURCE_NAME='SESSIONS_PER_USER' 
     AND (LIMIT = 'UNLIMITED' OR LIMIT = 'DEFAULT')) || ' profiles</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #f39c12;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Set: <code>ALTER PROFILE DEFAULT LIMIT SESSIONS_PER_USER 5;</code><br>' ||
    '2. Set: <code>ALTER PROFILE DEFAULT LIMIT IDLE_TIME 30;</code><br>' ||
    '3. Configure limits based on user roles and requirements</div></li>'
  ELSE '' END ||
  -- Remote listener check
  CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_LISTENER' AND VALUE IS NOT NULL) THEN
    '<li style="background-color: #fff9c4; padding: 10px; margin: 5px 0; border-radius: 4px; border-left: 4px solid #f9a825;">' ||
    '<strong style="color: #f9a825;"><span class="material-icons" style="font-size: 16px; vertical-align: middle;">router</span>Review Remote Listener Configuration</strong><br>' ||
    '<div style="margin-top: 8px;">Remote listener configured: <code>' || 
    (SELECT VALUE FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_LISTENER') || '</code></div>' ||
    '<div style="background-color: white; padding: 8px; margin-top: 8px; border-left: 3px solid #f39c12;">' ||
    '<strong>Remediation Steps:</strong><br>' ||
    '1. Review necessity of remote listener<br>' ||
    '2. If not needed: <code>ALTER SYSTEM SET REMOTE_LISTENER='''' SCOPE=BOTH;</code><br>' ||
    '3. If needed, ensure secure configuration with SSL/TLS</div></li>'
  ELSE '' END ||
  '</ol>' ||
  -- If no medium priority issues found
  CASE WHEN NOT EXISTS (
    SELECT 1 FROM (
      SELECT 1 FROM DBA_STMT_AUDIT_OPTS WHERE AUDIT_OPTION IN ('CREATE SESSION','SYSTEM GRANT') AND SUCCESS = 'BY ACCESS'
      UNION ALL
      SELECT 1 FROM ALL_USERS WHERE USERNAME IN ('BI','HR','IX','OE','PM','SCOTT','SH')
      UNION ALL
      SELECT 1 FROM DBA_USERS WHERE PROFILE='DEFAULT' AND ACCOUNT_STATUS='OPEN' 
        AND USERNAME NOT IN ('SYS','SYSTEM','DBSNMP','XDB','ANONYMOUS')
      UNION ALL
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='PASSWORD_LIFE_TIME' 
        AND (LIMIT = 'UNLIMITED' OR (REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 180))
      UNION ALL
      SELECT 1 FROM DBA_PROFILES WHERE RESOURCE_NAME='SESSIONS_PER_USER' AND (LIMIT = 'UNLIMITED' OR LIMIT = 'DEFAULT')
      UNION ALL
      SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'REMOTE_LISTENER' AND VALUE IS NOT NULL
    ) WHERE ROWNUM = 1
  ) THEN 
    '<p style="color: #f39c12; padding: 10px; background-color: #fff8e1; border-radius: 4px;">' ||
    '<span class="material-icons" style="vertical-align: middle;">check_circle</span> ' ||
    'No medium priority security issues were found.</p>'
  ELSE '' END
FROM DUAL;

PROMPT <h4 style="color: #17a2b8;"><span class="material-icons" style="color: #17a2b8;">info</span>ONGOING SECURITY PRACTICES</h4>
PROMPT <ul style="margin-bottom: 20px;">
PROMPT <li><strong>Regular Security Assessments</strong> - Run this CIS audit monthly</li>
PROMPT <li><strong>Patch Management</strong> - Apply Oracle Critical Patch Updates quarterly</li>
PROMPT <li><strong>Monitoring & Alerting</strong> - Set up automated alerts for security events</li>
PROMPT <li><strong>Backup Security</strong> - Encrypt backups and secure backup credentials</li>
PROMPT <li><strong>Documentation</strong> - Maintain security configuration baselines</li>
PROMPT <li><strong>Training</strong> - Regular security awareness for database administrators</li>
PROMPT </ul>

PROMPT <div style="background-color: #fff3cd; padding: 10px; border-left: 4px solid #ffc107; margin: 15px 0;">
PROMPT <strong><span class="material-icons" style="color: #ffc107;">info</span>Important Notes:</strong><br>
PROMPT • Always test changes in development environment first<br>
PROMPT • Some parameter changes require database restart<br>
PROMPT • Document all changes for compliance and rollback purposes<br>
PROMPT • Consider impact on applications before revoking privileges
PROMPT </div>

PROMPT </div>

-- Footer
PROMPT <div style="margin-top: 30px; padding-top: 20px; border-top: 2px solid #dee2e6; font-size: 12px; color: #6c757d;">
SELECT '<p><strong>Report Generated:</strong> ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || 
       ' | <strong>Database:</strong> ' || SYS_CONTEXT('USERENV', 'DB_NAME') ||
       ' | <strong>Instance:</strong> ' || SYS_CONTEXT('USERENV', 'INSTANCE_NAME') || '</p>' FROM DUAL;
-- Dynamic disclaimer based on version
SELECT '<p><strong>Disclaimer:</strong> This report is based on ' ||
  CASE 
    WHEN version LIKE '19.%' THEN 'CIS Oracle Database 19c Benchmark v1.0.0'
    WHEN version LIKE '18.%' THEN 'CIS Oracle Database 18c Benchmark v1.0.0'
    WHEN version LIKE '12.%' THEN 'CIS Oracle Database 12c Benchmark v2.0.0'
    WHEN version LIKE '11.2%' THEN 'CIS Oracle Database 11g R2 Benchmark v2.2.0'
    ELSE 'CIS Oracle Database Benchmark'
  END ||
  '. Some checks require manual verification of configuration files or additional privileges. Please review all findings and implement appropriate remediation steps based on your environment and security requirements.</p>'
FROM v$instance;
PROMPT <p><strong>Note:</strong> This audit tool checks a subset of the complete CIS benchmark. For comprehensive security assessment, consider using commercial database security tools or consulting with Oracle security specialists.</p>
PROMPT </div>

PROMPT </div>
PROMPT </body>
PROMPT </html>

SPOOL OFF
SET TERMOUT ON
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 24
SET LINESIZE 80

PROMPT
PROMPT ============================================================
PROMPT          CIS Oracle Database Audit Report Generated
PROMPT ============================================================
PROMPT Output file: CIS_&hostname._&instance_name..html
PROMPT
PROMPT Report includes comprehensive checks for:
PROMPT - Database installation and patching
PROMPT - Oracle parameter settings  
PROMPT - Connection and login restrictions
PROMPT - User access and authorization restrictions
PROMPT - Audit and logging policies
PROMPT
PROMPT Open the HTML file in a web browser to view the results.
PROMPT ============================================================

-- Display brief summary on screen
SELECT 'Audit completed at: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') AS "SUMMARY" FROM DUAL;
