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
SET SERVEROUTPUT ON

-- ============================================================================
-- PRIVILEGE VERIFICATION SECTION
-- Verify the current user has necessary privileges before starting the audit
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT                      CIS Oracle Database Audit Tool
PROMPT                        Privilege Verification
PROMPT ============================================================================
PROMPT

-- Check current user and basic connection
SELECT 'Current User: ' || USER || ' | Database: ' || SYS_CONTEXT('USERENV', 'DB_NAME') || 
       ' | Connected At: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') AS "CONNECTION INFO" FROM DUAL;

PROMPT
PROMPT Checking required privileges...
PROMPT

-- Privilege verification using PL/SQL block
DECLARE
    v_error_count NUMBER := 0;
    v_warning_count NUMBER := 0;
    v_test_count NUMBER;
    v_version VARCHAR2(100);
    v_cdb VARCHAR2(10) := 'NO';
    v_user VARCHAR2(128);
    TYPE privilege_test_rec IS RECORD (
        test_name VARCHAR2(50),
        sql_text VARCHAR2(4000),
        is_critical BOOLEAN,
        version_specific VARCHAR2(10) -- NULL, '12c+', '11g', etc.
    );
    TYPE privilege_test_tab IS TABLE OF privilege_test_rec;
    
    privilege_tests privilege_test_tab := privilege_test_tab(
        -- Critical system views
        privilege_test_rec('V$PARAMETER', 'SELECT COUNT(*) FROM V$PARAMETER WHERE ROWNUM <= 1', TRUE, NULL),
        privilege_test_rec('V$INSTANCE', 'SELECT COUNT(*) FROM V$INSTANCE WHERE ROWNUM <= 1', TRUE, NULL),
        privilege_test_rec('V$DATABASE', 'SELECT COUNT(*) FROM V$DATABASE WHERE ROWNUM <= 1', TRUE, NULL),
        
        -- Critical DBA views
        privilege_test_rec('DBA_USERS', 'SELECT COUNT(*) FROM DBA_USERS WHERE ROWNUM <= 1', TRUE, NULL),
        privilege_test_rec('DBA_TAB_PRIVS', 'SELECT COUNT(*) FROM DBA_TAB_PRIVS WHERE ROWNUM <= 1', TRUE, NULL),
        privilege_test_rec('DBA_SYS_PRIVS', 'SELECT COUNT(*) FROM DBA_SYS_PRIVS WHERE ROWNUM <= 1', TRUE, NULL),
        privilege_test_rec('DBA_ROLE_PRIVS', 'SELECT COUNT(*) FROM DBA_ROLE_PRIVS WHERE ROWNUM <= 1', TRUE, NULL),
        privilege_test_rec('DBA_PROFILES', 'SELECT COUNT(*) FROM DBA_PROFILES WHERE ROWNUM <= 1', TRUE, NULL),
        
        -- Audit-related views
        privilege_test_rec('DBA_STMT_AUDIT_OPTS', 'SELECT COUNT(*) FROM DBA_STMT_AUDIT_OPTS WHERE ROWNUM <= 1', TRUE, NULL),
        privilege_test_rec('DBA_PRIV_AUDIT_OPTS', 'SELECT COUNT(*) FROM DBA_PRIV_AUDIT_OPTS WHERE ROWNUM <= 1', TRUE, NULL),
        privilege_test_rec('DBA_OBJ_AUDIT_OPTS', 'SELECT COUNT(*) FROM DBA_OBJ_AUDIT_OPTS WHERE ROWNUM <= 1', TRUE, NULL),
        
        -- Security-specific views
        privilege_test_rec('DBA_USERS_WITH_DEFPWD', 'SELECT COUNT(*) FROM DBA_USERS_WITH_DEFPWD WHERE ROWNUM <= 1', TRUE, NULL),
        privilege_test_rec('DBA_DB_LINKS', 'SELECT COUNT(*) FROM DBA_DB_LINKS WHERE ROWNUM <= 1', FALSE, NULL),
        privilege_test_rec('DBA_PROXIES', 'SELECT COUNT(*) FROM DBA_PROXIES WHERE ROWNUM <= 1', FALSE, NULL),
        privilege_test_rec('DBA_ROLES', 'SELECT COUNT(*) FROM DBA_ROLES WHERE ROWNUM <= 1', FALSE, NULL),
        
        -- Version-specific views
        privilege_test_rec('V$PDBS', 'SELECT COUNT(*) FROM V$PDBS WHERE ROWNUM <= 1', FALSE, '12c+'),
        privilege_test_rec('AUDIT_UNIFIED_ENABLED_POLICIES', 'SELECT COUNT(*) FROM AUDIT_UNIFIED_ENABLED_POLICIES WHERE ROWNUM <= 1', FALSE, '12c+'),
        privilege_test_rec('DBA_AUDIT_POLICIES', 'SELECT COUNT(*) FROM DBA_AUDIT_POLICIES WHERE ROWNUM <= 1', FALSE, '12c+')
    );
    
BEGIN
    -- Get version and user info
    SELECT version INTO v_version FROM v$instance;
    SELECT USER INTO v_user FROM DUAL;
    
    -- Check if CDB
    BEGIN
        IF v_version LIKE '12.%' OR v_version LIKE '18.%' OR v_version LIKE '19.%' THEN
            SELECT CDB INTO v_cdb FROM V$DATABASE WHERE ROWNUM = 1;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            v_cdb := 'UNKNOWN';
    END;
    
    DBMS_OUTPUT.PUT_LINE('Database Version: ' || v_version);
    DBMS_OUTPUT.PUT_LINE('Multitenant (CDB): ' || v_cdb);
    DBMS_OUTPUT.PUT_LINE('Running as User: ' || v_user);
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Testing required privileges:');
    DBMS_OUTPUT.PUT_LINE('-----------------------------');
    
    -- Test each privilege
    FOR i IN 1..privilege_tests.COUNT LOOP
        -- Skip version-specific tests if not applicable
        IF privilege_tests(i).version_specific IS NOT NULL THEN
            IF privilege_tests(i).version_specific = '12c+' AND 
               NOT (v_version LIKE '12.%' OR v_version LIKE '18.%' OR v_version LIKE '19.%') THEN
                CONTINUE;
            END IF;
        END IF;
        
        BEGIN
            EXECUTE IMMEDIATE privilege_tests(i).sql_text INTO v_test_count;
            DBMS_OUTPUT.PUT_LINE('[PASS] ' || RPAD(privilege_tests(i).test_name, 30) || ' - Access granted');
        EXCEPTION
            WHEN OTHERS THEN
                IF privilege_tests(i).is_critical THEN
                    DBMS_OUTPUT.PUT_LINE('[FAIL] ' || RPAD(privilege_tests(i).test_name, 30) || ' - ' || SQLERRM);
                    v_error_count := v_error_count + 1;
                ELSE
                    DBMS_OUTPUT.PUT_LINE('[WARN] ' || RPAD(privilege_tests(i).test_name, 30) || ' - ' || SQLERRM);
                    v_warning_count := v_warning_count + 1;
                END IF;
        END;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Privilege Check Summary:');
    DBMS_OUTPUT.PUT_LINE('------------------------');
    DBMS_OUTPUT.PUT_LINE('Critical Failures: ' || v_error_count);
    DBMS_OUTPUT.PUT_LINE('Warnings: ' || v_warning_count);
    
    -- Provide recommendations based on results
    IF v_error_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('CRITICAL: Cannot proceed with audit due to missing privileges!');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('REQUIRED ACTIONS:');
        DBMS_OUTPUT.PUT_LINE('================');
        
        IF v_cdb = 'YES' THEN
            DBMS_OUTPUT.PUT_LINE('For MULTITENANT database, connect as SYS/SYSTEM and run:');
            DBMS_OUTPUT.PUT_LINE('CREATE ROLE C##CISSCANROLE CONTAINER=ALL;');
            DBMS_OUTPUT.PUT_LINE('GRANT CREATE SESSION TO C##CISSCANROLE CONTAINER=ALL;');
            DBMS_OUTPUT.PUT_LINE('GRANT SELECT ON V_$PARAMETER TO C##CISSCANROLE CONTAINER=ALL;');
            DBMS_OUTPUT.PUT_LINE('GRANT SELECT ON CDB_USERS TO C##CISSCANROLE CONTAINER=ALL;');
            DBMS_OUTPUT.PUT_LINE('GRANT SELECT ON CDB_TAB_PRIVS TO C##CISSCANROLE CONTAINER=ALL;');
            DBMS_OUTPUT.PUT_LINE('-- (See README.md for complete multitenant setup)');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('CREATE USER C##CISSCAN IDENTIFIED BY <password> CONTAINER=ALL;');
            DBMS_OUTPUT.PUT_LINE('GRANT C##CISSCANROLE TO C##CISSCAN CONTAINER=ALL;');
        ELSE
            DBMS_OUTPUT.PUT_LINE('For NON-MULTITENANT database, connect as SYS/SYSTEM and run:');
            DBMS_OUTPUT.PUT_LINE('CREATE ROLE CISSCANROLE;');
            DBMS_OUTPUT.PUT_LINE('GRANT CREATE SESSION TO CISSCANROLE;');
            DBMS_OUTPUT.PUT_LINE('GRANT SELECT ON V_$PARAMETER TO CISSCANROLE;');
            DBMS_OUTPUT.PUT_LINE('GRANT SELECT ON DBA_USERS TO CISSCANROLE;');
            DBMS_OUTPUT.PUT_LINE('GRANT SELECT ON DBA_TAB_PRIVS TO CISSCANROLE;');
            DBMS_OUTPUT.PUT_LINE('-- (See README.md for complete non-multitenant setup)');
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('CREATE USER CISSCAN IDENTIFIED BY <password>;');
            DBMS_OUTPUT.PUT_LINE('GRANT CISSCANROLE TO CISSCAN;');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('ALTERNATIVE: Grant DBA role (broader privileges):');
        IF v_cdb = 'YES' THEN
            DBMS_OUTPUT.PUT_LINE('GRANT C##DBA TO C##CISSCAN CONTAINER=ALL;');
        ELSE
            DBMS_OUTPUT.PUT_LINE('GRANT DBA TO CISSCAN;');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('AUDIT STOPPED - Please fix privileges and re-run');
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        
        -- Exit the script
        RAISE_APPLICATION_ERROR(-20001, 'Insufficient privileges for CIS audit');
        
    ELSIF v_warning_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('WARNINGS: Some optional features may not be available.');
        DBMS_OUTPUT.PUT_LINE('The audit will continue but some checks may be skipped.');
        DBMS_OUTPUT.PUT_LINE('For complete coverage, see README.md for full privilege setup.');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Continuing with audit...');
        
    ELSE
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('SUCCESS: All required privileges verified!');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Starting CIS Oracle Database Security Audit...');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('============================================================================');
END;
/

-- Continue only if no critical errors (the RAISE_APPLICATION_ERROR above will stop execution if needed)
PROMPT

-- Version Detection Variables (must be defined before query)
COLUMN db_version NEW_VALUE db_version NOPRINT
COLUMN version_num NEW_VALUE version_num NOPRINT
COLUMN version_display NEW_VALUE version_display NOPRINT
COLUMN is_11g NEW_VALUE is_11g NOPRINT
COLUMN is_12c NEW_VALUE is_12c NOPRINT
COLUMN is_18c NEW_VALUE is_18c NOPRINT
COLUMN is_19c NEW_VALUE is_19c NOPRINT
COLUMN is_multitenant NEW_VALUE is_multitenant NOPRINT
COLUMN cis_version NEW_VALUE cis_version NOPRINT

-- Detect Oracle Version and Container Context (must run with TERMOUT ON to set variables)
COLUMN current_container NEW_VALUE current_container NOPRINT
COLUMN container_name NEW_VALUE container_name NOPRINT
COLUMN is_cdb_root NEW_VALUE is_cdb_root NOPRINT
COLUMN is_pdb NEW_VALUE is_pdb NOPRINT

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
    WHEN version LIKE '19.%' THEN 'CIS Oracle Database 19c Benchmark v1.2.0'
    WHEN version LIKE '18.%' THEN 'CIS Oracle Database 18c Benchmark v1.1.0'
    WHEN version LIKE '12.%' THEN 'CIS Oracle Database 12c Benchmark v3.0.0'
    WHEN version LIKE '11.2%' THEN 'CIS Oracle Database 11g R2 Benchmark v2.2.0'
    ELSE 'CIS Oracle Database Benchmark'
  END AS cis_version,
  -- Container context detection
  CASE 
    WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
      CASE WHEN (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' THEN
        SYS_CONTEXT('USERENV', 'CON_NAME')
      ELSE 'NON_CDB'
      END
    ELSE 'SINGLE_TENANT'
  END AS current_container,
  CASE 
    WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
      CASE WHEN (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' THEN
        SYS_CONTEXT('USERENV', 'CON_NAME')
      ELSE 'Non-CDB'
      END
    ELSE 'Single-tenant'
  END AS container_name,
  CASE 
    WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
      CASE WHEN (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' THEN
        CASE WHEN SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT' THEN 'YES' ELSE 'NO' END
      ELSE 'NO'
      END
    ELSE 'NO'
  END AS is_cdb_root,
  CASE 
    WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
      CASE WHEN (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' THEN
        CASE WHEN SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT' THEN 'YES' ELSE 'NO' END
      ELSE 'NO'
      END
    ELSE 'NO'
  END AS is_pdb
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
SELECT '<p><strong>Host:</strong> ' || SYS_CONTEXT('USERENV', 'SERVER_HOST') || '</p>' FROM DUAL;
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

-- Add multitenant info for 12c+ with CIS benchmark context
SELECT CASE 
  WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
    '<p><strong>Container Database (CDB):</strong> ' || 
    NVL((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1), 'NO') || '</p>' ||
    CASE WHEN (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' THEN
      '<p><strong>Current Container:</strong> ' || SYS_CONTEXT('USERENV', 'CON_NAME') || '</p>' ||
      '<p><strong>CIS Assessment Level:</strong> ' ||
      CASE WHEN SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT' 
        THEN 'CDB Root Container (System-level controls)'
        ELSE 'PDB Container (Database-level controls)'
      END || '</p>' ||
      '<p><strong>Assessment Scope:</strong> ' ||
      CASE WHEN SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT' 
        THEN 'This report covers CDB-level controls. Run separately in each PDB for complete assessment.'
        ELSE 'This report covers PDB-level controls. Run from CDB$ROOT for CDB-level controls.'
      END || '</p>'
    ELSE '<p><strong>Assessment Scope:</strong> Non-CDB database (all controls apply directly)</p>' END
  ELSE '<p><strong>Assessment Scope:</strong> Single-tenant database (all controls apply directly)</p>' 
END FROM v$instance;

-- List detected PDBs (only when running in a multitenant CDB environment)
SELECT '<h4>Detected Pluggable Databases</h4>' ||
       '<table>' ||
       '<tr><th width="8%">CON_ID</th><th width="30%">Name</th><th width="20%">Open Mode</th><th width="12%">Restricted</th></tr>'
FROM DUAL
WHERE (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES';

SELECT '<tr><td>' || TO_CHAR(CON_ID) || '</td>' ||
       '<td>' || NAME || '</td>' ||
       '<td>' || OPEN_MODE || '</td>' ||
       '<td>' || RESTRICTED || '</td>' ||
       '</tr>'
FROM V$PDBS
WHERE (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES'
ORDER BY CON_ID;

SELECT '</table>' FROM DUAL
WHERE (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES';

PROMPT </div>

-- Table of Contents
PROMPT <div class="toc">
PROMPT <h3>Table of Contents</h3>
PROMPT <ul>
PROMPT <li><a href="#section1">1. Oracle Database Installation and Patching Requirements</a></li>
PROMPT <li><a href="#section2">2. Oracle Parameter Settings</a>
PROMPT   <ul>
PROMPT     <li><a href="#section2_1">2.1 Listener Settings</a></li>
PROMPT     <li><a href="#section2_2">2.2 Database Settings</a></li>
PROMPT     <li><a href="#section2_3">2.3 SQLNET.ORA Settings (18c+)</a></li>
PROMPT   </ul>
PROMPT </li>
PROMPT <li><a href="#section3">3. Oracle Connection and Login Restrictions</a></li>
PROMPT <li><a href="#section4">4. Oracle User Access and Authorization Restrictions</a>
PROMPT   <ul>
PROMPT     <li><a href="#section4_0">4.0 Database User Account Status (Informational)</a></li>
PROMPT     <li><a href="#section4_1">4.1 Default Public Privileges for Packages and Object Types</a></li>
PROMPT     <li><a href="#section4_2">4.2 Revoke Non-Default Privileges for Packages and Object Types</a></li>
PROMPT     <li><a href="#section4_3">4.3 Revoke Excessive System Privileges</a></li>
PROMPT     <li><a href="#section4_4">4.4 Revoke Role Privileges</a></li>
PROMPT     <li><a href="#section4_5">4.5 Revoke Excessive Table and View Privileges</a></li>
PROMPT     <li><a href="#section4_6">4.6-4.10 Additional Security Checks</a></li>
PROMPT   </ul>
PROMPT </li>
PROMPT <li><a href="#section5">5. Audit/Logging Policies and Procedures</a>
PROMPT   <ul>
PROMPT     <li><a href="#section5_38">5.38 Unified Auditing (12c+)</a></li>
PROMPT   </ul>
PROMPT </li>
PROMPT <li><a href="#summary">Executive Summary</a></li>
PROMPT </ul>
PROMPT <div id="exec-summary" style="margin: 30px 0;">
PROMPT <h2 id="summary" style="color: #1565c0; margin-bottom: 15px;">Executive Summary</h2>
SELECT '<div style="background-color: #e3f2fd; padding: 16px; border-radius: 8px; border-left: 5px solid #2196f3; margin-bottom: 20px;">' ||
       '<h3 style="margin-top: 0; color: #1565c0; display: flex; align-items: center; font-size: 18px;"><span class="material-icons" style="margin-right: 8px;">assessment</span>Audit Overview</h3>' ||
       '<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; font-size: 13px; color: #2c3e50;">' ||
       '<div><strong>Audit Date:</strong> ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || '</div>' ||
       '<div><strong>Database:</strong> ' || SYS_CONTEXT('USERENV', 'DB_NAME') || '</div>' ||
       '<div><strong>Instance:</strong> ' || SYS_CONTEXT('USERENV', 'INSTANCE_NAME') || '</div>' ||
       '<div><strong>Host:</strong> ' || SYS_CONTEXT('USERENV', 'SERVER_HOST') || '</div>' ||
       '<div><strong>Oracle Version:</strong> ' || version || '</div>' ||
       '<div><strong>Container Context:</strong> ' ||
         CASE WHEN (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES'
              THEN SYS_CONTEXT('USERENV', 'CON_NAME') || ' (CDB environment)'
              ELSE 'Non-CDB'
         END || '</div>' ||
       '</div></div>'
FROM v$instance;

WITH
  default_pw AS (
    SELECT COUNT(*) cnt FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%'
  ),
  sample_accounts AS (
    SELECT COUNT(*) cnt FROM DBA_USERS
    WHERE USERNAME IN ('BI','HR','IX','OE','PM','SCOTT','SH','DEMO','SAMPLE','TEST','GUEST','OUTLN')
      AND ACCOUNT_STATUS NOT LIKE 'LOCKED%'
      AND ACCOUNT_STATUS NOT LIKE 'EXPIRED%'
  ),
  param_issues AS (
    SELECT COUNT(*) cnt FROM V$PARAMETER
    WHERE (UPPER(NAME) = 'AUDIT_SYS_OPERATIONS' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'AUDIT_TRAIL' AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED'))
       OR (UPPER(NAME) = 'GLOBAL_NAMES' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'LOCAL_LISTENER' AND (VALUE IS NULL OR UPPER(VALUE) NOT LIKE '%IPC%'))
       OR (UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY' AND UPPER(VALUE) != 'FALSE' AND VALUE IS NOT NULL)
       OR (UPPER(NAME) = 'OS_ROLES' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'REMOTE_LISTENER' AND VALUE IS NOT NULL AND LENGTH(TRIM(VALUE)) > 0)
       OR (UPPER(NAME) = 'REMOTE_LOGIN_PASSWORDFILE' AND UPPER(VALUE) != 'NONE')
       OR (UPPER(NAME) = 'REMOTE_OS_AUTHENT' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'REMOTE_OS_ROLES' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'UTL_FILE_DIR' AND VALUE IS NOT NULL AND LENGTH(TRIM(VALUE)) > 0)
       OR (UPPER(NAME) = 'SEC_CASE_SENSITIVE_LOGON' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'SEC_MAX_FAILED_LOGIN_ATTEMPTS' AND NVL(VALUE,'0') NOT IN ('3','3.0'))
       OR (UPPER(NAME) = 'SEC_PROTOCOL_ERROR_FURTHER_ACTION' AND UPPER(VALUE) NOT LIKE '%DELAY%3%' AND UPPER(VALUE) NOT LIKE '%DROP%3%')
       OR (UPPER(NAME) = 'SEC_PROTOCOL_ERROR_TRACE_ACTION' AND UPPER(VALUE) != 'LOG')
       OR (UPPER(NAME) = 'SEC_RETURN_SERVER_RELEASE_BANNER' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'SQL92_SECURITY' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = '_TRACE_FILES_PUBLIC' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'RESOURCE_LIMIT' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'COMMON_USER_PREFIX' AND UPPER(VALUE) != 'C##')
       OR (UPPER(NAME) = 'ENABLE_DDL_LOGGING' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'LDAP_DIRECTORY_SYSAUTH' AND UPPER(VALUE) != 'NO')
       OR (UPPER(NAME) = 'ALLOW_GROUP_ACCESS_TO_SGA' AND UPPER(VALUE) != 'FALSE')
  ),
  profile_raw AS (
    SELECT PROFILE, RESOURCE_NAME FROM DBA_PROFILES
    WHERE RESOURCE_NAME IN ('FAILED_LOGIN_ATTEMPTS','PASSWORD_LOCK_TIME','PASSWORD_LIFE_TIME','PASSWORD_REUSE_MAX',
                            'PASSWORD_REUSE_TIME','PASSWORD_GRACE_TIME','SESSIONS_PER_USER','IDLE_TIME','INACTIVE_ACCOUNT_TIME')
      AND (
        LIMIT = 'UNLIMITED'
        OR LIMIT = 'DEFAULT'
        OR (RESOURCE_NAME = 'FAILED_LOGIN_ATTEMPTS' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 5)
        OR (RESOURCE_NAME = 'PASSWORD_LOCK_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9.]+$') AND TO_NUMBER(LIMIT) < 1)
        OR (RESOURCE_NAME = 'PASSWORD_LIFE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 90)
        OR (RESOURCE_NAME = 'PASSWORD_REUSE_MAX' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) < 20)
        OR (RESOURCE_NAME = 'PASSWORD_REUSE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) < 365)
        OR (RESOURCE_NAME = 'PASSWORD_GRACE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 5)
        OR (RESOURCE_NAME = 'SESSIONS_PER_USER' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 10)
        OR (RESOURCE_NAME = 'IDLE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 30)
        OR (RESOURCE_NAME = 'INACTIVE_ACCOUNT_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 120)
      )
  ),
  profile_issues AS (
    SELECT COUNT(*) cnt FROM profile_raw
  ),
  public_exec AS (
    SELECT COUNT(DISTINCT TABLE_NAME) cnt
    FROM DBA_TAB_PRIVS
    WHERE GRANTEE='PUBLIC'
      AND PRIVILEGE='EXECUTE'
      AND TABLE_NAME IN (
        'DBMS_LDAP','UTL_TCP','UTL_SMTP','UTL_HTTP','UTL_INADDR','UTL_URL','HTTPURITYPE','DBMS_NETWORK_ACL_ADMIN',
        'UTL_FILE','DBMS_LOB','DBMS_ADVISOR','DBMS_FILE_TRANSFER','DBMS_CRYPTO','DBMS_OBFUSCATION_TOOLKIT','DBMS_RANDOM',
        'DBMS_JAVA','DBMS_JAVA_TEST','DBMS_SCHEDULER','DBMS_JOB','DBMS_SQL','DBMS_XMLGEN','DBMS_XMLQUERY','DBMS_XMLSTORE',
        'DBMS_XMLSAVE','DBMS_AW','OWA_UTIL','DBMS_REDACT','DBMS_CREDENTIAL','DBMS_BACKUP_RESTORE','DBMS_STREAMS_RPC',
        'DBMS_AQADM_SYSCALLS','DBMS_REPCAT_SQL_UTL','INITJVMAUX','DBMS_STREAMS_ADM_UTL','DBMS_AQADM_SYS','DBMS_PRVTAQIM',
        'LTADM','WWV_DBMS_SQL','WWV_EXECUTE_IMMEDIATE','DBMS_IJOB'
      )
  ),
  any_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT sp.GRANTEE, sp.PRIVILEGE
      FROM DBA_SYS_PRIVS sp
      LEFT JOIN DBA_USERS u ON u.USERNAME = sp.GRANTEE
      LEFT JOIN DBA_ROLES r ON r.ROLE = sp.GRANTEE
      WHERE sp.PRIVILEGE LIKE '%ANY%'
        AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
        AND sp.GRANTEE NOT LIKE 'C##%'
    )
  ),
  system_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT sp.GRANTEE, sp.PRIVILEGE
      FROM DBA_SYS_PRIVS sp
      LEFT JOIN DBA_USERS u ON u.USERNAME = sp.GRANTEE
      LEFT JOIN DBA_ROLES r ON r.ROLE = sp.GRANTEE
      WHERE sp.PRIVILEGE IN ('ALTER SYSTEM','DROP ANY TABLE','CREATE ANY PROCEDURE','ALTER ANY PROCEDURE','DROP ANY PROCEDURE',
                             'CREATE ANY TRIGGER','ALTER ANY TRIGGER','DROP ANY TRIGGER','BECOME USER')
        AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
        AND sp.GRANTEE NOT LIKE 'C##%'
    )
  ),
  role_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT rp.GRANTEE, rp.GRANTED_ROLE
      FROM DBA_ROLE_PRIVS rp
      LEFT JOIN DBA_USERS u ON u.USERNAME = rp.GRANTEE
      LEFT JOIN DBA_ROLES gr ON gr.ROLE = rp.GRANTEE
      LEFT JOIN DBA_ROLES granted ON granted.ROLE = rp.GRANTED_ROLE
      WHERE NVL(u.ORACLE_MAINTAINED, NVL(gr.ORACLE_MAINTAINED, 'N')) = 'N'
        AND NVL(granted.ORACLE_MAINTAINED, 'N') = 'N'
        AND rp.GRANTEE NOT LIKE 'C##%'
        AND rp.GRANTED_ROLE IN ('DBA','SYSDBA','SYSOPER','EXP_FULL_DATABASE','IMP_FULL_DATABASE',
                                'DELETE_CATALOG_ROLE','EXECUTE_CATALOG_ROLE','SELECT_CATALOG_ROLE')
    )
  ),
  table_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT tp.GRANTEE, tp.TABLE_NAME
      FROM DBA_TAB_PRIVS tp
      LEFT JOIN DBA_USERS u ON u.USERNAME = tp.GRANTEE
      LEFT JOIN DBA_ROLES r ON r.ROLE = tp.GRANTEE
      WHERE tp.OWNER = 'SYS'
        AND tp.TABLE_NAME IN ('USER$','LINK$','USER_HISTORY$','PROXY_DATA$','UNDO$','USER$MIG')
        AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
        AND tp.GRANTEE NOT LIKE 'C##%'
    )
  ),
  exempt_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT sp.GRANTEE
      FROM DBA_SYS_PRIVS sp
      LEFT JOIN DBA_USERS u ON u.USERNAME = sp.GRANTEE
      LEFT JOIN DBA_ROLES r ON r.ROLE = sp.GRANTEE
      WHERE sp.PRIVILEGE = 'EXEMPT ACCESS POLICY'
        AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
    )
  ),
  audit_stmt_missing AS (
    SELECT COUNT(*) cnt
    FROM (
      SELECT 'CREATE SESSION' opt FROM DUAL UNION ALL
      SELECT 'SYSTEM GRANT' FROM DUAL UNION ALL
      SELECT 'USER' FROM DUAL UNION ALL
      SELECT 'ALTER USER' FROM DUAL UNION ALL
      SELECT 'DROP USER' FROM DUAL UNION ALL
      SELECT 'PROFILE' FROM DUAL UNION ALL
      SELECT 'ALTER PROFILE' FROM DUAL UNION ALL
      SELECT 'DROP PROFILE' FROM DUAL UNION ALL
      SELECT 'DATABASE LINK' FROM DUAL UNION ALL
      SELECT 'PUBLIC DATABASE LINK' FROM DUAL UNION ALL
      SELECT 'PUBLIC SYNONYM' FROM DUAL UNION ALL
      SELECT 'SYNONYM' FROM DUAL UNION ALL
      SELECT 'GRANT DIRECTORY' FROM DUAL UNION ALL
      SELECT 'SELECT ANY DICTIONARY' FROM DUAL
    ) expected
    LEFT JOIN (
      SELECT DISTINCT AUDIT_OPTION FROM DBA_STMT_AUDIT_OPTS WHERE SUCCESS = 'BY ACCESS'
    ) actual ON expected.opt = actual.AUDIT_OPTION
    WHERE actual.AUDIT_OPTION IS NULL
  ),
  audit_priv_missing AS (
    SELECT COUNT(*) cnt
    FROM (
      SELECT 'GRANT ANY PRIVILEGE' opt FROM DUAL UNION ALL
      SELECT 'GRANT ANY OBJECT PRIVILEGE' FROM DUAL
    ) expected
    LEFT JOIN (
      SELECT DISTINCT PRIVILEGE FROM DBA_PRIV_AUDIT_OPTS WHERE SUCCESS = 'BY ACCESS'
    ) actual ON expected.opt = actual.PRIVILEGE
    WHERE actual.PRIVILEGE IS NULL
  ),
  audit_param_gaps AS (
    SELECT (CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_TRAIL' AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED')) THEN 1 ELSE 0 END +
            CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_SYS_OPERATIONS' AND UPPER(VALUE) != 'TRUE') THEN 1 ELSE 0 END) cnt
    FROM DUAL
  ),
  metrics AS (
    SELECT dp.cnt AS default_pw_cnt,
           sa.cnt AS sample_account_cnt,
           pi.cnt AS param_issue_cnt,
           pr.cnt AS profile_issue_cnt,
           pe.cnt AS public_exec_cnt,
           ap.cnt AS any_priv_cnt,
           sp.cnt AS system_priv_cnt,
           rp.cnt AS role_priv_cnt,
           tp.cnt AS table_priv_cnt,
           ep.cnt AS exempt_priv_cnt,
           asm.cnt AS audit_stmt_gap_cnt,
           apr.cnt AS audit_priv_gap_cnt,
           apar.cnt AS audit_param_gap_cnt,
           (dp.cnt + sa.cnt) AS install_issues,
           pi.cnt AS config_issues,
           pr.cnt AS auth_issues,
           (pe.cnt + ap.cnt + sp.cnt + rp.cnt + tp.cnt + ep.cnt) AS privilege_issues,
           (asm.cnt + apr.cnt + apar.cnt) AS audit_issues,
           (dp.cnt + sa.cnt + pi.cnt + pr.cnt + pe.cnt + ap.cnt + sp.cnt + rp.cnt + tp.cnt + ep.cnt + asm.cnt + apr.cnt + apar.cnt) AS total_findings,
           (dp.cnt + pr.cnt) AS credential_findings,
           (ap.cnt + sp.cnt + rp.cnt + ep.cnt) AS privileged_identity_findings
    FROM default_pw dp
    CROSS JOIN sample_accounts sa
    CROSS JOIN param_issues pi
    CROSS JOIN profile_issues pr
    CROSS JOIN public_exec pe
    CROSS JOIN any_priv ap
    CROSS JOIN system_priv sp
    CROSS JOIN role_priv rp
    CROSS JOIN table_priv tp
    CROSS JOIN exempt_priv ep
    CROSS JOIN audit_stmt_missing asm
    CROSS JOIN audit_priv_missing apr
    CROSS JOIN audit_param_gaps apar
  )
SELECT '<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 15px; margin-bottom: 25px;">' ||
       '<div style="background: linear-gradient(135deg, #1e88e5 0%, #42a5f5 100%); color: white; padding: 18px; border-radius: 10px; text-align: center;">' ||
         '<div style="font-size: 34px; font-weight: 700;">' || total_findings || '</div>' ||
         '<div style="font-size: 13px; opacity: 0.9;">Open Findings</div>' ||
       '</div>' ||
       '<div style="background: linear-gradient(135deg, #43a047 0%, #66bb6a 100%); color: white; padding: 18px; border-radius: 10px; text-align: center;">' ||
         '<div style="font-size: 34px; font-weight: 700;">' || credential_findings || '</div>' ||
         '<div style="font-size: 13px; opacity: 0.9;">Password & Profile Gaps</div>' ||
       '</div>' ||
       '<div style="background: linear-gradient(135deg, #ef6c00 0%, #f57c00 100%); color: white; padding: 18px; border-radius: 10px; text-align: center;">' ||
         '<div style="font-size: 34px; font-weight: 700;">' || privilege_issues || '</div>' ||
         '<div style="font-size: 13px; opacity: 0.9;">Privilege & Role Issues</div>' ||
       '</div>' ||
       '<div style="background: linear-gradient(135deg, #8e24aa 0%, #ab47bc 100%); color: white; padding: 18px; border-radius: 10px; text-align: center;">' ||
         '<div style="font-size: 34px; font-weight: 700;">' || audit_issues || '</div>' ||
         '<div style="font-size: 13px; opacity: 0.9;">Audit & Monitoring Gaps</div>' ||
       '</div>' ||
       '</div>'
FROM metrics;

PROMPT <h3 style="color: #1565c0; margin: 25px 0 10px 0;">Security Domains at a Glance</h3>
PROMPT <table class="summary-table" style="box-shadow: 0 2px 4px rgba(0,0,0,0.1); border-radius: 8px; overflow: hidden; margin-bottom: 20px;">
PROMPT <tr style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white;">
PROMPT <th style="padding: 12px; text-align: left;">Domain</th>
PROMPT <th style="padding: 12px; text-align: center;">Outstanding Issues</th>
PROMPT <th style="padding: 12px; text-align: left;">Highlights</th>
PROMPT <th style="padding: 12px; text-align: left;">Status</th></tr>

WITH
  default_pw AS (
    SELECT COUNT(*) cnt FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%'
  ),
  sample_accounts AS (
    SELECT COUNT(*) cnt FROM DBA_USERS
    WHERE USERNAME IN ('BI','HR','IX','OE','PM','SCOTT','SH','DEMO','SAMPLE','TEST','GUEST','OUTLN')
      AND ACCOUNT_STATUS NOT LIKE 'LOCKED%'
      AND ACCOUNT_STATUS NOT LIKE 'EXPIRED%'
  ),
  param_issues AS (
    SELECT COUNT(*) cnt FROM V$PARAMETER
    WHERE (UPPER(NAME) = 'AUDIT_SYS_OPERATIONS' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'AUDIT_TRAIL' AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED'))
       OR (UPPER(NAME) = 'GLOBAL_NAMES' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'LOCAL_LISTENER' AND (VALUE IS NULL OR UPPER(VALUE) NOT LIKE '%IPC%'))
       OR (UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY' AND UPPER(VALUE) != 'FALSE' AND VALUE IS NOT NULL)
       OR (UPPER(NAME) = 'OS_ROLES' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'REMOTE_LISTENER' AND VALUE IS NOT NULL AND LENGTH(TRIM(VALUE)) > 0)
       OR (UPPER(NAME) = 'REMOTE_LOGIN_PASSWORDFILE' AND UPPER(VALUE) != 'NONE')
       OR (UPPER(NAME) = 'REMOTE_OS_AUTHENT' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'REMOTE_OS_ROLES' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'UTL_FILE_DIR' AND VALUE IS NOT NULL AND LENGTH(TRIM(VALUE)) > 0)
       OR (UPPER(NAME) = 'SEC_CASE_SENSITIVE_LOGON' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'SEC_MAX_FAILED_LOGIN_ATTEMPTS' AND NVL(VALUE,'0') NOT IN ('3','3.0'))
       OR (UPPER(NAME) = 'SEC_PROTOCOL_ERROR_FURTHER_ACTION' AND UPPER(VALUE) NOT LIKE '%DELAY%3%' AND UPPER(VALUE) NOT LIKE '%DROP%3%')
       OR (UPPER(NAME) = 'SEC_PROTOCOL_ERROR_TRACE_ACTION' AND UPPER(VALUE) != 'LOG')
       OR (UPPER(NAME) = 'SEC_RETURN_SERVER_RELEASE_BANNER' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'SQL92_SECURITY' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = '_TRACE_FILES_PUBLIC' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'RESOURCE_LIMIT' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'COMMON_USER_PREFIX' AND UPPER(VALUE) != 'C##')
       OR (UPPER(NAME) = 'ENABLE_DDL_LOGGING' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'LDAP_DIRECTORY_SYSAUTH' AND UPPER(VALUE) != 'NO')
       OR (UPPER(NAME) = 'ALLOW_GROUP_ACCESS_TO_SGA' AND UPPER(VALUE) != 'FALSE')
  ),
  profile_raw AS (
    SELECT PROFILE, RESOURCE_NAME FROM DBA_PROFILES
    WHERE RESOURCE_NAME IN ('FAILED_LOGIN_ATTEMPTS','PASSWORD_LOCK_TIME','PASSWORD_LIFE_TIME','PASSWORD_REUSE_MAX',
                            'PASSWORD_REUSE_TIME','PASSWORD_GRACE_TIME','SESSIONS_PER_USER','IDLE_TIME','INACTIVE_ACCOUNT_TIME')
      AND (
        LIMIT = 'UNLIMITED'
        OR LIMIT = 'DEFAULT'
        OR (RESOURCE_NAME = 'FAILED_LOGIN_ATTEMPTS' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 5)
        OR (RESOURCE_NAME = 'PASSWORD_LOCK_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9.]+$') AND TO_NUMBER(LIMIT) < 1)
        OR (RESOURCE_NAME = 'PASSWORD_LIFE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 90)
        OR (RESOURCE_NAME = 'PASSWORD_REUSE_MAX' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) < 20)
        OR (RESOURCE_NAME = 'PASSWORD_REUSE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) < 365)
        OR (RESOURCE_NAME = 'PASSWORD_GRACE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 5)
        OR (RESOURCE_NAME = 'SESSIONS_PER_USER' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 10)
        OR (RESOURCE_NAME = 'IDLE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 30)
        OR (RESOURCE_NAME = 'INACTIVE_ACCOUNT_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 120)
      )
  ),
  profile_issues AS (
    SELECT COUNT(*) cnt FROM profile_raw
  ),
  public_exec AS (
    SELECT COUNT(DISTINCT TABLE_NAME) cnt
    FROM DBA_TAB_PRIVS
    WHERE GRANTEE='PUBLIC'
      AND PRIVILEGE='EXECUTE'
      AND TABLE_NAME IN (
        'DBMS_LDAP','UTL_TCP','UTL_SMTP','UTL_HTTP','UTL_INADDR','UTL_URL','HTTPURITYPE','DBMS_NETWORK_ACL_ADMIN',
        'UTL_FILE','DBMS_LOB','DBMS_ADVISOR','DBMS_FILE_TRANSFER','DBMS_CRYPTO','DBMS_OBFUSCATION_TOOLKIT','DBMS_RANDOM',
        'DBMS_JAVA','DBMS_JAVA_TEST','DBMS_SCHEDULER','DBMS_JOB','DBMS_SQL','DBMS_XMLGEN','DBMS_XMLQUERY','DBMS_XMLSTORE',
        'DBMS_XMLSAVE','DBMS_AW','OWA_UTIL','DBMS_REDACT','DBMS_CREDENTIAL','DBMS_BACKUP_RESTORE','DBMS_STREAMS_RPC',
        'DBMS_AQADM_SYSCALLS','DBMS_REPCAT_SQL_UTL','INITJVMAUX','DBMS_STREAMS_ADM_UTL','DBMS_AQADM_SYS','DBMS_PRVTAQIM',
        'LTADM','WWV_DBMS_SQL','WWV_EXECUTE_IMMEDIATE','DBMS_IJOB'
      )
  ),
  any_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT sp.GRANTEE, sp.PRIVILEGE
      FROM DBA_SYS_PRIVS sp
      LEFT JOIN DBA_USERS u ON u.USERNAME = sp.GRANTEE
      LEFT JOIN DBA_ROLES r ON r.ROLE = sp.GRANTEE
      WHERE sp.PRIVILEGE LIKE '%ANY%'
        AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
        AND sp.GRANTEE NOT LIKE 'C##%'
    )
  ),
  system_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT sp.GRANTEE, sp.PRIVILEGE
      FROM DBA_SYS_PRIVS sp
      LEFT JOIN DBA_USERS u ON u.USERNAME = sp.GRANTEE
      LEFT JOIN DBA_ROLES r ON r.ROLE = sp.GRANTEE
      WHERE sp.PRIVILEGE IN ('ALTER SYSTEM','DROP ANY TABLE','CREATE ANY PROCEDURE','ALTER ANY PROCEDURE','DROP ANY PROCEDURE',
                             'CREATE ANY TRIGGER','ALTER ANY TRIGGER','DROP ANY TRIGGER','BECOME USER')
        AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
        AND sp.GRANTEE NOT LIKE 'C##%'
    )
  ),
  role_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT rp.GRANTEE, rp.GRANTED_ROLE
      FROM DBA_ROLE_PRIVS rp
      LEFT JOIN DBA_USERS u ON u.USERNAME = rp.GRANTEE
      LEFT JOIN DBA_ROLES gr ON gr.ROLE = rp.GRANTEE
      LEFT JOIN DBA_ROLES granted ON granted.ROLE = rp.GRANTED_ROLE
      WHERE NVL(u.ORACLE_MAINTAINED, NVL(gr.ORACLE_MAINTAINED, 'N')) = 'N'
        AND NVL(granted.ORACLE_MAINTAINED, 'N') = 'N'
        AND rp.GRANTEE NOT LIKE 'C##%'
        AND rp.GRANTED_ROLE IN ('DBA','SYSDBA','SYSOPER','EXP_FULL_DATABASE','IMP_FULL_DATABASE',
                                'DELETE_CATALOG_ROLE','EXECUTE_CATALOG_ROLE','SELECT_CATALOG_ROLE')
    )
  ),
  table_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT tp.GRANTEE, tp.TABLE_NAME
      FROM DBA_TAB_PRIVS tp
      LEFT JOIN DBA_USERS u ON u.USERNAME = tp.GRANTEE
      LEFT JOIN DBA_ROLES r ON r.ROLE = tp.GRANTEE
      WHERE tp.OWNER = 'SYS'
        AND tp.TABLE_NAME IN ('USER$','LINK$','USER_HISTORY$','PROXY_DATA$','UNDO$','USER$MIG')
        AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
        AND tp.GRANTEE NOT LIKE 'C##%'
    )
  ),
  exempt_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT sp.GRANTEE
      FROM DBA_SYS_PRIVS sp
      LEFT JOIN DBA_USERS u ON u.USERNAME = sp.GRANTEE
      LEFT JOIN DBA_ROLES r ON r.ROLE = sp.GRANTEE
      WHERE sp.PRIVILEGE = 'EXEMPT ACCESS POLICY'
        AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
    )
  ),
  audit_stmt_missing AS (
    SELECT COUNT(*) cnt
    FROM (
      SELECT 'CREATE SESSION' opt FROM DUAL UNION ALL
      SELECT 'SYSTEM GRANT' FROM DUAL UNION ALL
      SELECT 'USER' FROM DUAL UNION ALL
      SELECT 'ALTER USER' FROM DUAL UNION ALL
      SELECT 'DROP USER' FROM DUAL UNION ALL
      SELECT 'PROFILE' FROM DUAL UNION ALL
      SELECT 'ALTER PROFILE' FROM DUAL UNION ALL
      SELECT 'DROP PROFILE' FROM DUAL UNION ALL
      SELECT 'DATABASE LINK' FROM DUAL UNION ALL
      SELECT 'PUBLIC DATABASE LINK' FROM DUAL UNION ALL
      SELECT 'PUBLIC SYNONYM' FROM DUAL UNION ALL
      SELECT 'SYNONYM' FROM DUAL UNION ALL
      SELECT 'GRANT DIRECTORY' FROM DUAL UNION ALL
      SELECT 'SELECT ANY DICTIONARY' FROM DUAL
    ) expected
    LEFT JOIN (
      SELECT DISTINCT AUDIT_OPTION FROM DBA_STMT_AUDIT_OPTS WHERE SUCCESS = 'BY ACCESS'
    ) actual ON expected.opt = actual.AUDIT_OPTION
    WHERE actual.AUDIT_OPTION IS NULL
  ),
  audit_priv_missing AS (
    SELECT COUNT(*) cnt
    FROM (
      SELECT 'GRANT ANY PRIVILEGE' opt FROM DUAL UNION ALL
      SELECT 'GRANT ANY OBJECT PRIVILEGE' FROM DUAL
    ) expected
    LEFT JOIN (
      SELECT DISTINCT PRIVILEGE FROM DBA_PRIV_AUDIT_OPTS WHERE SUCCESS = 'BY ACCESS'
    ) actual ON expected.opt = actual.PRIVILEGE
    WHERE actual.PRIVILEGE IS NULL
  ),
  audit_param_gaps AS (
    SELECT (CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_TRAIL' AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED')) THEN 1 ELSE 0 END +
            CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_SYS_OPERATIONS' AND UPPER(VALUE) != 'TRUE') THEN 1 ELSE 0 END) cnt
    FROM DUAL
  ),
  metrics AS (
    SELECT dp.cnt AS default_pw_cnt,
           sa.cnt AS sample_account_cnt,
           pi.cnt AS param_issue_cnt,
           pr.cnt AS profile_issue_cnt,
           pe.cnt AS public_exec_cnt,
           ap.cnt AS any_priv_cnt,
           sp.cnt AS system_priv_cnt,
           rp.cnt AS role_priv_cnt,
           tp.cnt AS table_priv_cnt,
           ep.cnt AS exempt_priv_cnt,
           asm.cnt AS audit_stmt_gap_cnt,
           apr.cnt AS audit_priv_gap_cnt,
           apar.cnt AS audit_param_gap_cnt,
           (dp.cnt + sa.cnt) AS install_issues,
           pi.cnt AS config_issues,
           pr.cnt AS auth_issues,
           (pe.cnt + ap.cnt + sp.cnt + rp.cnt + tp.cnt + ep.cnt) AS privilege_issues,
           (asm.cnt + apr.cnt + apar.cnt) AS audit_issues
    FROM default_pw dp
    CROSS JOIN sample_accounts sa
    CROSS JOIN param_issues pi
    CROSS JOIN profile_issues pr
    CROSS JOIN public_exec pe
    CROSS JOIN any_priv ap
    CROSS JOIN system_priv sp
    CROSS JOIN role_priv rp
    CROSS JOIN table_priv tp
    CROSS JOIN exempt_priv ep
    CROSS JOIN audit_stmt_missing asm
    CROSS JOIN audit_priv_missing apr
    CROSS JOIN audit_param_gaps apar
  )
SELECT '<tr><td style="padding: 10px; font-weight: 500;">Access & Accounts</td>' ||
       '<td style="padding: 10px; text-align: center; font-weight: bold;">' || install_issues || '</td>' ||
       '<td style="padding: 10px;">Default passwords: ' || default_pw_cnt || ' &nbsp;|&nbsp; Sample accounts: ' || sample_account_cnt || '</td>' ||
       '<td style="padding: 10px;">' ||
         CASE WHEN install_issues = 0 THEN '<span style="color: #2e7d32; font-weight: 600;">Compliant</span>'
              ELSE '<span style="color: #c62828; font-weight: 600;">Needs attention</span>' END ||
       '</td></tr>' ||
       '<tr><td style="padding: 10px; font-weight: 500;">Configuration & Parameters</td>' ||
       '<td style="padding: 10px; text-align: center; font-weight: bold;">' || config_issues || '</td>' ||
       '<td style="padding: 10px;">Parameters requiring hardening: ' || param_issue_cnt || '</td>' ||
       '<td style="padding: 10px;">' ||
         CASE WHEN config_issues = 0 THEN '<span style="color: #2e7d32; font-weight: 600;">Compliant</span>'
              ELSE '<span style="color: #c62828; font-weight: 600;">Needs attention</span>' END ||
       '</td></tr>' ||
       '<tr><td style="padding: 10px; font-weight: 500;">Authentication Policies</td>' ||
       '<td style="padding: 10px; text-align: center; font-weight: bold;">' || auth_issues || '</td>' ||
       '<td style="padding: 10px;">Profile settings to adjust: ' || profile_issue_cnt || '</td>' ||
       '<td style="padding: 10px;">' ||
         CASE WHEN auth_issues = 0 THEN '<span style="color: #2e7d32; font-weight: 600;">Compliant</span>'
              ELSE '<span style="color: #c62828; font-weight: 600;">Needs attention</span>' END ||
       '</td></tr>' ||
       '<tr><td style="padding: 10px; font-weight: 500;">Privileges & Roles</td>' ||
       '<td style="padding: 10px; text-align: center; font-weight: bold;">' || privilege_issues || '</td>' ||
       '<td style="padding: 10px;">PUBLIC EXECUTE: ' || public_exec_cnt || ', ANY privileges: ' || any_priv_cnt || ', Elevated roles: ' || role_priv_cnt || '</td>' ||
       '<td style="padding: 10px;">' ||
         CASE WHEN privilege_issues = 0 THEN '<span style="color: #2e7d32; font-weight: 600;">Compliant</span>'
              ELSE '<span style="color: #c62828; font-weight: 600;">Needs attention</span>' END ||
       '</td></tr>' ||
       '<tr><td style="padding: 10px; font-weight: 500;">Auditing & Monitoring</td>' ||
       '<td style="padding: 10px; text-align: center; font-weight: bold;">' || audit_issues || '</td>' ||
       '<td style="padding: 10px;">Statement audits: ' || audit_stmt_gap_cnt || ', privilege audits: ' || audit_priv_gap_cnt || ', parameter fixes: ' || audit_param_gap_cnt || '</td>' ||
       '<td style="padding: 10px;">' ||
         CASE WHEN audit_issues = 0 THEN '<span style="color: #2e7d32; font-weight: 600;">Compliant</span>'
              ELSE '<span style="color: #c62828; font-weight: 600;">Needs attention</span>' END ||
       '</td></tr>'
FROM metrics;
PROMPT </table>

PROMPT <h3 style="color: #1565c0; margin: 25px 0 10px 0;">Priority Actions</h3>
WITH
  default_pw AS (
    SELECT COUNT(*) cnt FROM DBA_USERS_WITH_DEFPWD WHERE USERNAME NOT LIKE '%XS$NULL%'
  ),
  sample_accounts AS (
    SELECT COUNT(*) cnt FROM DBA_USERS
    WHERE USERNAME IN ('BI','HR','IX','OE','PM','SCOTT','SH','DEMO','SAMPLE','TEST','GUEST','OUTLN')
      AND ACCOUNT_STATUS NOT LIKE 'LOCKED%'
      AND ACCOUNT_STATUS NOT LIKE 'EXPIRED%'
  ),
  param_issues AS (
    SELECT COUNT(*) cnt FROM V$PARAMETER
    WHERE (UPPER(NAME) = 'AUDIT_SYS_OPERATIONS' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'AUDIT_TRAIL' AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED'))
       OR (UPPER(NAME) = 'GLOBAL_NAMES' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'LOCAL_LISTENER' AND (VALUE IS NULL OR UPPER(VALUE) NOT LIKE '%IPC%'))
       OR (UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY' AND UPPER(VALUE) != 'FALSE' AND VALUE IS NOT NULL)
       OR (UPPER(NAME) = 'OS_ROLES' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'REMOTE_LISTENER' AND VALUE IS NOT NULL AND LENGTH(TRIM(VALUE)) > 0)
       OR (UPPER(NAME) = 'REMOTE_LOGIN_PASSWORDFILE' AND UPPER(VALUE) != 'NONE')
       OR (UPPER(NAME) = 'REMOTE_OS_AUTHENT' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'REMOTE_OS_ROLES' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'UTL_FILE_DIR' AND VALUE IS NOT NULL AND LENGTH(TRIM(VALUE)) > 0)
       OR (UPPER(NAME) = 'SEC_CASE_SENSITIVE_LOGON' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'SEC_MAX_FAILED_LOGIN_ATTEMPTS' AND NVL(VALUE,'0') NOT IN ('3','3.0'))
       OR (UPPER(NAME) = 'SEC_PROTOCOL_ERROR_FURTHER_ACTION' AND UPPER(VALUE) NOT LIKE '%DELAY%3%' AND UPPER(VALUE) NOT LIKE '%DROP%3%')
       OR (UPPER(NAME) = 'SEC_PROTOCOL_ERROR_TRACE_ACTION' AND UPPER(VALUE) != 'LOG')
       OR (UPPER(NAME) = 'SEC_RETURN_SERVER_RELEASE_BANNER' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'SQL92_SECURITY' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = '_TRACE_FILES_PUBLIC' AND UPPER(VALUE) != 'FALSE')
       OR (UPPER(NAME) = 'RESOURCE_LIMIT' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'COMMON_USER_PREFIX' AND UPPER(VALUE) != 'C##')
       OR (UPPER(NAME) = 'ENABLE_DDL_LOGGING' AND UPPER(VALUE) != 'TRUE')
       OR (UPPER(NAME) = 'LDAP_DIRECTORY_SYSAUTH' AND UPPER(VALUE) != 'NO')
       OR (UPPER(NAME) = 'ALLOW_GROUP_ACCESS_TO_SGA' AND UPPER(VALUE) != 'FALSE')
  ),
  profile_raw AS (
    SELECT PROFILE, RESOURCE_NAME FROM DBA_PROFILES
    WHERE RESOURCE_NAME IN ('FAILED_LOGIN_ATTEMPTS','PASSWORD_LOCK_TIME','PASSWORD_LIFE_TIME','PASSWORD_REUSE_MAX',
                            'PASSWORD_REUSE_TIME','PASSWORD_GRACE_TIME','SESSIONS_PER_USER','IDLE_TIME','INACTIVE_ACCOUNT_TIME')
      AND (
        LIMIT = 'UNLIMITED'
        OR LIMIT = 'DEFAULT'
        OR (RESOURCE_NAME = 'FAILED_LOGIN_ATTEMPTS' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 5)
        OR (RESOURCE_NAME = 'PASSWORD_LOCK_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9.]+$') AND TO_NUMBER(LIMIT) < 1)
        OR (RESOURCE_NAME = 'PASSWORD_LIFE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 90)
        OR (RESOURCE_NAME = 'PASSWORD_REUSE_MAX' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) < 20)
        OR (RESOURCE_NAME = 'PASSWORD_REUSE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) < 365)
        OR (RESOURCE_NAME = 'PASSWORD_GRACE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 5)
        OR (RESOURCE_NAME = 'SESSIONS_PER_USER' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 10)
        OR (RESOURCE_NAME = 'IDLE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 30)
        OR (RESOURCE_NAME = 'INACTIVE_ACCOUNT_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 120)
      )
  ),
  profile_issues AS (
    SELECT COUNT(*) cnt FROM profile_raw
  ),
  public_exec AS (
    SELECT COUNT(DISTINCT TABLE_NAME) cnt
    FROM DBA_TAB_PRIVS
    WHERE GRANTEE='PUBLIC'
      AND PRIVILEGE='EXECUTE'
      AND TABLE_NAME IN (
        'DBMS_LDAP','UTL_TCP','UTL_SMTP','UTL_HTTP','UTL_INADDR','UTL_URL','HTTPURITYPE','DBMS_NETWORK_ACL_ADMIN',
        'UTL_FILE','DBMS_LOB','DBMS_ADVISOR','DBMS_FILE_TRANSFER','DBMS_CRYPTO','DBMS_OBFUSCATION_TOOLKIT','DBMS_RANDOM',
        'DBMS_JAVA','DBMS_JAVA_TEST','DBMS_SCHEDULER','DBMS_JOB','DBMS_SQL','DBMS_XMLGEN','DBMS_XMLQUERY','DBMS_XMLSTORE',
        'DBMS_XMLSAVE','DBMS_AW','OWA_UTIL','DBMS_REDACT','DBMS_CREDENTIAL','DBMS_BACKUP_RESTORE','DBMS_STREAMS_RPC',
        'DBMS_AQADM_SYSCALLS','DBMS_REPCAT_SQL_UTL','INITJVMAUX','DBMS_STREAMS_ADM_UTL','DBMS_AQADM_SYS','DBMS_PRVTAQIM',
        'LTADM','WWV_DBMS_SQL','WWV_EXECUTE_IMMEDIATE','DBMS_IJOB'
      )
  ),
  any_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT sp.GRANTEE, sp.PRIVILEGE
      FROM DBA_SYS_PRIVS sp
      LEFT JOIN DBA_USERS u ON u.USERNAME = sp.GRANTEE
      LEFT JOIN DBA_ROLES r ON r.ROLE = sp.GRANTEE
      WHERE sp.PRIVILEGE LIKE '%ANY%'
        AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
        AND sp.GRANTEE NOT LIKE 'C##%'
    )
  ),
  system_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT sp.GRANTEE, sp.PRIVILEGE
      FROM DBA_SYS_PRIVS sp
      LEFT JOIN DBA_USERS u ON u.USERNAME = sp.GRANTEE
      LEFT JOIN DBA_ROLES r ON r.ROLE = sp.GRANTEE
      WHERE sp.PRIVILEGE IN ('ALTER SYSTEM','DROP ANY TABLE','CREATE ANY PROCEDURE','ALTER ANY PROCEDURE','DROP ANY PROCEDURE',
                             'CREATE ANY TRIGGER','ALTER ANY TRIGGER','DROP ANY TRIGGER','BECOME USER')
        AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
        AND sp.GRANTEE NOT LIKE 'C##%'
    )
  ),
  role_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT rp.GRANTEE, rp.GRANTED_ROLE
      FROM DBA_ROLE_PRIVS rp
      LEFT JOIN DBA_USERS u ON u.USERNAME = rp.GRANTEE
      LEFT JOIN DBA_ROLES gr ON gr.ROLE = rp.GRANTEE
      LEFT JOIN DBA_ROLES granted ON granted.ROLE = rp.GRANTED_ROLE
      WHERE NVL(u.ORACLE_MAINTAINED, NVL(gr.ORACLE_MAINTAINED, 'N')) = 'N'
        AND NVL(granted.ORACLE_MAINTAINED, 'N') = 'N'
        AND rp.GRANTEE NOT LIKE 'C##%'
        AND rp.GRANTED_ROLE IN ('DBA','SYSDBA','SYSOPER','EXP_FULL_DATABASE','IMP_FULL_DATABASE',
                                'DELETE_CATALOG_ROLE','EXECUTE_CATALOG_ROLE','SELECT_CATALOG_ROLE')
    )
  ),
  table_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT tp.GRANTEE, tp.TABLE_NAME
      FROM DBA_TAB_PRIVS tp
      LEFT JOIN DBA_USERS u ON u.USERNAME = tp.GRANTEE
      LEFT JOIN DBA_ROLES r ON r.ROLE = tp.GRANTEE
      WHERE tp.OWNER = 'SYS'
        AND tp.TABLE_NAME IN ('USER$','LINK$','USER_HISTORY$','PROXY_DATA$','UNDO$','USER$MIG')
        AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
        AND tp.GRANTEE NOT LIKE 'C##%'
    )
  ),
  exempt_priv AS (
    SELECT COUNT(*) cnt FROM (
      SELECT DISTINCT sp.GRANTEE
      FROM DBA_SYS_PRIVS sp
      LEFT JOIN DBA_USERS u ON u.USERNAME = sp.GRANTEE
      LEFT JOIN DBA_ROLES r ON r.ROLE = sp.GRANTEE
      WHERE sp.PRIVILEGE = 'EXEMPT ACCESS POLICY'
        AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
    )
  ),
  audit_stmt_missing AS (
    SELECT COUNT(*) cnt
    FROM (
      SELECT 'CREATE SESSION' opt FROM DUAL UNION ALL
      SELECT 'SYSTEM GRANT' FROM DUAL UNION ALL
      SELECT 'USER' FROM DUAL UNION ALL
      SELECT 'ALTER USER' FROM DUAL UNION ALL
      SELECT 'DROP USER' FROM DUAL UNION ALL
      SELECT 'PROFILE' FROM DUAL UNION ALL
      SELECT 'ALTER PROFILE' FROM DUAL UNION ALL
      SELECT 'DROP PROFILE' FROM DUAL UNION ALL
      SELECT 'DATABASE LINK' FROM DUAL UNION ALL
      SELECT 'PUBLIC DATABASE LINK' FROM DUAL UNION ALL
      SELECT 'PUBLIC SYNONYM' FROM DUAL UNION ALL
      SELECT 'SYNONYM' FROM DUAL UNION ALL
      SELECT 'GRANT DIRECTORY' FROM DUAL UNION ALL
      SELECT 'SELECT ANY DICTIONARY' FROM DUAL
    ) expected
    LEFT JOIN (
      SELECT DISTINCT AUDIT_OPTION FROM DBA_STMT_AUDIT_OPTS WHERE SUCCESS = 'BY ACCESS'
    ) actual ON expected.opt = actual.AUDIT_OPTION
    WHERE actual.AUDIT_OPTION IS NULL
  ),
  audit_priv_missing AS (
    SELECT COUNT(*) cnt
    FROM (
      SELECT 'GRANT ANY PRIVILEGE' opt FROM DUAL UNION ALL
      SELECT 'GRANT ANY OBJECT PRIVILEGE' FROM DUAL
    ) expected
    LEFT JOIN (
      SELECT DISTINCT PRIVILEGE FROM DBA_PRIV_AUDIT_OPTS WHERE SUCCESS = 'BY ACCESS'
    ) actual ON expected.opt = actual.PRIVILEGE
    WHERE actual.PRIVILEGE IS NULL
  ),
  audit_param_gaps AS (
    SELECT (CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_TRAIL' AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED')) THEN 1 ELSE 0 END +
            CASE WHEN EXISTS (SELECT 1 FROM V$PARAMETER WHERE UPPER(NAME) = 'AUDIT_SYS_OPERATIONS' AND UPPER(VALUE) != 'TRUE') THEN 1 ELSE 0 END) cnt
    FROM DUAL
  ),
  metrics AS (
    SELECT dp.cnt AS default_pw_cnt,
           sa.cnt AS sample_account_cnt,
           pi.cnt AS param_issue_cnt,
           pr.cnt AS profile_issue_cnt,
           pe.cnt AS public_exec_cnt,
           ap.cnt AS any_priv_cnt,
           sp.cnt AS system_priv_cnt,
           rp.cnt AS role_priv_cnt,
           tp.cnt AS table_priv_cnt,
           ep.cnt AS exempt_priv_cnt,
           asm.cnt AS audit_stmt_gap_cnt,
           apr.cnt AS audit_priv_gap_cnt,
           apar.cnt AS audit_param_gap_cnt,
           (dp.cnt + sa.cnt + pi.cnt + pr.cnt + pe.cnt + ap.cnt + sp.cnt + rp.cnt + tp.cnt + ep.cnt + asm.cnt + apr.cnt + apar.cnt) AS total_findings
    FROM default_pw dp
    CROSS JOIN sample_accounts sa
    CROSS JOIN param_issues pi
    CROSS JOIN profile_issues pr
    CROSS JOIN public_exec pe
    CROSS JOIN any_priv ap
    CROSS JOIN system_priv sp
    CROSS JOIN role_priv rp
    CROSS JOIN table_priv tp
    CROSS JOIN exempt_priv ep
    CROSS JOIN audit_stmt_missing asm
    CROSS JOIN audit_priv_missing apr
    CROSS JOIN audit_param_gaps apar
  )
SELECT '<ul style="margin: 0 0 20px 0; padding-left: 20px; color: #37474f; font-size: 13px;">' ||
       CASE WHEN default_pw_cnt > 0 THEN '<li><strong>Reset ' || default_pw_cnt || '</strong> account(s) with default passwords.</li>' ELSE '' END ||
       CASE WHEN param_issue_cnt > 0 THEN '<li><strong>Review ' || param_issue_cnt || '</strong> database initialization parameter(s) that diverge from CIS guidance.</li>' ELSE '' END ||
       CASE WHEN profile_issue_cnt > 0 THEN '<li><strong>Harden password profiles:</strong> ' || profile_issue_cnt || ' rule(s) exceed policy limits.</li>' ELSE '' END ||
       CASE WHEN (public_exec_cnt + any_priv_cnt + system_priv_cnt + role_priv_cnt + exempt_priv_cnt) > 0 THEN '<li><strong>Reduce elevated privileges:</strong> PUBLIC packages (' || public_exec_cnt || '), ANY privileges (' || any_priv_cnt || '), sensitive roles (' || role_priv_cnt || ').</li>' ELSE '' END ||
       CASE WHEN (audit_stmt_gap_cnt + audit_priv_gap_cnt + audit_param_gap_cnt) > 0 THEN '<li><strong>Enable auditing:</strong> ' || (audit_stmt_gap_cnt + audit_priv_gap_cnt + audit_param_gap_cnt) || ' required audit controls are disabled.</li>' ELSE '' END ||
       CASE WHEN total_findings = 0 THEN '<li>All evaluated CIS checks passed. Continue monitoring and periodic reviews.</li>' ELSE '' END ||
       '</ul>'
FROM metrics;

PROMPT <div style="background-color: #fff3cd; padding: 12px; border-left: 4px solid #ffc107; border-radius: 6px; font-size: 12px; color: #795548;">
PROMPT <strong>Reminder:</strong> validate remediation steps in a non-production environment and coordinate changes with application owners.
PROMPT </div>
PROMPT </div>

PROMPT </div>

-- Section 1: Oracle Database Installation and Patching Requirements
PROMPT <h2 id="section1">1. Oracle Database Installation and Patching Requirements</h2>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 1.1 Ensure the Appropriate Version/Patches for Oracle Software Is Installed
-- Version Check
SELECT '<tr class="' ||
  CASE 
    WHEN version LIKE '19.%' THEN 'pass'
    WHEN version LIKE '18.%' THEN 'pass'
    WHEN version LIKE '12.%' THEN 'pass'
    WHEN version LIKE '11.2.0.4%' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>1.1a</td>' ||
  '<td>Ensure Appropriate Oracle Version Is Installed (Scored)</td>' ||
  '<td>' || 
    CASE 
      WHEN version LIKE '19.%' OR version LIKE '18.%' OR version LIKE '12.%' OR version LIKE '11.2.0.4%' THEN 'PASS'
      ELSE 'FAIL'
    END || '</td>' ||
  '<td>' || version || '</td>' ||
  '<td>' || 
    CASE 
      WHEN version LIKE '19.%' THEN '19.x (supported)'
      WHEN version LIKE '18.%' THEN '18.x (supported)'
      WHEN version LIKE '12.%' THEN '12.x (supported)'
      WHEN version LIKE '11.2%' THEN '11.2.0.4+ (minimum)'
      ELSE 'Supported version required'
    END || '</td>' ||
  '<td class="remediation">Upgrade to supported Oracle version</td>' ||
  '</tr>'
FROM v$instance;

-- Recent Patches Check for 11g (using DBA_REGISTRY_HISTORY)
SELECT CASE WHEN vi.version LIKE '11.%' THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(drh.ID) > 0 THEN 'pass'
    ELSE 'warning'
  END || '">' ||
  '<td>1.1b</td>' ||
  '<td>Ensure Recent Patches Are Applied - 11g (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(drh.ID) > 0 THEN 'PASS' ELSE 'WARNING' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(drh.ID) > 0 THEN 
      'Recent patches found: ' || COUNT(drh.ID) || ' patches in last 90 days'
    ELSE 'No recent patches found in last 90 days'
    END || '</td>' ||
  '<td>Recent PSU/CPU patches within 90 days</td>' ||
  '<td class="remediation">Apply latest PSU/CPU patches. Query: SELECT ACTION,VERSION,ID FROM DBA_REGISTRY_HISTORY WHERE TO_DATE(TRIM(TO_CHAR(ID)),''YYMMDD'') > SYSDATE-90 AND ID > 160000</td>' ||
  '</tr>'
ELSE '' END
FROM v$instance vi 
LEFT JOIN DBA_REGISTRY_HISTORY drh ON (
  vi.version LIKE '11.%' 
  AND TO_DATE(TRIM(TO_CHAR(drh.ID)), 'YYMMDD') > SYSDATE-90 
  AND drh.ID > 160000
)
GROUP BY vi.version;

-- Patch Check for 12c+ (Manual - requires opatch)
SELECT CASE WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
  '<tr class="manual">' ||
  '<td>1.1c</td>' ||
  '<td>Ensure Recent Patches Are Applied - 12c+ (Scored)</td>' ||
  '<td>MANUAL</td>' ||
  '<td>Requires OS-level opatch command verification</td>' ||
  '<td>' || 
    CASE 
      WHEN version LIKE '19.%' THEN 'Latest 19c RU (Release Update)'
      WHEN version LIKE '18.%' THEN 'Latest 18c RU (Release Update)'
      WHEN version LIKE '12.%' THEN 'Latest 12c RU/PSU'
    END || '</td>' ||
  '<td class="remediation">Run: opatch lsinventory | grep "&lt;latest_patch_version&gt;" OR $ORACLE_HOME/OPatch/opatch lsinventory</td>' ||
  '</tr>'
ELSE '' END FROM v$instance;

-- 1.2 Ensure All Default Passwords Are Changed (11g and 12c+ non-multitenant/PDB)
WITH default_pwd_11g AS (
  SELECT 
    vi.version,
    dp.USERNAME
  FROM v$instance vi
  CROSS JOIN DBA_USERS_WITH_DEFPWD dp
  WHERE vi.version LIKE '11.%'
  AND dp.USERNAME NOT LIKE '%XS$NULL%'
),
default_pwd_12c_non_mt AS (
  SELECT 
    vi.version,
    a.USERNAME
  FROM v$instance vi
  CROSS JOIN DBA_USERS_WITH_DEFPWD a
  CROSS JOIN DBA_USERS b
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND a.USERNAME = b.USERNAME
  AND b.ACCOUNT_STATUS = 'OPEN'
),
default_pwd_combined AS (
  SELECT version, USERNAME FROM default_pwd_11g
  UNION ALL
  SELECT version, USERNAME FROM default_pwd_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM default_pwd_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>1.2</td>' ||
  '<td>Ensure All Default Passwords Are Changed (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM default_pwd_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM default_pwd_combined) > 0 THEN 
      (SELECT LISTAGG(USERNAME, ', ') WITHIN GROUP (ORDER BY USERNAME) FROM default_pwd_combined)
    ELSE 'No users with default passwords'
    END || '</td>' ||
  '<td>No users should have default passwords</td>' ||
  '<td class="remediation">PASSWORD &lt;username&gt; or ALTER USER &lt;username&gt; IDENTIFIED BY &lt;new_password&gt;</td>' ||
  '</tr>'
FROM DUAL;

-- 1.2b Ensure All Default Passwords Are Changed (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(U.USERNAME) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>1.2b</td>' ||
  '<td>Ensure All Default Passwords Are Changed in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(U.USERNAME) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(U.USERNAME) > 0 THEN 
      LISTAGG(DECODE(U.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE U.CON_ID = B.CON_ID)) || ':' || U.USERNAME, '; ') WITHIN GROUP (ORDER BY U.CON_ID, U.USERNAME)
    ELSE 'No users with default passwords in any container'
    END || '</td>' ||
  '<td>No users should have default passwords in any container</td>' ||
  '<td class="remediation">For each container: PASSWORD &lt;username&gt; or ALTER USER &lt;username&gt; IDENTIFIED BY &lt;new_password&gt;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT DISTINCT 
    a.CON_ID,
    a.USERNAME
  FROM CDB_USERS_WITH_DEFPWD a
  CROSS JOIN CDB_USERS c
  WHERE a.USERNAME = c.USERNAME
  AND c.ACCOUNT_STATUS = 'OPEN'
  AND a.CON_ID = c.CON_ID
) U
GROUP BY ef.env_type;

-- 1.3 Ensure All Sample Data And Users Have Been Removed (11g and 12c+ non-multitenant/PDB)
WITH sample_users_11g AS (
  SELECT 
    vi.version,
    du.USERNAME
  FROM v$instance vi
  CROSS JOIN DBA_USERS du
  WHERE vi.version LIKE '11.%'
  AND du.USERNAME IN ('BI','HR','IX','OE','PM','SCOTT','SH')
),
sample_users_12c_non_mt AS (
  SELECT 
    vi.version,
    du.USERNAME
  FROM v$instance vi
  CROSS JOIN DBA_USERS du
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND du.USERNAME IN ('BI','HR','IX','OE','PM','SCOTT','SH')
),
sample_users_combined AS (
  SELECT version, USERNAME FROM sample_users_11g
  UNION ALL
  SELECT version, USERNAME FROM sample_users_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM sample_users_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>1.3</td>' ||
  '<td>Ensure All Sample Data And Users Have Been Removed (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM sample_users_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM sample_users_combined) > 0 THEN 
      (SELECT LISTAGG(USERNAME, ', ') WITHIN GROUP (ORDER BY USERNAME) FROM sample_users_combined)
    ELSE 'No sample users found'
    END || '</td>' ||
  '<td>No Oracle sample users should exist</td>' ||
  '<td class="remediation">Execute $ORACLE_HOME/demo/schema/drop_sch.sql to remove sample schemas</td>' ||
  '</tr>'
FROM DUAL;

-- 1.3b Ensure All Sample Data And Users Have Been Removed (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(U.USERNAME) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>1.3b</td>' ||
  '<td>Ensure All Sample Data And Users Have Been Removed in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(U.USERNAME) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(U.USERNAME) > 0 THEN 
      LISTAGG(DECODE(U.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE U.CON_ID = B.CON_ID)) || ':' || U.USERNAME, '; ') WITHIN GROUP (ORDER BY U.CON_ID, U.USERNAME)
    ELSE 'No sample users found in any container'
    END || '</td>' ||
  '<td>No Oracle sample users should exist in any container</td>' ||
  '<td class="remediation">For each container: Execute $ORACLE_HOME/demo/schema/drop_sch.sql or DROP USER &lt;sample_user&gt; CASCADE</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT DISTINCT 
    a.CON_ID,
    a.USERNAME
  FROM CDB_USERS a
  WHERE a.USERNAME IN ('BI','HR','IX','OE','PM','SCOTT','SH')
) U
GROUP BY ef.env_type;

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
FROM v$instance vi CROSS JOIN pdbadmin_check pc;

-- 1.5 12c+: Check for proper common user naming in CDB
SELECT CASE WHEN (vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%') THEN
  CASE WHEN (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' THEN
    '<tr class="' ||
    CASE 
      WHEN COUNT(du.USERNAME) = 0 THEN 'pass'
      ELSE 'fail'
    END || '">' ||
    '<td>1.5</td>' ||
    '<td>Ensure Common Users Follow Naming Convention (12c+ CDB) (Scored)</td>' ||
    '<td>' || CASE WHEN COUNT(du.USERNAME) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
    '<td>' || 
      CASE WHEN COUNT(du.USERNAME) > 0 THEN 
        'Common users without C## prefix: ' || LISTAGG(du.USERNAME, ', ') WITHIN GROUP (ORDER BY du.USERNAME)
      ELSE 'All common users follow naming convention'
      END || '</td>' ||
    '<td>Common users should start with C##</td>' ||
    '<td class="remediation">Review and rename or drop non-compliant common users</td>' ||
    '</tr>'
  ELSE ''
  END
ELSE '' END
FROM DBA_USERS du CROSS JOIN V$INSTANCE vi
WHERE du.COMMON = 'YES' 
AND du.USERNAME NOT LIKE 'C##%'
AND du.USERNAME NOT IN ('SYS','SYSTEM','APPQOSSYS','AUDSYS','CTXSYS','DBSFWUSER','DBSNMP','DIP','DVF',
'DVSYS','GGSYS','GSMADMIN_INTERNAL','GSMCATUSER','GSMROOTUSER','GSMUSER','LBACSYS','MDDATA','MDSYS','OJVMSYS','OLAPSYS',
'ORACLE_OCM','ORDDATA','ORDPLUGINS','ORDSYS','OUTLN','REMOTE_SCHEDULER_AGENT','SI_INFORMTN_SCHEMA','SYS$UMF','SYSBACKUP',
'SYSDG','SYSKM','SYSRAC','WMSYS','XDB','XS$NULL')
GROUP BY vi.version;

-- 1.6 18c+: Check for schema-only accounts
SELECT CASE WHEN version LIKE '18.%' OR version LIKE '19.%' THEN
  '<tr class="manual">' ||
  '<td>1.6</td>' ||
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
PROMPT <h3 id="section2_1">2.1 Listener Settings</h3>
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
PROMPT <h3 id="section2_2">2.2 Database Settings</h3>
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

-- 2.2.3 GLOBAL_NAMES (11g and 12c+ Non-Multitenant)
SELECT CASE 
  WHEN vi.version LIKE '11.%' OR 
       (vi.version NOT LIKE '11.%' AND (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO') OR
       (vi.version NOT LIKE '11.%' AND (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT') THEN
    '<tr class="' ||
    CASE 
      WHEN UPPER(vp.VALUE) = 'TRUE' THEN 'pass'
      ELSE 'fail'
    END || '">' ||
    '<td>2.2.3a</td>' ||
    '<td>Ensure GLOBAL_NAMES Is Set to TRUE (Scored)</td>' ||
    '<td>' || CASE WHEN UPPER(vp.VALUE) = 'TRUE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
    '<td>' || vp.VALUE || '</td>' ||
    '<td>TRUE</td>' ||
    '<td class="remediation">ALTER SYSTEM SET GLOBAL_NAMES = TRUE SCOPE = SPFILE;</td>' ||
    '</tr>'
  ELSE '' 
END
FROM V$PARAMETER vp CROSS JOIN v$instance vi
WHERE UPPER(vp.NAME) = 'GLOBAL_NAMES';

-- 2.2.3 GLOBAL_NAMES (12c+ Multi-tenant Container Database)
WITH mt_global_names AS (
  SELECT DISTINCT 
    UPPER(V.VALUE) AS PARAM_VALUE,
    DECODE(V.CON_ID,
      0, (SELECT NAME FROM V$DATABASE),
      1, (SELECT NAME FROM V$DATABASE),
      (SELECT NAME FROM V$PDBS B WHERE V.CON_ID = B.CON_ID)
    ) AS CONTAINER_NAME,
    V.CON_ID
  FROM V$SYSTEM_PARAMETER V
  WHERE UPPER(V.NAME) = 'GLOBAL_NAMES'
    AND EXISTS (SELECT 1 FROM v$instance WHERE version NOT LIKE '11.%')
    AND (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES'
    AND SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT'
)
SELECT CASE 
  WHEN mt_context.is_mt_context = 1 THEN
    '<tr class="' ||
    CASE 
      WHEN COUNT(CASE WHEN mgn.PARAM_VALUE != 'TRUE' THEN 1 END) = 0 THEN 'pass'
      ELSE 'fail'
    END || '">' ||
    '<td>2.2.3b</td>' ||
    '<td>Ensure GLOBAL_NAMES Is Set to TRUE - Multi-tenant (Scored)</td>' ||
    '<td>' || CASE WHEN COUNT(CASE WHEN mgn.PARAM_VALUE != 'TRUE' THEN 1 END) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
    '<td>' || 
      CASE WHEN COUNT(*) > 0 THEN 
        LISTAGG(mgn.CONTAINER_NAME || ':' || mgn.PARAM_VALUE, ', ') WITHIN GROUP (ORDER BY mgn.CONTAINER_NAME)
      ELSE 'No containers found'
      END || '</td>' ||
    '<td>TRUE for all containers</td>' ||
    '<td class="remediation">ALTER SYSTEM SET GLOBAL_NAMES = TRUE SCOPE = SPFILE; (run in each container)</td>' ||
    '</tr>'
  ELSE ''
END
FROM mt_global_names mgn 
CROSS JOIN (
  SELECT CASE 
    WHEN EXISTS (SELECT 1 FROM v$instance WHERE version NOT LIKE '11.%') 
         AND (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES'
         AND SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT' THEN 1 
    ELSE 0 
  END AS is_mt_context FROM DUAL
) mt_context
GROUP BY mt_context.is_mt_context;

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

-- 2.2.5 O7_DICTIONARY_ACCESSIBILITY (11g)
WITH o7_check_11g AS (
  SELECT 
    vi.version,
    CASE WHEN COUNT(vp.VALUE) > 0 THEN 1 ELSE 0 END AS param_exists,
    MAX(UPPER(vp.VALUE)) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'O7_DICTIONARY_ACCESSIBILITY'
  WHERE vi.version LIKE '11.%'
  GROUP BY vi.version
),
o7_check_12c_non_mt AS (
  SELECT 
    vi.version,
    CASE WHEN COUNT(vsp.VALUE) > 0 THEN 1 ELSE 0 END AS param_exists,
    MAX(UPPER(vsp.VALUE)) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'O7_DICTIONARY_ACCESSIBILITY'
  WHERE vi.version NOT LIKE '11.%' AND 
        ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
         ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  GROUP BY vi.version
),
o7_check_combined AS (
  SELECT version, param_exists, param_value FROM o7_check_11g
  UNION ALL
  SELECT version, param_exists, param_value FROM o7_check_12c_non_mt
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(occ.param_exists) = 0 THEN 'warning'
    WHEN MAX(occ.param_value) = 'FALSE' OR MAX(occ.param_value) IS NULL THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.5a</td>' ||
  '<td>Ensure O7_DICTIONARY_ACCESSIBILITY Is Set to FALSE (Scored)</td>' ||
  '<td>' || 
    CASE 
      WHEN MAX(occ.param_exists) = 0 THEN 'N/A'
      WHEN MAX(occ.param_value) = 'FALSE' OR MAX(occ.param_value) IS NULL THEN 'PASS' 
      ELSE 'FAIL' 
    END || '</td>' ||
  '<td>' || 
    CASE 
      WHEN MAX(occ.param_exists) = 0 THEN 'Parameter not found in this Oracle version'
      WHEN MAX(occ.param_value) IS NULL THEN 'FALSE (default)'
      ELSE MAX(occ.param_value)
    END || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">' ||
    CASE 
      WHEN MAX(occ.param_exists) = 0 THEN 'Parameter may not exist in this Oracle version'
      ELSE 'ALTER SYSTEM SET O7_DICTIONARY_ACCESSIBILITY=FALSE SCOPE = SPFILE;'
    END || '</td>' ||
  '</tr>'
ELSE '' END
FROM o7_check_combined occ;

-- 2.2.5 O7_DICTIONARY_ACCESSIBILITY (12c+ Multi-tenant Container Database)
WITH mt_o7_check AS (
  SELECT DISTINCT 
    UPPER(V.VALUE) AS PARAM_VALUE,
    DECODE(V.CON_ID,
      0, (SELECT NAME FROM V$DATABASE),
      1, (SELECT NAME FROM V$DATABASE),
      (SELECT NAME FROM V$PDBS B WHERE V.CON_ID = B.CON_ID)
    ) AS CONTAINER_NAME,
    V.CON_ID
  FROM V$SYSTEM_PARAMETER V
  WHERE UPPER(V.NAME) = 'O7_DICTIONARY_ACCESSIBILITY'
    AND EXISTS (SELECT 1 FROM v$instance WHERE version NOT LIKE '11.%')
    AND (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES'
    AND SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT'
)
SELECT CASE 
  WHEN mt_context.is_mt_context = 1 THEN
    '<tr class="' ||
    CASE 
      WHEN COUNT(*) = 0 THEN 'warning'
      WHEN COUNT(CASE WHEN moc.PARAM_VALUE != 'FALSE' AND moc.PARAM_VALUE IS NOT NULL THEN 1 END) = 0 THEN 'pass'
      ELSE 'fail'
    END || '">' ||
    '<td>2.2.5b</td>' ||
    '<td>Ensure O7_DICTIONARY_ACCESSIBILITY Is Set to FALSE - Multi-tenant (Scored)</td>' ||
    '<td>' || 
      CASE 
        WHEN COUNT(*) = 0 THEN 'N/A'
        WHEN COUNT(CASE WHEN moc.PARAM_VALUE != 'FALSE' AND moc.PARAM_VALUE IS NOT NULL THEN 1 END) = 0 THEN 'PASS'
        ELSE 'FAIL'
      END || '</td>' ||
    '<td>' || 
      CASE WHEN COUNT(*) > 0 THEN 
        LISTAGG(moc.CONTAINER_NAME || ':' || NVL(moc.PARAM_VALUE, 'FALSE(default)'), ', ') WITHIN GROUP (ORDER BY moc.CONTAINER_NAME)
      ELSE 'Parameter not found in containers'
      END || '</td>' ||
    '<td>FALSE for all containers</td>' ||
    '<td class="remediation">' ||
      CASE WHEN COUNT(*) = 0 THEN 'Parameter may not exist in this Oracle version'
      ELSE 'ALTER SYSTEM SET O7_DICTIONARY_ACCESSIBILITY=FALSE SCOPE = SPFILE; (run in each container)'
      END || '</td>' ||
    '</tr>'
  ELSE ''
END
FROM mt_o7_check moc
CROSS JOIN (
  SELECT CASE 
    WHEN EXISTS (SELECT 1 FROM v$instance WHERE version NOT LIKE '11.%') 
         AND (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES'
         AND SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT' THEN 1 
    ELSE 0 
  END AS is_mt_context FROM DUAL
) mt_context
GROUP BY mt_context.is_mt_context;

-- 2.2.6 OS_ROLES (11g)
WITH os_roles_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'OS_ROLES'
  WHERE vi.version LIKE '11.%'
),
os_roles_12c_non_mt AS (
  SELECT 
    vi.version,
    UPPER(vsp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'OS_ROLES'
  WHERE vi.version NOT LIKE '11.%' AND 
        ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
         ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
),
os_roles_combined AS (
  SELECT version, param_value FROM os_roles_11g
  UNION ALL
  SELECT version, param_value FROM os_roles_12c_non_mt
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(orc.param_value) = 'FALSE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.6a</td>' ||
  '<td>Ensure OS_ROLES Is Set to FALSE (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(orc.param_value) = 'FALSE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(orc.param_value), 'NULL') || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET OS_ROLES = FALSE SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM os_roles_combined orc;

-- 2.2.6 OS_ROLES (12c+ Multi-tenant Container Database)
WITH mt_os_roles AS (
  SELECT DISTINCT 
    UPPER(V.VALUE) AS PARAM_VALUE,
    DECODE(V.CON_ID,
      0, (SELECT NAME FROM V$DATABASE),
      1, (SELECT NAME FROM V$DATABASE),
      (SELECT NAME FROM V$PDBS B WHERE V.CON_ID = B.CON_ID)
    ) AS CONTAINER_NAME,
    V.CON_ID
  FROM V$SYSTEM_PARAMETER V
  WHERE UPPER(V.NAME) = 'OS_ROLES'
    AND EXISTS (SELECT 1 FROM v$instance WHERE version NOT LIKE '11.%')
    AND (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES'
    AND SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT'
)
SELECT CASE 
  WHEN mt_context.is_mt_context = 1 THEN
    '<tr class="' ||
    CASE 
      WHEN COUNT(CASE WHEN mor.PARAM_VALUE != 'FALSE' THEN 1 END) = 0 THEN 'pass'
      ELSE 'fail'
    END || '">' ||
    '<td>2.2.6b</td>' ||
    '<td>Ensure OS_ROLES Is Set to FALSE - Multi-tenant (Scored)</td>' ||
    '<td>' || CASE WHEN COUNT(CASE WHEN mor.PARAM_VALUE != 'FALSE' THEN 1 END) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
    '<td>' || 
      CASE WHEN COUNT(*) > 0 THEN 
        LISTAGG(mor.CONTAINER_NAME || ':' || NVL(mor.PARAM_VALUE, 'NULL'), ', ') WITHIN GROUP (ORDER BY mor.CONTAINER_NAME)
      ELSE 'No containers found'
      END || '</td>' ||
    '<td>FALSE for all containers</td>' ||
    '<td class="remediation">ALTER SYSTEM SET OS_ROLES = FALSE SCOPE = SPFILE; (run in each container)</td>' ||
    '</tr>'
  ELSE ''
END
FROM mt_os_roles mor
CROSS JOIN (
  SELECT CASE 
    WHEN EXISTS (SELECT 1 FROM v$instance WHERE version NOT LIKE '11.%') 
         AND (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES'
         AND SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT' THEN 1 
    ELSE 0 
  END AS is_mt_context FROM DUAL
) mt_context
GROUP BY mt_context.is_mt_context;

-- 2.2.7 REMOTE_LISTENER (11g)
WITH remote_listener_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'REMOTE_LISTENER'
  WHERE vi.version LIKE '11.%'
),
remote_listener_12c_non_mt AS (
  SELECT 
    vi.version,
    UPPER(vsp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'REMOTE_LISTENER'
  WHERE vi.version NOT LIKE '11.%' AND 
        ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
         ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
),
remote_listener_combined AS (
  SELECT version, param_value FROM remote_listener_11g
  UNION ALL
  SELECT version, param_value FROM remote_listener_12c_non_mt
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(rlc.param_value) IS NULL OR LENGTH(TRIM(MAX(rlc.param_value))) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.7a</td>' ||
  '<td>Ensure REMOTE_LISTENER Is Empty (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(rlc.param_value) IS NULL OR LENGTH(TRIM(MAX(rlc.param_value))) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(rlc.param_value), 'Empty') || '</td>' ||
  '<td>Empty</td>' ||
  '<td class="remediation">ALTER SYSTEM SET REMOTE_LISTENER = '''' SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM remote_listener_combined rlc;

-- 2.2.7 REMOTE_LISTENER (12c+ Multi-tenant Container Database)
WITH mt_remote_listener AS (
  SELECT DISTINCT 
    UPPER(V.VALUE) AS PARAM_VALUE,
    DECODE(V.CON_ID,
      0, (SELECT NAME FROM V$DATABASE),
      1, (SELECT NAME FROM V$DATABASE),
      (SELECT NAME FROM V$PDBS B WHERE V.CON_ID = B.CON_ID)
    ) AS CONTAINER_NAME,
    V.CON_ID
  FROM V$SYSTEM_PARAMETER V
  WHERE UPPER(V.NAME) = 'REMOTE_LISTENER'
    AND EXISTS (SELECT 1 FROM v$instance WHERE version NOT LIKE '11.%')
    AND (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES'
    AND SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT'
)
SELECT CASE 
  WHEN mt_context.is_mt_context = 1 THEN
    '<tr class="' ||
    CASE 
      WHEN COUNT(CASE WHEN mtrl.PARAM_VALUE IS NOT NULL AND LENGTH(TRIM(mtrl.PARAM_VALUE)) > 0 THEN 1 END) = 0 THEN 'pass'
      ELSE 'fail'
    END || '">' ||
    '<td>2.2.7b</td>' ||
    '<td>Ensure REMOTE_LISTENER Is Empty - Multi-tenant (Scored)</td>' ||
    '<td>' || CASE WHEN COUNT(CASE WHEN mtrl.PARAM_VALUE IS NOT NULL AND LENGTH(TRIM(mtrl.PARAM_VALUE)) > 0 THEN 1 END) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
    '<td>' || 
      CASE WHEN COUNT(*) > 0 THEN 
        LISTAGG(mtrl.CONTAINER_NAME || ':' || NVL(mtrl.PARAM_VALUE, 'Empty'), ', ') WITHIN GROUP (ORDER BY mtrl.CONTAINER_NAME)
      ELSE 'No containers found'
      END || '</td>' ||
    '<td>Empty for all containers</td>' ||
    '<td class="remediation">ALTER SYSTEM SET REMOTE_LISTENER = '''' SCOPE = SPFILE; (run in each container)</td>' ||
    '</tr>'
  ELSE ''
END
FROM mt_remote_listener mtrl
CROSS JOIN (
  SELECT CASE 
    WHEN EXISTS (SELECT 1 FROM v$instance WHERE version NOT LIKE '11.%') 
         AND (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES'
         AND SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT' THEN 1 
    ELSE 0 
  END AS is_mt_context FROM DUAL
) mt_context
GROUP BY mt_context.is_mt_context;

-- 2.2.8 REMOTE_LOGIN_PASSWORDFILE (11g)
WITH remote_login_pwdfile_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'REMOTE_LOGIN_PASSWORDFILE'
  WHERE vi.version LIKE '11.%'
),
remote_login_pwdfile_12c AS (
  SELECT 
    vi.version,
    UPPER(vsp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'REMOTE_LOGIN_PASSWORDFILE'
  WHERE vi.version NOT LIKE '11.%'
),
remote_login_pwdfile_combined AS (
  SELECT version, param_value FROM remote_login_pwdfile_11g
  UNION ALL
  SELECT version, param_value FROM remote_login_pwdfile_12c
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(rlpc.param_value) = 'NONE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.8</td>' ||
  '<td>Ensure REMOTE_LOGIN_PASSWORDFILE Is Set to NONE (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(rlpc.param_value) = 'NONE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(rlpc.param_value), 'NULL') || '</td>' ||
  '<td>NONE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET REMOTE_LOGIN_PASSWORDFILE = ''NONE'' SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM remote_login_pwdfile_combined rlpc;

-- 2.2.9 REMOTE_OS_AUTHENT (11g)
WITH remote_os_authent_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'REMOTE_OS_AUTHENT'
  WHERE vi.version LIKE '11.%'
),
remote_os_authent_12c AS (
  SELECT 
    vi.version,
    UPPER(vsp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'REMOTE_OS_AUTHENT'
  WHERE vi.version NOT LIKE '11.%'
),
remote_os_authent_combined AS (
  SELECT version, param_value FROM remote_os_authent_11g
  UNION ALL
  SELECT version, param_value FROM remote_os_authent_12c
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(roac.param_value) = 'FALSE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.9</td>' ||
  '<td>Ensure REMOTE_OS_AUTHENT Is Set to FALSE (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(roac.param_value) = 'FALSE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(roac.param_value), 'NULL') || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET REMOTE_OS_AUTHENT = FALSE SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM remote_os_authent_combined roac;

-- 2.2.10 REMOTE_OS_ROLES (11g)
WITH remote_os_roles_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'REMOTE_OS_ROLES'
  WHERE vi.version LIKE '11.%'
),
remote_os_roles_12c AS (
  SELECT 
    vi.version,
    UPPER(vsp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'REMOTE_OS_ROLES'
  WHERE vi.version NOT LIKE '11.%'
),
remote_os_roles_combined AS (
  SELECT version, param_value FROM remote_os_roles_11g
  UNION ALL
  SELECT version, param_value FROM remote_os_roles_12c
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(rorc.param_value) = 'FALSE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.10</td>' ||
  '<td>Ensure REMOTE_OS_ROLES Is Set to FALSE (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(rorc.param_value) = 'FALSE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(rorc.param_value), 'NULL') || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET REMOTE_OS_ROLES = FALSE SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM remote_os_roles_combined rorc;

-- 2.2.11 UTL_FILE_DIR (11g)
WITH utl_file_dir_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'UTL_FILE_DIR'
  WHERE vi.version LIKE '11.%'
),
utl_file_dir_12c_only AS (
  SELECT 
    vi.version,
    vsp.VALUE AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'UTL_FILE_DIR'
  WHERE vi.version LIKE '12.%'
),
utl_file_dir_18c_19c AS (
  SELECT 
    vi.version,
    'N/A' AS param_value
  FROM v$instance vi
  WHERE vi.version LIKE '18.%' OR vi.version LIKE '19.%'
),
utl_file_dir_combined AS (
  SELECT version, param_value FROM utl_file_dir_11g
  UNION ALL
  SELECT version, param_value FROM utl_file_dir_12c_only
  UNION ALL
  SELECT version, param_value FROM utl_file_dir_18c_19c
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(ufdc.param_value) = 'N/A' THEN 'warning'
    WHEN MAX(ufdc.param_value) IS NULL OR LENGTH(TRIM(MAX(ufdc.param_value))) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.11</td>' ||
  '<td>Ensure UTL_FILE_DIR Is Empty (Scored)</td>' ||
  '<td>' || 
    CASE 
      WHEN MAX(ufdc.param_value) = 'N/A' THEN 'N/A'
      WHEN MAX(ufdc.param_value) IS NULL OR LENGTH(TRIM(MAX(ufdc.param_value))) = 0 THEN 'PASS' 
      ELSE 'FAIL' 
    END || '</td>' ||
  '<td>' || 
    CASE 
      WHEN MAX(ufdc.param_value) = 'N/A' THEN 'Parameter deprecated in 18c+'
      ELSE NVL(MAX(ufdc.param_value), 'Empty')
    END || '</td>' ||
  '<td>Empty (deprecated in 18c+)</td>' ||
  '<td class="remediation">' ||
    CASE 
      WHEN MAX(ufdc.param_value) = 'N/A' THEN 'Use UTL_FILE_DIR initialization parameter is deprecated in 18c+. Use CREATE DIRECTORY instead.'
      ELSE 'ALTER SYSTEM SET UTL_FILE_DIR = '''' SCOPE = SPFILE;'
    END || '</td>' ||
  '</tr>'
ELSE '' END
FROM utl_file_dir_combined ufdc;

-- 2.2.12 SEC_CASE_SENSITIVE_LOGON (11g)
WITH sec_case_sensitive_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'SEC_CASE_SENSITIVE_LOGON'
  WHERE vi.version LIKE '11.%'
),
sec_case_sensitive_12c AS (
  SELECT 
    vi.version,
    UPPER(vsp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'SEC_CASE_SENSITIVE_LOGON'
  WHERE vi.version NOT LIKE '11.%'
),
sec_case_sensitive_combined AS (
  SELECT version, param_value FROM sec_case_sensitive_11g
  UNION ALL
  SELECT version, param_value FROM sec_case_sensitive_12c
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(scsc.param_value) = 'TRUE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.12</td>' ||
  '<td>Ensure SEC_CASE_SENSITIVE_LOGON Is Set to TRUE (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(scsc.param_value) = 'TRUE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(scsc.param_value), 'NULL') || '</td>' ||
  '<td>TRUE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET SEC_CASE_SENSITIVE_LOGON = TRUE SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM sec_case_sensitive_combined scsc;

-- 2.2.13 SEC_MAX_FAILED_LOGIN_ATTEMPTS (11g)
WITH sec_max_failed_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'SEC_MAX_FAILED_LOGIN_ATTEMPTS'
  WHERE vi.version LIKE '11.%'
),
sec_max_failed_12c AS (
  SELECT 
    vi.version,
    UPPER(vsp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'SEC_MAX_FAILED_LOGIN_ATTEMPTS'
  WHERE vi.version NOT LIKE '11.%'
),
sec_max_failed_combined AS (
  SELECT version, param_value FROM sec_max_failed_11g
  UNION ALL
  SELECT version, param_value FROM sec_max_failed_12c
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(smfc.param_value) = '3' OR (REGEXP_LIKE(MAX(smfc.param_value), '^[0-9]+$') AND TO_NUMBER(MAX(smfc.param_value)) = 3) THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.13</td>' ||
  '<td>Ensure SEC_MAX_FAILED_LOGIN_ATTEMPTS Is Set to 3 (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(smfc.param_value) = '3' OR (REGEXP_LIKE(MAX(smfc.param_value), '^[0-9]+$') AND TO_NUMBER(MAX(smfc.param_value)) = 3) THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(smfc.param_value), 'NULL') || '</td>' ||
  '<td>3</td>' ||
  '<td class="remediation">ALTER SYSTEM SET SEC_MAX_FAILED_LOGIN_ATTEMPTS = 3 SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM sec_max_failed_combined smfc;

-- 2.2.14 SEC_PROTOCOL_ERROR_FURTHER_ACTION (11g)
WITH sec_protocol_further_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'SEC_PROTOCOL_ERROR_FURTHER_ACTION'
  WHERE vi.version LIKE '11.%'
),
sec_protocol_further_12c AS (
  SELECT 
    vi.version,
    UPPER(vsp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'SEC_PROTOCOL_ERROR_FURTHER_ACTION'
  WHERE vi.version NOT LIKE '11.%'
),
sec_protocol_further_combined AS (
  SELECT version, param_value FROM sec_protocol_further_11g
  UNION ALL
  SELECT version, param_value FROM sec_protocol_further_12c
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(spfc.param_value) LIKE '%DROP%3%' OR MAX(spfc.param_value) LIKE '%DELAY%3%' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.14</td>' ||
  '<td>Ensure SEC_PROTOCOL_ERROR_FURTHER_ACTION Is Set to DELAY,3 or DROP,3 (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(spfc.param_value) LIKE '%DROP%3%' OR MAX(spfc.param_value) LIKE '%DELAY%3%' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(spfc.param_value), 'Not Set') || '</td>' ||
  '<td>DELAY,3 or DROP,3</td>' ||
  '<td class="remediation">ALTER SYSTEM SET SEC_PROTOCOL_ERROR_FURTHER_ACTION = ''DELAY,3'' SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM sec_protocol_further_combined spfc;

-- 2.2.15 SEC_PROTOCOL_ERROR_TRACE_ACTION (11g)
WITH sec_protocol_trace_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'SEC_PROTOCOL_ERROR_TRACE_ACTION'
  WHERE vi.version LIKE '11.%'
),
sec_protocol_trace_12c AS (
  SELECT 
    vi.version,
    UPPER(vsp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'SEC_PROTOCOL_ERROR_TRACE_ACTION'
  WHERE vi.version NOT LIKE '11.%'
),
sec_protocol_trace_combined AS (
  SELECT version, param_value FROM sec_protocol_trace_11g
  UNION ALL
  SELECT version, param_value FROM sec_protocol_trace_12c
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(sptc.param_value) = 'LOG' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.15</td>' ||
  '<td>Ensure SEC_PROTOCOL_ERROR_TRACE_ACTION Is Set to LOG (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(sptc.param_value) = 'LOG' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(sptc.param_value), 'Not Set') || '</td>' ||
  '<td>LOG</td>' ||
  '<td class="remediation">ALTER SYSTEM SET SEC_PROTOCOL_ERROR_TRACE_ACTION=LOG SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM sec_protocol_trace_combined sptc;

-- 2.2.16 SEC_RETURN_SERVER_RELEASE_BANNER (11g)
WITH sec_return_banner_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'SEC_RETURN_SERVER_RELEASE_BANNER'
  WHERE vi.version LIKE '11.%'
),
sec_return_banner_12c_non_mt AS (
  SELECT 
    vi.version,
    UPPER(vsp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'SEC_RETURN_SERVER_RELEASE_BANNER'
  WHERE vi.version NOT LIKE '11.%' AND 
        ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
         ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
),
sec_return_banner_combined AS (
  SELECT version, param_value FROM sec_return_banner_11g
  UNION ALL
  SELECT version, param_value FROM sec_return_banner_12c_non_mt
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(srbc.param_value) = 'FALSE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.16</td>' ||
  '<td>Ensure SEC_RETURN_SERVER_RELEASE_BANNER Is Set to FALSE (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(srbc.param_value) = 'FALSE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(srbc.param_value), 'Not Set') || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET SEC_RETURN_SERVER_RELEASE_BANNER = FALSE SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM sec_return_banner_combined srbc;

-- 2.2.17 SQL92_SECURITY (11g and 12c+)
WITH sql92_security_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'SQL92_SECURITY'
  WHERE vi.version LIKE '11.%'
),
sql92_security_12c AS (
  SELECT 
    vi.version,
    UPPER(vsp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'SQL92_SECURITY'
  WHERE vi.version NOT LIKE '11.%'
),
sql92_security_combined AS (
  SELECT version, param_value FROM sql92_security_11g
  UNION ALL
  SELECT version, param_value FROM sql92_security_12c
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(ssc.param_value) = 'TRUE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.17</td>' ||
  '<td>Ensure SQL92_SECURITY Is Set to TRUE (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(ssc.param_value) = 'TRUE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(ssc.param_value), 'Not Set') || '</td>' ||
  '<td>TRUE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET SQL92_SECURITY = TRUE SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM sql92_security_combined ssc;

-- 2.2.17b SQL92_SECURITY (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(DISTINCT CASE WHEN UPPER(V.VALUE) != 'TRUE' THEN 1 END) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.17b</td>' ||
  '<td>Ensure SQL92_SECURITY Is Set to TRUE in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(DISTINCT CASE WHEN UPPER(V.VALUE) != 'TRUE' THEN 1 END) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || LISTAGG(DECODE(V.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE V.CON_ID = B.CON_ID)) || ':' || V.VALUE, '; ') WITHIN GROUP (ORDER BY V.CON_ID) || '</td>' ||
  '<td>TRUE for all containers</td>' ||
  '<td class="remediation">For each container: ALTER SYSTEM SET SQL92_SECURITY = TRUE SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    v.CON_ID,
    v.VALUE
  FROM V$SYSTEM_PARAMETER v
  WHERE UPPER(v.NAME) = 'SQL92_SECURITY'
) V
GROUP BY ef.env_type;

-- 2.2.18 _TRACE_FILES_PUBLIC (11g and 12c+)
WITH trace_files_public_11g AS (
  SELECT 
    vi.version,
    vp.VALUE AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON vp.NAME = '_trace_files_public'
  WHERE vi.version LIKE '11.%'
),
trace_files_public_12c AS (
  SELECT 
    vi.version,
    b.KSPPSTVL AS param_value
  FROM v$instance vi
  LEFT JOIN (
    SELECT b.KSPPSTVL
    FROM SYS.X$KSPPI a, SYS.X$KSPPCV b
    WHERE A.INDX = B.INDX
    AND A.KSPPINM LIKE '\_%trace_files_public' ESCAPE '\'
  ) b ON 1=1
  WHERE vi.version NOT LIKE '11.%'
),
trace_files_public_combined AS (
  SELECT version, param_value FROM trace_files_public_11g
  UNION ALL
  SELECT version, param_value FROM trace_files_public_12c
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(tfpc.param_value) = 'FALSE' OR MAX(tfpc.param_value) IS NULL THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.18</td>' ||
  '<td>Ensure _TRACE_FILES_PUBLIC Is Set to FALSE (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(tfpc.param_value) = 'FALSE' OR MAX(tfpc.param_value) IS NULL THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(tfpc.param_value), 'FALSE (default)') || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET "_trace_files_public" = FALSE SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM trace_files_public_combined tfpc;

-- 2.2.19 RESOURCE_LIMIT (11g and 12c+ non-multitenant/PDB)
WITH resource_limit_11g AS (
  SELECT 
    vi.version,
    UPPER(vp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$PARAMETER vp ON UPPER(vp.NAME) = 'RESOURCE_LIMIT'
  WHERE vi.version LIKE '11.%'
),
resource_limit_12c_non_mt AS (
  SELECT 
    vi.version,
    UPPER(vsp.VALUE) AS param_value
  FROM v$instance vi
  LEFT JOIN V$SYSTEM_PARAMETER vsp ON UPPER(vsp.NAME) = 'RESOURCE_LIMIT'
  WHERE vi.version NOT LIKE '11.%' AND 
        ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
         ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
),
resource_limit_combined AS (
  SELECT version, param_value FROM resource_limit_11g
  UNION ALL
  SELECT version, param_value FROM resource_limit_12c_non_mt
)
SELECT CASE WHEN COUNT(*) > 0 THEN
  '<tr class="' ||
  CASE 
    WHEN MAX(rlc.param_value) = 'TRUE' THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.19</td>' ||
  '<td>Ensure RESOURCE_LIMIT Is Set to TRUE (Scored)</td>' ||
  '<td>' || CASE WHEN MAX(rlc.param_value) = 'TRUE' THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(MAX(rlc.param_value), 'Not Set') || '</td>' ||
  '<td>TRUE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET RESOURCE_LIMIT = TRUE SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM resource_limit_combined rlc;

-- 2.2.19b RESOURCE_LIMIT (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(DISTINCT CASE WHEN UPPER(V.VALUE) != 'TRUE' THEN 1 END) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.19b</td>' ||
  '<td>Ensure RESOURCE_LIMIT Is Set to TRUE in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(DISTINCT CASE WHEN UPPER(V.VALUE) != 'TRUE' THEN 1 END) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || LISTAGG(DECODE(V.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE V.CON_ID = B.CON_ID)) || ':' || V.VALUE, '; ') WITHIN GROUP (ORDER BY V.CON_ID) || '</td>' ||
  '<td>TRUE for all containers</td>' ||
  '<td class="remediation">For each container: ALTER SYSTEM SET RESOURCE_LIMIT = TRUE SCOPE = SPFILE;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    v.CON_ID,
    v.VALUE
  FROM V$SYSTEM_PARAMETER v
  WHERE UPPER(v.NAME) = 'RESOURCE_LIMIT'
) V
GROUP BY ef.env_type;

-- 2.2.20 PDB_OS_CREDENTIAL (18c+ only)
SELECT CASE WHEN vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(vsp.VALUE) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.20</td>' ||
  '<td>Ensure PDB_OS_CREDENTIAL Is Set to NULL (18c+) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(vsp.VALUE) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(vsp.VALUE) > 0 THEN 
      LISTAGG(DECODE(vsp.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE vsp.CON_ID = B.CON_ID)) || ':' || vsp.VALUE, '; ') WITHIN GROUP (ORDER BY vsp.CON_ID)
    ELSE 'NULL (compliant)'
    END || '</td>' ||
  '<td>NULL for all containers</td>' ||
  '<td class="remediation">Using DBMS_CREDENTIAL package, ensure credentials are set for standalone, container and pluggable databases</td>' ||
  '</tr>'
ELSE '' END
FROM v$instance vi
CROSS JOIN (
  SELECT CON_ID, VALUE
  FROM V$SYSTEM_PARAMETER
  WHERE UPPER(NAME) = 'PDB_OS_CREDENTIAL' AND VALUE IS NOT NULL
) vsp
GROUP BY vi.version;

-- 12c+ Specific Parameters
SELECT CASE WHEN vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN UPPER(vp.VALUE) IN ('C##', 'c##') THEN 'pass'
    ELSE 'warning'
  END || '">' ||
  '<td>2.2.21</td>' ||
  '<td>Ensure COMMON_USER_PREFIX Is Set Appropriately (12c+) (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(vp.VALUE) IN ('C##', 'c##') THEN 'PASS' ELSE 'WARNING' END || '</td>' ||
  '<td>' || NVL(vp.VALUE, 'Not Set') || '</td>' ||
  '<td>C## (default)</td>' ||
  '<td class="remediation">Maintain default or set organizational standard</td>' ||
  '</tr>'
ELSE '' END
FROM V$PARAMETER vp CROSS JOIN v$instance vi
WHERE UPPER(vp.NAME) = 'COMMON_USER_PREFIX';

-- 12c+ ENABLE_DDL_LOGGING
SELECT CASE WHEN vi.version LIKE '12.%' OR vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN UPPER(vp.VALUE) = 'TRUE' THEN 'pass'
    ELSE 'warning'
  END || '">' ||
  '<td>2.2.22</td>' ||
  '<td>Ensure ENABLE_DDL_LOGGING Is Set to TRUE (12c+) (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(vp.VALUE) = 'TRUE' THEN 'PASS' ELSE 'WARNING' END || '</td>' ||
  '<td>' || vp.VALUE || '</td>' ||
  '<td>TRUE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET ENABLE_DDL_LOGGING=TRUE</td>' ||
  '</tr>'
ELSE '' END
FROM V$PARAMETER vp CROSS JOIN v$instance vi
WHERE UPPER(vp.NAME) = 'ENABLE_DDL_LOGGING';

-- 18c+ LDAP_DIRECTORY_SYSAUTH
SELECT CASE WHEN vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN UPPER(vp.VALUE) = 'NO' OR vp.VALUE IS NULL THEN 'pass'
    ELSE 'warning'
  END || '">' ||
  '<td>2.2.23</td>' ||
  '<td>Ensure LDAP_DIRECTORY_SYSAUTH Is Set to NO (18c+) (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(vp.VALUE) = 'NO' OR vp.VALUE IS NULL THEN 'PASS' ELSE 'WARNING' END || '</td>' ||
  '<td>' || NVL(vp.VALUE, 'NO (default)') || '</td>' ||
  '<td>NO</td>' ||
  '<td class="remediation">ALTER SYSTEM SET LDAP_DIRECTORY_SYSAUTH=NO SCOPE=SPFILE</td>' ||
  '</tr>'
ELSE '' END
FROM V$PARAMETER vp CROSS JOIN v$instance vi
WHERE UPPER(vp.NAME) = 'LDAP_DIRECTORY_SYSAUTH';

-- 19c+ ALLOW_GROUP_ACCESS_TO_SGA
SELECT CASE WHEN vi.version LIKE '19.%' THEN
  '<tr class="' ||
  CASE 
    WHEN UPPER(vp.VALUE) = 'FALSE' OR vp.VALUE IS NULL THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>2.2.24</td>' ||
  '<td>Ensure ALLOW_GROUP_ACCESS_TO_SGA Is Set to FALSE (19c) (Scored)</td>' ||
  '<td>' || CASE WHEN UPPER(vp.VALUE) = 'FALSE' OR vp.VALUE IS NULL THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || NVL(vp.VALUE, 'FALSE (default)') || '</td>' ||
  '<td>FALSE</td>' ||
  '<td class="remediation">ALTER SYSTEM SET ALLOW_GROUP_ACCESS_TO_SGA=FALSE SCOPE=SPFILE</td>' ||
  '</tr>'
ELSE '' END
FROM V$PARAMETER vp CROSS JOIN v$instance vi
WHERE UPPER(vp.NAME) = 'ALLOW_GROUP_ACCESS_TO_SGA';

PROMPT </table>

-- Section 2.3: SQLNET.ORA Settings (18c+)
SELECT CASE WHEN vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<h2 id="section2_3">2.3 SQLNET.ORA Settings (18c+)</h2>' ||
  '<table>' ||
  '<tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>'
ELSE '' END
FROM v$instance vi;

-- 2.3.1 ENCRYPTION_SERVER (18c+)
SELECT CASE WHEN vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="warning">' ||
  '<td>2.3.1</td>' ||
  '<td>Ensure ENCRYPTION_SERVER Is Set to REQUIRED (18c+) (Scored)</td>' ||
  '<td>MANUAL_CHECK</td>' ||
  '<td>Execute: grep -i "encryption_server=required" $ORACLE_HOME/network/admin/sqlnet.ora</td>' ||
  '<td>REQUIRED</td>' ||
  '<td class="remediation">Edit $ORACLE_HOME/network/admin/sqlnet.ora: encryption_server = required</td>' ||
  '</tr>'
ELSE '' END
FROM v$instance vi;

-- 2.3.2 SQLNET.CRYPTO_CHECKSUM_SERVER (18c+)
SELECT CASE WHEN vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '<tr class="warning">' ||
  '<td>2.3.2</td>' ||
  '<td>Ensure SQLNET.CRYPTO_CHECKSUM_SERVER Is Set to REQUIRED (18c+) (Scored)</td>' ||
  '<td>MANUAL_CHECK</td>' ||
  '<td>Execute: grep -i "crypto_checksum_server=required" $ORACLE_HOME/network/admin/sqlnet.ora</td>' ||
  '<td>REQUIRED</td>' ||
  '<td class="remediation">Edit $ORACLE_HOME/network/admin/sqlnet.ora: sqlnet.crypto_checksum_server = required</td>' ||
  '</tr>'
ELSE '' END
FROM v$instance vi;

SELECT CASE WHEN vi.version LIKE '18.%' OR vi.version LIKE '19.%' THEN
  '</table>'
ELSE '' END
FROM v$instance vi;

-- Section 3: Oracle Connection and Login Restrictions
PROMPT <h2 id="section3">3. Oracle Connection and Login Restrictions</h2>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 3.1 FAILED_LOGIN_ATTEMPTS (11g and 12c+ non-multitenant/PDB)
WITH failed_login_11g AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version LIKE '11.%'
  AND p.RESOURCE_NAME = 'FAILED_LOGIN_ATTEMPTS'
  AND (p.LIMIT = 'DEFAULT' OR p.LIMIT = 'UNLIMITED' OR TO_NUMBER(p.LIMIT) > 5)
),
failed_login_12c_non_mt AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND TO_NUMBER(DECODE(p.LIMIT,
        'DEFAULT',(SELECT DISTINCT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                   FROM DBA_PROFILES
                   WHERE PROFILE='DEFAULT'
                   AND RESOURCE_NAME='FAILED_LOGIN_ATTEMPTS'),
        'UNLIMITED','9999',
        p.LIMIT)) > 5
  AND p.RESOURCE_NAME = 'FAILED_LOGIN_ATTEMPTS'
  AND EXISTS (SELECT 'X' FROM DBA_USERS u WHERE u.PROFILE = p.PROFILE)
),
failed_login_combined AS (
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM failed_login_11g
  UNION ALL
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM failed_login_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM failed_login_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.1</td>' ||
  '<td>Ensure FAILED_LOGIN_ATTEMPTS Is Less than or Equal to 5 (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM failed_login_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM failed_login_combined) > 0 THEN 
      (SELECT LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE) FROM failed_login_combined)
    ELSE 'All profiles compliant (5 or less)'
    END || '</td>' ||
  '<td>Less than or equal to 5 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT FAILED_LOGIN_ATTEMPTS 5;</td>' ||
  '</tr>'
FROM DUAL;

-- 3.1b FAILED_LOGIN_ATTEMPTS (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(P.PROFILE) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.1b</td>' ||
  '<td>Ensure FAILED_LOGIN_ATTEMPTS Is Less than or Equal to 5 in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(P.PROFILE) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(P.PROFILE) > 0 THEN 
      LISTAGG(DECODE(P.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE P.CON_ID = B.CON_ID)) || ':' || P.PROFILE || ':' || P.LIMIT, '; ') WITHIN GROUP (ORDER BY P.CON_ID, P.PROFILE)
    ELSE 'All profiles compliant in all containers'
    END || '</td>' ||
  '<td>Less than or equal to 5 for all profiles in all containers</td>' ||
  '<td class="remediation">For each container: ALTER PROFILE DEFAULT LIMIT FAILED_LOGIN_ATTEMPTS 5;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    p.CON_ID,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM CDB_PROFILES p
  WHERE TO_NUMBER(DECODE(p.LIMIT,
          'DEFAULT',(SELECT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                     FROM CDB_PROFILES
                     WHERE PROFILE='DEFAULT'
                     AND RESOURCE_NAME='FAILED_LOGIN_ATTEMPTS'
                     AND CON_ID = p.CON_ID),
          'UNLIMITED','9999',p.LIMIT)) > 5
  AND p.RESOURCE_NAME = 'FAILED_LOGIN_ATTEMPTS'
  AND EXISTS (SELECT 'X' FROM CDB_USERS u WHERE u.PROFILE = p.PROFILE AND u.CON_ID = p.CON_ID)
) P
GROUP BY ef.env_type;

-- 3.2 PASSWORD_LOCK_TIME (11g and 12c+ non-multitenant/PDB)
WITH password_lock_11g AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version LIKE '11.%'
  AND p.RESOURCE_NAME = 'PASSWORD_LOCK_TIME'
  AND (p.LIMIT = 'DEFAULT' OR p.LIMIT = 'UNLIMITED' OR TO_NUMBER(p.LIMIT) < 1)
),
password_lock_12c_non_mt AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND TO_NUMBER(DECODE(p.LIMIT,
        'DEFAULT',(SELECT DISTINCT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                   FROM DBA_PROFILES
                   WHERE PROFILE='DEFAULT'
                   AND RESOURCE_NAME='PASSWORD_LOCK_TIME'),
        'UNLIMITED','9999',
        p.LIMIT)) < 1
  AND p.RESOURCE_NAME = 'PASSWORD_LOCK_TIME'
  AND EXISTS (SELECT 'X' FROM DBA_USERS u WHERE u.PROFILE = p.PROFILE)
),
password_lock_combined AS (
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM password_lock_11g
  UNION ALL
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM password_lock_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM password_lock_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.2</td>' ||
  '<td>Ensure PASSWORD_LOCK_TIME Is Greater than or Equal to 1 (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM password_lock_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM password_lock_combined) > 0 THEN 
      (SELECT LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE) FROM password_lock_combined)
    ELSE 'All profiles compliant (1 or more)'
    END || '</td>' ||
  '<td>Greater than or equal to 1 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT PASSWORD_LOCK_TIME 1;</td>' ||
  '</tr>'
FROM DUAL;

-- 3.2b PASSWORD_LOCK_TIME (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(P.PROFILE) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.2b</td>' ||
  '<td>Ensure PASSWORD_LOCK_TIME Is Greater than or Equal to 1 in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(P.PROFILE) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(P.PROFILE) > 0 THEN 
      LISTAGG(DECODE(P.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE P.CON_ID = B.CON_ID)) || ':' || P.PROFILE || ':' || P.LIMIT, '; ') WITHIN GROUP (ORDER BY P.CON_ID, P.PROFILE)
    ELSE 'All profiles compliant in all containers'
    END || '</td>' ||
  '<td>Greater than or equal to 1 for all profiles in all containers</td>' ||
  '<td class="remediation">For each container: ALTER PROFILE DEFAULT LIMIT PASSWORD_LOCK_TIME 1;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    p.CON_ID,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM CDB_PROFILES p
  WHERE TO_NUMBER(DECODE(p.LIMIT,
          'DEFAULT',(SELECT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                     FROM CDB_PROFILES
                     WHERE PROFILE='DEFAULT'
                     AND RESOURCE_NAME='PASSWORD_LOCK_TIME'
                     AND CON_ID = p.CON_ID),
          'UNLIMITED','9999',p.LIMIT)) < 1
  AND p.RESOURCE_NAME = 'PASSWORD_LOCK_TIME'
  AND EXISTS (SELECT 'X' FROM CDB_USERS u WHERE u.PROFILE = p.PROFILE AND u.CON_ID = p.CON_ID)
) P
GROUP BY ef.env_type;

-- 3.3 PASSWORD_LIFE_TIME (11g and 12c+ non-multitenant/PDB)
WITH password_life_11g AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version LIKE '11.%'
  AND p.RESOURCE_NAME = 'PASSWORD_LIFE_TIME'
  AND (p.LIMIT = 'DEFAULT' OR p.LIMIT = 'UNLIMITED' OR TO_NUMBER(p.LIMIT) > 90)
),
password_life_12c_non_mt AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND TO_NUMBER(DECODE(p.LIMIT,
        'DEFAULT',(SELECT DISTINCT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                   FROM DBA_PROFILES
                   WHERE PROFILE='DEFAULT'
                   AND RESOURCE_NAME='PASSWORD_LIFE_TIME'),
        'UNLIMITED','9999',
        p.LIMIT)) > 90
  AND p.RESOURCE_NAME = 'PASSWORD_LIFE_TIME'
  AND EXISTS (SELECT 'X' FROM DBA_USERS u WHERE u.PROFILE = p.PROFILE)
),
password_life_combined AS (
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM password_life_11g
  UNION ALL
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM password_life_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM password_life_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.3</td>' ||
  '<td>Ensure PASSWORD_LIFE_TIME Is Less than or Equal to 90 (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM password_life_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM password_life_combined) > 0 THEN 
      (SELECT LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE) FROM password_life_combined)
    ELSE 'All profiles compliant (90 or less)'
    END || '</td>' ||
  '<td>Less than or equal to 90 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME 90;</td>' ||
  '</tr>'
FROM DUAL;

-- 3.3b PASSWORD_LIFE_TIME (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(P.PROFILE) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.3b</td>' ||
  '<td>Ensure PASSWORD_LIFE_TIME Is Less than or Equal to 90 in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(P.PROFILE) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(P.PROFILE) > 0 THEN 
      LISTAGG(DECODE(P.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE P.CON_ID = B.CON_ID)) || ':' || P.PROFILE || ':' || P.LIMIT, '; ') WITHIN GROUP (ORDER BY P.CON_ID, P.PROFILE)
    ELSE 'All profiles compliant in all containers'
    END || '</td>' ||
  '<td>Less than or equal to 90 for all profiles in all containers</td>' ||
  '<td class="remediation">For each container: ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME 90;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    p.CON_ID,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM CDB_PROFILES p
  WHERE TO_NUMBER(DECODE(p.LIMIT,
          'DEFAULT',(SELECT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                     FROM CDB_PROFILES
                     WHERE PROFILE='DEFAULT'
                     AND RESOURCE_NAME='PASSWORD_LIFE_TIME'
                     AND CON_ID = p.CON_ID),
          'UNLIMITED','9999',p.LIMIT)) > 90
  AND p.RESOURCE_NAME = 'PASSWORD_LIFE_TIME'
  AND EXISTS (SELECT 'X' FROM CDB_USERS u WHERE u.PROFILE = p.PROFILE AND u.CON_ID = p.CON_ID)
) P
GROUP BY ef.env_type;

-- 3.4 PASSWORD_REUSE_MAX (11g and 12c+ non-multitenant/PDB)
WITH password_reuse_max_11g AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version LIKE '11.%'
  AND p.RESOURCE_NAME = 'PASSWORD_REUSE_MAX'
  AND (p.LIMIT = 'DEFAULT' OR p.LIMIT = 'UNLIMITED' OR TO_NUMBER(p.LIMIT) < 20)
),
password_reuse_max_12c_non_mt AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND TO_NUMBER(DECODE(p.LIMIT,
        'DEFAULT',(SELECT DISTINCT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                   FROM DBA_PROFILES
                   WHERE PROFILE='DEFAULT'
                   AND RESOURCE_NAME='PASSWORD_REUSE_MAX'),
        'UNLIMITED','9999',
        p.LIMIT)) < 20
  AND p.RESOURCE_NAME = 'PASSWORD_REUSE_MAX'
  AND EXISTS (SELECT 'X' FROM DBA_USERS u WHERE u.PROFILE = p.PROFILE)
),
password_reuse_max_combined AS (
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM password_reuse_max_11g
  UNION ALL
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM password_reuse_max_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM password_reuse_max_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.4</td>' ||
  '<td>Ensure PASSWORD_REUSE_MAX Is Greater than or Equal to 20 (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM password_reuse_max_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM password_reuse_max_combined) > 0 THEN 
      (SELECT LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE) FROM password_reuse_max_combined)
    ELSE 'All profiles compliant (20 or more)'
    END || '</td>' ||
  '<td>Greater than or equal to 20 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_MAX 20;</td>' ||
  '</tr>'
FROM DUAL;

-- 3.4b PASSWORD_REUSE_MAX (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(P.PROFILE) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.4b</td>' ||
  '<td>Ensure PASSWORD_REUSE_MAX Is Greater than or Equal to 20 in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(P.PROFILE) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(P.PROFILE) > 0 THEN 
      LISTAGG(DECODE(P.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE P.CON_ID = B.CON_ID)) || ':' || P.PROFILE || ':' || P.LIMIT, '; ') WITHIN GROUP (ORDER BY P.CON_ID, P.PROFILE)
    ELSE 'All profiles compliant in all containers'
    END || '</td>' ||
  '<td>Greater than or equal to 20 for all profiles in all containers</td>' ||
  '<td class="remediation">For each container: ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_MAX 20;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    p.CON_ID,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM CDB_PROFILES p
  WHERE TO_NUMBER(DECODE(p.LIMIT,
          'DEFAULT',(SELECT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                     FROM CDB_PROFILES
                     WHERE PROFILE='DEFAULT'
                     AND RESOURCE_NAME='PASSWORD_REUSE_MAX'
                     AND CON_ID = p.CON_ID),
          'UNLIMITED','9999',p.LIMIT)) < 20
  AND p.RESOURCE_NAME = 'PASSWORD_REUSE_MAX'
  AND EXISTS (SELECT 'X' FROM CDB_USERS u WHERE u.PROFILE = p.PROFILE AND u.CON_ID = p.CON_ID)
) P
GROUP BY ef.env_type;

-- 3.5 PASSWORD_REUSE_TIME (11g and 12c+ non-multitenant/PDB)
WITH password_reuse_time_11g AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version LIKE '11.%'
  AND p.RESOURCE_NAME = 'PASSWORD_REUSE_TIME'
  AND (p.LIMIT = 'DEFAULT' OR p.LIMIT = 'UNLIMITED' OR TO_NUMBER(p.LIMIT) < 365)
),
password_reuse_time_12c_non_mt AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND TO_NUMBER(DECODE(p.LIMIT,
        'DEFAULT',(SELECT DISTINCT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                   FROM DBA_PROFILES
                   WHERE PROFILE='DEFAULT'
                   AND RESOURCE_NAME='PASSWORD_REUSE_TIME'),
        'UNLIMITED','9999',
        p.LIMIT)) < 365
  AND p.RESOURCE_NAME = 'PASSWORD_REUSE_TIME'
  AND EXISTS (SELECT 'X' FROM DBA_USERS u WHERE u.PROFILE = p.PROFILE)
),
password_reuse_time_combined AS (
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM password_reuse_time_11g
  UNION ALL
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM password_reuse_time_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM password_reuse_time_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.5</td>' ||
  '<td>Ensure PASSWORD_REUSE_TIME Is Greater than or Equal to 365 (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM password_reuse_time_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM password_reuse_time_combined) > 0 THEN 
      (SELECT LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE) FROM password_reuse_time_combined)
    ELSE 'All profiles compliant (365 or more)'
    END || '</td>' ||
  '<td>Greater than or equal to 365 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_TIME 365;</td>' ||
  '</tr>'
FROM DUAL;

-- 3.5b PASSWORD_REUSE_TIME (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(P.PROFILE) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.5b</td>' ||
  '<td>Ensure PASSWORD_REUSE_TIME Is Greater than or Equal to 365 in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(P.PROFILE) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(P.PROFILE) > 0 THEN 
      LISTAGG(DECODE(P.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE P.CON_ID = B.CON_ID)) || ':' || P.PROFILE || ':' || P.LIMIT, '; ') WITHIN GROUP (ORDER BY P.CON_ID, P.PROFILE)
    ELSE 'All profiles compliant in all containers'
    END || '</td>' ||
  '<td>Greater than or equal to 365 for all profiles in all containers</td>' ||
  '<td class="remediation">For each container: ALTER PROFILE DEFAULT LIMIT PASSWORD_REUSE_TIME 365;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    p.CON_ID,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM CDB_PROFILES p
  WHERE TO_NUMBER(DECODE(p.LIMIT,
          'DEFAULT',(SELECT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                     FROM CDB_PROFILES
                     WHERE PROFILE='DEFAULT'
                     AND RESOURCE_NAME='PASSWORD_REUSE_TIME'
                     AND CON_ID = p.CON_ID),
          'UNLIMITED','9999',p.LIMIT)) < 365
  AND p.RESOURCE_NAME = 'PASSWORD_REUSE_TIME'
  AND EXISTS (SELECT 'X' FROM CDB_USERS u WHERE u.PROFILE = p.PROFILE AND u.CON_ID = p.CON_ID)
) P
GROUP BY ef.env_type;

-- 3.6 PASSWORD_GRACE_TIME (11g and 12c+ non-multitenant/PDB)
WITH password_grace_11g AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version LIKE '11.%'
  AND p.RESOURCE_NAME = 'PASSWORD_GRACE_TIME'
  AND (p.LIMIT = 'DEFAULT' OR p.LIMIT = 'UNLIMITED' OR TO_NUMBER(p.LIMIT) > 5)
),
password_grace_12c_non_mt AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND TO_NUMBER(DECODE(p.LIMIT,
        'DEFAULT',(SELECT DISTINCT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                   FROM DBA_PROFILES
                   WHERE PROFILE='DEFAULT'
                   AND RESOURCE_NAME='PASSWORD_GRACE_TIME'),
        'UNLIMITED','9999',
        p.LIMIT)) > 5
  AND p.RESOURCE_NAME = 'PASSWORD_GRACE_TIME'
  AND EXISTS (SELECT 'X' FROM DBA_USERS u WHERE u.PROFILE = p.PROFILE)
),
password_grace_combined AS (
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM password_grace_11g
  UNION ALL
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM password_grace_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM password_grace_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.6</td>' ||
  '<td>Ensure PASSWORD_GRACE_TIME Is Less than or Equal to 5 (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM password_grace_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM password_grace_combined) > 0 THEN 
      (SELECT LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE) FROM password_grace_combined)
    ELSE 'All profiles compliant (5 or less)'
    END || '</td>' ||
  '<td>Less than or equal to 5 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT PASSWORD_GRACE_TIME 5;</td>' ||
  '</tr>'
FROM DUAL;

-- 3.6b PASSWORD_GRACE_TIME (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(P.PROFILE) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.6b</td>' ||
  '<td>Ensure PASSWORD_GRACE_TIME Is Less than or Equal to 5 in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(P.PROFILE) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(P.PROFILE) > 0 THEN 
      LISTAGG(DECODE(P.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE P.CON_ID = B.CON_ID)) || ':' || P.PROFILE || ':' || P.LIMIT, '; ') WITHIN GROUP (ORDER BY P.CON_ID, P.PROFILE)
    ELSE 'All profiles compliant in all containers'
    END || '</td>' ||
  '<td>Less than or equal to 5 for all profiles in all containers</td>' ||
  '<td class="remediation">For each container: ALTER PROFILE DEFAULT LIMIT PASSWORD_GRACE_TIME 5;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    p.CON_ID,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM CDB_PROFILES p
  WHERE TO_NUMBER(DECODE(p.LIMIT,
          'DEFAULT',(SELECT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                     FROM CDB_PROFILES
                     WHERE PROFILE='DEFAULT'
                     AND RESOURCE_NAME='PASSWORD_GRACE_TIME'
                     AND CON_ID = p.CON_ID),
          'UNLIMITED','9999',p.LIMIT)) > 5
  AND p.RESOURCE_NAME = 'PASSWORD_GRACE_TIME'
  AND EXISTS (SELECT 'X' FROM CDB_USERS u WHERE u.PROFILE = p.PROFILE AND u.CON_ID = p.CON_ID)
) P
GROUP BY ef.env_type;

-- 3.7 DBA_USERS External Authentication (11g and 12c+ non-multitenant/PDB)
WITH external_auth_11g AS (
  SELECT 
    vi.version,
    du.USERNAME
  FROM v$instance vi
  CROSS JOIN DBA_USERS du
  WHERE vi.version LIKE '11.%'
  AND du.PASSWORD='EXTERNAL'
),
external_auth_12c_non_mt AS (
  SELECT 
    vi.version,
    du.USERNAME
  FROM v$instance vi
  CROSS JOIN DBA_USERS du
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND du.AUTHENTICATION_TYPE = 'EXTERNAL'
),
external_auth_combined AS (
  SELECT version, USERNAME FROM external_auth_11g
  UNION ALL
  SELECT version, USERNAME FROM external_auth_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM external_auth_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.7</td>' ||
  '<td>Ensure No Users Use EXTERNAL Authentication (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM external_auth_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM external_auth_combined) > 0 THEN 
      (SELECT LISTAGG(USERNAME, ', ') WITHIN GROUP (ORDER BY USERNAME) FROM external_auth_combined)
    ELSE 'No users with EXTERNAL authentication'
    END || '</td>' ||
  '<td>No users should use EXTERNAL authentication</td>' ||
  '<td class="remediation">ALTER USER &lt;username&gt; IDENTIFIED BY &lt;password&gt;;</td>' ||
  '</tr>'
FROM DUAL;

-- 3.7b DBA_USERS External Authentication (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(U.USERNAME) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.7b</td>' ||
  '<td>Ensure No Users Use EXTERNAL Authentication in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(U.USERNAME) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(U.USERNAME) > 0 THEN 
      LISTAGG(DECODE(U.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE U.CON_ID = B.CON_ID)) || ':' || U.USERNAME, '; ') WITHIN GROUP (ORDER BY U.CON_ID, U.USERNAME)
    ELSE 'No users with EXTERNAL authentication in any container'
    END || '</td>' ||
  '<td>No users should use EXTERNAL authentication in any container</td>' ||
  '<td class="remediation">For each container: ALTER USER &lt;username&gt; IDENTIFIED BY &lt;password&gt;;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    a.CON_ID,
    a.USERNAME
  FROM CDB_USERS a
  WHERE a.AUTHENTICATION_TYPE = 'EXTERNAL'
) U
GROUP BY ef.env_type;

-- 3.8 PASSWORD_VERIFY_FUNCTION (11g and 12c+ non-multitenant/PDB)
WITH password_verify_11g AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version LIKE '11.%'
  AND p.RESOURCE_NAME = 'PASSWORD_VERIFY_FUNCTION'
  AND (p.LIMIT = 'DEFAULT' OR p.LIMIT = 'NULL')
),
password_verify_12c_non_mt AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND DECODE(p.LIMIT,
        'DEFAULT',(SELECT LIMIT
                   FROM DBA_PROFILES
                   WHERE PROFILE='DEFAULT'
                   AND RESOURCE_NAME = p.RESOURCE_NAME),
        p.LIMIT) = 'NULL'
  AND p.RESOURCE_NAME = 'PASSWORD_VERIFY_FUNCTION'
  AND EXISTS (SELECT 'X' FROM DBA_USERS u WHERE u.PROFILE = p.PROFILE)
),
password_verify_combined AS (
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM password_verify_11g
  UNION ALL
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM password_verify_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM password_verify_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.8</td>' ||
  '<td>Ensure PASSWORD_VERIFY_FUNCTION Is Set for All Profiles (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM password_verify_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM password_verify_combined) > 0 THEN 
      (SELECT LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE) FROM password_verify_combined)
    ELSE 'All profiles have password verification function'
    END || '</td>' ||
  '<td>Password verification function set for all profiles</td>' ||
  '<td class="remediation">Create and assign password verification function to profiles</td>' ||
  '</tr>'
FROM DUAL;

-- 3.8b PASSWORD_VERIFY_FUNCTION (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(P.PROFILE) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.8b</td>' ||
  '<td>Ensure PASSWORD_VERIFY_FUNCTION Is Set for All Profiles in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(P.PROFILE) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(P.PROFILE) > 0 THEN 
      LISTAGG(DECODE(P.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE P.CON_ID = B.CON_ID)) || ':' || P.PROFILE || ':' || P.LIMIT, '; ') WITHIN GROUP (ORDER BY P.CON_ID, P.PROFILE)
    ELSE 'All profiles have password verification function in all containers'
    END || '</td>' ||
  '<td>Password verification function set for all profiles in all containers</td>' ||
  '<td class="remediation">For each container: Create and assign password verification function to profiles</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    p.CON_ID,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM CDB_PROFILES p
  WHERE DECODE(p.LIMIT,
          'DEFAULT',(SELECT LIMIT
                     FROM CDB_PROFILES
                     WHERE PROFILE='DEFAULT'
                     AND RESOURCE_NAME = p.RESOURCE_NAME
                     AND CON_ID = p.CON_ID),
          p.LIMIT) = 'NULL'
  AND p.RESOURCE_NAME = 'PASSWORD_VERIFY_FUNCTION'
  AND EXISTS (SELECT 'X' FROM CDB_USERS u WHERE u.PROFILE = p.PROFILE AND u.CON_ID = p.CON_ID)
) P
GROUP BY ef.env_type;

-- 3.9 SESSIONS_PER_USER (11g and 12c+ non-multitenant/PDB)
WITH sessions_per_user_11g AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version LIKE '11.%'
  AND p.RESOURCE_NAME = 'SESSIONS_PER_USER'
  AND (p.LIMIT = 'DEFAULT' OR p.LIMIT = 'UNLIMITED' OR TO_NUMBER(p.LIMIT) > 10)
),
sessions_per_user_12c_non_mt AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND TO_NUMBER(DECODE(p.LIMIT,
        'DEFAULT',(SELECT DISTINCT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                   FROM DBA_PROFILES
                   WHERE PROFILE='DEFAULT'
                   AND RESOURCE_NAME='SESSIONS_PER_USER'),
        'UNLIMITED','9999',
        p.LIMIT)) > 10
  AND p.RESOURCE_NAME = 'SESSIONS_PER_USER'
  AND EXISTS (SELECT 'X' FROM DBA_USERS u WHERE u.PROFILE = p.PROFILE)
),
sessions_per_user_combined AS (
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM sessions_per_user_11g
  UNION ALL
  SELECT version, PROFILE, RESOURCE_NAME, LIMIT FROM sessions_per_user_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM sessions_per_user_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.9</td>' ||
  '<td>Ensure SESSIONS_PER_USER Is Less than or Equal to 10 (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM sessions_per_user_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM sessions_per_user_combined) > 0 THEN 
      (SELECT LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE) FROM sessions_per_user_combined)
    ELSE 'All profiles compliant (10 or less)'
    END || '</td>' ||
  '<td>Less than or equal to 10 for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT SESSIONS_PER_USER 10;</td>' ||
  '</tr>'
FROM DUAL;

-- 3.9b SESSIONS_PER_USER (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(P.PROFILE) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.9b</td>' ||
  '<td>Ensure SESSIONS_PER_USER Is Less than or Equal to 10 in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(P.PROFILE) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(P.PROFILE) > 0 THEN 
      LISTAGG(DECODE(P.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE P.CON_ID = B.CON_ID)) || ':' || P.PROFILE || ':' || P.LIMIT, '; ') WITHIN GROUP (ORDER BY P.CON_ID, P.PROFILE)
    ELSE 'All profiles compliant in all containers'
    END || '</td>' ||
  '<td>Less than or equal to 10 for all profiles in all containers</td>' ||
  '<td class="remediation">For each container: ALTER PROFILE DEFAULT LIMIT SESSIONS_PER_USER 10;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    p.CON_ID,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM CDB_PROFILES p
  WHERE TO_NUMBER(DECODE(p.LIMIT,
          'DEFAULT',(SELECT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                     FROM CDB_PROFILES
                     WHERE PROFILE='DEFAULT'
                     AND RESOURCE_NAME='SESSIONS_PER_USER'
                     AND CON_ID = p.CON_ID),
          'UNLIMITED','9999',p.LIMIT)) > 10
  AND p.RESOURCE_NAME = 'SESSIONS_PER_USER'
  AND EXISTS (SELECT 'X' FROM CDB_USERS u WHERE u.PROFILE = p.PROFILE AND u.CON_ID = p.CON_ID)
) P
GROUP BY ef.env_type;

-- 3.10 No Users Assigned DEFAULT Profile (11g and 12c+ non-multitenant/PDB)
WITH default_profile_11g AS (
  SELECT 
    vi.version,
    du.USERNAME
  FROM v$instance vi
  CROSS JOIN DBA_USERS du
  WHERE vi.version LIKE '11.%'
  AND du.PROFILE='DEFAULT'
  AND du.ACCOUNT_STATUS='OPEN'
  AND du.USERNAME NOT IN ('ANONYMOUS', 'CTXSYS', 'DBSNMP', 'EXFSYS', 'LBACSYS',
    'MDSYS', 'MGMT_VIEW','OLAPSYS','OWBSYS', 'ORDPLUGINS',
    'ORDSYS', 'OUTLN', 'SI_INFORMTN_SCHEMA','SYS',
    'SYSMAN', 'SYSTEM', 'TSMSYS', 'WK_TEST', 'WKSYS',
    'WKPROXY', 'WMSYS', 'XDB', 'CISSCAN')
),
default_profile_12c_non_mt AS (
  SELECT 
    vi.version,
    du.USERNAME
  FROM v$instance vi
  CROSS JOIN DBA_USERS du
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND du.PROFILE='DEFAULT'
  AND du.ACCOUNT_STATUS='OPEN'
  AND du.ORACLE_MAINTAINED = 'N'
),
default_profile_combined AS (
  SELECT version, USERNAME FROM default_profile_11g
  UNION ALL
  SELECT version, USERNAME FROM default_profile_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM default_profile_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.10</td>' ||
  '<td>Ensure No Users Are Assigned the DEFAULT Profile (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM default_profile_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM default_profile_combined) > 0 THEN 
      (SELECT LISTAGG(USERNAME, ', ') WITHIN GROUP (ORDER BY USERNAME) FROM default_profile_combined)
    ELSE 'No non-system users with DEFAULT profile'
    END || '</td>' ||
  '<td>No application users should use DEFAULT profile</td>' ||
  '<td class="remediation">ALTER USER &lt;username&gt; PROFILE &lt;appropriate_profile&gt;;</td>' ||
  '</tr>'
FROM DUAL;

-- 3.10b No Users Assigned DEFAULT Profile (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(U.USERNAME) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.10b</td>' ||
  '<td>Ensure No Users Are Assigned the DEFAULT Profile in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(U.USERNAME) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(U.USERNAME) > 0 THEN 
      LISTAGG(DECODE(U.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE U.CON_ID = B.CON_ID)) || ':' || U.USERNAME, '; ') WITHIN GROUP (ORDER BY U.CON_ID, U.USERNAME)
    ELSE 'No non-system users with DEFAULT profile in any container'
    END || '</td>' ||
  '<td>No application users should use DEFAULT profile in any container</td>' ||
  '<td class="remediation">For each container: ALTER USER &lt;username&gt; PROFILE &lt;appropriate_profile&gt;;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    A.CON_ID,
    A.USERNAME
  FROM CDB_USERS A
  WHERE A.PROFILE='DEFAULT'
  AND A.ACCOUNT_STATUS='OPEN'
  AND A.ORACLE_MAINTAINED = 'N'
) U
GROUP BY ef.env_type;

-- 3.11 INACTIVE_ACCOUNT_TIME (12c+ non-multitenant/PDB)
WITH inactive_account_12c_non_mt AS (
  SELECT 
    vi.version,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM v$instance vi
  CROSS JOIN DBA_PROFILES p
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND TO_NUMBER(DECODE(p.LIMIT,
        'DEFAULT',(SELECT DISTINCT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                   FROM DBA_PROFILES
                   WHERE PROFILE='DEFAULT'
                   AND RESOURCE_NAME='INACTIVE_ACCOUNT_TIME'),
        'UNLIMITED','9999',
        p.LIMIT)) > 120
  AND p.RESOURCE_NAME = 'INACTIVE_ACCOUNT_TIME'
  AND EXISTS (SELECT 'X' FROM DBA_USERS u WHERE u.PROFILE = p.PROFILE)
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM inactive_account_12c_non_mt) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.11</td>' ||
  '<td>Ensure INACTIVE_ACCOUNT_TIME Is Less Than or Equal to 120 Days (12c+) (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM inactive_account_12c_non_mt) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM inactive_account_12c_non_mt) > 0 THEN 
      (SELECT LISTAGG(PROFILE || ':' || LIMIT, ', ') WITHIN GROUP (ORDER BY PROFILE) FROM inactive_account_12c_non_mt)
    ELSE 'All profiles compliant (120 days or less)'
    END || '</td>' ||
  '<td>Less than or equal to 120 days for all profiles</td>' ||
  '<td class="remediation">ALTER PROFILE DEFAULT LIMIT INACTIVE_ACCOUNT_TIME 120;</td>' ||
  '</tr>'
FROM DUAL;

-- 3.11b INACTIVE_ACCOUNT_TIME (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(P.PROFILE) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>3.11b</td>' ||
  '<td>Ensure INACTIVE_ACCOUNT_TIME Is Less Than or Equal to 120 Days in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(P.PROFILE) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(P.PROFILE) > 0 THEN 
      LISTAGG(DECODE(P.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE P.CON_ID = B.CON_ID)) || ':' || P.PROFILE || ':' || P.LIMIT, '; ') WITHIN GROUP (ORDER BY P.CON_ID, P.PROFILE)
    ELSE 'All profiles compliant in all containers'
    END || '</td>' ||
  '<td>Less than or equal to 120 days for all profiles in all containers</td>' ||
  '<td class="remediation">For each container: ALTER PROFILE DEFAULT LIMIT INACTIVE_ACCOUNT_TIME 120;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT DISTINCT
    p.CON_ID,
    p.PROFILE,
    p.RESOURCE_NAME,
    p.LIMIT
  FROM CDB_PROFILES p
  WHERE TO_NUMBER(DECODE(p.LIMIT,
          'DEFAULT',(SELECT DISTINCT DECODE(LIMIT,'UNLIMITED',9999,LIMIT)
                     FROM CDB_PROFILES
                     WHERE PROFILE='DEFAULT'
                     AND RESOURCE_NAME='INACTIVE_ACCOUNT_TIME'
                     AND CON_ID = p.CON_ID),
          'UNLIMITED','9999',p.LIMIT)) > 120
  AND p.RESOURCE_NAME = 'INACTIVE_ACCOUNT_TIME'
  AND EXISTS (SELECT 'X' FROM CDB_USERS u WHERE u.PROFILE = p.PROFILE AND u.CON_ID = p.CON_ID)
) P
GROUP BY ef.env_type;

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

-- 4.0 Database User Account Status Information
PROMPT <h3 id="section4_0">4.0 Database User Account Status (Informational)</h3>
PROMPT <p>This section provides an overview of all database user accounts and their current status across different Oracle environments.</p>
PROMPT <table>
PROMPT <tr><th width="8%">Username</th><th width="8%">Status</th><th width="8%">Profile</th><th width="12%">Oracle Maintained</th><th width="8%">Common User</th><th width="8%">Container</th><th width="48%">Description/Purpose</th></tr>

-- 4.0.1 User Status for 11g
WITH user_descriptions AS (
  SELECT 'ANONYMOUS' as username, 'Account used for anonymous HTTP access to Oracle XML DB' as description FROM dual UNION ALL
  SELECT 'APPQOSSYS', 'Oracle Application Quality of Service Management schema' FROM dual UNION ALL
  SELECT 'AUDSYS', 'Oracle Audit Vault schema (12c+)' FROM dual UNION ALL
  SELECT 'CTXSYS', 'Oracle Text search engine schema - manages full-text indexing and searching' FROM dual UNION ALL
  SELECT 'DBSNMP', 'Account used by Oracle Enterprise Manager agents for database monitoring and management' FROM dual UNION ALL
  SELECT 'DIP', 'Directory Integration Platform account for LDAP synchronization' FROM dual UNION ALL
  SELECT 'DMSYS', 'Oracle Data Mining schema - performs data mining operations and manages mining models' FROM dual UNION ALL
  SELECT 'DVF', 'Database Vault Factor account (Oracle Database Vault)' FROM dual UNION ALL
  SELECT 'DVSYS', 'Database Vault owner account - manages Database Vault policies and rules' FROM dual UNION ALL
  SELECT 'EXFSYS', 'Oracle Expression Filter schema - manages rule-based filtering' FROM dual UNION ALL
  SELECT 'FLOWS_FILES', 'Oracle Application Express file storage schema' FROM dual UNION ALL
  SELECT 'GGSYS', 'Oracle GoldenGate schema for replication management' FROM dual UNION ALL
  SELECT 'GSMADMIN_INTERNAL', 'Global Service Manager internal administration account' FROM dual UNION ALL
  SELECT 'GSMCATUSER', 'Global Service Manager catalog user' FROM dual UNION ALL
  SELECT 'GSMROOTUSER', 'Global Service Manager root user' FROM dual UNION ALL
  SELECT 'GSMUSER', 'Global Service Manager user account' FROM dual UNION ALL
  SELECT 'HR', 'Oracle sample schema - Human Resources demo data' FROM dual UNION ALL
  SELECT 'IX', 'Oracle Information Extraction sample schema' FROM dual UNION ALL
  SELECT 'LBACSYS', 'Oracle Label Security administrator account - manages row-level security labels' FROM dual UNION ALL
  SELECT 'MDDATA', 'Oracle Spatial schema for storing geocoder and router data' FROM dual UNION ALL
  SELECT 'MDSYS', 'Oracle Spatial and Locator administrator account - manages spatial data and operations' FROM dual UNION ALL
  SELECT 'MGMT_VIEW', 'Oracle Enterprise Manager management view account' FROM dual UNION ALL
  SELECT 'OE', 'Oracle sample schema - Order Entry demo data' FROM dual UNION ALL
  SELECT 'OJVMSYS', 'Oracle Java Virtual Machine system account' FROM dual UNION ALL
  SELECT 'OLAPSYS', 'Oracle OLAP administrator account - creates and manages OLAP metadata structures' FROM dual UNION ALL
  SELECT 'ORACLE_OCM', 'Oracle Configuration Manager account for configuration collection' FROM dual UNION ALL
  SELECT 'ORDDATA', 'Oracle Multimedia data account' FROM dual UNION ALL
  SELECT 'ORDPLUGINS', 'Oracle Multimedia user - manages multimedia format plugins and processing' FROM dual UNION ALL
  SELECT 'ORDSYS', 'Oracle Multimedia administrator account - manages multimedia data types and operations' FROM dual UNION ALL
  SELECT 'OUTLN', 'Account supporting plan stability - maintains consistent SQL execution plans across database changes' FROM dual UNION ALL
  SELECT 'OWBSYS', 'Oracle Warehouse Builder repository owner' FROM dual UNION ALL
  SELECT 'PM', 'Oracle sample schema - Product Media demo data' FROM dual UNION ALL
  SELECT 'REMOTE_SCHEDULER_AGENT', 'Remote Scheduler Agent account for job execution' FROM dual UNION ALL
  SELECT 'SCOTT', 'Classic Oracle sample schema - original demo user with EMP/DEPT tables' FROM dual UNION ALL
  SELECT 'SH', 'Oracle sample schema - Sales History data warehouse demo' FROM dual UNION ALL
  SELECT 'SI_INFORMTN_SCHEMA', 'SQL/MM Still Image information schema' FROM dual UNION ALL
  SELECT 'SYS', 'Database superuser account - owns data dictionary and has all system privileges' FROM dual UNION ALL
  SELECT 'SYS$UMF', 'Unified Messaging Framework system account' FROM dual UNION ALL
  SELECT 'SYSBACKUP', 'Backup and recovery administrative account with limited privileges' FROM dual UNION ALL
  SELECT 'SYSDG', 'Data Guard administrative account for standby database management' FROM dual UNION ALL
  SELECT 'SYSKM', 'Key management administrative account for Transparent Data Encryption' FROM dual UNION ALL
  SELECT 'SYSMAN', 'Oracle Enterprise Manager system management account' FROM dual UNION ALL
  SELECT 'SYSRAC', 'Real Application Clusters administrative account' FROM dual UNION ALL
  SELECT 'SYSTEM', 'Default administrative account - manages internal database structures and operations' FROM dual UNION ALL
  SELECT 'TSMSYS', 'Transparent Session Migration system account' FROM dual UNION ALL
  SELECT 'WK_TEST', 'Workspace Manager test account' FROM dual UNION ALL
  SELECT 'WKPROXY', 'Workspace Manager proxy account' FROM dual UNION ALL
  SELECT 'WKSYS', 'Workspace Manager system account' FROM dual UNION ALL
  SELECT 'WMSYS', 'Workspace Manager administrator account - manages workspace versioning and long transactions' FROM dual UNION ALL
  SELECT 'XDB', 'Oracle XML Database account - manages XML storage, indexing, and processing capabilities' FROM dual UNION ALL
  SELECT 'XS$NULL', 'Oracle Database Real Application Security null user' FROM dual
)
SELECT 
  '<tr>' ||
  '<td>' || du.USERNAME || '</td>' ||
  '<td>' || 
    CASE 
      WHEN du.ACCOUNT_STATUS = 'OPEN' THEN '<span style="color: green; font-weight: bold;">OPEN</span>'
      WHEN du.ACCOUNT_STATUS = 'LOCKED' THEN '<span style="color: red;">LOCKED</span>'
      WHEN du.ACCOUNT_STATUS LIKE '%EXPIRED%' THEN '<span style="color: orange;">EXPIRED</span>'
      ELSE du.ACCOUNT_STATUS
    END || '</td>' ||
  '<td>' || du.PROFILE || '</td>' ||
  '<td>N/A (11g)</td>' ||
  '<td>N/A (11g)</td>' ||
  '<td>N/A (11g)</td>' ||
  '<td>' || NVL(ud.description, 'Application or custom user account') || '</td>' ||
  '</tr>'
FROM DBA_USERS du
LEFT JOIN user_descriptions ud ON UPPER(du.USERNAME) = UPPER(ud.username)
CROSS JOIN v$instance vi
WHERE vi.version LIKE '11.%'
ORDER BY 
  CASE 
    WHEN du.USERNAME IN ('SYS', 'SYSTEM') THEN 1
    WHEN du.USERNAME IN ('SYSMAN', 'DBSNMP', 'SYSDG', 'SYSBACKUP', 'SYSKM', 'SYSRAC') THEN 2
    WHEN ud.description IS NOT NULL THEN 3
    ELSE 4
  END,
  du.USERNAME;

-- 4.0.2 User Status for 12c+ Non-Multitenant/PDB
WITH user_descriptions AS (
  SELECT 'ANONYMOUS' as username, 'Account used for anonymous HTTP access to Oracle XML DB' as description FROM dual UNION ALL
  SELECT 'APPQOSSYS', 'Oracle Application Quality of Service Management schema' FROM dual UNION ALL
  SELECT 'AUDSYS', 'Oracle Audit Vault schema (12c+)' FROM dual UNION ALL
  SELECT 'CTXSYS', 'Oracle Text search engine schema - manages full-text indexing and searching' FROM dual UNION ALL
  SELECT 'DBSNMP', 'Account used by Oracle Enterprise Manager agents for database monitoring and management' FROM dual UNION ALL
  SELECT 'DIP', 'Directory Integration Platform account for LDAP synchronization' FROM dual UNION ALL
  SELECT 'DMSYS', 'Oracle Data Mining schema - performs data mining operations and manages mining models' FROM dual UNION ALL
  SELECT 'DVF', 'Database Vault Factor account (Oracle Database Vault)' FROM dual UNION ALL
  SELECT 'DVSYS', 'Database Vault owner account - manages Database Vault policies and rules' FROM dual UNION ALL
  SELECT 'EXFSYS', 'Oracle Expression Filter schema - manages rule-based filtering' FROM dual UNION ALL
  SELECT 'FLOWS_FILES', 'Oracle Application Express file storage schema' FROM dual UNION ALL
  SELECT 'GGSYS', 'Oracle GoldenGate schema for replication management' FROM dual UNION ALL
  SELECT 'GSMADMIN_INTERNAL', 'Global Service Manager internal administration account' FROM dual UNION ALL
  SELECT 'GSMCATUSER', 'Global Service Manager catalog user' FROM dual UNION ALL
  SELECT 'GSMROOTUSER', 'Global Service Manager root user' FROM dual UNION ALL
  SELECT 'GSMUSER', 'Global Service Manager user account' FROM dual UNION ALL
  SELECT 'HR', 'Oracle sample schema - Human Resources demo data' FROM dual UNION ALL
  SELECT 'IX', 'Oracle Information Extraction sample schema' FROM dual UNION ALL
  SELECT 'LBACSYS', 'Oracle Label Security administrator account - manages row-level security labels' FROM dual UNION ALL
  SELECT 'MDDATA', 'Oracle Spatial schema for storing geocoder and router data' FROM dual UNION ALL
  SELECT 'MDSYS', 'Oracle Spatial and Locator administrator account - manages spatial data and operations' FROM dual UNION ALL
  SELECT 'MGMT_VIEW', 'Oracle Enterprise Manager management view account' FROM dual UNION ALL
  SELECT 'OE', 'Oracle sample schema - Order Entry demo data' FROM dual UNION ALL
  SELECT 'OJVMSYS', 'Oracle Java Virtual Machine system account' FROM dual UNION ALL
  SELECT 'OLAPSYS', 'Oracle OLAP administrator account - creates and manages OLAP metadata structures' FROM dual UNION ALL
  SELECT 'ORACLE_OCM', 'Oracle Configuration Manager account for configuration collection' FROM dual UNION ALL
  SELECT 'ORDDATA', 'Oracle Multimedia data account' FROM dual UNION ALL
  SELECT 'ORDPLUGINS', 'Oracle Multimedia user - manages multimedia format plugins and processing' FROM dual UNION ALL
  SELECT 'ORDSYS', 'Oracle Multimedia administrator account - manages multimedia data types and operations' FROM dual UNION ALL
  SELECT 'OUTLN', 'Account supporting plan stability - maintains consistent SQL execution plans across database changes' FROM dual UNION ALL
  SELECT 'OWBSYS', 'Oracle Warehouse Builder repository owner' FROM dual UNION ALL
  SELECT 'PDBADMIN', '12c+ Pluggable Database administrator account - manages PDB-specific operations' FROM dual UNION ALL
  SELECT 'PM', 'Oracle sample schema - Product Media demo data' FROM dual UNION ALL
  SELECT 'REMOTE_SCHEDULER_AGENT', 'Remote Scheduler Agent account for job execution' FROM dual UNION ALL
  SELECT 'SCOTT', 'Classic Oracle sample schema - original demo user with EMP/DEPT tables' FROM dual UNION ALL
  SELECT 'SH', 'Oracle sample schema - Sales History data warehouse demo' FROM dual UNION ALL
  SELECT 'SI_INFORMTN_SCHEMA', 'SQL/MM Still Image information schema' FROM dual UNION ALL
  SELECT 'SYS', 'Database superuser account - owns data dictionary and has all system privileges' FROM dual UNION ALL
  SELECT 'SYS$UMF', 'Unified Messaging Framework system account' FROM dual UNION ALL
  SELECT 'SYSBACKUP', 'Backup and recovery administrative account with limited privileges' FROM dual UNION ALL
  SELECT 'SYSDG', 'Data Guard administrative account for standby database management' FROM dual UNION ALL
  SELECT 'SYSKM', 'Key management administrative account for Transparent Data Encryption' FROM dual UNION ALL
  SELECT 'SYSMAN', 'Oracle Enterprise Manager system management account' FROM dual UNION ALL
  SELECT 'SYSRAC', 'Real Application Clusters administrative account' FROM dual UNION ALL
  SELECT 'SYSTEM', 'Default administrative account - manages internal database structures and operations' FROM dual UNION ALL
  SELECT 'TSMSYS', 'Transparent Session Migration system account' FROM dual UNION ALL
  SELECT 'WK_TEST', 'Workspace Manager test account' FROM dual UNION ALL
  SELECT 'WKPROXY', 'Workspace Manager proxy account' FROM dual UNION ALL
  SELECT 'WKSYS', 'Workspace Manager system account' FROM dual UNION ALL
  SELECT 'WMSYS', 'Workspace Manager administrator account - manages workspace versioning and long transactions' FROM dual UNION ALL
  SELECT 'XDB', 'Oracle XML Database account - manages XML storage, indexing, and processing capabilities' FROM dual UNION ALL
  SELECT 'XS$NULL', 'Oracle Database Real Application Security null user' FROM dual
)
SELECT 
  '<tr>' ||
  '<td>' || du.USERNAME || '</td>' ||
  '<td>' || 
    CASE 
      WHEN du.ACCOUNT_STATUS = 'OPEN' THEN '<span style="color: green; font-weight: bold;">OPEN</span>'
      WHEN du.ACCOUNT_STATUS = 'LOCKED' THEN '<span style="color: red;">LOCKED</span>'
      WHEN du.ACCOUNT_STATUS LIKE '%EXPIRED%' THEN '<span style="color: orange;">EXPIRED</span>'
      ELSE du.ACCOUNT_STATUS
    END || '</td>' ||
  '<td>' || du.PROFILE || '</td>' ||
  '<td>' || NVL(du.ORACLE_MAINTAINED, 'N/A') || '</td>' ||
  '<td>' || NVL(du.COMMON, 'N/A') || '</td>' ||
  '<td>N/A (Non-MT)</td>' ||
  '<td>' || NVL(ud.description, 'Application or custom user account') || '</td>' ||
  '</tr>'
FROM DBA_USERS du
LEFT JOIN user_descriptions ud ON UPPER(du.USERNAME) = UPPER(ud.username)
CROSS JOIN v$instance vi
WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
ORDER BY 
  CASE 
    WHEN du.USERNAME IN ('SYS', 'SYSTEM') THEN 1
    WHEN du.USERNAME IN ('SYSMAN', 'DBSNMP', 'SYSDG', 'SYSBACKUP', 'SYSKM', 'SYSRAC', 'PDBADMIN') THEN 2
    WHEN ud.description IS NOT NULL THEN 3
    ELSE 4
  END,
  du.USERNAME;

-- 4.0.3 User Status for 12c+ Multi-tenant CDB
WITH user_descriptions AS (
  SELECT 'ANONYMOUS' as username, 'Account used for anonymous HTTP access to Oracle XML DB' as description FROM dual UNION ALL
  SELECT 'APPQOSSYS', 'Oracle Application Quality of Service Management schema' FROM dual UNION ALL
  SELECT 'AUDSYS', 'Oracle Audit Vault schema (12c+)' FROM dual UNION ALL
  SELECT 'CTXSYS', 'Oracle Text search engine schema - manages full-text indexing and searching' FROM dual UNION ALL
  SELECT 'DBSNMP', 'Account used by Oracle Enterprise Manager agents for database monitoring and management' FROM dual UNION ALL
  SELECT 'DIP', 'Directory Integration Platform account for LDAP synchronization' FROM dual UNION ALL
  SELECT 'DMSYS', 'Oracle Data Mining schema - performs data mining operations and manages mining models' FROM dual UNION ALL
  SELECT 'DVF', 'Database Vault Factor account (Oracle Database Vault)' FROM dual UNION ALL
  SELECT 'DVSYS', 'Database Vault owner account - manages Database Vault policies and rules' FROM dual UNION ALL
  SELECT 'EXFSYS', 'Oracle Expression Filter schema - manages rule-based filtering' FROM dual UNION ALL
  SELECT 'FLOWS_FILES', 'Oracle Application Express file storage schema' FROM dual UNION ALL
  SELECT 'GGSYS', 'Oracle GoldenGate schema for replication management' FROM dual UNION ALL
  SELECT 'GSMADMIN_INTERNAL', 'Global Service Manager internal administration account' FROM dual UNION ALL
  SELECT 'GSMCATUSER', 'Global Service Manager catalog user' FROM dual UNION ALL
  SELECT 'GSMROOTUSER', 'Global Service Manager root user' FROM dual UNION ALL
  SELECT 'GSMUSER', 'Global Service Manager user account' FROM dual UNION ALL
  SELECT 'HR', 'Oracle sample schema - Human Resources demo data' FROM dual UNION ALL
  SELECT 'IX', 'Oracle Information Extraction sample schema' FROM dual UNION ALL
  SELECT 'LBACSYS', 'Oracle Label Security administrator account - manages row-level security labels' FROM dual UNION ALL
  SELECT 'MDDATA', 'Oracle Spatial schema for storing geocoder and router data' FROM dual UNION ALL
  SELECT 'MDSYS', 'Oracle Spatial and Locator administrator account - manages spatial data and operations' FROM dual UNION ALL
  SELECT 'MGMT_VIEW', 'Oracle Enterprise Manager management view account' FROM dual UNION ALL
  SELECT 'OE', 'Oracle sample schema - Order Entry demo data' FROM dual UNION ALL
  SELECT 'OJVMSYS', 'Oracle Java Virtual Machine system account' FROM dual UNION ALL
  SELECT 'OLAPSYS', 'Oracle OLAP administrator account - creates and manages OLAP metadata structures' FROM dual UNION ALL
  SELECT 'ORACLE_OCM', 'Oracle Configuration Manager account for configuration collection' FROM dual UNION ALL
  SELECT 'ORDDATA', 'Oracle Multimedia data account' FROM dual UNION ALL
  SELECT 'ORDPLUGINS', 'Oracle Multimedia user - manages multimedia format plugins and processing' FROM dual UNION ALL
  SELECT 'ORDSYS', 'Oracle Multimedia administrator account - manages multimedia data types and operations' FROM dual UNION ALL
  SELECT 'OUTLN', 'Account supporting plan stability - maintains consistent SQL execution plans across database changes' FROM dual UNION ALL
  SELECT 'OWBSYS', 'Oracle Warehouse Builder repository owner' FROM dual UNION ALL
  SELECT 'PDBADMIN', '12c+ Pluggable Database administrator account - manages PDB-specific operations' FROM dual UNION ALL
  SELECT 'PM', 'Oracle sample schema - Product Media demo data' FROM dual UNION ALL
  SELECT 'REMOTE_SCHEDULER_AGENT', 'Remote Scheduler Agent account for job execution' FROM dual UNION ALL
  SELECT 'SCOTT', 'Classic Oracle sample schema - original demo user with EMP/DEPT tables' FROM dual UNION ALL
  SELECT 'SH', 'Oracle sample schema - Sales History data warehouse demo' FROM dual UNION ALL
  SELECT 'SI_INFORMTN_SCHEMA', 'SQL/MM Still Image information schema' FROM dual UNION ALL
  SELECT 'SYS', 'Database superuser account - owns data dictionary and has all system privileges' FROM dual UNION ALL
  SELECT 'SYS$UMF', 'Unified Messaging Framework system account' FROM dual UNION ALL
  SELECT 'SYSBACKUP', 'Backup and recovery administrative account with limited privileges' FROM dual UNION ALL
  SELECT 'SYSDG', 'Data Guard administrative account for standby database management' FROM dual UNION ALL
  SELECT 'SYSKM', 'Key management administrative account for Transparent Data Encryption' FROM dual UNION ALL
  SELECT 'SYSMAN', 'Oracle Enterprise Manager system management account' FROM dual UNION ALL
  SELECT 'SYSRAC', 'Real Application Clusters administrative account' FROM dual UNION ALL
  SELECT 'SYSTEM', 'Default administrative account - manages internal database structures and operations' FROM dual UNION ALL
  SELECT 'TSMSYS', 'Transparent Session Migration system account' FROM dual UNION ALL
  SELECT 'WK_TEST', 'Workspace Manager test account' FROM dual UNION ALL
  SELECT 'WKPROXY', 'Workspace Manager proxy account' FROM dual UNION ALL
  SELECT 'WKSYS', 'Workspace Manager system account' FROM dual UNION ALL
  SELECT 'WMSYS', 'Workspace Manager administrator account - manages workspace versioning and long transactions' FROM dual UNION ALL
  SELECT 'XDB', 'Oracle XML Database account - manages XML storage, indexing, and processing capabilities' FROM dual UNION ALL
  SELECT 'XS$NULL', 'Oracle Database Real Application Security null user' FROM dual
),
environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT 
  '<tr>' ||
  '<td>' || cu.USERNAME || '</td>' ||
  '<td>' || 
    CASE 
      WHEN cu.ACCOUNT_STATUS = 'OPEN' THEN '<span style="color: green; font-weight: bold;">OPEN</span>'
      WHEN cu.ACCOUNT_STATUS = 'LOCKED' THEN '<span style="color: red;">LOCKED</span>'
      WHEN cu.ACCOUNT_STATUS LIKE '%EXPIRED%' THEN '<span style="color: orange;">EXPIRED</span>'
      ELSE cu.ACCOUNT_STATUS
    END || '</td>' ||
  '<td>' || cu.PROFILE || '</td>' ||
  '<td>' || NVL(cu.ORACLE_MAINTAINED, 'N/A') || '</td>' ||
  '<td>' || NVL(cu.COMMON, 'N/A') || '</td>' ||
  '<td>' || DECODE(cu.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,'CDB$ROOT',(SELECT NAME FROM V$PDBS B WHERE cu.CON_ID = B.CON_ID)) || '</td>' ||
  '<td>' || NVL(ud.description, 'Application or custom user account') || '</td>' ||
  '</tr>'
FROM environment_flag ef
CROSS JOIN CDB_USERS cu
LEFT JOIN user_descriptions ud ON UPPER(cu.USERNAME) = UPPER(ud.username)
WHERE ef.env_type = 2
ORDER BY 
  cu.CON_ID,
  CASE 
    WHEN cu.USERNAME IN ('SYS', 'SYSTEM') THEN 1
    WHEN cu.USERNAME IN ('SYSMAN', 'DBSNMP', 'SYSDG', 'SYSBACKUP', 'SYSKM', 'SYSRAC', 'PDBADMIN') THEN 2
    WHEN ud.description IS NOT NULL THEN 3
    ELSE 4
  END,
  cu.USERNAME;

PROMPT </table>
PROMPT <p><strong>Note:</strong> Users with <span style="color: green; font-weight: bold;">OPEN</span> status can connect to the database. Users with <span style="color: red;">LOCKED</span> or <span style="color: orange;">EXPIRED</span> status cannot connect until unlocked or password reset.</p>
PROMPT <p><strong>Security Recommendation:</strong> Regularly review user accounts and lock or drop unused accounts. Ensure sample schemas (HR, OE, PM, SH, SCOTT) are removed from production databases.</p>

-- 4.1 Default Public Privileges for Packages and Object Types
PROMPT <h3 id="section4_1">4.1 Default Public Privileges for Packages and Object Types</h3>
PROMPT <p>This section checks for dangerous PUBLIC EXECUTE privileges on Oracle built-in packages that should be revoked for security.</p>
PROMPT <p>The checks are compatible with Oracle 11g, 12c+ non-multitenant, and 12c+ multitenant environments.</p>

-- Oracle Environment Detection
DEFINE oracle_version = ''
DEFINE is_multitenant = ''
COL oracle_version NEW_VALUE oracle_version NOPRINT
COL is_multitenant NEW_VALUE is_multitenant NOPRINT

SELECT TO_NUMBER(SUBSTR(VERSION, 1, 2)) AS oracle_version
FROM V$INSTANCE;

-- Detect multitenant for 12c+
SELECT CASE 
  WHEN EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') THEN 'YES'
  ELSE 'NO'
END AS is_multitenant
FROM DUAL;

-- 4.1.1 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "Network" Packages
PROMPT <h4>4.1.1 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "Network" Packages</h4>
PROMPT <p>Network packages: DBMS_LDAP, UTL_INADDR, UTL_TCP, UTL_MAIL, UTL_SMTP, UTL_DBWS, UTL_ORAMTS, UTL_HTTP, HTTPURITYPE</p>
PROMPT <table>
PROMPT <tr><th width="5%">Package</th><th width="8%">Status</th><th width="30%">Current Value</th><th width="15%">Expected</th><th width="42%">Remediation</th></tr>

-- Network Packages Check - All Oracle versions (11g, 12c+ non-MT, 12c+ MT)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_LDAP</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>UTL_INADDR</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>UTL_TCP</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>UTL_MAIL</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>UTL_SMTP</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>UTL_DBWS</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege (12c+ only)'
    ELSE 'No PUBLIC privilege found or not applicable'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON UTL_DBWS FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='UTL_DBWS';

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>UTL_ORAMTS</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>UTL_HTTP</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>HTTPURITYPE</td>' ||
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

-- Additional check for Multitenant environments (12c+)
-- This query shows packages with privileges across all containers
SELECT '<tr class="info">' ||
  '<td colspan="5"><i>For Oracle 12c+ multitenant environments, check CDB_TAB_PRIVS for container-specific privileges if needed.</i></td>' ||
  '</tr>'
FROM DUAL
WHERE EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES');

PROMPT </table>

-- 4.1.2 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "File System" Packages
PROMPT <h4>4.1.2 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "File System" Packages</h4>
PROMPT <p>File system packages: DBMS_ADVISOR, DBMS_LOB, UTL_FILE</p>
PROMPT <table>
PROMPT <tr><th width="5%">Package</th><th width="8%">Status</th><th width="30%">Current Value</th><th width="15%">Expected</th><th width="42%">Remediation</th></tr>

-- File System Packages Check - All Oracle versions
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_ADVISOR</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_LOB</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>UTL_FILE</td>' ||
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

PROMPT </table>

-- 4.1.3 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "Encryption" Packages
PROMPT <h4>4.1.3 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "Encryption" Packages</h4>
PROMPT <p>Encryption packages: DBMS_CRYPTO, DBMS_OBFUSCATION_TOOLKIT, DBMS_RANDOM</p>
PROMPT <table>
PROMPT <tr><th width="5%">Package</th><th width="8%">Status</th><th width="30%">Current Value</th><th width="15%">Expected</th><th width="42%">Remediation</th></tr>

-- Encryption Packages Check - All Oracle versions
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_CRYPTO</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_CRYPTO FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_CRYPTO';

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_OBFUSCATION_TOOLKIT</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_RANDOM</td>' ||
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

PROMPT </table>

-- 4.1.4 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "Java" Packages
PROMPT <h4>4.1.4 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "Java" Packages</h4>
PROMPT <p>Java packages: DBMS_JAVA, DBMS_JAVA_TEST</p>
PROMPT <table>
PROMPT <tr><th width="5%">Package</th><th width="8%">Status</th><th width="30%">Current Value</th><th width="15%">Expected</th><th width="42%">Remediation</th></tr>

-- Java Packages Check - All Oracle versions
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_JAVA</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_JAVA_TEST</td>' ||
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

PROMPT </table>

-- 4.1.5 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "Job Scheduler" Packages
PROMPT <h4>4.1.5 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "Job Scheduler" Packages</h4>
PROMPT <p>Job scheduler packages: DBMS_SCHEDULER, DBMS_JOB</p>
PROMPT <table>
PROMPT <tr><th width="5%">Package</th><th width="8%">Status</th><th width="30%">Current Value</th><th width="15%">Expected</th><th width="42%">Remediation</th></tr>

-- Job Scheduler Packages Check - All Oracle versions
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_SCHEDULER</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_JOB</td>' ||
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

PROMPT </table>

-- 4.1.6 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "SQL Injection Helper" Packages
PROMPT <h4>4.1.6 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "SQL Injection Helper" Packages</h4>
PROMPT <p>SQL Injection Helper packages: DBMS_SQL, DBMS_XMLGEN, DBMS_XMLQUERY, DBMS_XMLSTORE, DBMS_XMLSAVE, DBMS_AW, OWA_UTIL, DBMS_REDACT</p>
PROMPT <table>
PROMPT <tr><th width="5%">Package</th><th width="8%">Status</th><th width="30%">Current Value</th><th width="15%">Expected</th><th width="42%">Remediation</th></tr>

-- SQL Injection Helper Packages Check - All Oracle versions
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_SQL</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_XMLGEN</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_XMLQUERY</td>' ||
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

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_XMLSTORE</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_XMLSTORE FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_XMLSTORE';

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_XMLSAVE</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_XMLSAVE FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_XMLSAVE';

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_AW</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_AW FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_AW';

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>OWA_UTIL</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON OWA_UTIL FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='OWA_UTIL';

SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_REDACT</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege (12c+ only)'
    ELSE 'No PUBLIC privilege found or not applicable'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_REDACT FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_REDACT';

PROMPT </table>

-- 4.1.7 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "DBMS_CREDENTIAL" Package (18c+)
PROMPT <h4>4.1.7 Ensure 'EXECUTE' is revoked from 'PUBLIC' on "DBMS_CREDENTIAL" Package (Oracle 18c+)</h4>
PROMPT <p>DBMS_CREDENTIAL package: Provides credential management functionality introduced in Oracle 18c</p>
PROMPT <table>
PROMPT <tr><th width="5%">Package</th><th width="8%">Status</th><th width="30%">Current Value</th><th width="15%">Expected</th><th width="42%">Remediation</th></tr>

-- Check if Oracle version is 18c+ before running the check
SELECT '<tr class="info">' ||
  '<td colspan="5"><i>Checking Oracle version for DBMS_CREDENTIAL package compatibility...</i></td>' ||
  '</tr>'
FROM DUAL
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- DBMS_CREDENTIAL Check - Oracle 18c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_CREDENTIAL</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_CREDENTIAL FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_CREDENTIAL'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
);

-- DBMS_CREDENTIAL Check - Oracle 18c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>DBMS_CREDENTIAL (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN 'PUBLIC has EXECUTE privilege in ' || container_name
    ELSE 'No PUBLIC privilege found in ' || container_name
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_CREDENTIAL FROM PUBLIC;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name
  FROM CDB_TAB_PRIVS A
  WHERE A.GRANTEE='PUBLIC' 
    AND A.PRIVILEGE='EXECUTE' 
    AND A.TABLE_NAME='DBMS_CREDENTIAL'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- Show informational message for Oracle versions < 18c
SELECT '<tr class="info">' ||
  '<td colspan="5"><i>DBMS_CREDENTIAL package is not available in Oracle versions prior to 18c. Current version: ' ||
  (SELECT VERSION FROM V$INSTANCE) || '</i></td>' ||
  '</tr>'
FROM DUAL
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) < 18;

PROMPT </table>

-- 4.2 Revoke Non-Default Privileges for Packages and Object Types
PROMPT <h3 id="section4_2">4.2 Revoke Non-Default Privileges for Packages and Object Types</h3>
PROMPT <p>This section checks for non-default PUBLIC EXECUTE privileges on Oracle built-in packages that should be revoked for security.</p>
PROMPT <p>The checks are compatible with Oracle 11g and 12c+ (including non-multitenant and multitenant environments).</p>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 4.2.1 DBMS_SYS_SQL - Oracle 11g (Non-multitenant only)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.1</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_SYS_SQL (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_SYS_SQL FROM PUBLIC;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_SYS_SQL'
HAVING '&version_num' = '11';

-- 4.2.1 DBMS_SYS_SQL - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.1</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_SYS_SQL (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_SYS_SQL FROM PUBLIC;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_TAB_PRIVS 
     WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_SYS_SQL'
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.2.1 DBMS_SYS_SQL - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.1</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_SYS_SQL (Scored) - CDB All Containers (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN 'PUBLIC has EXECUTE privilege in ' || container_name
    ELSE 'No PUBLIC privilege found in ' || container_name
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_SYS_SQL FROM PUBLIC;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name
  FROM CDB_TAB_PRIVS A
  WHERE A.GRANTEE='PUBLIC' 
    AND A.PRIVILEGE='EXECUTE' 
    AND A.TABLE_NAME='DBMS_SYS_SQL'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.2.2 through 4.2.14 - Container-aware checks for remaining packages
-- Detects execution context and uses appropriate views

-- 4.2.2 DBMS_BACKUP_RESTORE - For 11g, 12c+ Non-MT, or when running from PDB
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
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_BACKUP_RESTORE'
AND (
  -- Oracle 11g (non-multitenant)
  TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) = 11
  OR 
  -- Oracle 12c+ Non-multitenant
  (TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12 AND NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES'))
  OR 
  -- Oracle 12c+ Running from PDB (not CDB$ROOT)
  (TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12 AND 
   EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
);

-- 4.2.2 DBMS_BACKUP_RESTORE - For 12c+ CDB when running from CDB$ROOT
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.2</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_BACKUP_RESTORE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN 'PUBLIC has EXECUTE privilege in ' || container_name
    ELSE 'No PUBLIC privilege found in ' || container_name
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_BACKUP_RESTORE FROM PUBLIC;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name
  FROM CDB_TAB_PRIVS A
  WHERE A.GRANTEE='PUBLIC' 
    AND A.PRIVILEGE='EXECUTE' 
    AND A.TABLE_NAME='DBMS_BACKUP_RESTORE'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.2.3 DBMS_AQADM_SYSCALLS - For 11g, 12c+ Non-MT, or when running from PDB
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
WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_AQADM_SYSCALLS'
AND (
  -- Oracle 11g (non-multitenant)
  TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) = 11
  OR 
  -- Oracle 12c+ Non-multitenant
  (TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12 AND NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES'))
  OR 
  -- Oracle 12c+ Running from PDB (not CDB$ROOT)
  (TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12 AND 
   EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
);

-- 4.2.3 DBMS_AQADM_SYSCALLS - For 12c+ CDB when running from CDB$ROOT
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.3</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on DBMS_AQADM_SYSCALLS (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN 'PUBLIC has EXECUTE privilege in ' || container_name
    ELSE 'No PUBLIC privilege found in ' || container_name
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON DBMS_AQADM_SYSCALLS FROM PUBLIC;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name
  FROM CDB_TAB_PRIVS A
  WHERE A.GRANTEE='PUBLIC' 
    AND A.PRIVILEGE='EXECUTE' 
    AND A.TABLE_NAME='DBMS_AQADM_SYSCALLS'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.2.4 through 4.2.14 - Container-aware implementations
-- Each check uses DBA_TAB_PRIVS for 11g/Non-MT/PDB context, CDB_TAB_PRIVS for CDB$ROOT context

-- Consolidated query for DBA_TAB_PRIVS context (11g, 12c+ Non-MT, or PDB)
SELECT '<tr class="' ||
  CASE 
    WHEN package_name = 'DBMS_REPCAT_SQL_UTL' AND priv_count = 0 THEN 'pass'
    WHEN package_name = 'DBMS_REPCAT_SQL_UTL' AND priv_count > 0 THEN 'fail'
    WHEN package_name = 'INITJVMAUX' AND priv_count = 0 THEN 'pass'
    WHEN package_name = 'INITJVMAUX' AND priv_count > 0 THEN 'fail'
    WHEN package_name = 'DBMS_STREAMS_ADM_UTL' AND priv_count = 0 THEN 'pass'
    WHEN package_name = 'DBMS_STREAMS_ADM_UTL' AND priv_count > 0 THEN 'fail'
    WHEN package_name = 'DBMS_AQADM_SYS' AND priv_count = 0 THEN 'pass'
    WHEN package_name = 'DBMS_AQADM_SYS' AND priv_count > 0 THEN 'fail'
    WHEN package_name = 'DBMS_STREAMS_RPC' AND priv_count = 0 THEN 'pass'
    WHEN package_name = 'DBMS_STREAMS_RPC' AND priv_count > 0 THEN 'fail'
    WHEN package_name = 'DBMS_PRVTAQIM' AND priv_count = 0 THEN 'pass'
    WHEN package_name = 'DBMS_PRVTAQIM' AND priv_count > 0 THEN 'fail'
    WHEN package_name = 'LTADM' AND priv_count = 0 THEN 'pass'
    WHEN package_name = 'LTADM' AND priv_count > 0 THEN 'fail'
    WHEN package_name = 'WWV_DBMS_SQL' AND priv_count = 0 THEN 'pass'
    WHEN package_name = 'WWV_DBMS_SQL' AND priv_count > 0 THEN 'fail'
    WHEN package_name = 'WWV_EXECUTE_IMMEDIATE' AND priv_count = 0 THEN 'pass'
    WHEN package_name = 'WWV_EXECUTE_IMMEDIATE' AND priv_count > 0 THEN 'fail'
    WHEN package_name = 'DBMS_IJOB' AND priv_count = 0 THEN 'pass'
    WHEN package_name = 'DBMS_IJOB' AND priv_count > 0 THEN 'fail'
    WHEN package_name = 'DBMS_FILE_TRANSFER' AND priv_count = 0 THEN 'pass'
    WHEN package_name = 'DBMS_FILE_TRANSFER' AND priv_count > 0 THEN 'fail'
    ELSE 'info'
  END || '">' ||
  '<td>4.2.' ||
  CASE package_name
    WHEN 'DBMS_REPCAT_SQL_UTL' THEN '4'
    WHEN 'INITJVMAUX' THEN '5'
    WHEN 'DBMS_STREAMS_ADM_UTL' THEN '6'
    WHEN 'DBMS_AQADM_SYS' THEN '7'
    WHEN 'DBMS_STREAMS_RPC' THEN '8'
    WHEN 'DBMS_PRVTAQIM' THEN '9'
    WHEN 'LTADM' THEN '10'
    WHEN 'WWV_DBMS_SQL' THEN '11'
    WHEN 'WWV_EXECUTE_IMMEDIATE' THEN '12'
    WHEN 'DBMS_IJOB' THEN '13'
    WHEN 'DBMS_FILE_TRANSFER' THEN '14'
  END || '</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on ' || package_name || ' (Scored)</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN 'PUBLIC has EXECUTE privilege'
    ELSE 'No PUBLIC privilege found'
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON ' || package_name || ' FROM PUBLIC;</td>' ||
  '</tr>'
FROM (
  SELECT 'DBMS_REPCAT_SQL_UTL' AS package_name, COUNT(*) AS priv_count
  FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_REPCAT_SQL_UTL'
  UNION ALL
  SELECT 'INITJVMAUX' AS package_name, COUNT(*) AS priv_count
  FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='INITJVMAUX'
  UNION ALL
  SELECT 'DBMS_STREAMS_ADM_UTL' AS package_name, COUNT(*) AS priv_count
  FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_STREAMS_ADM_UTL'
  UNION ALL
  SELECT 'DBMS_AQADM_SYS' AS package_name, COUNT(*) AS priv_count
  FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_AQADM_SYS'
  UNION ALL
  SELECT 'DBMS_STREAMS_RPC' AS package_name, COUNT(*) AS priv_count
  FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_STREAMS_RPC'
  UNION ALL
  SELECT 'DBMS_PRVTAQIM' AS package_name, COUNT(*) AS priv_count
  FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_PRVTAQIM'
  UNION ALL
  SELECT 'LTADM' AS package_name, COUNT(*) AS priv_count
  FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='LTADM'
  UNION ALL
  SELECT 'WWV_DBMS_SQL' AS package_name, COUNT(*) AS priv_count
  FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='WWV_DBMS_SQL'
  UNION ALL
  SELECT 'WWV_EXECUTE_IMMEDIATE' AS package_name, COUNT(*) AS priv_count
  FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='WWV_EXECUTE_IMMEDIATE'
  UNION ALL
  SELECT 'DBMS_IJOB' AS package_name, COUNT(*) AS priv_count
  FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_IJOB'
  UNION ALL
  SELECT 'DBMS_FILE_TRANSFER' AS package_name, COUNT(*) AS priv_count
  FROM DBA_TAB_PRIVS WHERE GRANTEE='PUBLIC' AND PRIVILEGE='EXECUTE' AND TABLE_NAME='DBMS_FILE_TRANSFER'
)
WHERE (
  -- Oracle 11g (non-multitenant)
  TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) = 11
  OR 
  -- Oracle 12c+ Non-multitenant
  (TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12 AND NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES'))
  OR 
  -- Oracle 12c+ Running from PDB (not CDB$ROOT)
  (TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12 AND 
   EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
ORDER BY package_name;

-- Consolidated query for CDB context (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.2.' ||
  CASE package_name
    WHEN 'DBMS_REPCAT_SQL_UTL' THEN '4'
    WHEN 'INITJVMAUX' THEN '5'
    WHEN 'DBMS_STREAMS_ADM_UTL' THEN '6'
    WHEN 'DBMS_AQADM_SYS' THEN '7'
    WHEN 'DBMS_STREAMS_RPC' THEN '8'
    WHEN 'DBMS_PRVTAQIM' THEN '9'
    WHEN 'LTADM' THEN '10'
    WHEN 'WWV_DBMS_SQL' THEN '11'
    WHEN 'WWV_EXECUTE_IMMEDIATE' THEN '12'
    WHEN 'DBMS_IJOB' THEN '13'
    WHEN 'DBMS_FILE_TRANSFER' THEN '14'
  END || '</td>' ||
  '<td>Ensure EXECUTE Is Revoked from PUBLIC on ' || package_name || ' (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN 'PUBLIC has EXECUTE privilege in ' || container_name
    ELSE 'No PUBLIC privilege found in ' || container_name
    END || '</td>' ||
  '<td>No EXECUTE privilege for PUBLIC</td>' ||
  '<td class="remediation">REVOKE EXECUTE ON ' || package_name || ' FROM PUBLIC;</td>' ||
  '</tr>'
FROM (
  SELECT 
    A.TABLE_NAME AS package_name,
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name
  FROM CDB_TAB_PRIVS A
  WHERE A.GRANTEE='PUBLIC' 
    AND A.PRIVILEGE='EXECUTE' 
    AND A.TABLE_NAME IN ('DBMS_REPCAT_SQL_UTL','INITJVMAUX','DBMS_STREAMS_ADM_UTL','DBMS_AQADM_SYS','DBMS_STREAMS_RPC','DBMS_PRVTAQIM','LTADM','WWV_DBMS_SQL','WWV_EXECUTE_IMMEDIATE','DBMS_IJOB','DBMS_FILE_TRANSFER')
  GROUP BY A.TABLE_NAME, A.CON_ID
  ORDER BY A.CON_ID, A.TABLE_NAME
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- All 4.2 checks are now fully container-aware:
-- Container Detection Logic Implemented:
-- ✓ Oracle Version: TO_NUMBER(SUBSTR(VERSION, 1, 2)) FROM V$INSTANCE
-- ✓ Is CDB: CDB FROM V$DATABASE (YES/NO)
-- ✓ Container Name: SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL (CDB$ROOT, PDB_NAME, or NULL)
-- Execution Logic:
-- ✓ Oracle 11g: Uses DBA_TAB_PRIVS
-- ✓ Oracle 12c+ Non-MT: Uses DBA_TAB_PRIVS  
-- ✓ Oracle 12c+ MT running from PDB: Uses DBA_TAB_PRIVS (PDB-scoped)
-- ✓ Oracle 12c+ MT running from CDB$ROOT: Uses CDB_TAB_PRIVS (cross-container)

PROMPT </table>

-- 4.3 Revoke Excessive System Privileges
PROMPT <h3 id="section4_3">4.3 Revoke Excessive System Privileges</h3>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 4.3.1 SELECT_ANY_DICTIONARY - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.1</td>' ||
  '<td>Ensure SELECT_ANY_DICTIONARY Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('DBA','DBSNMP','OEM_MONITOR','OLAPSYS','ORACLE_OCM','SYSMAN','WMSYS')
HAVING '&version_num' = '11';

-- 4.3.1 SELECT_ANY_DICTIONARY - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.1</td>' ||
  '<td>Ensure SELECT_ANY_DICTIONARY Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE SELECT_ANY_DICTIONARY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='SELECT ANY DICTIONARY'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='SELECT ANY DICTIONARY'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.3.1 SELECT_ANY_DICTIONARY - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.1</td>' ||
  '<td>Ensure SELECT_ANY_DICTIONARY Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE SELECT_ANY_DICTIONARY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='SELECT ANY DICTIONARY'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.3.2 SELECT ANY TABLE - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.2</td>' ||
  '<td>Ensure SELECT ANY TABLE Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('DBA', 'MDSYS', 'SYS', 'IMP_FULL_DATABASE', 'EXP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE', 'WMSYS', 'SYSTEM','OLAP_DBA','OLAPSYS')
HAVING '&version_num' = '11';

-- 4.3.2 SELECT ANY TABLE - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.2</td>' ||
  '<td>Ensure SELECT ANY TABLE Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE SELECT ANY TABLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='SELECT ANY TABLE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='SELECT ANY TABLE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.3.2 SELECT ANY TABLE - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.2</td>' ||
  '<td>Ensure SELECT ANY TABLE Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE SELECT ANY TABLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='SELECT ANY TABLE'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.3.3 AUDIT SYSTEM - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.3</td>' ||
  '<td>Ensure AUDIT SYSTEM Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('DBA','DATAPUMP_IMP_FULL_DATABASE','IMP_FULL_DATABASE','SYS')
HAVING '&version_num' = '11';

-- 4.3.3 AUDIT SYSTEM - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.3</td>' ||
  '<td>Ensure AUDIT SYSTEM Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE AUDIT SYSTEM FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='AUDIT SYSTEM'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='AUDIT SYSTEM'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.3.3 AUDIT SYSTEM - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.3</td>' ||
  '<td>Ensure AUDIT SYSTEM Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE AUDIT SYSTEM FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='AUDIT SYSTEM'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.3.4 EXEMPT ACCESS POLICY - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.4</td>' ||
  '<td>Ensure EXEMPT ACCESS POLICY Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN COUNT(*) > 0 THEN
      LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No grantees found'
    END || '</td>' ||
  '<td>No users should have this privilege</td>' ||
  '<td class="remediation">REVOKE EXEMPT ACCESS POLICY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_SYS_PRIVS
WHERE PRIVILEGE='EXEMPT ACCESS POLICY'
HAVING '&version_num' = '11';

-- 4.3.4 EXEMPT ACCESS POLICY - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.4</td>' ||
  '<td>Ensure EXEMPT ACCESS POLICY Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>No users should have this privilege</td>' ||
  '<td class="remediation">REVOKE EXEMPT ACCESS POLICY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='EXEMPT ACCESS POLICY'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='EXEMPT ACCESS POLICY'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.3.4 EXEMPT ACCESS POLICY - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.4</td>' ||
  '<td>Ensure EXEMPT ACCESS POLICY Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>No users should have this privilege</td>' ||
  '<td class="remediation">REVOKE EXEMPT ACCESS POLICY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='EXEMPT ACCESS POLICY'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.3.5 BECOME USER - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.5</td>' ||
  '<td>Ensure BECOME USER Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE')
HAVING '&version_num' = '11';

-- 4.3.5 BECOME USER - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.5</td>' ||
  '<td>Ensure BECOME USER Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE BECOME USER FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='BECOME USER'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='BECOME USER'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.3.5 BECOME USER - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.5</td>' ||
  '<td>Ensure BECOME USER Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE BECOME USER FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='BECOME USER'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.3.6 CREATE_PROCEDURE - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.6</td>' ||
  '<td>Ensure CREATE_PROCEDURE Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('DBA','DBSNMP','MDSYS','OLAPSYS','OWB$CLIENT','OWBSYS','RECOVERY_CATALOG_OWNER','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYS','APEX_030200','APEX_040000','APEX_040100','APEX_040200','RESOURCE')
HAVING '&version_num' = '11';

-- 4.3.6 CREATE_PROCEDURE - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.6</td>' ||
  '<td>Ensure CREATE_PROCEDURE Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized users and roles should have this privilege</td>' ||
  '<td class="remediation">REVOKE CREATE PROCEDURE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='CREATE PROCEDURE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='CREATE PROCEDURE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.3.6 CREATE_PROCEDURE - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.6</td>' ||
  '<td>Ensure CREATE_PROCEDURE Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized users and roles should have this privilege</td>' ||
  '<td class="remediation">REVOKE CREATE PROCEDURE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='CREATE PROCEDURE'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

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
AND GRANTEE NOT IN ('SYS','SYSTEM','APEX_030200','APEX_040000','APEX_040100','APEX_040200',
'DBA','EM_EXPRESS_ALL','GSMADMIN_INTERNAL','GSMADMIN_ROLE','GSMUSER_ROLE','SYSBACKUP','SYSDG','SYSRAC');

-- 4.3.8 CREATE ANY LIBRARY - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.8</td>' ||
  '<td>Ensure CREATE ANY LIBRARY Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('SYS','SYSTEM','DBA','IMP_FULL_DATABASE')
HAVING '&version_num' = '11';

-- 4.3.8 CREATE ANY LIBRARY - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.8</td>' ||
  '<td>Ensure CREATE ANY LIBRARY Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE CREATE ANY LIBRARY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='CREATE ANY LIBRARY'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='CREATE ANY LIBRARY'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.3.8 CREATE ANY LIBRARY - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.8</td>' ||
  '<td>Ensure CREATE ANY LIBRARY Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE CREATE ANY LIBRARY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='CREATE ANY LIBRARY'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.3.9 CREATE LIBRARY - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.9</td>' ||
  '<td>Ensure CREATE LIBRARY Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('SYS','SYSTEM','DBA','SPATIAL_CSW_ADMIN_USR','XDB','EXFSYS','MDSYS','SPATIAL_WFS_ADMIN_USR')
HAVING '&version_num' = '11';

-- 4.3.9 CREATE LIBRARY - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.9</td>' ||
  '<td>Ensure CREATE LIBRARY Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE CREATE LIBRARY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='CREATE LIBRARY'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='CREATE LIBRARY'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.3.9 CREATE LIBRARY - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.9</td>' ||
  '<td>Ensure CREATE LIBRARY Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE CREATE LIBRARY FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='CREATE LIBRARY'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.3.10 GRANT ANY OBJECT PRIVILEGE - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.10</td>' ||
  '<td>Ensure GRANT ANY OBJECT PRIVILEGE Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE')
HAVING '&version_num' = '11';

-- 4.3.10 GRANT ANY OBJECT PRIVILEGE - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.10</td>' ||
  '<td>Ensure GRANT ANY OBJECT PRIVILEGE Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE GRANT ANY OBJECT PRIVILEGE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='GRANT ANY OBJECT PRIVILEGE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='GRANT ANY OBJECT PRIVILEGE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.3.10 GRANT ANY OBJECT PRIVILEGE - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.10</td>' ||
  '<td>Ensure GRANT ANY OBJECT PRIVILEGE Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE GRANT ANY OBJECT PRIVILEGE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='GRANT ANY OBJECT PRIVILEGE'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.3.11 GRANT ANY ROLE - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.11</td>' ||
  '<td>Ensure GRANT ANY ROLE Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('DBA','SYS','DATAPUMP_IMP_FULL_DATABASE','IMP_FULL_DATABASE','SPATIAL_WFS_ADMIN_USR','SPATIAL_CSW_ADMIN_USR')
HAVING '&version_num' = '11';

-- 4.3.11 GRANT ANY ROLE - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.11</td>' ||
  '<td>Ensure GRANT ANY ROLE Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE GRANT ANY ROLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='GRANT ANY ROLE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='GRANT ANY ROLE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.3.11 GRANT ANY ROLE - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.11</td>' ||
  '<td>Ensure GRANT ANY ROLE Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE GRANT ANY ROLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='GRANT ANY ROLE'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.3.12 GRANT ANY PRIVILEGE - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.12</td>' ||
  '<td>Ensure GRANT ANY PRIVILEGE Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE')
HAVING '&version_num' = '11';

-- 4.3.12 GRANT ANY PRIVILEGE - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.12</td>' ||
  '<td>Ensure GRANT ANY PRIVILEGE Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE GRANT ANY PRIVILEGE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='GRANT ANY PRIVILEGE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='GRANT ANY PRIVILEGE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.3.12 GRANT ANY PRIVILEGE - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.3.12</td>' ||
  '<td>Ensure GRANT ANY PRIVILEGE Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have this privilege</td>' ||
  '<td class="remediation">REVOKE GRANT ANY PRIVILEGE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='GRANT ANY PRIVILEGE'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

PROMPT </table>

-- 4.4 Revoke Role Privileges
PROMPT <h3 id="section4_4">4.4 Revoke Role Privileges</h3>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 4.4.1 DELETE_CATALOG_ROLE - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.1</td>' ||
  '<td>Ensure DELETE_CATALOG_ROLE Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('DBA','SYS')
HAVING '&version_num' = '11';

-- 4.4.1 DELETE_CATALOG_ROLE - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.1</td>' ||
  '<td>Ensure DELETE_CATALOG_ROLE Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this role</td>' ||
  '<td class="remediation">REVOKE DELETE_CATALOG_ROLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_ROLE_PRIVS 
     WHERE GRANTED_ROLE='DELETE_CATALOG_ROLE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_ROLE_PRIVS 
     WHERE GRANTED_ROLE='DELETE_CATALOG_ROLE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.4.1 DELETE_CATALOG_ROLE - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.1</td>' ||
  '<td>Ensure DELETE_CATALOG_ROLE Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have this role</td>' ||
  '<td class="remediation">REVOKE DELETE_CATALOG_ROLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_ROLE_PRIVS A
  WHERE A.GRANTED_ROLE='DELETE_CATALOG_ROLE'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.4.2 SELECT_CATALOG_ROLE - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.2</td>' ||
  '<td>Ensure SELECT_CATALOG_ROLE Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE','EXP_FULL_DATABASE','OEM_MONITOR','SYSMAN')
HAVING '&version_num' = '11';

-- 4.4.2 SELECT_CATALOG_ROLE - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.2</td>' ||
  '<td>Ensure SELECT_CATALOG_ROLE Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this role</td>' ||
  '<td class="remediation">REVOKE SELECT_CATALOG_ROLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_ROLE_PRIVS 
     WHERE GRANTED_ROLE='SELECT_CATALOG_ROLE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_ROLE_PRIVS 
     WHERE GRANTED_ROLE='SELECT_CATALOG_ROLE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.4.2 SELECT_CATALOG_ROLE - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.2</td>' ||
  '<td>Ensure SELECT_CATALOG_ROLE Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have this role</td>' ||
  '<td class="remediation">REVOKE SELECT_CATALOG_ROLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_ROLE_PRIVS A
  WHERE A.GRANTED_ROLE='SELECT_CATALOG_ROLE'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.4.3 EXECUTE_CATALOG_ROLE - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.3</td>' ||
  '<td>Ensure EXECUTE_CATALOG_ROLE Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('DBA','SYS','IMP_FULL_DATABASE','EXP_FULL_DATABASE')
HAVING '&version_num' = '11';

-- 4.4.3 EXECUTE_CATALOG_ROLE - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.3</td>' ||
  '<td>Ensure EXECUTE_CATALOG_ROLE Is Revoked from Unauthorized GRANTEE (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found'
    END || '</td>' ||
  '<td>Only authorized system users should have this role</td>' ||
  '<td class="remediation">REVOKE EXECUTE_CATALOG_ROLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_ROLE_PRIVS 
     WHERE GRANTED_ROLE='EXECUTE_CATALOG_ROLE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_ROLE_PRIVS 
     WHERE GRANTED_ROLE='EXECUTE_CATALOG_ROLE'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS grantee_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.4.3 EXECUTE_CATALOG_ROLE - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.3</td>' ||
  '<td>Ensure EXECUTE_CATALOG_ROLE Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN grantee_list
    ELSE 'No unauthorized grantees found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have this role</td>' ||
  '<td class="remediation">REVOKE EXECUTE_CATALOG_ROLE FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS grantee_list
  FROM CDB_ROLE_PRIVS A
  WHERE A.GRANTED_ROLE='EXECUTE_CATALOG_ROLE'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.4.4 DBA - Oracle 11g
SELECT '<tr class="' ||
  CASE
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.4</td>' ||
  '<td>Ensure DBA Is Revoked from Unauthorized GRANTEE (Scored) - 11g</td>' ||
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
AND GRANTEE NOT IN ('SYS','SYSTEM')
HAVING '&version_num' = '11';

-- 4.4.4 DBA - Oracle 12c+ Non-multitenant OR when running from PDB
WITH dba_access AS (
  -- Direct DBA role grants
  SELECT 'GRANT' AS PATH, GRANTEE, GRANTED_ROLE
  FROM DBA_ROLE_PRIVS
  WHERE GRANTED_ROLE = 'DBA' 
    AND GRANTEE NOT IN ('SYS', 'SYSTEM')
    AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
  UNION
  -- Proxy access to DBA users
  SELECT 'PROXY', PROXY || '-' || CLIENT, 'DBA'
  FROM DBA_PROXIES
  WHERE CLIENT IN (SELECT GRANTEE FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE = 'DBA')
    AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
),
dba_env_info AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
),
dba_access_summary AS (
  SELECT 
    COUNT(*) AS access_count,
    LISTAGG(PATH || ':' || GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) AS access_list
  FROM dba_access
)
SELECT '<tr class="' ||
  CASE
    WHEN s.access_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.4</td>' ||
  '<td>Ensure DBA Is Revoked from Unauthorized GRANTEE (Scored) - ' || e.env_type || '</td>' ||
  '<td>' || CASE WHEN s.access_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN s.access_count > 0 THEN s.access_list
    ELSE 'No unauthorized DBA access found'
    END || '</td>' ||
  '<td>Only SYS and SYSTEM should have DBA role</td>' ||
  '<td class="remediation">REVOKE DBA FROM &lt;grantee&gt;; or ALTER USER &lt;proxy&gt; REVOKE CONNECT THROUGH &lt;client&gt;;</td>' ||
  '</tr>'
FROM dba_access_summary s CROSS JOIN dba_env_info e;

-- 4.4.4 DBA - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
WITH dba_access_cdb AS (
  -- Direct DBA role grants
  SELECT 'GRANT' AS PATH, A.GRANTEE, A.GRANTED_ROLE,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS CON
  FROM CDB_ROLE_PRIVS A
  WHERE A.GRANTED_ROLE='DBA'
  AND A.GRANTEE NOT IN ('SYS', 'SYSTEM')
    AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  UNION
  -- Proxy access to DBA users
  SELECT 'PROXY', A.PROXY || '-' || A.CLIENT, 'DBA',
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS CON
  FROM CDB_PROXIES A
  WHERE A.CLIENT IN (SELECT B.GRANTEE FROM CDB_ROLE_PRIVS B WHERE B.GRANTED_ROLE = 'DBA' AND A.CON_ID = B.CON_ID)
    AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
),
dba_access_summary AS (
  SELECT 
    CON AS container_name,
    COUNT(*) AS access_count,
    LISTAGG(PATH || ':' || GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) AS access_list
  FROM dba_access_cdb
  GROUP BY CON
  ORDER BY CON
)
SELECT '<tr class="' ||
  CASE
    WHEN access_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.4</td>' ||
  '<td>Ensure DBA Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN access_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN access_count > 0 THEN access_list
    ELSE 'No unauthorized DBA access found in ' || container_name
    END || '</td>' ||
  '<td>Only SYS and SYSTEM should have DBA role</td>' ||
  '<td class="remediation">REVOKE DBA FROM &lt;grantee&gt;; or ALTER USER &lt;proxy&gt; REVOKE CONNECT THROUGH &lt;client&gt;;</td>' ||
  '</tr>'
FROM dba_access_summary;

-- 4.4.5 AUDIT_ADMIN - Oracle 18c+ Non-multitenant OR when running from PDB
WITH audit_admin_access AS (
  -- Direct AUDIT_ADMIN role grants
  SELECT 'GRANT' AS PATH, GRANTEE, GRANTED_ROLE
  FROM DBA_ROLE_PRIVS
  WHERE GRANTED_ROLE = 'AUDIT_ADMIN' 
  AND GRANTEE NOT IN ('SYS', 'SYSTEM')
    AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
  UNION
  -- Proxy access to AUDIT_ADMIN users
  SELECT 'PROXY', PROXY || '-' || CLIENT, 'AUDIT_ADMIN'
  FROM DBA_PROXIES
  WHERE CLIENT IN (SELECT GRANTEE FROM DBA_ROLE_PRIVS WHERE GRANTED_ROLE = 'AUDIT_ADMIN')
    AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
),
environment_info AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '18c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '18c+ Non-MT'
    END AS env_type
  FROM DUAL
),
audit_admin_summary AS (
  SELECT 
    COUNT(*) AS access_count,
    LISTAGG(PATH || ':' || GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) AS access_list
  FROM audit_admin_access
)
SELECT '<tr class="' ||
  CASE
    WHEN s.access_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.5</td>' ||
  '<td>Ensure AUDIT_ADMIN Is Revoked from Unauthorized GRANTEE (Scored) - ' || e.env_type || '</td>' ||
  '<td>' || CASE WHEN s.access_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN s.access_count > 0 THEN s.access_list
    ELSE 'No unauthorized AUDIT_ADMIN access found'
    END || '</td>' ||
  '<td>Only authorized system users should have AUDIT_ADMIN role</td>' ||
  '<td class="remediation">REVOKE AUDIT_ADMIN FROM &lt;grantee&gt;; or ALTER USER &lt;proxy&gt; REVOKE CONNECT THROUGH &lt;client&gt;;</td>' ||
  '</tr>'
FROM audit_admin_summary s CROSS JOIN environment_info e;

-- 4.4.5 AUDIT_ADMIN - Oracle 18c+ Multitenant CDB (when running from CDB$ROOT)
WITH audit_admin_access_cdb AS (
  -- Direct AUDIT_ADMIN role grants
  SELECT 'GRANT' AS PATH, A.GRANTEE, A.GRANTED_ROLE,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS CON
  FROM CDB_ROLE_PRIVS A
  WHERE A.GRANTED_ROLE='AUDIT_ADMIN'
  AND A.GRANTEE NOT IN ('SYS', 'SYSTEM')
    AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  UNION
  -- Proxy access to AUDIT_ADMIN users
  SELECT 'PROXY', A.PROXY || '-' || A.CLIENT, 'AUDIT_ADMIN',
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS CON
  FROM CDB_PROXIES A
  WHERE A.CLIENT IN (SELECT B.GRANTEE FROM CDB_ROLE_PRIVS B WHERE B.GRANTED_ROLE = 'AUDIT_ADMIN' AND A.CON_ID = B.CON_ID)
    AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
),
audit_admin_access_summary AS (
  SELECT 
    CON AS container_name,
    COUNT(*) AS access_count,
    LISTAGG(PATH || ':' || GRANTEE, ', ') WITHIN GROUP (ORDER BY GRANTEE) AS access_list
  FROM audit_admin_access_cdb
  GROUP BY CON
  ORDER BY CON
)
SELECT '<tr class="' ||
  CASE
    WHEN access_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.4.5</td>' ||
  '<td>Ensure AUDIT_ADMIN Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN access_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN access_count > 0 THEN access_list
    ELSE 'No unauthorized AUDIT_ADMIN access found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have AUDIT_ADMIN role</td>' ||
  '<td class="remediation">REVOKE AUDIT_ADMIN FROM &lt;grantee&gt;; or ALTER USER &lt;proxy&gt; REVOKE CONNECT THROUGH &lt;client&gt;;</td>' ||
  '</tr>'
FROM audit_admin_access_summary;

PROMPT </table>

-- 4.5 Revoke Excessive Table and View Privileges
PROMPT <h3 id="section4_5">4.5 Revoke Excessive Table and View Privileges</h3>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 4.5.1 ALL on AUD$ - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.1</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on AUD$ (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>Only DELETE_CATALOG_ROLE should have privileges on AUD$</td>' ||
  '<td class="remediation">REVOKE ALL ON SYS.AUD$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='AUD$'
AND GRANTEE NOT IN ('DELETE_CATALOG_ROLE')
HAVING '&version_num' = '11';

-- 4.5.1 ALL on AUD$ - Oracle 12c+ Non-multitenant OR when running from PDB
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.1</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on AUD$ (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on SYS.AUD$</td>' ||
  '<td class="remediation">REVOKE ALL ON SYS.AUD$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_TAB_PRIVS 
     WHERE TABLE_NAME='AUD$'
       AND OWNER = 'SYS'
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_TAB_PRIVS 
     WHERE TABLE_NAME='AUD$'
       AND OWNER = 'SYS'
       AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )) AS privilege_list,
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
  WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND (
      -- Non-multitenant database
      NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
      OR 
      -- Running from PDB (not CDB$ROOT)
      (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
       (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
    )
);

-- 4.5.1 ALL on AUD$ - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.1</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on AUD$ (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on SYS.AUD$</td>' ||
  '<td class="remediation">REVOKE ALL ON SYS.AUD$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME='AUD$'
  AND A.OWNER = 'SYS'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.5.2 ALL on USER_HISTORY$ - Oracle 11g and 12c+ Non-multitenant/PDB
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.2</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on USER_HISTORY$ (Scored) - ' || version_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on USER_HISTORY$</td>' ||
  '<td class="remediation">REVOKE ALL ON USER_HISTORY$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_TAB_PRIVS 
     WHERE TABLE_NAME='USER_HISTORY$'
       AND (
         -- Oracle 11g: no grantee filtering
         (SELECT version FROM v$instance) LIKE '11.%'
         OR
         -- Oracle 12c+ non-multitenant or PDB: filter Oracle-maintained users/roles
         ((SELECT version FROM v$instance) NOT LIKE '11.%'
          AND OWNER = 'SYS'
          AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
          AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
          AND (
            NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
            OR 
            (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
             (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
          )
         )
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_TAB_PRIVS 
     WHERE TABLE_NAME='USER_HISTORY$'
       AND (
         -- Oracle 11g: no grantee filtering
         (SELECT version FROM v$instance) LIKE '11.%'
         OR
         -- Oracle 12c+ non-multitenant or PDB: filter Oracle-maintained users/roles
         ((SELECT version FROM v$instance) NOT LIKE '11.%'
          AND OWNER = 'SYS'
          AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
          AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
          AND (
            NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
            OR 
            (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
             (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
          )
         )
       )) AS privilege_list,
    CASE 
      WHEN (SELECT version FROM v$instance) LIKE '11.%' THEN 'Oracle 11g'
      ELSE '12c+ Non-MT'
    END AS version_type
  FROM DUAL
);

-- 4.5.2 ALL on USER_HISTORY$ - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.2</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on USER_HISTORY$ (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on USER_HISTORY$</td>' ||
  '<td class="remediation">REVOKE ALL ON USER_HISTORY$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME='USER_HISTORY$'
  AND A.OWNER = 'SYS'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE (SELECT version FROM v$instance) NOT LIKE '11.%'
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.5.3 ALL on LINK$ - Oracle 11g and 12c+ Non-multitenant/PDB
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.3</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on LINK$ (Scored) - ' || version_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on LINK$</td>' ||
  '<td class="remediation">REVOKE ALL ON LINK$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_TAB_PRIVS 
     WHERE TABLE_NAME='LINK$'
       AND (
         -- Oracle 11g: no grantee filtering
         (SELECT version FROM v$instance) LIKE '11.%'
         OR
         -- Oracle 12c+ non-multitenant or PDB: filter Oracle-maintained users/roles
         ((SELECT version FROM v$instance) NOT LIKE '11.%'
          AND OWNER = 'SYS'
          AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
          AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
          AND (
            NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
            OR 
            (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
             (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
          )
         )
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_TAB_PRIVS 
     WHERE TABLE_NAME='LINK$'
       AND (
         -- Oracle 11g: no grantee filtering
         (SELECT version FROM v$instance) LIKE '11.%'
         OR
         -- Oracle 12c+ non-multitenant or PDB: filter Oracle-maintained users/roles
         ((SELECT version FROM v$instance) NOT LIKE '11.%'
          AND OWNER = 'SYS'
          AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
          AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
          AND (
            NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
            OR 
            (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
             (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
          )
         )
       )) AS privilege_list,
    CASE 
      WHEN (SELECT version FROM v$instance) LIKE '11.%' THEN 'Oracle 11g'
      ELSE '12c+ Non-MT'
    END AS version_type
  FROM DUAL
);

-- 4.5.3 ALL on LINK$ - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.3</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on LINK$ (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on LINK$</td>' ||
  '<td class="remediation">REVOKE ALL ON LINK$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME='LINK$'
  AND A.OWNER = 'SYS'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE (SELECT version FROM v$instance) NOT LIKE '11.%'
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.5.4 ALL on SYS.USER$ - Oracle 11g and 12c+ Non-multitenant/PDB
WITH user_privileges AS (
  SELECT GRANTEE, PRIVILEGE
  FROM DBA_TAB_PRIVS 
  WHERE TABLE_NAME='USER$'
    AND (
      -- Oracle 11g: use hardcoded exclusion list
      ((SELECT version FROM v$instance) LIKE '11.%'
       AND GRANTEE NOT IN ('CTXSYS','XDB','APEX_030200','APEX_040000','APEX_040100','APEX_040200','ORACLE_OCM'))
      OR
      -- Oracle 12c+ non-multitenant or PDB: filter Oracle-maintained users/roles
      ((SELECT version FROM v$instance) NOT LIKE '11.%'
       AND OWNER = 'SYS'
       AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
       AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
       AND (
         NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
         OR 
         (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
          (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
       )
      )
    )
),
version_info AS (
  SELECT 
    CASE 
      WHEN (SELECT version FROM v$instance) LIKE '11.%' THEN 'Oracle 11g'
      ELSE '12c+ Non-MT'
    END AS version_type
  FROM DUAL
),
user_priv_summary AS (
  SELECT 
    COUNT(*) AS priv_count,
    LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE) AS privilege_list
  FROM user_privileges
)
SELECT '<tr class="' ||
  CASE 
    WHEN s.priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.4</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on SYS.USER$ (Scored) - ' || v.version_type || '</td>' ||
  '<td>' || CASE WHEN s.priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN s.priv_count > 0 THEN s.privilege_list
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on SYS.USER$</td>' ||
  '<td class="remediation">REVOKE ALL ON SYS.USER$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM user_priv_summary s CROSS JOIN version_info v;

-- 4.5.4 ALL on SYS.USER$ - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
WITH user_priv_cdb AS (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME='USER$'
  AND A.OWNER = 'SYS'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
    AND (SELECT version FROM v$instance) NOT LIKE '11.%'
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.4</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on SYS.USER$ (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on SYS.USER$</td>' ||
  '<td class="remediation">REVOKE ALL ON SYS.USER$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM user_priv_cdb;

-- 4.5.5 ALL on DBA_% - Oracle 11g and 12c+ Non-multitenant/PDB
WITH dba_privileges AS (
  SELECT TABLE_NAME, GRANTEE, PRIVILEGE
  FROM DBA_TAB_PRIVS
  WHERE (
    -- Oracle 11g: use specified exclusion list
    ((SELECT version FROM v$instance) LIKE '11.%'
     AND TABLE_NAME LIKE 'DBA_%'
     AND GRANTEE NOT IN ('APPQOSSYS','AQ_ADMINISTRATOR_ROLE','CTXSYS','EXFSYS','MDSYS',
     'OLAP_XS_ADMIN','OLAPSYS','ORDSYS','OWB$CLIENT','OWBSYS','SELECT_CATALOG_ROLE',
     'WM_ADMIN_ROLE','WMSYS','XDBADMIN','LBACSYS','ADM_PARALLEL_EXECUTE_TASK','CISSCANROLE')
     AND NOT REGEXP_LIKE(GRANTEE,'^APEX_0[3-9][0-9][0-9][0-9][0-9]$'))
    OR
    -- Oracle 12c+ non-multitenant or PDB: filter Oracle-maintained users/roles
    ((SELECT version FROM v$instance) NOT LIKE '11.%'
     AND TABLE_NAME LIKE 'DBA\_%' ESCAPE '\'
     AND OWNER = 'SYS'
     AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
     AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
     AND (
       -- Non-multitenant database
       NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
       OR 
       -- Running from PDB (not CDB$ROOT)
       (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
        (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
     )
    )
  )
),
dba_version_info AS (
  SELECT 
    CASE 
      WHEN (SELECT version FROM v$instance) LIKE '11.%' THEN 'Oracle 11g'
      ELSE '12c+ Non-MT'
    END AS version_type
  FROM DUAL
),
dba_priv_summary AS (
  SELECT 
    COUNT(*) AS priv_count
  FROM dba_privileges
)
SELECT '<tr class="' ||
  CASE 
    WHEN s.priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.5</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on DBA_% (Scored) - ' || v.version_type || '</td>' ||
  '<td>' || CASE WHEN s.priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN s.priv_count > 0 THEN 
      'Found ' || s.priv_count || ' unauthorized privileges on DBA views'
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on DBA_% views</td>' ||
  '<td class="remediation">REVOKE ALL ON &lt;dba_view&gt; FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM dba_priv_summary s CROSS JOIN dba_version_info v;

-- 4.5.5 ALL on DBA_% - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
WITH dba_priv_cdb AS (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.TABLE_NAME, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME LIKE 'DBA\_%' ESCAPE '\'
  AND A.OWNER = 'SYS'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
    AND (SELECT version FROM v$instance) NOT LIKE '11.%'
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.5</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on DBA_% (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN 'Found ' || priv_count || ' unauthorized privileges on DBA views in ' || container_name
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on DBA_% views</td>' ||
  '<td class="remediation">REVOKE ALL ON &lt;dba_view&gt; FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM dba_priv_cdb;

-- 4.5.6 ALL on SYS.SCHEDULER$_CREDENTIAL - Oracle 11g and 12c+ Non-multitenant/PDB
WITH scheduler_privileges AS (
  SELECT GRANTEE, PRIVILEGE
  FROM DBA_TAB_PRIVS
  WHERE TABLE_NAME='SCHEDULER$_CREDENTIAL'
  AND (
    -- Oracle 11g: no grantee filtering
    (SELECT version FROM v$instance) LIKE '11.%'
    OR
    -- Oracle 12c+ non-multitenant or PDB: filter Oracle-maintained users/roles
    ((SELECT version FROM v$instance) NOT LIKE '11.%'
     AND OWNER = 'SYS'
     AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
     AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
     AND (
       -- Non-multitenant database
       NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
       OR 
       -- Running from PDB (not CDB$ROOT)
       (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
        (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
     )
    )
  )
),
scheduler_version_info AS (
  SELECT 
    CASE 
      WHEN (SELECT version FROM v$instance) LIKE '11.%' THEN 'Oracle 11g'
      ELSE '12c+ Non-MT'
    END AS version_type
  FROM DUAL
),
scheduler_priv_summary AS (
  SELECT 
    COUNT(*) AS priv_count,
    LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE) AS privilege_list
  FROM scheduler_privileges
)
SELECT '<tr class="' ||
  CASE 
    WHEN s.priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on SYS.SCHEDULER$_CREDENTIAL (Scored) - ' || v.version_type || '</td>' ||
  '<td>' || CASE WHEN s.priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN s.priv_count > 0 THEN s.privilege_list
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on SYS.SCHEDULER$_CREDENTIAL</td>' ||
  '<td class="remediation">REVOKE ALL ON SYS.SCHEDULER$_CREDENTIAL FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM scheduler_priv_summary s CROSS JOIN scheduler_version_info v;

-- 4.5.6 ALL on SYS.SCHEDULER$_CREDENTIAL - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
WITH scheduler_priv_cdb AS (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME='SCHEDULER$_CREDENTIAL'
  AND A.OWNER = 'SYS'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
    AND (SELECT version FROM v$instance) NOT LIKE '11.%'
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on SYS.SCHEDULER$_CREDENTIAL (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on SYS.SCHEDULER$_CREDENTIAL</td>' ||
  '<td class="remediation">REVOKE ALL ON SYS.SCHEDULER$_CREDENTIAL FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM scheduler_priv_cdb;

-- 4.5.6a ALL on CDB_LOCAL_ADMINAUTH$ - Oracle 12c+ Non-multitenant/PDB
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6a</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on CDB_LOCAL_ADMINAUTH$ (Oracle 12c+) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on CDB_LOCAL_ADMINAUTH$</td>' ||
  '<td class="remediation">REVOKE ALL ON CDB_LOCAL_ADMINAUTH$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='CDB_LOCAL_ADMINAUTH$'
AND (SELECT version FROM v$instance) NOT LIKE '11.%'
AND OWNER = 'SYS'
AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
);

-- 4.5.6a ALL on CDB_LOCAL_ADMINAUTH$ - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
WITH cdb_admin_priv_cdb AS (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME='CDB_LOCAL_ADMINAUTH$'
  AND A.OWNER = 'SYS'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
    AND (SELECT version FROM v$instance) NOT LIKE '11.%'
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6a</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on CDB_LOCAL_ADMINAUTH$ (Oracle 12c+) (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on CDB_LOCAL_ADMINAUTH$</td>' ||
  '<td class="remediation">REVOKE ALL ON CDB_LOCAL_ADMINAUTH$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM cdb_admin_priv_cdb;

-- 4.5.6b ALL on DEFAULT_PWD$ - Oracle 12c+ Non-multitenant/PDB
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6b</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on DEFAULT_PWD$ (Oracle 12c+) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on DEFAULT_PWD$</td>' ||
  '<td class="remediation">REVOKE ALL ON DEFAULT_PWD$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='DEFAULT_PWD$'
AND (SELECT version FROM v$instance) NOT LIKE '11.%'
AND OWNER = 'SYS'
AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
);

-- 4.5.6b ALL on DEFAULT_PWD$ - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
WITH default_pwd_priv_cdb AS (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME='DEFAULT_PWD$'
  AND A.OWNER = 'SYS'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
    AND (SELECT version FROM v$instance) NOT LIKE '11.%'
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6b</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on DEFAULT_PWD$ (Oracle 12c+) (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on DEFAULT_PWD$</td>' ||
  '<td class="remediation">REVOKE ALL ON DEFAULT_PWD$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM default_pwd_priv_cdb;

-- 4.5.6c ALL on ENC$ - Oracle 12c+ Non-multitenant/PDB
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6c</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on ENC$ (Oracle 12c+) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on ENC$</td>' ||
  '<td class="remediation">REVOKE ALL ON ENC$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='ENC$'
AND (SELECT version FROM v$instance) NOT LIKE '11.%'
AND OWNER = 'SYS'
AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
);

-- 4.5.6c ALL on ENC$ - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
WITH enc_priv_cdb AS (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME='ENC$'
  AND A.OWNER = 'SYS'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
    AND (SELECT version FROM v$instance) NOT LIKE '11.%'
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6c</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on ENC$ (Oracle 12c+) (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on ENC$</td>' ||
  '<td class="remediation">REVOKE ALL ON ENC$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM enc_priv_cdb;

-- 4.5.6d ALL on HISTGRM$ - Oracle 12c+ Non-multitenant/PDB
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6d</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on HISTGRM$ (Oracle 12c+) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on HISTGRM$</td>' ||
  '<td class="remediation">REVOKE ALL ON HISTGRM$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='HISTGRM$'
AND (SELECT version FROM v$instance) NOT LIKE '11.%'
AND OWNER = 'SYS'
AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
);

-- 4.5.6d ALL on HISTGRM$ - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
WITH histgrm_priv_cdb AS (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME='HISTGRM$'
  AND A.OWNER = 'SYS'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
    AND (SELECT version FROM v$instance) NOT LIKE '11.%'
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6d</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on HISTGRM$ (Oracle 12c+) (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on HISTGRM$</td>' ||
  '<td class="remediation">REVOKE ALL ON HISTGRM$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM histgrm_priv_cdb;

-- 4.5.6e ALL on HIST_HEAD$ - Oracle 12c+ Non-multitenant/PDB
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6e</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on HIST_HEAD$ (Oracle 12c+) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on HIST_HEAD$</td>' ||
  '<td class="remediation">REVOKE ALL ON HIST_HEAD$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='HIST_HEAD$'
AND (SELECT version FROM v$instance) NOT LIKE '11.%'
AND OWNER = 'SYS'
AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
);

-- 4.5.6e ALL on HIST_HEAD$ - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
WITH hist_head_priv_cdb AS (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME='HIST_HEAD$'
  AND A.OWNER = 'SYS'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
    AND (SELECT version FROM v$instance) NOT LIKE '11.%'
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6e</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on HIST_HEAD$ (Oracle 12c+) (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on HIST_HEAD$</td>' ||
  '<td class="remediation">REVOKE ALL ON HIST_HEAD$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM hist_head_priv_cdb;

-- 4.5.6f ALL on PDB_SYNC$ - Oracle 12c+ Non-multitenant/PDB
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6f</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on PDB_SYNC$ (Oracle 12c+) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on PDB_SYNC$</td>' ||
  '<td class="remediation">REVOKE ALL ON PDB_SYNC$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='PDB_SYNC$'
AND (SELECT version FROM v$instance) NOT LIKE '11.%'
AND OWNER = 'SYS'
AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
);

-- 4.5.6f ALL on PDB_SYNC$ - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6f</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on PDB_SYNC$ (Oracle 12c+) (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on PDB_SYNC$</td>' ||
  '<td class="remediation">REVOKE ALL ON PDB_SYNC$ FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME='PDB_SYNC$'
  AND A.OWNER = 'SYS'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE (SELECT version FROM v$instance) NOT LIKE '11.%'
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.5.6g ALL on XS$VERIFIERS - Oracle 12c+ Non-multitenant/PDB
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6g</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on XS$VERIFIERS (Oracle 12c+) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE)
    ELSE 'No unauthorized privileges found'
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on XS$VERIFIERS</td>' ||
  '<td class="remediation">REVOKE ALL ON XS$VERIFIERS FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM DBA_TAB_PRIVS
WHERE TABLE_NAME='XS$VERIFIERS'
AND (SELECT version FROM v$instance) NOT LIKE '11.%'
AND OWNER = 'SYS'
AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
);

-- 4.5.6g ALL on XS$VERIFIERS - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.6g</td>' ||
  '<td>Ensure ALL Is Revoked from Unauthorized GRANTEE on XS$VERIFIERS (Oracle 12c+) (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN privilege_list
    ELSE 'No unauthorized privileges found in ' || container_name
    END || '</td>' ||
  '<td>No unauthorized privileges should be granted on XS$VERIFIERS</td>' ||
  '<td class="remediation">REVOKE ALL ON XS$VERIFIERS FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_TAB_PRIVS A
  WHERE A.TABLE_NAME='XS$VERIFIERS'
  AND A.OWNER = 'SYS'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE (SELECT version FROM v$instance) NOT LIKE '11.%'
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.5.7 Ensure 'SYS.USER$MIG' Has Been Dropped (11g and 12c+ non-multitenant/PDB)
WITH user_mig_11g AS (
  SELECT 
    vi.version,
    at.OWNER,
    at.TABLE_NAME
  FROM v$instance vi
  CROSS JOIN ALL_TABLES at
  WHERE vi.version LIKE '11.%'
  AND at.OWNER='SYS'
  AND at.TABLE_NAME='USER$MIG'
),
user_mig_12c_non_mt AS (
  SELECT 
    vi.version,
    dt.OWNER,
    dt.TABLE_NAME
  FROM v$instance vi
  CROSS JOIN DBA_TABLES dt
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND dt.TABLE_NAME='USER$MIG' 
  AND dt.OWNER='SYS'
),
user_mig_combined AS (
  SELECT version, OWNER, TABLE_NAME FROM user_mig_11g
  UNION ALL
  SELECT version, OWNER, TABLE_NAME FROM user_mig_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM user_mig_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.7</td>' ||
  '<td>Ensure SYS.USER$MIG Has Been Dropped (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM user_mig_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM user_mig_combined) > 0 THEN 
      'SYS.USER$MIG table found'
    ELSE 'SYS.USER$MIG table not found (compliant)'
    END || '</td>' ||
  '<td>SYS.USER$MIG table should be dropped</td>' ||
  '<td class="remediation">DROP TABLE SYS.USER$MIG;</td>' ||
  '</tr>'
FROM DUAL;

-- 4.5.7b Ensure 'SYS.USER$MIG' Has Been Dropped (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(T.TABLE_NAME) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.5.7b</td>' ||
  '<td>Ensure SYS.USER$MIG Has Been Dropped in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(T.TABLE_NAME) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(T.TABLE_NAME) > 0 THEN 
      'SYS.USER$MIG found in: ' || LISTAGG(DECODE(T.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE T.CON_ID = B.CON_ID)), ', ') WITHIN GROUP (ORDER BY T.CON_ID)
    ELSE 'SYS.USER$MIG table not found in any container (compliant)'
    END || '</td>' ||
  '<td>SYS.USER$MIG table should be dropped from all containers</td>' ||
  '<td class="remediation">For each container: DROP TABLE SYS.USER$MIG;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    A.CON_ID,
    A.OWNER,
    A.TABLE_NAME
  FROM CDB_TABLES A
  WHERE A.TABLE_NAME='USER$MIG' 
  AND A.OWNER='SYS'
) T
GROUP BY ef.env_type;

PROMPT </table>

-- 4.6 Additional Security Checks
PROMPT <h3 id="section4_6">4.6-4.10 Additional Security Checks</h3>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 4.6 %ANY% Privileges - Oracle 11g and 12c+ Non-multitenant/PDB
WITH any_privileges AS (
  SELECT GRANTEE, PRIVILEGE
  FROM DBA_SYS_PRIVS
  WHERE PRIVILEGE LIKE '%ANY%'
  AND (
    -- Oracle 11g: use specified exclusion list
    ((SELECT version FROM v$instance) LIKE '11.%'
     AND GRANTEE NOT IN ('AQ_ADMINISTRATOR_ROLE','DBA','DBSNMP','EXFSYS',
     'EXP_FULL_DATABASE','IMP_FULL_DATABASE','DATAPUMP_IMP_FULL_DATABASE',
     'JAVADEBUGPRIV','MDSYS','OEM_MONITOR','OLAPSYS','OLAP_DBA','ORACLE_OCM',
     'OWB$CLIENT','OWBSYS','SCHEDULER_ADMIN','SPATIAL_CSW_ADMIN_USR',
     'SPATIAL_WFS_ADMIN_USR','SYS','SYSMAN','SYSTEM','WMSYS','APEX_030200',
     'APEX_040000','APEX_040100','APEX_040200','LBACSYS','OUTLN'))
    OR
    -- Oracle 12c+ non-multitenant or PDB: filter Oracle-maintained users/roles
    ((SELECT version FROM v$instance) NOT LIKE '11.%'
     AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
     AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
     AND (
       -- Non-multitenant database
       NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
       OR 
       -- Running from PDB (not CDB$ROOT)
       (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
        (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
     )
    )
  )
),
any_version_info AS (
  SELECT 
    CASE 
      WHEN (SELECT version FROM v$instance) LIKE '11.%' THEN 'Oracle 11g'
      ELSE '12c+ Non-MT'
    END AS version_type
  FROM DUAL
),
any_priv_summary AS (
  SELECT 
    COUNT(*) AS priv_count,
    LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE) AS privilege_list
  FROM any_privileges
)
SELECT '<tr class="' ||
  CASE 
    WHEN s.priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.6</td>' ||
  '<td>Ensure %ANY% Is Revoked from Unauthorized GRANTEE (Scored) - ' || v.version_type || '</td>' ||
  '<td>' || CASE WHEN s.priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN s.priv_count > 0 THEN 
      'Found ' || s.priv_count || ' unauthorized %ANY% privileges: ' || s.privilege_list
    ELSE 'No unauthorized %ANY% privileges found'
    END || '</td>' ||
  '<td>Only authorized system users should have %ANY% privileges</td>' ||
  '<td class="remediation">REVOKE &lt;ANY_PRIVILEGE&gt; FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM any_priv_summary s CROSS JOIN any_version_info v;

-- 4.6 %ANY% Privileges - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
WITH any_priv_cdb AS (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE LIKE '%ANY%'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
    AND (SELECT version FROM v$instance) NOT LIKE '11.%'
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.6</td>' ||
  '<td>Ensure %ANY% Is Revoked from Unauthorized GRANTEE (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN 'Found ' || priv_count || ' unauthorized %ANY% privileges in ' || container_name || ': ' || privilege_list
    ELSE 'No unauthorized %ANY% privileges found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have %ANY% privileges</td>' ||
  '<td class="remediation">REVOKE &lt;ANY_PRIVILEGE&gt; FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM any_priv_cdb;

-- 4.7 DBA_SYS_PRIVS with ADMIN_OPTION - Oracle 11g and 12c+ Non-multitenant/PDB
WITH admin_option_privileges AS (
  SELECT GRANTEE, PRIVILEGE
  FROM DBA_SYS_PRIVS
  WHERE ADMIN_OPTION='YES'
  AND (
    -- Oracle 11g: use specified exclusion list
    ((SELECT version FROM v$instance) LIKE '11.%'
     AND GRANTEE NOT IN ('AQ_ADMINISTRATOR_ROLE','DBA','OWBSYS','SCHEDULER_ADMIN','SYS','SYSTEM','WMSYS','APEX_030200','APEX_040000','APEX_040100','APEX_040200'))
    OR
    -- Oracle 12c+ non-multitenant or PDB: filter Oracle-maintained users/roles
    ((SELECT version FROM v$instance) NOT LIKE '11.%'
     AND GRANTEE NOT IN (SELECT USERNAME FROM DBA_USERS WHERE ORACLE_MAINTAINED='Y')
     AND GRANTEE NOT IN (SELECT ROLE FROM DBA_ROLES WHERE ORACLE_MAINTAINED='Y')
     AND (
       -- Non-multitenant database
       NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
       OR 
       -- Running from PDB (not CDB$ROOT)
       (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
        (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
     )
    )
  )
),
admin_version_info AS (
  SELECT 
    CASE 
      WHEN (SELECT version FROM v$instance) LIKE '11.%' THEN 'Oracle 11g'
      ELSE '12c+ Non-MT'
    END AS version_type
  FROM DUAL
),
admin_priv_summary AS (
  SELECT 
    COUNT(*) AS priv_count,
    LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE) AS privilege_list
  FROM admin_option_privileges
)
SELECT '<tr class="' ||
  CASE 
    WHEN s.priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.7</td>' ||
  '<td>Ensure DBA_SYS_PRIVS Is Revoked from Unauthorized GRANTEE with ADMIN_OPTION=YES (Scored) - ' || v.version_type || '</td>' ||
  '<td>' || CASE WHEN s.priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN s.priv_count > 0 THEN 
      'Found ' || s.priv_count || ' unauthorized ADMIN_OPTION privileges: ' || s.privilege_list
    ELSE 'No unauthorized ADMIN_OPTION privileges found'
    END || '</td>' ||
  '<td>Only authorized system users should have ADMIN_OPTION=YES</td>' ||
  '<td class="remediation">REVOKE &lt;privilege&gt; FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM admin_priv_summary s CROSS JOIN admin_version_info v;

-- 4.7 DBA_SYS_PRIVS with ADMIN_OPTION - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
WITH admin_priv_cdb AS (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_SYS_PRIVS A
  WHERE A.ADMIN_OPTION='YES'
  AND A.GRANTEE NOT IN (SELECT USERNAME FROM CDB_USERS WHERE ORACLE_MAINTAINED='Y')
  AND A.GRANTEE NOT IN (SELECT ROLE FROM CDB_ROLES WHERE ORACLE_MAINTAINED='Y')
    AND (SELECT version FROM v$instance) NOT LIKE '11.%'
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.7</td>' ||
  '<td>Ensure DBA_SYS_PRIVS Is Revoked from Unauthorized GRANTEE with ADMIN_OPTION=YES (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN 'Found ' || priv_count || ' unauthorized ADMIN_OPTION privileges in ' || container_name || ': ' || privilege_list
    ELSE 'No unauthorized ADMIN_OPTION privileges found in ' || container_name
    END || '</td>' ||
  '<td>Only authorized system users should have ADMIN_OPTION=YES</td>' ||
  '<td class="remediation">REVOKE &lt;privilege&gt; FROM &lt;grantee&gt;;</td>' ||
  '</tr>'
FROM admin_priv_cdb;

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

-- 4.9 EXECUTE ANY PROCEDURE from OUTLN - Oracle 11g and 12c+ Non-multitenant/PDB
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.9</td>' ||
  '<td>Ensure EXECUTE ANY PROCEDURE Is Revoked from OUTLN (Scored) - ' || version_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN 'OUTLN has EXECUTE ANY PROCEDURE: ' || privilege_list
    ELSE 'OUTLN does not have EXECUTE ANY PROCEDURE'
    END || '</td>' ||
  '<td>OUTLN should not have EXECUTE ANY PROCEDURE</td>' ||
  '<td class="remediation">REVOKE EXECUTE ANY PROCEDURE FROM OUTLN;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='EXECUTE ANY PROCEDURE'
       AND GRANTEE='OUTLN'
       AND (
         (SELECT version FROM v$instance) LIKE '11.%'
         OR
         ((SELECT version FROM v$instance) NOT LIKE '11.%'
          AND (
            NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
            OR 
            (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
             (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
          )
         )
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='EXECUTE ANY PROCEDURE'
       AND GRANTEE='OUTLN'
       AND (
         (SELECT version FROM v$instance) LIKE '11.%'
         OR
         ((SELECT version FROM v$instance) NOT LIKE '11.%'
          AND (
            NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
            OR 
            (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
             (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
          )
         )
       )) AS privilege_list,
    CASE 
      WHEN (SELECT version FROM v$instance) LIKE '11.%' THEN 'Oracle 11g'
      ELSE '12c+ Non-MT'
    END AS version_type
  FROM DUAL
  WHERE (
    (SELECT version FROM v$instance) LIKE '11.%'
    OR
    ((SELECT version FROM v$instance) NOT LIKE '11.%'
     AND (
       NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
       OR 
       (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
        (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
     )
    )
  )
);

-- 4.9 EXECUTE ANY PROCEDURE from OUTLN - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.9</td>' ||
  '<td>Ensure EXECUTE ANY PROCEDURE Is Revoked from OUTLN (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN 'OUTLN has EXECUTE ANY PROCEDURE in ' || container_name || ': ' || privilege_list
    ELSE 'OUTLN does not have EXECUTE ANY PROCEDURE in ' || container_name
    END || '</td>' ||
  '<td>OUTLN should not have EXECUTE ANY PROCEDURE</td>' ||
  '<td class="remediation">REVOKE EXECUTE ANY PROCEDURE FROM OUTLN;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='EXECUTE ANY PROCEDURE'
  AND A.GRANTEE='OUTLN'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE (SELECT version FROM v$instance) NOT LIKE '11.%'
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.10 EXECUTE ANY PROCEDURE from DBSNMP - Oracle 11g and 12c+ Non-multitenant/PDB
SELECT '<tr class="' ||
  CASE 
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.10</td>' ||
  '<td>Ensure EXECUTE ANY PROCEDURE Is Revoked from DBSNMP (Scored) - ' || version_type || '</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN priv_count > 0 THEN 'DBSNMP has EXECUTE ANY PROCEDURE: ' || privilege_list
    ELSE 'DBSNMP does not have EXECUTE ANY PROCEDURE'
    END || '</td>' ||
  '<td>DBSNMP should not have EXECUTE ANY PROCEDURE</td>' ||
  '<td class="remediation">REVOKE EXECUTE ANY PROCEDURE FROM DBSNMP;</td>' ||
  '</tr>'
FROM (
  SELECT 
    (SELECT COUNT(*) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='EXECUTE ANY PROCEDURE'
       AND GRANTEE='DBSNMP'
       AND (
         (SELECT version FROM v$instance) LIKE '11.%'
         OR
         ((SELECT version FROM v$instance) NOT LIKE '11.%'
          AND (
            NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
            OR 
            (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
             (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
          )
         )
       )) AS priv_count,
    (SELECT LISTAGG(GRANTEE || ':' || PRIVILEGE, ', ') WITHIN GROUP (ORDER BY GRANTEE) FROM DBA_SYS_PRIVS 
     WHERE PRIVILEGE='EXECUTE ANY PROCEDURE'
       AND GRANTEE='DBSNMP'
       AND (
         (SELECT version FROM v$instance) LIKE '11.%'
         OR
         ((SELECT version FROM v$instance) NOT LIKE '11.%'
          AND (
            NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
            OR 
            (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
             (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
          )
         )
       )) AS privilege_list,
    CASE 
      WHEN (SELECT version FROM v$instance) LIKE '11.%' THEN 'Oracle 11g'
      ELSE '12c+ Non-MT'
    END AS version_type
  FROM DUAL
  WHERE (
    (SELECT version FROM v$instance) LIKE '11.%'
    OR
    ((SELECT version FROM v$instance) NOT LIKE '11.%'
     AND (
       NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
       OR 
       (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
        (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
     )
    )
  )
);

-- 4.10 EXECUTE ANY PROCEDURE from DBSNMP - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN priv_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.10</td>' ||
  '<td>Ensure EXECUTE ANY PROCEDURE Is Revoked from DBSNMP (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN priv_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' ||
    CASE WHEN priv_count > 0 THEN 'DBSNMP has EXECUTE ANY PROCEDURE in ' || container_name || ': ' || privilege_list
    ELSE 'DBSNMP does not have EXECUTE ANY PROCEDURE in ' || container_name
    END || '</td>' ||
  '<td>DBSNMP should not have EXECUTE ANY PROCEDURE</td>' ||
  '<td class="remediation">REVOKE EXECUTE ANY PROCEDURE FROM DBSNMP;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS priv_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.GRANTEE || ':' || A.PRIVILEGE, ', ') WITHIN GROUP (ORDER BY A.GRANTEE) AS privilege_list
  FROM CDB_SYS_PRIVS A
  WHERE A.PRIVILEGE='EXECUTE ANY PROCEDURE'
  AND A.GRANTEE='DBSNMP'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE (SELECT version FROM v$instance) NOT LIKE '11.%'
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 4.11 Ensure No Public Database Links Exist (11g and 12c+ non-multitenant/PDB)
WITH public_db_links_11g AS (
  SELECT 
    vi.version,
    dbl.DB_LINK,
    dbl.HOST
  FROM v$instance vi
  CROSS JOIN DBA_DB_LINKS dbl
  WHERE vi.version LIKE '11.%'
  AND dbl.OWNER = 'PUBLIC'
),
public_db_links_12c_non_mt AS (
  SELECT 
    vi.version,
    dbl.DB_LINK,
    dbl.HOST
  FROM v$instance vi
  CROSS JOIN DBA_DB_LINKS dbl
  WHERE vi.version NOT LIKE '11.%' 
  AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'NO' OR
       ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES' AND SYS_CONTEXT('USERENV', 'CON_NAME') != 'CDB$ROOT'))
  AND dbl.OWNER = 'PUBLIC'
),
public_db_links_combined AS (
  SELECT version, DB_LINK, HOST FROM public_db_links_11g
  UNION ALL
  SELECT version, DB_LINK, HOST FROM public_db_links_12c_non_mt
)
SELECT '<tr class="' ||
  CASE 
    WHEN (SELECT COUNT(*) FROM public_db_links_combined) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.11</td>' ||
  '<td>Ensure No Public Database Links Exist (Scored)</td>' ||
  '<td>' || CASE WHEN (SELECT COUNT(*) FROM public_db_links_combined) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN (SELECT COUNT(*) FROM public_db_links_combined) > 0 THEN 
      (SELECT LISTAGG(DB_LINK || '->' || HOST, ', ') WITHIN GROUP (ORDER BY DB_LINK) FROM public_db_links_combined)
    ELSE 'No public database links found (compliant)'
    END || '</td>' ||
  '<td>No public database links should exist</td>' ||
  '<td class="remediation">DROP PUBLIC DATABASE LINK &lt;DB_LINK&gt;;</td>' ||
  '</tr>'
FROM DUAL;

-- 4.11b Ensure No Public Database Links Exist (12c+ multi-tenant)
WITH environment_flag AS (
  SELECT 
    CASE 
      WHEN vi.version LIKE '11.%' THEN 1
      WHEN vi.version NOT LIKE '11.%' AND ((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES') THEN 2
      ELSE 0
    END as env_type
  FROM v$instance vi
)
SELECT CASE WHEN ef.env_type = 2 THEN
  '<tr class="' ||
  CASE 
    WHEN COUNT(L.DB_LINK) = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>4.11b</td>' ||
  '<td>Ensure No Public Database Links Exist in All Containers (12c+ Multi-tenant) (Scored)</td>' ||
  '<td>' || CASE WHEN COUNT(L.DB_LINK) = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(L.DB_LINK) > 0 THEN 
      LISTAGG(DECODE(L.CON_ID,0,(SELECT NAME FROM V$DATABASE),1,(SELECT NAME FROM V$DATABASE),(SELECT NAME FROM V$PDBS B WHERE L.CON_ID = B.CON_ID)) || ':' || L.DB_LINK || '->' || L.HOST, '; ') WITHIN GROUP (ORDER BY L.CON_ID, L.DB_LINK)
    ELSE 'No public database links found in any container (compliant)'
    END || '</td>' ||
  '<td>No public database links should exist in any container</td>' ||
  '<td class="remediation">For each container: DROP PUBLIC DATABASE LINK &lt;DB_LINK&gt;;</td>' ||
  '</tr>'
ELSE '' END
FROM environment_flag ef
CROSS JOIN (
  SELECT 
    A.CON_ID,
    A.DB_LINK,
    A.HOST
  FROM CDB_DB_LINKS A
  WHERE A.OWNER = 'PUBLIC'
) L
GROUP BY ef.env_type;

PROMPT </table>

-- Section 5: Audit/Logging Policies and Procedures
PROMPT <h2 id="section5">5. Audit/Logging Policies and Procedures</h2>
PROMPT <table>
PROMPT <tr><th width="5%">Control</th><th width="35%">Title</th><th width="8%">Status</th><th width="20%">Current Value</th><th width="15%">Expected</th><th width="17%">Remediation</th></tr>

-- 5.1 Enable 'USER' Audit Option - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.1</td>' ||
  '<td>Enable USER Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'USER audit not enabled'
    END || '</td>' ||
  '<td>USER audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT USER;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='USER' 
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.1 Enable 'USER' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB
WITH user_audit_opts AS (
  SELECT AUDIT_OPTION, SUCCESS, FAILURE
  FROM DBA_STMT_AUDIT_OPTS
  WHERE USER_NAME IS NULL 
  AND PROXY_NAME IS NULL
  AND SUCCESS = 'BY ACCESS' 
  AND FAILURE = 'BY ACCESS'
  AND AUDIT_OPTION='USER'
  AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
  AND (
    -- Non-multitenant database
    NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    OR 
    -- Running from PDB (not CDB$ROOT)
    (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
     (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
  )
),
user_audit_env_info AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS env_type
  FROM DUAL
),
user_audit_summary AS (
  SELECT 
    COUNT(*) AS audit_count,
    LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION) AS audit_details
  FROM user_audit_opts
)
SELECT '<tr class="' ||
  CASE 
    WHEN s.audit_count > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.1</td>' ||
  '<td>Enable USER Audit Option (Scored) - ' || e.env_type || '</td>' ||
  '<td>' || CASE WHEN s.audit_count > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN s.audit_count > 0 THEN s.audit_details
    ELSE 'USER audit not enabled'
    END || '</td>' ||
  '<td>USER audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT USER;</td>' ||
  '</tr>'
FROM user_audit_summary s CROSS JOIN user_audit_env_info e;

-- 5.1 Enable 'USER' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
WITH user_audit_cdb AS (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='USER'
    AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
    AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.1</td>' ||
  '<td>Enable USER Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'USER audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>USER audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT USER;</td>' ||
  '</tr>'
FROM user_audit_cdb;

-- 5.2 Enable 'ALTER USER' Audit Option - Oracle 11g Traditional Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.2</td>' ||
  '<td>Enable ALTER USER Audit Option (Scored) - 11g Traditional</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'ALTER USER audit not enabled'
    END || '</td>' ||
  '<td>ALTER USER audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT ALTER USER;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='ALTER USER'
AND USER_NAME IS NULL
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS'
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.2 Enable 'ALTER USER' Audit Option - Oracle 12c Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.2</td>' ||
  '<td>Enable ALTER USER Audit Option (Scored) - 12c Unified</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUD.POLICY_NAME || ':' || AUD.AUDIT_OPTION || ' (' || AUD.AUDIT_OPTION_TYPE || ')', ', ') WITHIN GROUP (ORDER BY AUD.POLICY_NAME)
    ELSE 'ALTER USER audit not enabled in unified policies'
    END || '</td>' ||
  '<td>ALTER USER audit enabled via unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS ALTER USER;</td>' ||
  '</tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME
AND AUD.AUDIT_OPTION = 'ALTER USER'
AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES'
AND ENABLED.FAILURE = 'YES'
HAVING '&version_num' = '12';

-- 5.2 Enable 'ALTER USER' Audit Option - Oracle 18c+ Unified Auditing
WITH VERSION_CHECK AS (
  SELECT TO_NUMBER(SUBSTR(VERSION, 1, 2)) AS db_version FROM V$INSTANCE
),
CIS_AUDIT(AUDIT_OPTION) AS (
  SELECT 'ALTER USER' FROM DUAL
),
AUDIT_ENABLED AS (
  SELECT DISTINCT AUDIT_OPTION
  FROM AUDIT_UNIFIED_POLICIES AUD
  WHERE AUD.AUDIT_OPTION IN ('ALTER USER')
  AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
  AND EXISTS (
    SELECT *
    FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
    WHERE ENABLED.SUCCESS = 'YES'
    AND ENABLED.FAILURE = 'YES'
    AND ENABLED.ENABLED_OPTION = 'BY USER'
    AND ENABLED.ENTITY_NAME = 'ALL USERS'
    AND ENABLED.POLICY_NAME = AUD.POLICY_NAME
  )
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(E.AUDIT_OPTION) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.2</td>' ||
  '<td>Enable ALTER USER Audit Option (Scored) - 18c+ Unified</td>' ||
  '<td>' || CASE WHEN COUNT(E.AUDIT_OPTION) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(E.AUDIT_OPTION) > 0 THEN 
      'ALTER USER audit enabled via unified policies'
    ELSE 'ALTER USER audit not enabled in unified policies'
    END || '</td>' ||
  '<td>ALTER USER audit enabled via unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS ALTER USER;</td>' ||
  '</tr>'
FROM CIS_AUDIT C
LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION
CROSS JOIN VERSION_CHECK V
WHERE V.db_version >= 18
GROUP BY V.db_version;

-- 5.3 Enable 'DROP USER' Audit Option - Oracle 11g Traditional Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.3</td>' ||
  '<td>Enable DROP USER Audit Option (Scored) - 11g Traditional</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'DROP USER audit not enabled'
    END || '</td>' ||
  '<td>DROP USER audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT DROP USER;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='DROP USER'
AND USER_NAME IS NULL
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS'
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.3 Enable 'DROP USER' Audit Option - Oracle 12c Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.3</td>' ||
  '<td>Enable DROP USER Audit Option (Scored) - 12c Unified</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUD.POLICY_NAME || ':' || AUD.AUDIT_OPTION || ' (' || AUD.AUDIT_OPTION_TYPE || ')', ', ') WITHIN GROUP (ORDER BY AUD.POLICY_NAME)
    ELSE 'DROP USER audit not enabled in unified policies'
    END || '</td>' ||
  '<td>DROP USER audit enabled via unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS DROP USER;</td>' ||
  '</tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME
AND AUD.AUDIT_OPTION = 'DROP USER'
AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES'
AND ENABLED.FAILURE = 'YES'
HAVING '&version_num' = '12';

-- 5.3 Enable 'DROP USER' Audit Option - Oracle 18c+ Unified Auditing
WITH VERSION_CHECK AS (
  SELECT TO_NUMBER(SUBSTR(VERSION, 1, 2)) AS db_version FROM V$INSTANCE
),
CIS_AUDIT(AUDIT_OPTION) AS (
  SELECT 'DROP USER' FROM DUAL
),
AUDIT_ENABLED AS (
  SELECT DISTINCT AUDIT_OPTION
  FROM AUDIT_UNIFIED_POLICIES AUD
  WHERE AUD.AUDIT_OPTION IN ('DROP USER')
  AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
  AND EXISTS (
    SELECT *
    FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
    WHERE ENABLED.SUCCESS = 'YES'
    AND ENABLED.FAILURE = 'YES'
    AND ENABLED.ENABLED_OPTION = 'BY USER'
    AND ENABLED.ENTITY_NAME = 'ALL USERS'
    AND ENABLED.POLICY_NAME = AUD.POLICY_NAME
  )
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(E.AUDIT_OPTION) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.3</td>' ||
  '<td>Enable DROP USER Audit Option (Scored) - 18c+ Unified</td>' ||
  '<td>' || CASE WHEN COUNT(E.AUDIT_OPTION) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(E.AUDIT_OPTION) > 0 THEN 
      'DROP USER audit enabled via unified policies'
    ELSE 'DROP USER audit not enabled in unified policies'
    END || '</td>' ||
  '<td>DROP USER audit enabled via unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS DROP USER;</td>' ||
  '</tr>'
FROM CIS_AUDIT C
LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION
CROSS JOIN VERSION_CHECK V
WHERE V.db_version >= 18
GROUP BY V.db_version;

-- 5.4 Enable 'ROLE' Audit Option - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.4</td>' ||
  '<td>Enable ROLE Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'ROLE audit not enabled'
    END || '</td>' ||
  '<td>ROLE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT ROLE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='ROLE' 
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.4 Enable 'ROLE' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.4</td>' ||
  '<td>Enable ROLE Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'ROLE audit not enabled'
    END || '</td>' ||
  '<td>ROLE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT ROLE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='ROLE'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.4 Enable 'ROLE' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.4</td>' ||
  '<td>Enable ROLE Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'ROLE audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>ROLE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT ROLE;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='ROLE'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.5 Enable 'SYSTEM GRANT' Audit Option - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.5</td>' ||
  '<td>Enable SYSTEM GRANT Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'SYSTEM GRANT audit not enabled'
    END || '</td>' ||
  '<td>SYSTEM GRANT audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT SYSTEM GRANT;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='SYSTEM GRANT' 
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.5 Enable 'SYSTEM GRANT' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.5</td>' ||
  '<td>Enable SYSTEM GRANT Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'SYSTEM GRANT audit not enabled'
    END || '</td>' ||
  '<td>SYSTEM GRANT audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT SYSTEM GRANT;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='SYSTEM GRANT'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.5 Enable 'SYSTEM GRANT' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.5</td>' ||
  '<td>Enable SYSTEM GRANT Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'SYSTEM GRANT audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>SYSTEM GRANT audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT SYSTEM GRANT;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='SYSTEM GRANT'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.6 Enable 'PROFILE' Audit Option - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.6</td>' ||
  '<td>Enable PROFILE Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'PROFILE audit not enabled'
    END || '</td>' ||
  '<td>PROFILE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT PROFILE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='PROFILE' 
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.6 Enable 'PROFILE' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.6</td>' ||
  '<td>Enable PROFILE Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'PROFILE audit not enabled'
    END || '</td>' ||
  '<td>PROFILE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT PROFILE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='PROFILE'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.6 Enable 'PROFILE' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.6</td>' ||
  '<td>Enable PROFILE Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'PROFILE audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>PROFILE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT PROFILE;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='PROFILE'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.7 Enable 'ALTER PROFILE' Audit Option - Oracle 11g Traditional Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.7</td>' ||
  '<td>Enable ALTER PROFILE Audit Option (Scored) - 11g Traditional</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'ALTER PROFILE audit not enabled'
    END || '</td>' ||
  '<td>ALTER PROFILE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT ALTER PROFILE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='ALTER PROFILE'
AND USER_NAME IS NULL
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS'
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.7 Enable 'ALTER PROFILE' Audit Option - Oracle 12c Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.7</td>' ||
  '<td>Enable ALTER PROFILE Audit Option (Scored) - 12c Unified</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUD.POLICY_NAME || ':' || AUD.AUDIT_OPTION || ' (' || AUD.AUDIT_OPTION_TYPE || ')', ', ') WITHIN GROUP (ORDER BY AUD.POLICY_NAME)
    ELSE 'ALTER PROFILE audit not enabled in unified policies'
    END || '</td>' ||
  '<td>ALTER PROFILE audit enabled via unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS ALTER PROFILE;</td>' ||
  '</tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME
AND AUD.AUDIT_OPTION = 'ALTER PROFILE'
AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES'
AND ENABLED.FAILURE = 'YES'
HAVING '&version_num' = '12';

-- 5.7 Enable 'ALTER PROFILE' Audit Option - Oracle 18c+ Unified Auditing
WITH VERSION_CHECK AS (
  SELECT TO_NUMBER(SUBSTR(VERSION, 1, 2)) AS db_version FROM V$INSTANCE
),
CIS_AUDIT(AUDIT_OPTION) AS (
  SELECT 'ALTER PROFILE' FROM DUAL
),
AUDIT_ENABLED AS (
  SELECT DISTINCT AUDIT_OPTION
  FROM AUDIT_UNIFIED_POLICIES AUD
  WHERE AUD.AUDIT_OPTION IN ('ALTER PROFILE')
  AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
  AND EXISTS (
    SELECT *
    FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
    WHERE ENABLED.SUCCESS = 'YES'
    AND ENABLED.FAILURE = 'YES'
    AND ENABLED.ENABLED_OPTION = 'BY USER'
    AND ENABLED.ENTITY_NAME = 'ALL USERS'
    AND ENABLED.POLICY_NAME = AUD.POLICY_NAME
  )
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(E.AUDIT_OPTION) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.7</td>' ||
  '<td>Enable ALTER PROFILE Audit Option (Scored) - 18c+ Unified</td>' ||
  '<td>' || CASE WHEN COUNT(E.AUDIT_OPTION) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(E.AUDIT_OPTION) > 0 THEN 
      'ALTER PROFILE audit enabled via unified policies'
    ELSE 'ALTER PROFILE audit not enabled in unified policies'
    END || '</td>' ||
  '<td>ALTER PROFILE audit enabled via unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS ALTER PROFILE;</td>' ||
  '</tr>'
FROM CIS_AUDIT C
LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION
CROSS JOIN VERSION_CHECK V
WHERE V.db_version >= 18
GROUP BY V.db_version;

-- 5.8 Enable 'DROP PROFILE' Audit Option - Oracle 11g Traditional Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.8</td>' ||
  '<td>Enable DROP PROFILE Audit Option (Scored) - 11g Traditional</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'DROP PROFILE audit not enabled'
    END || '</td>' ||
  '<td>DROP PROFILE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT DROP PROFILE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='DROP PROFILE'
AND USER_NAME IS NULL
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS'
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.8 Enable 'DROP PROFILE' Audit Option - Oracle 12c Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.8</td>' ||
  '<td>Enable DROP PROFILE Audit Option (Scored) - 12c Unified</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUD.POLICY_NAME || ':' || AUD.AUDIT_OPTION || ' (' || AUD.AUDIT_OPTION_TYPE || ')', ', ') WITHIN GROUP (ORDER BY AUD.POLICY_NAME)
    ELSE 'DROP PROFILE audit not enabled in unified policies'
    END || '</td>' ||
  '<td>DROP PROFILE audit enabled via unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS DROP PROFILE;</td>' ||
  '</tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME
AND AUD.AUDIT_OPTION = 'DROP PROFILE'
AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES'
AND ENABLED.FAILURE = 'YES'
HAVING '&version_num' = '12';

-- 5.8 Enable 'DROP PROFILE' Audit Option - Oracle 18c+ Unified Auditing
WITH VERSION_CHECK AS (
  SELECT TO_NUMBER(SUBSTR(VERSION, 1, 2)) AS db_version FROM V$INSTANCE
),
CIS_AUDIT(AUDIT_OPTION) AS (
  SELECT 'DROP PROFILE' FROM DUAL
),
AUDIT_ENABLED AS (
  SELECT DISTINCT AUDIT_OPTION
  FROM AUDIT_UNIFIED_POLICIES AUD
  WHERE AUD.AUDIT_OPTION IN ('DROP PROFILE')
  AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
  AND EXISTS (
    SELECT *
    FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
    WHERE ENABLED.SUCCESS = 'YES'
    AND ENABLED.FAILURE = 'YES'
    AND ENABLED.ENABLED_OPTION = 'BY USER'
    AND ENABLED.ENTITY_NAME = 'ALL USERS'
    AND ENABLED.POLICY_NAME = AUD.POLICY_NAME
  )
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(E.AUDIT_OPTION) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.8</td>' ||
  '<td>Enable DROP PROFILE Audit Option (Scored) - 18c+ Unified</td>' ||
  '<td>' || CASE WHEN COUNT(E.AUDIT_OPTION) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(E.AUDIT_OPTION) > 0 THEN 
      'DROP PROFILE audit enabled via unified policies'
    ELSE 'DROP PROFILE audit not enabled in unified policies'
    END || '</td>' ||
  '<td>DROP PROFILE audit enabled via unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS DROP PROFILE;</td>' ||
  '</tr>'
FROM CIS_AUDIT C
LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION
CROSS JOIN VERSION_CHECK V
WHERE V.db_version >= 18
GROUP BY V.db_version;

-- 5.9 Enable 'DATABASE LINK' Audit Option - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.9</td>' ||
  '<td>Enable DATABASE LINK Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'DATABASE LINK audit not enabled'
    END || '</td>' ||
  '<td>DATABASE LINK audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT DATABASE LINK;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='DATABASE LINK' 
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.9 Enable 'DATABASE LINK' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.9</td>' ||
  '<td>Enable DATABASE LINK Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'DATABASE LINK audit not enabled'
    END || '</td>' ||
  '<td>DATABASE LINK audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT DATABASE LINK;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='DATABASE LINK'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.9 Enable 'DATABASE LINK' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.9</td>' ||
  '<td>Enable DATABASE LINK Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'DATABASE LINK audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>DATABASE LINK audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT DATABASE LINK;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='DATABASE LINK'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.10 Enable 'PUBLIC DATABASE LINK' Audit Option - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.10</td>' ||
  '<td>Enable PUBLIC DATABASE LINK Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'PUBLIC DATABASE LINK audit not enabled'
    END || '</td>' ||
  '<td>PUBLIC DATABASE LINK audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT PUBLIC DATABASE LINK;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='PUBLIC DATABASE LINK' 
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.10 Enable 'PUBLIC DATABASE LINK' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.10</td>' ||
  '<td>Enable PUBLIC DATABASE LINK Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'PUBLIC DATABASE LINK audit not enabled'
    END || '</td>' ||
  '<td>PUBLIC DATABASE LINK audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT PUBLIC DATABASE LINK;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='PUBLIC DATABASE LINK'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.10 Enable 'PUBLIC DATABASE LINK' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.10</td>' ||
  '<td>Enable PUBLIC DATABASE LINK Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'PUBLIC DATABASE LINK audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>PUBLIC DATABASE LINK audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT PUBLIC DATABASE LINK;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='PUBLIC DATABASE LINK'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.11 Enable 'PUBLIC SYNONYM' Audit Option - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.11</td>' ||
  '<td>Enable PUBLIC SYNONYM Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'PUBLIC SYNONYM audit not enabled'
    END || '</td>' ||
  '<td>PUBLIC SYNONYM audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT PUBLIC SYNONYM;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='PUBLIC SYNONYM' 
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.11 Enable 'PUBLIC SYNONYM' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.11</td>' ||
  '<td>Enable PUBLIC SYNONYM Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'PUBLIC SYNONYM audit not enabled'
    END || '</td>' ||
  '<td>PUBLIC SYNONYM audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT PUBLIC SYNONYM;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='PUBLIC SYNONYM'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.11 Enable 'PUBLIC SYNONYM' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.11</td>' ||
  '<td>Enable PUBLIC SYNONYM Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'PUBLIC SYNONYM audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>PUBLIC SYNONYM audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT PUBLIC SYNONYM;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='PUBLIC SYNONYM'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.12 Enable 'SYNONYM' Audit Option - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.12</td>' ||
  '<td>Enable SYNONYM Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'SYNONYM audit not enabled'
    END || '</td>' ||
  '<td>SYNONYM audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT SYNONYM;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='SYNONYM' 
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.12 Enable 'SYNONYM' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.12</td>' ||
  '<td>Enable SYNONYM Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'SYNONYM audit not enabled'
    END || '</td>' ||
  '<td>SYNONYM audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT SYNONYM;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='SYNONYM'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.12 Enable 'SYNONYM' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.12</td>' ||
  '<td>Enable SYNONYM Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'SYNONYM audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>SYNONYM audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT SYNONYM;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='SYNONYM'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.13 Enable 'GRANT DIRECTORY' Audit Option - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.13</td>' ||
  '<td>Enable GRANT DIRECTORY Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'GRANT DIRECTORY audit not enabled'
    END || '</td>' ||
  '<td>GRANT DIRECTORY audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT GRANT DIRECTORY;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='GRANT DIRECTORY' 
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.13 Enable 'DIRECTORY' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.13</td>' ||
  '<td>Enable DIRECTORY Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'DIRECTORY audit not enabled'
    END || '</td>' ||
  '<td>DIRECTORY audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT DIRECTORY;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='DIRECTORY'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.13 Enable 'DIRECTORY' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.13</td>' ||
  '<td>Enable DIRECTORY Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'DIRECTORY audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>DIRECTORY audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT DIRECTORY;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='DIRECTORY'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.14 Enable 'SELECT ANY DICTIONARY' Audit Option - Oracle 11g
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.14</td>' ||
  '<td>Enable SELECT ANY DICTIONARY Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'SELECT ANY DICTIONARY audit not enabled'
    END || '</td>' ||
  '<td>SELECT ANY DICTIONARY audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT SELECT ANY DICTIONARY;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='SELECT ANY DICTIONARY' 
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.14 Enable 'SELECT ANY DICTIONARY' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.14</td>' ||
  '<td>Enable SELECT ANY DICTIONARY Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'SELECT ANY DICTIONARY audit not enabled'
    END || '</td>' ||
  '<td>SELECT ANY DICTIONARY audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT SELECT ANY DICTIONARY;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='SELECT ANY DICTIONARY'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.14 Enable 'SELECT ANY DICTIONARY' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.14</td>' ||
  '<td>Enable SELECT ANY DICTIONARY Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'SELECT ANY DICTIONARY audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>SELECT ANY DICTIONARY audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT SELECT ANY DICTIONARY;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='SELECT ANY DICTIONARY'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.15 Enable 'GRANT ANY OBJECT PRIVILEGE' Audit Option - Oracle 11g (uses DBA_PRIV_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.15</td>' ||
  '<td>Enable GRANT ANY OBJECT PRIVILEGE Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(PRIVILEGE || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY PRIVILEGE)
    ELSE 'GRANT ANY OBJECT PRIVILEGE audit not enabled'
    END || '</td>' ||
  '<td>GRANT ANY OBJECT PRIVILEGE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT GRANT ANY OBJECT PRIVILEGE;</td>' ||
  '</tr>'
FROM DBA_PRIV_AUDIT_OPTS
WHERE PRIVILEGE='GRANT ANY OBJECT PRIVILEGE' 
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.15 Enable 'GRANT ANY OBJECT PRIVILEGE' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB (uses DBA_STMT_AUDIT_OPTS)
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN audit_count > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.15</td>' ||
  '<td>Enable GRANT ANY OBJECT PRIVILEGE Audit Option (Scored) - ' || env_type || '</td>' ||
  '<td>' || CASE WHEN audit_count > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'GRANT ANY OBJECT PRIVILEGE audit not enabled'
    END || '</td>' ||
  '<td>GRANT ANY OBJECT PRIVILEGE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT GRANT ANY OBJECT PRIVILEGE;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    CI.container_desc AS env_type,
    LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION) AS audit_details
  FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
  WHERE USER_NAME IS NULL 
  AND PROXY_NAME IS NULL
  AND SUCCESS = 'BY ACCESS' 
  AND FAILURE = 'BY ACCESS'
  AND AUDIT_OPTION='GRANT ANY OBJECT PRIVILEGE'
  AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
  AND (
    -- Non-multitenant database
    NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
    OR 
    -- Running from PDB (not CDB$ROOT)
    (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
     (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
  )
  GROUP BY CI.container_desc
);

-- 5.15 Enable 'GRANT ANY OBJECT PRIVILEGE' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT, uses CDB_STMT_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.15</td>' ||
  '<td>Enable GRANT ANY OBJECT PRIVILEGE Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'GRANT ANY OBJECT PRIVILEGE audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>GRANT ANY OBJECT PRIVILEGE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT GRANT ANY OBJECT PRIVILEGE;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='GRANT ANY OBJECT PRIVILEGE'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.16 Enable 'GRANT ANY PRIVILEGE' Audit Option - Oracle 11g (uses DBA_PRIV_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.16</td>' ||
  '<td>Enable GRANT ANY PRIVILEGE Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(PRIVILEGE || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY PRIVILEGE)
    ELSE 'GRANT ANY PRIVILEGE audit not enabled'
    END || '</td>' ||
  '<td>GRANT ANY PRIVILEGE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT GRANT ANY PRIVILEGE;</td>' ||
  '</tr>'
FROM DBA_PRIV_AUDIT_OPTS
WHERE PRIVILEGE='GRANT ANY PRIVILEGE' 
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.16 Enable 'GRANT ANY PRIVILEGE' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB (uses DBA_STMT_AUDIT_OPTS)
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.16</td>' ||
  '<td>Enable GRANT ANY PRIVILEGE Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'GRANT ANY PRIVILEGE audit not enabled'
    END || '</td>' ||
  '<td>GRANT ANY PRIVILEGE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT GRANT ANY PRIVILEGE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='GRANT ANY PRIVILEGE'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.16 Enable 'GRANT ANY PRIVILEGE' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT, uses CDB_STMT_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.16</td>' ||
  '<td>Enable GRANT ANY PRIVILEGE Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'GRANT ANY PRIVILEGE audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>GRANT ANY PRIVILEGE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT GRANT ANY PRIVILEGE;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='GRANT ANY PRIVILEGE'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.17 Enable 'DROP ANY PROCEDURE' Audit Option - Oracle 11g (uses DBA_STMT_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.17</td>' ||
  '<td>Enable DROP ANY PROCEDURE Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'DROP ANY PROCEDURE audit not enabled'
    END || '</td>' ||
  '<td>DROP ANY PROCEDURE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT DROP ANY PROCEDURE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='DROP ANY PROCEDURE'
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.17 Enable 'DROP ANY PROCEDURE' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB (uses DBA_STMT_AUDIT_OPTS)
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.17</td>' ||
  '<td>Enable DROP ANY PROCEDURE Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'DROP ANY PROCEDURE audit not enabled'
    END || '</td>' ||
  '<td>DROP ANY PROCEDURE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT DROP ANY PROCEDURE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='DROP ANY PROCEDURE'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.17 Enable 'DROP ANY PROCEDURE' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT, uses CDB_STMT_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.17</td>' ||
  '<td>Enable DROP ANY PROCEDURE Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'DROP ANY PROCEDURE audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>DROP ANY PROCEDURE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT DROP ANY PROCEDURE;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='DROP ANY PROCEDURE'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.18 Enable 'ALL' Audit Option on 'SYS.AUD$' - Oracle 11g (uses DBA_OBJ_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.18</td>' ||
  '<td>Enable ALL Audit Option on SYS.AUD$ (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'ALL audit on SYS.AUD$ enabled (ALT:' || MAX(ALT) || ', AUD:' || MAX(AUD) || ', COM:' || MAX(COM) || ', DEL:' || MAX(DEL) || ', GRA:' || MAX(GRA) || ', IND:' || MAX(IND) || ', INS:' || MAX(INS) || ', LOC:' || MAX(LOC) || ', REN:' || MAX(REN) || ', SEL:' || MAX(SEL) || ', UPD:' || MAX(UPD) || ', FBK:' || MAX(FBK) || ')'
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
AND FBK='A/A'
HAVING '&version_num' = '11';

-- 5.18 Enable 'ALL' Audit Option on 'SYS.AUD$' - Oracle 12c+ Non-multitenant OR when running from PDB (uses DBA_OBJ_AUDIT_OPTS)
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.18</td>' ||
  '<td>Enable ALL Audit Option on SYS.AUD$ (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 'ALL audit on SYS.AUD$ enabled (ALT:' || MAX(ALT) || ', AUD:' || MAX(AUD) || ', COM:' || MAX(COM) || ', DEL:' || MAX(DEL) || ', GRA:' || MAX(GRA) || ', IND:' || MAX(IND) || ', INS:' || MAX(INS) || ', LOC:' || MAX(LOC) || ', REN:' || MAX(REN) || ', SEL:' || MAX(SEL) || ', UPD:' || MAX(UPD) || ', FBK:' || MAX(FBK) || ')'
    ELSE 'ALL audit on SYS.AUD$ not enabled'
    END || '</td>' ||
  '<td>ALL audit on SYS.AUD$ enabled (ALL operations audited)</td>' ||
  '<td class="remediation">AUDIT ALL ON SYS.AUD$ BY ACCESS;</td>' ||
  '</tr>'
FROM DBA_OBJ_AUDIT_OPTS, CONTAINER_INFO CI
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
AND FBK='A/A'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.18 Enable 'ALL' Audit Option on 'SYS.AUD$' - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT, uses CDB_OBJ_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.18</td>' ||
  '<td>Enable ALL Audit Option on SYS.AUD$ (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'ALL audit on SYS.AUD$ not enabled in ' || container_name
    END || '</td>' ||
  '<td>ALL audit on SYS.AUD$ enabled (ALL operations audited)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT ALL ON SYS.AUD$ BY ACCESS;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    'ALL audit on SYS.AUD$ enabled (ALT:' || A.ALT || ', AUD:' || A.AUD || ', COM:' || A.COM || ', DEL:' || A.DEL || ', GRA:' || A.GRA || ', IND:' || A.IND || ', INS:' || A.INS || ', LOC:' || A.LOC || ', REN:' || A.REN || ', SEL:' || A.SEL || ', UPD:' || A.UPD || ', FBK:' || A.FBK || ')' AS audit_details
  FROM CDB_OBJ_AUDIT_OPTS A
  WHERE A.OBJECT_NAME='AUD$'
  AND A.ALT='A/A'
  AND A.AUD='A/A'
  AND A.COM='A/A'
  AND A.DEL='A/A'
  AND A.GRA='A/A'
  AND A.IND='A/A'
  AND A.INS='A/A'
  AND A.LOC='A/A'
  AND A.REN='A/A'
  AND A.SEL='A/A'
  AND A.UPD='A/A'
  AND A.FBK='A/A'
  GROUP BY A.CON_ID, A.ALT, A.AUD, A.COM, A.DEL, A.GRA, A.IND, A.INS, A.LOC, A.REN, A.SEL, A.UPD, A.FBK
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.19 Enable 'PROCEDURE' Audit Option - Oracle 11g (uses DBA_STMT_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.19</td>' ||
  '<td>Enable PROCEDURE Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'PROCEDURE audit not enabled'
    END || '</td>' ||
  '<td>PROCEDURE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT PROCEDURE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='PROCEDURE'
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.19 Enable 'PROCEDURE' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB (uses DBA_STMT_AUDIT_OPTS)
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.19</td>' ||
  '<td>Enable PROCEDURE Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'PROCEDURE audit not enabled'
    END || '</td>' ||
  '<td>PROCEDURE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT PROCEDURE;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='PROCEDURE'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.19 Enable 'PROCEDURE' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT, uses CDB_STMT_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.19</td>' ||
  '<td>Enable PROCEDURE Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'PROCEDURE audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>PROCEDURE audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT PROCEDURE;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='PROCEDURE'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.20 Enable 'ALTER SYSTEM' Audit Option - Oracle 11g (uses DBA_STMT_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.20</td>' ||
  '<td>Enable ALTER SYSTEM Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'ALTER SYSTEM audit not enabled'
    END || '</td>' ||
  '<td>ALTER SYSTEM audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT ALTER SYSTEM;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='ALTER SYSTEM'
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.20 Enable 'ALTER SYSTEM' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB (uses DBA_STMT_AUDIT_OPTS)
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.20</td>' ||
  '<td>Enable ALTER SYSTEM Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'ALTER SYSTEM audit not enabled'
    END || '</td>' ||
  '<td>ALTER SYSTEM audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT ALTER SYSTEM;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='ALTER SYSTEM'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.20 Enable 'ALTER SYSTEM' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT, uses CDB_STMT_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.20</td>' ||
  '<td>Enable ALTER SYSTEM Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'ALTER SYSTEM audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>ALTER SYSTEM audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT ALTER SYSTEM;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='ALTER SYSTEM'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.21 Enable 'TRIGGER' Audit Option - Oracle 11g (uses DBA_STMT_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.21</td>' ||
  '<td>Enable TRIGGER Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'TRIGGER audit not enabled'
    END || '</td>' ||
  '<td>TRIGGER audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT TRIGGER;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='TRIGGER'
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.21 Enable 'TRIGGER' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB (uses DBA_STMT_AUDIT_OPTS)
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.21</td>' ||
  '<td>Enable TRIGGER Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'TRIGGER audit not enabled'
    END || '</td>' ||
  '<td>TRIGGER audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT TRIGGER;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='TRIGGER'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.21 Enable 'TRIGGER' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT, uses CDB_STMT_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.21</td>' ||
  '<td>Enable TRIGGER Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'TRIGGER audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>TRIGGER audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT TRIGGER;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='TRIGGER'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.22 Enable 'CREATE SESSION' Audit Option - Oracle 11g (uses DBA_STMT_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.22</td>' ||
  '<td>Enable CREATE SESSION Audit Option (Scored) - 11g</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'CREATE SESSION audit not enabled'
    END || '</td>' ||
  '<td>CREATE SESSION audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT SESSION;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS
WHERE AUDIT_OPTION='CREATE SESSION'
AND USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
HAVING '&version_num' = '11';

-- 5.22 Enable 'CREATE SESSION' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB (uses DBA_STMT_AUDIT_OPTS)
WITH CONTAINER_INFO AS (
  SELECT 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END AS container_desc
  FROM DUAL
)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.22</td>' ||
  '<td>Enable CREATE SESSION Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE 'CREATE SESSION audit not enabled'
    END || '</td>' ||
  '<td>CREATE SESSION audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT SESSION;</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='CREATE SESSION'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;

-- 5.22 Enable 'CREATE SESSION' Audit Option - Oracle 12c+ Multitenant CDB (when running from CDB$ROOT, uses CDB_STMT_AUDIT_OPTS)
SELECT '<tr class="' ||
  CASE
    WHEN audit_count = 0 THEN 'fail'
    ELSE 'pass'
  END || '">' ||
  '<td>5.22</td>' ||
  '<td>Enable CREATE SESSION Audit Option (Scored) - CDB (' || container_name || ')</td>' ||
  '<td>' || CASE WHEN audit_count = 0 THEN 'FAIL' ELSE 'PASS' END || '</td>' ||
  '<td>' ||
    CASE WHEN audit_count > 0 THEN audit_details
    ELSE 'CREATE SESSION audit not enabled in ' || container_name
    END || '</td>' ||
  '<td>CREATE SESSION audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">Connect to each container: ALTER SESSION SET CONTAINER=&lt;container&gt;; AUDIT SESSION;</td>' ||
  '</tr>'
FROM (
  SELECT 
    COUNT(*) AS audit_count,
    DECODE(A.CON_ID, 0, (SELECT NAME FROM V$DATABASE), 1, (SELECT NAME FROM V$DATABASE), (SELECT NAME FROM V$PDBS B WHERE A.CON_ID = B.CON_ID)) AS container_name,
    LISTAGG(A.AUDIT_OPTION || ' (SUCCESS:' || A.SUCCESS || ', FAILURE:' || A.FAILURE || ')', ', ') WITHIN GROUP (ORDER BY A.AUDIT_OPTION) AS audit_details
  FROM CDB_STMT_AUDIT_OPTS A
  WHERE A.USER_NAME IS NULL 
  AND A.PROXY_NAME IS NULL
  AND A.SUCCESS = 'BY ACCESS' 
  AND A.FAILURE = 'BY ACCESS'
  AND A.AUDIT_OPTION='CREATE SESSION'
  GROUP BY A.CON_ID
  ORDER BY A.CON_ID
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) = 'CDB$ROOT';

-- 5.23 Enable 'CREATE USER' Audit Option - Oracle 12c Unified Auditing (Note: Title suggests DATABASE LINK but spec checks CREATE USER)
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.23</td>' ||
  '<td>Enable CREATE USER Audit Option (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG('Policy: ' || AUD.POLICY_NAME || ', Option: ' || AUD.AUDIT_OPTION || ', Type: ' || AUD.AUDIT_OPTION_TYPE, '; ') WITHIN GROUP (ORDER BY AUD.POLICY_NAME)
    ELSE 'CREATE USER unified audit policy not enabled'
    END || '</td>' ||
  '<td>CREATE USER audit enabled in unified audit policy (SUCCESS=YES, FAILURE=YES)</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS CREATE USER;</td>' ||
  '</tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME
AND AUD.AUDIT_OPTION = 'CREATE USER'
AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES'
AND ENABLED.FAILURE = 'YES'
AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.23 Enable 'CREATE USER' Audit Option - Oracle 18c+ Unified Auditing (Enhanced)
SELECT '<tr class="' ||
  CASE 
    WHEN missing_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.23</td>' ||
  '<td>Enable CREATE USER Audit Option (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN missing_count = 0 THEN 'CREATE USER unified audit policy enabled'
    ELSE 'CREATE USER unified audit policy missing (' || missing_count || ' options not configured)'
    END || '</td>' ||
  '<td>CREATE USER audit enabled in unified audit policy (SUCCESS=YES, FAILURE=YES)</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS CREATE USER;</td>' ||
  '</tr>'
FROM (
  WITH
  CIS_AUDIT(AUDIT_OPTION) AS
  (
    SELECT 'CREATE USER' AS AUDIT_OPTION FROM DUAL
  ),
  AUDIT_ENABLED AS
  ( 
    SELECT DISTINCT AUDIT_OPTION
    FROM AUDIT_UNIFIED_POLICIES AUD
    WHERE AUD.AUDIT_OPTION IN ('CREATE USER' )
    AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT *
      FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
      WHERE ENABLED.SUCCESS = 'YES'
      AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER'
      AND ENABLED.ENTITY_NAME = 'ALL USERS'
      AND ENABLED.POLICY_NAME = AUD.POLICY_NAME)
  )
  SELECT COUNT(*) AS missing_count
  FROM CIS_AUDIT C
  LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION
  WHERE E.AUDIT_OPTION IS NULL
)
WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.24 Ensure the 'CREATE ROLE' Action Audit Is Enabled - Oracle 12c Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.24</td>' ||
  '<td>Ensure CREATE ROLE Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG('Policy: ' || AUD.POLICY_NAME || ', Option: ' || AUD.AUDIT_OPTION, '; ') WITHIN GROUP (ORDER BY AUD.POLICY_NAME)
    ELSE 'CREATE ROLE unified audit policy not enabled'
    END || '</td>' ||
  '<td>CREATE ROLE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS CREATE ROLE;</td>' ||
  '</tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME
AND AUD.AUDIT_OPTION = 'CREATE ROLE'
AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES'
AND ENABLED.FAILURE = 'YES'
AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.24 Ensure the 'CREATE ROLE' Action Audit Is Enabled - Oracle 18c+ Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN missing_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.24</td>' ||
  '<td>Ensure CREATE ROLE Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN missing_count = 0 THEN 'CREATE ROLE unified audit policy enabled'
    ELSE 'CREATE ROLE unified audit policy missing'
    END || '</td>' ||
  '<td>CREATE ROLE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS CREATE ROLE;</td>' ||
  '</tr>'
FROM (
  WITH
  CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'CREATE ROLE' AS AUDIT_OPTION FROM DUAL ),
  AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD
    WHERE AUD.AUDIT_OPTION = 'CREATE ROLE' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
      WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS'
      AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C
  LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION
  WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.25 Ensure the 'ALTER ROLE' Action Audit Is Enabled - Oracle 12c Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.25</td>' ||
  '<td>Ensure ALTER ROLE Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG('Policy: ' || AUD.POLICY_NAME || ', Option: ' || AUD.AUDIT_OPTION, '; ') WITHIN GROUP (ORDER BY AUD.POLICY_NAME)
    ELSE 'ALTER ROLE unified audit policy not enabled'
    END || '</td>' ||
  '<td>ALTER ROLE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS ALTER ROLE;</td>' ||
  '</tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME
AND AUD.AUDIT_OPTION = 'ALTER ROLE'
AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES'
AND ENABLED.FAILURE = 'YES'
AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.25 Ensure the 'ALTER ROLE' Action Audit Is Enabled - Oracle 18c+ Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN missing_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.25</td>' ||
  '<td>Ensure ALTER ROLE Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN missing_count = 0 THEN 'ALTER ROLE unified audit policy enabled'
    ELSE 'ALTER ROLE unified audit policy missing'
    END || '</td>' ||
  '<td>ALTER ROLE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS ALTER ROLE;</td>' ||
  '</tr>'
FROM (
  WITH
  CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'ALTER ROLE' AS AUDIT_OPTION FROM DUAL ),
  AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD
    WHERE AUD.AUDIT_OPTION = 'ALTER ROLE' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
      WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS'
      AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C
  LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION
  WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.26 Ensure the 'DROP ROLE' Action Audit Is Enabled - Oracle 12c Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.26</td>' ||
  '<td>Ensure DROP ROLE Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG('Policy: ' || AUD.POLICY_NAME || ', Option: ' || AUD.AUDIT_OPTION, '; ') WITHIN GROUP (ORDER BY AUD.POLICY_NAME)
    ELSE 'DROP ROLE unified audit policy not enabled'
    END || '</td>' ||
  '<td>DROP ROLE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS DROP ROLE;</td>' ||
  '</tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME
AND AUD.AUDIT_OPTION = 'DROP ROLE'
AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES'
AND ENABLED.FAILURE = 'YES'
AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.26 Ensure the 'DROP ROLE' Action Audit Is Enabled - Oracle 18c+ Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN missing_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.26</td>' ||
  '<td>Ensure DROP ROLE Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN missing_count = 0 THEN 'DROP ROLE unified audit policy enabled'
    ELSE 'DROP ROLE unified audit policy missing'
    END || '</td>' ||
  '<td>DROP ROLE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS DROP ROLE;</td>' ||
  '</tr>'
FROM (
  WITH
  CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'DROP ROLE' AS AUDIT_OPTION FROM DUAL ),
  AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD
    WHERE AUD.AUDIT_OPTION = 'DROP ROLE' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
      WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS'
      AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C
  LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION
  WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.27 Ensure the 'GRANT' Action Audit Is Enabled - Oracle 12c Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.27</td>' ||
  '<td>Ensure GRANT Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG('Policy: ' || AUD.POLICY_NAME || ', Option: ' || AUD.AUDIT_OPTION, '; ') WITHIN GROUP (ORDER BY AUD.POLICY_NAME)
    ELSE 'GRANT unified audit policy not enabled'
    END || '</td>' ||
  '<td>GRANT audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS GRANT;</td>' ||
  '</tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME
AND AUD.AUDIT_OPTION = 'GRANT'
AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES'
AND ENABLED.FAILURE = 'YES'
AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.27 Ensure the 'GRANT' Action Audit Is Enabled - Oracle 18c+ Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN missing_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.27</td>' ||
  '<td>Ensure GRANT Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN missing_count = 0 THEN 'GRANT unified audit policy enabled'
    ELSE 'GRANT unified audit policy missing'
    END || '</td>' ||
  '<td>GRANT audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS GRANT;</td>' ||
  '</tr>'
FROM (
  WITH
  CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'GRANT' AS AUDIT_OPTION FROM DUAL ),
  AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD
    WHERE AUD.AUDIT_OPTION = 'GRANT' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
      WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS'
      AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C
  LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION
  WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.28 Ensure the 'REVOKE' Action Audit Is Enabled - Oracle 12c Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.28</td>' ||
  '<td>Ensure REVOKE Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG('Policy: ' || AUD.POLICY_NAME || ', Option: ' || AUD.AUDIT_OPTION, '; ') WITHIN GROUP (ORDER BY AUD.POLICY_NAME)
    ELSE 'REVOKE unified audit policy not enabled'
    END || '</td>' ||
  '<td>REVOKE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS REVOKE;</td>' ||
  '</tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME
AND AUD.AUDIT_OPTION = 'REVOKE'
AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES'
AND ENABLED.FAILURE = 'YES'
AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.28 Ensure the 'REVOKE' Action Audit Is Enabled - Oracle 18c+ Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN missing_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.28</td>' ||
  '<td>Ensure REVOKE Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN missing_count = 0 THEN 'REVOKE unified audit policy enabled'
    ELSE 'REVOKE unified audit policy missing'
    END || '</td>' ||
  '<td>REVOKE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS REVOKE;</td>' ||
  '</tr>'
FROM (
  WITH
  CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'REVOKE' AS AUDIT_OPTION FROM DUAL ),
  AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD
    WHERE AUD.AUDIT_OPTION = 'REVOKE' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
      WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS'
      AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C
  LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION
  WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.29 Ensure the 'CREATE PROFILE' Action Audit Is Enabled - Oracle 12c Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.29</td>' ||
  '<td>Ensure CREATE PROFILE Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG('Policy: ' || AUD.POLICY_NAME || ', Option: ' || AUD.AUDIT_OPTION, '; ') WITHIN GROUP (ORDER BY AUD.POLICY_NAME)
    ELSE 'CREATE PROFILE unified audit policy not enabled'
    END || '</td>' ||
  '<td>CREATE PROFILE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS CREATE PROFILE;</td>' ||
  '</tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME
AND AUD.AUDIT_OPTION = 'CREATE PROFILE'
AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES'
AND ENABLED.FAILURE = 'YES'
AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.29 Ensure the 'CREATE PROFILE' Action Audit Is Enabled - Oracle 18c+ Unified Auditing
SELECT '<tr class="' ||
  CASE 
    WHEN missing_count = 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.29</td>' ||
  '<td>Ensure CREATE PROFILE Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN missing_count = 0 THEN 'CREATE PROFILE unified audit policy enabled'
    ELSE 'CREATE PROFILE unified audit policy missing'
    END || '</td>' ||
  '<td>CREATE PROFILE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS CREATE PROFILE;</td>' ||
  '</tr>'
FROM (
  WITH
  CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'CREATE PROFILE' AS AUDIT_OPTION FROM DUAL ),
  AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD
    WHERE AUD.AUDIT_OPTION = 'CREATE PROFILE' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
      WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS'
      AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C
  LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION
  WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.30-5.37 Additional Unified Auditing Checks (ALTER PROFILE, DROP PROFILE, DATABASE LINK operations, SYNONYM operations)
-- Note: Adding remaining checks in abbreviated format due to space constraints

-- 5.30 ALTER PROFILE - 12c
SELECT '<tr class="' || CASE WHEN COUNT(*) > 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.30</td><td>Ensure ALTER PROFILE Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'ALTER PROFILE audit enabled' ELSE 'ALTER PROFILE audit not enabled' END || '</td>' ||
  '<td>ALTER PROFILE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS ALTER PROFILE;</td></tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME AND AUD.AUDIT_OPTION = 'ALTER PROFILE' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES' AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.30 ALTER PROFILE - 18c+
SELECT '<tr class="' || CASE WHEN missing_count = 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.30</td><td>Ensure ALTER PROFILE Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'ALTER PROFILE audit enabled' ELSE 'ALTER PROFILE audit missing' END || '</td>' ||
  '<td>ALTER PROFILE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS ALTER PROFILE;</td></tr>'
FROM ( WITH CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'ALTER PROFILE' FROM DUAL ), AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD WHERE AUD.AUDIT_OPTION = 'ALTER PROFILE' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS' AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.31 DROP PROFILE - 12c
SELECT '<tr class="' || CASE WHEN COUNT(*) > 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.31</td><td>Ensure DROP PROFILE Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'DROP PROFILE audit enabled' ELSE 'DROP PROFILE audit not enabled' END || '</td>' ||
  '<td>DROP PROFILE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS DROP PROFILE;</td></tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME AND AUD.AUDIT_OPTION = 'DROP PROFILE' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES' AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.31 DROP PROFILE - 18c+
SELECT '<tr class="' || CASE WHEN missing_count = 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.31</td><td>Ensure DROP PROFILE Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'DROP PROFILE audit enabled' ELSE 'DROP PROFILE audit missing' END || '</td>' ||
  '<td>DROP PROFILE audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS DROP PROFILE;</td></tr>'
FROM ( WITH CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'DROP PROFILE' FROM DUAL ), AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD WHERE AUD.AUDIT_OPTION = 'DROP PROFILE' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS' AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.32 CREATE DATABASE LINK - 12c
SELECT '<tr class="' || CASE WHEN COUNT(*) > 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.32</td><td>Ensure CREATE DATABASE LINK Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'CREATE DATABASE LINK audit enabled' ELSE 'CREATE DATABASE LINK audit not enabled' END || '</td>' ||
  '<td>CREATE DATABASE LINK audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS CREATE DATABASE LINK;</td></tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME AND AUD.AUDIT_OPTION = 'CREATE DATABASE LINK' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES' AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.32 CREATE DATABASE LINK - 18c+
SELECT '<tr class="' || CASE WHEN missing_count = 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.32</td><td>Ensure CREATE DATABASE LINK Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'CREATE DATABASE LINK audit enabled' ELSE 'CREATE DATABASE LINK audit missing' END || '</td>' ||
  '<td>CREATE DATABASE LINK audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS CREATE DATABASE LINK;</td></tr>'
FROM ( WITH CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'CREATE DATABASE LINK' FROM DUAL ), AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD WHERE AUD.AUDIT_OPTION = 'CREATE DATABASE LINK' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS' AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.33 ALTER DATABASE LINK - 12c
SELECT '<tr class="' || CASE WHEN COUNT(*) > 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.33</td><td>Ensure ALTER DATABASE LINK Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'ALTER DATABASE LINK audit enabled' ELSE 'ALTER DATABASE LINK audit not enabled' END || '</td>' ||
  '<td>ALTER DATABASE LINK audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS ALTER DATABASE LINK;</td></tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME AND AUD.AUDIT_OPTION = 'ALTER DATABASE LINK' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES' AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.33 ALTER DATABASE LINK - 18c+
SELECT '<tr class="' || CASE WHEN missing_count = 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.33</td><td>Ensure ALTER DATABASE LINK Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'ALTER DATABASE LINK audit enabled' ELSE 'ALTER DATABASE LINK audit missing' END || '</td>' ||
  '<td>ALTER DATABASE LINK audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS ALTER DATABASE LINK;</td></tr>'
FROM ( WITH CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'ALTER DATABASE LINK' FROM DUAL ), AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD WHERE AUD.AUDIT_OPTION = 'ALTER DATABASE LINK' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS' AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.34 DROP DATABASE LINK - 12c
SELECT '<tr class="' || CASE WHEN COUNT(*) > 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.34</td><td>Ensure DROP DATABASE LINK Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'DROP DATABASE LINK audit enabled' ELSE 'DROP DATABASE LINK audit not enabled' END || '</td>' ||
  '<td>DROP DATABASE LINK audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS DROP DATABASE LINK;</td></tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME AND AUD.AUDIT_OPTION = 'DROP DATABASE LINK' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES' AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.34 DROP DATABASE LINK - 18c+
SELECT '<tr class="' || CASE WHEN missing_count = 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.34</td><td>Ensure DROP DATABASE LINK Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'DROP DATABASE LINK audit enabled' ELSE 'DROP DATABASE LINK audit missing' END || '</td>' ||
  '<td>DROP DATABASE LINK audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS DROP DATABASE LINK;</td></tr>'
FROM ( WITH CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'DROP DATABASE LINK' FROM DUAL ), AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD WHERE AUD.AUDIT_OPTION = 'DROP DATABASE LINK' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS' AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.35 CREATE SYNONYM - 12c
SELECT '<tr class="' || CASE WHEN COUNT(*) > 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.35</td><td>Ensure CREATE SYNONYM Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'CREATE SYNONYM audit enabled' ELSE 'CREATE SYNONYM audit not enabled' END || '</td>' ||
  '<td>CREATE SYNONYM audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS CREATE SYNONYM;</td></tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME AND AUD.AUDIT_OPTION = 'CREATE SYNONYM' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES' AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.35 CREATE SYNONYM - 18c+
SELECT '<tr class="' || CASE WHEN missing_count = 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.35</td><td>Ensure CREATE SYNONYM Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'CREATE SYNONYM audit enabled' ELSE 'CREATE SYNONYM audit missing' END || '</td>' ||
  '<td>CREATE SYNONYM audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS CREATE SYNONYM;</td></tr>'
FROM ( WITH CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'CREATE SYNONYM' FROM DUAL ), AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD WHERE AUD.AUDIT_OPTION = 'CREATE SYNONYM' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS' AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.36 ALTER SYNONYM - 12c
SELECT '<tr class="' || CASE WHEN COUNT(*) > 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.36</td><td>Ensure ALTER SYNONYM Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'ALTER SYNONYM audit enabled' ELSE 'ALTER SYNONYM audit not enabled' END || '</td>' ||
  '<td>ALTER SYNONYM audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS ALTER SYNONYM;</td></tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME AND AUD.AUDIT_OPTION = 'ALTER SYNONYM' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES' AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.36 ALTER SYNONYM - 18c+
SELECT '<tr class="' || CASE WHEN missing_count = 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.36</td><td>Ensure ALTER SYNONYM Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'ALTER SYNONYM audit enabled' ELSE 'ALTER SYNONYM audit missing' END || '</td>' ||
  '<td>ALTER SYNONYM audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS ALTER SYNONYM;</td></tr>'
FROM ( WITH CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'ALTER SYNONYM' FROM DUAL ), AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD WHERE AUD.AUDIT_OPTION = 'ALTER SYNONYM' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS' AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

-- 5.37 DROP SYNONYM - 12c
SELECT '<tr class="' || CASE WHEN COUNT(*) > 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.37</td><td>Ensure DROP SYNONYM Action Audit Is Enabled (Scored) - 12c Unified Auditing</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'DROP SYNONYM audit enabled' ELSE 'DROP SYNONYM audit not enabled' END || '</td>' ||
  '<td>DROP SYNONYM audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS DROP SYNONYM;</td></tr>'
FROM AUDIT_UNIFIED_POLICIES AUD, AUDIT_UNIFIED_ENABLED_POLICIES ENABLED
WHERE AUD.POLICY_NAME = ENABLED.POLICY_NAME AND AUD.AUDIT_OPTION = 'DROP SYNONYM' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
AND ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES' AND ENABLED.ENABLED_OPTION = 'BY USER'
HAVING '&version_num' = '12';

-- 5.37 DROP SYNONYM - 18c+
SELECT '<tr class="' || CASE WHEN missing_count = 0 THEN 'pass' ELSE 'fail' END || '">' ||
  '<td>5.37</td><td>Ensure DROP SYNONYM Action Audit Is Enabled (Scored) - 18c+ Unified Auditing</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || CASE WHEN missing_count = 0 THEN 'DROP SYNONYM audit enabled' ELSE 'DROP SYNONYM audit missing' END || '</td>' ||
  '<td>DROP SYNONYM audit enabled in unified audit policy</td>' ||
  '<td class="remediation">ALTER AUDIT POLICY CIS_UNIFIED_AUDIT_POLICY ADD ACTIONS DROP SYNONYM;</td></tr>'
FROM ( WITH CIS_AUDIT(AUDIT_OPTION) AS ( SELECT 'DROP SYNONYM' FROM DUAL ), AUDIT_ENABLED AS
  ( SELECT DISTINCT AUDIT_OPTION FROM AUDIT_UNIFIED_POLICIES AUD WHERE AUD.AUDIT_OPTION = 'DROP SYNONYM' AND AUD.AUDIT_OPTION_TYPE = 'STANDARD ACTION'
    AND EXISTS (SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES ENABLED WHERE ENABLED.SUCCESS = 'YES' AND ENABLED.FAILURE = 'YES'
      AND ENABLED.ENABLED_OPTION = 'BY USER' AND ENABLED.ENTITY_NAME = 'ALL USERS' AND ENABLED.POLICY_NAME = AUD.POLICY_NAME) )
  SELECT COUNT(*) AS missing_count FROM CIS_AUDIT C LEFT JOIN AUDIT_ENABLED E ON C.AUDIT_OPTION = E.AUDIT_OPTION WHERE E.AUDIT_OPTION IS NULL
) WHERE TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 18;

PROMPT </table>

-- 12c+ Unified Auditing Section
SELECT CASE WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN
  '<h3 id="section5_38">5.38 Unified Auditing (12c+)</h3>' ||
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
  '<td>5.38.1</td>' ||
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
  '<td>5.38.2</td>' ||
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
  '<td>5.38.3</td>' ||
  '<td>Fine-Grained Auditing (FGA) Policies</td>' ||
  '<td>' || CASE WHEN fc.policy_count > 0 THEN 'CONFIGURED' ELSE 'NONE' END || '</td>' ||
  '<td>FGA policies: ' || fc.policy_count || '</td>' ||
  '<td>As required for sensitive tables</td>' ||
  '<td class="remediation">DBMS_FGA.ADD_POLICY</td>' ||
  '</tr>'
ELSE '' END
FROM v$instance vi, fga_count fc;

SELECT CASE WHEN version LIKE '12.%' OR version LIKE '18.%' OR version LIKE '19.%' THEN '</table>' ELSE '' END FROM v$instance;

PROMPT <div style="margin-top: 40px; padding-top: 20px; border-top: 2px solid #dee2e6; font-size: 12px; color: #607d8b;">
SELECT '<p><strong>Report Generated:</strong> ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') ||
       ' | <strong>Database:</strong> ' || SYS_CONTEXT('USERENV', 'DB_NAME') ||
       ' | <strong>Instance:</strong> ' || SYS_CONTEXT('USERENV', 'INSTANCE_NAME') || '</p>' FROM DUAL;
SELECT '<p><strong>Benchmark Reference:</strong> ' ||
  CASE 
    WHEN version LIKE '19.%' THEN 'CIS Oracle Database 19c Benchmark v1.2.0'
    WHEN version LIKE '18.%' THEN 'CIS Oracle Database 18c Benchmark v1.1.0'
    WHEN version LIKE '12.%' THEN 'CIS Oracle Database 12c Benchmark v3.0.0'
    WHEN version LIKE '11.2%' THEN 'CIS Oracle Database 11g R2 Benchmark v2.2.0'
    ELSE 'CIS Oracle Database Benchmark'
  END || '.</p>'
  || '<p>Validate findings against business requirements and test all fixes prior to production deployment.</p>'
FROM v$instance;
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

-- ============================================================================
-- DISPLAY COMPREHENSIVE REMEDIATION COMMANDS
-- Structured remediation output aligned with CIS report sections
-- ============================================================================

SET TERMOUT ON
SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 0
SET LINESIZE 200
SET TRIMSPOOL ON

PROMPT
PROMPT ============================================================================
PROMPT Remediation Command Summary
PROMPT ============================================================================
PROMPT Review and test all statements in a non-production environment.
PROMPT Apply changes during approved maintenance windows and capture backups.
PROMPT

SELECT '[Context] Database Version : ' || version FROM V$INSTANCE;
SELECT '[Context] Host / Instance  : ' || SYS_CONTEXT('USERENV', 'SERVER_HOST') || ' / ' || SYS_CONTEXT('USERENV', 'INSTANCE_NAME') FROM DUAL;
SELECT '[Context] Multitenant Mode : ' || NVL((SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1), 'NO') FROM DUAL;

SET DEFINE ON
SELECT '[Context] Execution Scope  : ' ||
  CASE
    WHEN '&current_container' = 'CDB$ROOT' THEN 'CDB root (system-wide controls). Re-run in each PDB for full coverage.'
    WHEN '&is_pdb' = 'YES' THEN 'PDB ' || '&container_name' || ' (local controls). Re-run from CDB$ROOT for system controls.'
    WHEN '&is_multitenant' = 'NO' THEN 'Non-CDB database (all controls covered in this run).'
    ELSE 'Single-tenant database (all controls covered in this run).'
  END
FROM DUAL;
SET DEFINE OFF

PROMPT
PROMPT [1] Installation & Patching
PROMPT   Focus on supported versions, CPU/PSU patching, and removal of sample schemas.

WITH default_pw AS (
  SELECT USERNAME
  FROM DBA_USERS_WITH_DEFPWD
  WHERE USERNAME NOT LIKE '%XS$NULL%'
), summary_default AS (
  SELECT COUNT(*) AS total FROM default_pw
), sample_default AS (
  SELECT * FROM default_pw WHERE ROWNUM <= 50
)
SELECT (
  '[1.2] Default Password Accounts' || CHR(10) ||
  CASE
    WHEN (SELECT total FROM summary_default) > 0 THEN
      '  Issue  : ' || (SELECT total FROM summary_default) || ' account(s) use default credentials' || CHR(10) ||
      '  Action :' || CHR(10) ||
      NVL((SELECT LISTAGG('    ALTER USER ' || USERNAME || ' IDENTIFIED BY <new_strong_password> ACCOUNT UNLOCK;', CHR(10))
             WITHIN GROUP (ORDER BY USERNAME) FROM sample_default),
          '    -- Review DBA_USERS_WITH_DEFPWD for the affected accounts.') || CHR(10) ||
      CASE WHEN (SELECT total FROM summary_default) > 50 THEN '    -- Additional accounts exist; query DBA_USERS_WITH_DEFPWD for full list.' || CHR(10) ELSE '' END ||
      '    -- Replace <new_strong_password> and expire/reset passwords per policy.'
    ELSE
      '  Status : OK'
  END
) || CHR(10)
FROM summary_default;

WITH sample_accounts AS (
  SELECT USERNAME, ACCOUNT_STATUS
  FROM DBA_USERS
  WHERE USERNAME IN ('BI','HR','IX','OE','PM','SCOTT','SH','DEMO','SAMPLE','TEST','GUEST','OUTLN')
), summary_sample AS (
  SELECT COUNT(*) AS total FROM sample_accounts
), sample_list AS (
  SELECT * FROM sample_accounts WHERE ROWNUM <= 50
)
SELECT (
  '[1.3] Sample / Unused Accounts' || CHR(10) ||
  CASE
    WHEN (SELECT total FROM summary_sample) > 0 THEN
      '  Issue  : ' || (SELECT total FROM summary_sample) || ' sample or legacy account(s) present' || CHR(10) ||
      '  Action :' || CHR(10) ||
      NVL((SELECT LISTAGG(
               CASE WHEN ACCOUNT_STATUS LIKE 'OPEN%'
                    THEN '    ALTER USER ' || USERNAME || ' ACCOUNT LOCK;'
                    ELSE '    DROP USER ' || USERNAME || ' CASCADE; -- verify the account is unused before dropping'
               END,
               CHR(10)) WITHIN GROUP (ORDER BY USERNAME)
             FROM sample_list),
          '    -- Review DBA_USERS for sample accounts before removing them.') || CHR(10) ||
      CASE WHEN (SELECT total FROM summary_sample) > 50 THEN '    -- Additional accounts exist; query DBA_USERS for full list.' || CHR(10) ELSE '' END ||
      '    -- Confirm with application owners prior to removal.'
    ELSE
      '  Status : OK'
  END
) || CHR(10)
FROM summary_sample;

SET DEFINE ON
WITH common_summary AS (
  SELECT COUNT(*) AS total
  FROM DBA_USERS
  WHERE COMMON = 'YES'
    AND USERNAME NOT LIKE 'C##%'
    AND USERNAME NOT IN ('SYS','SYSTEM')
), common_list AS (
  SELECT USERNAME
  FROM DBA_USERS
  WHERE COMMON = 'YES'
    AND USERNAME NOT LIKE 'C##%'
    AND USERNAME NOT IN ('SYS','SYSTEM')
  ORDER BY USERNAME
)
SELECT (
  '[1.5] Common User Naming (CDB only)' || CHR(10) ||
  CASE
    WHEN ('&is_multitenant' = 'YES')
         AND (SELECT CDB FROM V$DATABASE WHERE ROWNUM = 1) = 'YES'
         AND (SELECT total FROM common_summary) > 0 THEN
      '  Issue  : ' || (SELECT total FROM common_summary) || ' common user(s) without C## prefix' || CHR(10) ||
      '  Action :' || CHR(10) ||
      NVL((SELECT LISTAGG('    -- Review: ' || USERNAME, CHR(10)) WITHIN GROUP (ORDER BY USERNAME) FROM common_list),
          '    -- Review DBA_USERS for non-compliant common users.') || CHR(10) ||
      '    -- Rename (ALTER USER) or drop non-compliant common users after validation.'
    WHEN ('&is_multitenant' = 'YES') THEN
      '  Status : OK'
    ELSE
      '  Status : Not applicable (non-CDB)'
  END
) || CHR(10)
FROM DUAL;
SET DEFINE OFF

PROMPT
PROMPT [2] Oracle Parameter Hardening
PROMPT   Apply ALTER SYSTEM statements from a privileged session; restart may be required for SPFILE changes.

SELECT (
  '[2.1] Listener Configuration' || CHR(10) ||
  '  Action : Review $ORACLE_HOME/network/admin/listener.ora and ensure:' || CHR(10) ||
  '    * SECURE_CONTROL_<listener_name> = ON' || CHR(10) ||
  '    * ADMIN_RESTRICTIONS_<listener_name> = ON' || CHR(10) ||
  '    * SECURE_REGISTER_<listener_name> = TCPS or IPC' || CHR(10) ||
  '    * extproc entries are removed or tightly restricted' || CHR(10) ||
  '    * Restart listener with `lsnrctl stop` / `lsnrctl start`'
) || CHR(10)
FROM DUAL;

WITH param_issues AS (
  SELECT LOWER(NAME) AS name,
         VALUE,
         CASE LOWER(NAME)
           WHEN 'audit_sys_operations' THEN 'ALTER SYSTEM SET AUDIT_SYS_OPERATIONS=TRUE SCOPE=SPFILE;'
           WHEN 'audit_trail' THEN 'ALTER SYSTEM SET AUDIT_TRAIL=DB SCOPE=SPFILE;'
           WHEN 'global_names' THEN 'ALTER SYSTEM SET GLOBAL_NAMES=TRUE SCOPE=SPFILE;'
           WHEN 'local_listener' THEN 'ALTER SYSTEM SET LOCAL_LISTENER=''(DESCRIPTION=(ADDRESS=(PROTOCOL=IPC)(KEY=REGISTER)))'' SCOPE=BOTH;'
           WHEN 'o7_dictionary_accessibility' THEN 'ALTER SYSTEM SET O7_DICTIONARY_ACCESSIBILITY=FALSE SCOPE=SPFILE;'
           WHEN 'os_roles' THEN 'ALTER SYSTEM SET OS_ROLES=FALSE SCOPE=SPFILE;'
           WHEN 'remote_listener' THEN 'ALTER SYSTEM SET REMOTE_LISTENER='''' SCOPE=SPFILE;'
           WHEN 'remote_login_passwordfile' THEN 'ALTER SYSTEM SET REMOTE_LOGIN_PASSWORDFILE=NONE SCOPE=SPFILE;'
           WHEN 'remote_os_authent' THEN 'ALTER SYSTEM SET REMOTE_OS_AUTHENT=FALSE SCOPE=SPFILE;'
           WHEN 'remote_os_roles' THEN 'ALTER SYSTEM SET REMOTE_OS_ROLES=FALSE SCOPE=SPFILE;'
           WHEN 'utl_file_dir' THEN 'ALTER SYSTEM SET UTL_FILE_DIR='''' SCOPE=SPFILE; -- create explicit DIRECTORY objects instead'
           WHEN 'sec_case_sensitive_logon' THEN 'ALTER SYSTEM SET SEC_CASE_SENSITIVE_LOGON=TRUE SCOPE=SPFILE;'
           WHEN 'sec_max_failed_login_attempts' THEN 'ALTER SYSTEM SET SEC_MAX_FAILED_LOGIN_ATTEMPTS=3 SCOPE=SPFILE;'
           WHEN 'sec_protocol_error_further_action' THEN 'ALTER SYSTEM SET SEC_PROTOCOL_ERROR_FURTHER_ACTION=''DELAY,3'' SCOPE=SPFILE;'
           WHEN 'sec_protocol_error_trace_action' THEN 'ALTER SYSTEM SET SEC_PROTOCOL_ERROR_TRACE_ACTION=LOG SCOPE=SPFILE;'
           WHEN 'sec_return_server_release_banner' THEN 'ALTER SYSTEM SET SEC_RETURN_SERVER_RELEASE_BANNER=FALSE SCOPE=SPFILE;'
           WHEN 'sql92_security' THEN 'ALTER SYSTEM SET SQL92_SECURITY=TRUE SCOPE=SPFILE;'
           WHEN '_trace_files_public' THEN 'ALTER SYSTEM SET "_trace_files_public"=FALSE SCOPE=SPFILE;'
           WHEN 'resource_limit' THEN 'ALTER SYSTEM SET RESOURCE_LIMIT=TRUE SCOPE=SPFILE;'
           WHEN 'common_user_prefix' THEN 'ALTER SYSTEM SET COMMON_USER_PREFIX=''C##'' SCOPE=SPFILE;'
           WHEN 'enable_ddl_logging' THEN 'ALTER SYSTEM SET ENABLE_DDL_LOGGING=TRUE SCOPE=SPFILE;'
           WHEN 'ldap_directory_sysauth' THEN 'ALTER SYSTEM SET LDAP_DIRECTORY_SYSAUTH=NO SCOPE=SPFILE;'
           WHEN 'allow_group_access_to_sga' THEN 'ALTER SYSTEM SET ALLOW_GROUP_ACCESS_TO_SGA=FALSE SCOPE=SPFILE;'
           ELSE 'ALTER SYSTEM SET ' || UPPER(NAME) || '=<secure_value> SCOPE=SPFILE;'
         END AS command
  FROM V$PARAMETER
  WHERE (UPPER(NAME) = 'AUDIT_SYS_OPERATIONS' AND UPPER(VALUE) != 'TRUE')
     OR (UPPER(NAME) = 'AUDIT_TRAIL' AND UPPER(VALUE) NOT IN ('OS','DB','XML','DB,EXTENDED','XML,EXTENDED'))
     OR (UPPER(NAME) = 'GLOBAL_NAMES' AND UPPER(VALUE) != 'TRUE')
     OR (UPPER(NAME) = 'LOCAL_LISTENER' AND (VALUE IS NULL OR UPPER(VALUE) NOT LIKE '%IPC%'))
     OR (UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY' AND UPPER(VALUE) != 'FALSE')
     OR (UPPER(NAME) = 'OS_ROLES' AND UPPER(VALUE) != 'FALSE')
     OR (UPPER(NAME) = 'REMOTE_LISTENER' AND VALUE IS NOT NULL AND LENGTH(TRIM(VALUE)) > 0)
     OR (UPPER(NAME) = 'REMOTE_LOGIN_PASSWORDFILE' AND UPPER(VALUE) != 'NONE')
     OR (UPPER(NAME) = 'REMOTE_OS_AUTHENT' AND UPPER(VALUE) != 'FALSE')
     OR (UPPER(NAME) = 'REMOTE_OS_ROLES' AND UPPER(VALUE) != 'FALSE')
     OR (UPPER(NAME) = 'UTL_FILE_DIR' AND VALUE IS NOT NULL AND LENGTH(TRIM(VALUE)) > 0)
     OR (UPPER(NAME) = 'SEC_CASE_SENSITIVE_LOGON' AND UPPER(VALUE) != 'TRUE')
     OR (UPPER(NAME) = 'SEC_MAX_FAILED_LOGIN_ATTEMPTS' AND NVL(VALUE,'0') NOT IN ('3','3.0'))
     OR (UPPER(NAME) = 'SEC_PROTOCOL_ERROR_FURTHER_ACTION' AND UPPER(VALUE) NOT LIKE '%DELAY%3%' AND UPPER(VALUE) NOT LIKE '%DROP%3%')
     OR (UPPER(NAME) = 'SEC_PROTOCOL_ERROR_TRACE_ACTION' AND UPPER(VALUE) != 'LOG')
     OR (UPPER(NAME) = 'SEC_RETURN_SERVER_RELEASE_BANNER' AND UPPER(VALUE) != 'FALSE')
     OR (UPPER(NAME) = 'SQL92_SECURITY' AND UPPER(VALUE) != 'TRUE')
     OR (UPPER(NAME) = '_TRACE_FILES_PUBLIC' AND UPPER(VALUE) != 'FALSE')
     OR (UPPER(NAME) = 'RESOURCE_LIMIT' AND UPPER(VALUE) != 'TRUE')
     OR (UPPER(NAME) = 'COMMON_USER_PREFIX' AND UPPER(VALUE) != 'C##')
     OR (UPPER(NAME) = 'ENABLE_DDL_LOGGING' AND UPPER(VALUE) != 'TRUE')
     OR (UPPER(NAME) = 'LDAP_DIRECTORY_SYSAUTH' AND UPPER(VALUE) != 'NO')
     OR (UPPER(NAME) = 'ALLOW_GROUP_ACCESS_TO_SGA' AND UPPER(VALUE) != 'FALSE')
)
SELECT (
  '[2.2] Database Parameters' || CHR(10) ||
  CASE
    WHEN COUNT(*) > 0 THEN
      '  Issue  : ' || COUNT(*) || ' parameter(s) deviate from CIS guidance' || CHR(10) ||
      '  Action :' || CHR(10) ||
      LISTAGG('    ' || command || ' -- current: ' || NVL(VALUE, '<null>'), CHR(10))
        WITHIN GROUP (ORDER BY name)
    ELSE
      '  Status : OK'
  END
) || CHR(10)
FROM param_issues;

SELECT (
  '[2.3] SQLNET.ORA Encryption (18c+)' || CHR(10) ||
  CASE
    WHEN (SELECT TO_NUMBER(SUBSTR(version,1,2)) FROM V$INSTANCE) >= 18 THEN
      '  Action : Edit $ORACLE_HOME/network/admin/sqlnet.ora and add:' || CHR(10) ||
      '    SQLNET.ENCRYPTION_SERVER = REQUIRED' || CHR(10) ||
      '    SQLNET.CRYPTO_CHECKSUM_SERVER = REQUIRED' || CHR(10) ||
      '    SQLNET.ENCRYPTION_TYPES_SERVER = (AES256, AES192, AES128)' || CHR(10) ||
      '    -- Restart database and listener after changes.'
    ELSE
      '  Status : Not applicable to version ' || (SELECT version FROM V$INSTANCE)
  END
) || CHR(10)
FROM DUAL;

PROMPT
PROMPT [3] Connection & Login Policies
PROMPT   Harden password profiles and verification functions.

WITH profile_issues AS (
  SELECT PROFILE,
         RESOURCE_NAME,
         LIMIT,
         CASE RESOURCE_NAME
           WHEN 'FAILED_LOGIN_ATTEMPTS' THEN 'ALTER PROFILE ' || PROFILE || ' LIMIT FAILED_LOGIN_ATTEMPTS 5;'
           WHEN 'PASSWORD_LOCK_TIME' THEN 'ALTER PROFILE ' || PROFILE || ' LIMIT PASSWORD_LOCK_TIME 1;'
           WHEN 'PASSWORD_LIFE_TIME' THEN 'ALTER PROFILE ' || PROFILE || ' LIMIT PASSWORD_LIFE_TIME 90;'
           WHEN 'PASSWORD_REUSE_MAX' THEN 'ALTER PROFILE ' || PROFILE || ' LIMIT PASSWORD_REUSE_MAX 20;'
           WHEN 'PASSWORD_REUSE_TIME' THEN 'ALTER PROFILE ' || PROFILE || ' LIMIT PASSWORD_REUSE_TIME 365;'
           WHEN 'PASSWORD_GRACE_TIME' THEN 'ALTER PROFILE ' || PROFILE || ' LIMIT PASSWORD_GRACE_TIME 5;'
           WHEN 'SESSIONS_PER_USER' THEN 'ALTER PROFILE ' || PROFILE || ' LIMIT SESSIONS_PER_USER 10;'
           WHEN 'IDLE_TIME' THEN 'ALTER PROFILE ' || PROFILE || ' LIMIT IDLE_TIME 30;'
           WHEN 'INACTIVE_ACCOUNT_TIME' THEN 'ALTER PROFILE ' || PROFILE || ' LIMIT INACTIVE_ACCOUNT_TIME 120;'
         END AS command
  FROM DBA_PROFILES
  WHERE RESOURCE_NAME IN ('FAILED_LOGIN_ATTEMPTS','PASSWORD_LOCK_TIME','PASSWORD_LIFE_TIME','PASSWORD_REUSE_MAX',
                          'PASSWORD_REUSE_TIME','PASSWORD_GRACE_TIME','SESSIONS_PER_USER','IDLE_TIME','INACTIVE_ACCOUNT_TIME')
    AND (
      LIMIT = 'UNLIMITED'
      OR LIMIT = 'DEFAULT'
      OR (RESOURCE_NAME = 'FAILED_LOGIN_ATTEMPTS' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 5)
      OR (RESOURCE_NAME = 'PASSWORD_LOCK_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9.]+$') AND TO_NUMBER(LIMIT) < 1)
      OR (RESOURCE_NAME = 'PASSWORD_LIFE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 90)
      OR (RESOURCE_NAME = 'PASSWORD_REUSE_MAX' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) < 20)
      OR (RESOURCE_NAME = 'PASSWORD_REUSE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) < 365)
      OR (RESOURCE_NAME = 'PASSWORD_GRACE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 5)
      OR (RESOURCE_NAME = 'SESSIONS_PER_USER' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 10)
      OR (RESOURCE_NAME = 'IDLE_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 30)
      OR (RESOURCE_NAME = 'INACTIVE_ACCOUNT_TIME' AND REGEXP_LIKE(LIMIT, '^[0-9]+$') AND TO_NUMBER(LIMIT) > 120)
    )
), summary_profiles AS (
  SELECT COUNT(*) AS total FROM profile_issues
), sample_profiles AS (
  SELECT * FROM profile_issues WHERE ROWNUM <= 100
)
SELECT (
  '[3.1] Password Profile Limits' || CHR(10) ||
  CASE
    WHEN (SELECT total FROM summary_profiles) > 0 THEN
      '  Issue  : ' || (SELECT total FROM summary_profiles) || ' profile setting(s) exceed CIS thresholds' || CHR(10) ||
      '  Action :' || CHR(10) ||
      NVL((SELECT LISTAGG('    ' || command || CASE WHEN LIMIT NOT IN ('UNLIMITED','DEFAULT') THEN ' -- current: ' || LIMIT ELSE '' END,
             CHR(10)) WITHIN GROUP (ORDER BY PROFILE, RESOURCE_NAME) FROM sample_profiles),
          '    -- Review DBA_PROFILES for detailed profile settings.') || CHR(10) ||
      CASE WHEN (SELECT total FROM summary_profiles) > 100 THEN '    -- Additional entries exist; query DBA_PROFILES for full list.' || CHR(10) ELSE '' END
    ELSE
      '  Status : OK'
  END
) || CHR(10)
FROM summary_profiles;

SELECT (
  '[3.2] Password Verify Function' || CHR(10) ||
  CASE
    WHEN EXISTS (
      SELECT 1 FROM DBA_PROFILES 
      WHERE RESOURCE_NAME = 'PASSWORD_VERIFY_FUNCTION'
        AND (LIMIT IS NULL OR UPPER(LIMIT) IN ('NULL','DEFAULT'))
    ) THEN
      '  Action : ALTER PROFILE DEFAULT LIMIT PASSWORD_VERIFY_FUNCTION ' ||
      CASE 
        WHEN (SELECT version FROM V$INSTANCE) LIKE '11.%' THEN 'VERIFY_FUNCTION_11G;'
        ELSE 'ORA12C_VERIFY_FUNCTION;'
      END
    ELSE
      '  Status : OK'
  END
) || CHR(10)
FROM DUAL;

PROMPT
PROMPT [4] User Access & Authorization
PROMPT   Remove blanket privileges and tighten role assignments.

WITH public_exec AS (
  SELECT TABLE_NAME
  FROM DBA_TAB_PRIVS
  WHERE GRANTEE = 'PUBLIC'
    AND PRIVILEGE = 'EXECUTE'
    AND TABLE_NAME IN (
      'DBMS_LDAP','UTL_TCP','UTL_SMTP','UTL_HTTP','UTL_INADDR','UTL_URL','HTTPURITYPE','DBMS_NETWORK_ACL_ADMIN',
      'UTL_FILE','DBMS_LOB','DBMS_ADVISOR','DBMS_FILE_TRANSFER','DBMS_CRYPTO','DBMS_OBFUSCATION_TOOLKIT','DBMS_RANDOM',
      'DBMS_JAVA','DBMS_JAVA_TEST','DBMS_SCHEDULER','DBMS_JOB','DBMS_SQL','DBMS_XMLGEN','DBMS_XMLQUERY','DBMS_XMLSTORE',
      'DBMS_XMLSAVE','DBMS_AW','OWA_UTIL','DBMS_REDACT','DBMS_CREDENTIAL','DBMS_BACKUP_RESTORE','DBMS_STREAMS_RPC',
      'DBMS_AQADM_SYSCALLS','DBMS_REPCAT_SQL_UTL','INITJVMAUX','DBMS_STREAMS_ADM_UTL','DBMS_AQADM_SYS','DBMS_PRVTAQIM',
      'LTADM','WWV_DBMS_SQL','WWV_EXECUTE_IMMEDIATE','DBMS_IJOB'
    )
), summary_public AS (
  SELECT COUNT(*) AS total FROM public_exec
), sample_public AS (
  SELECT * FROM public_exec WHERE ROWNUM <= 50
)
SELECT (
  '[4.1] PUBLIC EXECUTE Privileges' || CHR(10) ||
  CASE
    WHEN (SELECT total FROM summary_public) > 0 THEN
      '  Issue  : ' || (SELECT total FROM summary_public) || ' package(s) exposed to PUBLIC' || CHR(10) ||
      '  Action :' || CHR(10) ||
      NVL((SELECT LISTAGG('    REVOKE EXECUTE ON ' || TABLE_NAME || ' FROM PUBLIC;', CHR(10))
             WITHIN GROUP (ORDER BY TABLE_NAME) FROM sample_public),
          '    -- Review DBA_TAB_PRIVS for EXECUTE grants to PUBLIC.') || CHR(10) ||
      CASE WHEN (SELECT total FROM summary_public) > 50 THEN '    -- Additional entries exist; query DBA_TAB_PRIVS for full list.' || CHR(10) ELSE '' END
    ELSE
      '  Status : OK'
  END
) || CHR(10)
FROM summary_public;

WITH any_privs AS (
  SELECT sp.GRANTEE, sp.PRIVILEGE
  FROM DBA_SYS_PRIVS sp
  LEFT JOIN DBA_USERS u ON u.USERNAME = sp.GRANTEE
  LEFT JOIN DBA_ROLES r ON r.ROLE = sp.GRANTEE
  WHERE sp.PRIVILEGE LIKE '%ANY%'
    AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
    AND sp.GRANTEE NOT LIKE 'C##%'
), summary_any AS (
  SELECT COUNT(*) AS total FROM any_privs
), sample_any AS (
  SELECT * FROM any_privs WHERE ROWNUM <= 30
)
SELECT (
  '[4.2] ANY Privileges Granted' || CHR(10) ||
  CASE
    WHEN (SELECT total FROM summary_any) > 0 THEN
      '  Issue  : ' || (SELECT total FROM summary_any) || ' excessive ANY privilege assignments detected' || CHR(10) ||
      '  Action :' || CHR(10) ||
      NVL((SELECT LISTAGG('    REVOKE ' || PRIVILEGE || ' FROM ' || GRANTEE || ';', CHR(10))
             WITHIN GROUP (ORDER BY GRANTEE, PRIVILEGE) FROM sample_any),
          '    -- Review DBA_SYS_PRIVS for privilege details.') || CHR(10) ||
      CASE WHEN (SELECT total FROM summary_any) > 30 THEN '    -- Additional entries exist; query DBA_SYS_PRIVS for full list.' || CHR(10) ELSE '' END
    ELSE
      '  Status : OK'
  END
) || CHR(10)
FROM summary_any;

WITH system_privs AS (
  SELECT sp.GRANTEE, sp.PRIVILEGE
  FROM DBA_SYS_PRIVS sp
  LEFT JOIN DBA_USERS u ON u.USERNAME = sp.GRANTEE
  LEFT JOIN DBA_ROLES r ON r.ROLE = sp.GRANTEE
  WHERE sp.PRIVILEGE IN ('ALTER SYSTEM','DROP ANY TABLE','CREATE ANY PROCEDURE','ALTER ANY PROCEDURE','DROP ANY PROCEDURE',
                         'CREATE ANY TRIGGER','ALTER ANY TRIGGER','DROP ANY TRIGGER','BECOME USER')
    AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
    AND sp.GRANTEE NOT LIKE 'C##%'
), summary_sys AS (
  SELECT COUNT(*) AS total FROM system_privs
), sample_sys AS (
  SELECT * FROM system_privs WHERE ROWNUM <= 30
)
SELECT (
  '[4.3] High-Risk System Privileges' || CHR(10) ||
  CASE
    WHEN (SELECT total FROM summary_sys) > 0 THEN
      '  Issue  : ' || (SELECT total FROM summary_sys) || ' high-impact privilege grants detected' || CHR(10) ||
      '  Action :' || CHR(10) ||
      NVL((SELECT LISTAGG('    REVOKE ' || PRIVILEGE || ' FROM ' || GRANTEE || ';', CHR(10))
             WITHIN GROUP (ORDER BY GRANTEE, PRIVILEGE) FROM sample_sys),
          '    -- Review DBA_SYS_PRIVS for privilege details.') || CHR(10) ||
      CASE WHEN (SELECT total FROM summary_sys) > 30 THEN '    -- Additional entries exist; query DBA_SYS_PRIVS for full list.' || CHR(10) ELSE '' END
    ELSE
      '  Status : OK'
  END
) || CHR(10)
FROM summary_sys;

WITH role_privs AS (
  SELECT rp.GRANTEE, rp.GRANTED_ROLE
  FROM DBA_ROLE_PRIVS rp
  LEFT JOIN DBA_USERS u ON u.USERNAME = rp.GRANTEE
  LEFT JOIN DBA_ROLES gr ON gr.ROLE = rp.GRANTEE
  LEFT JOIN DBA_ROLES granted ON granted.ROLE = rp.GRANTED_ROLE
  WHERE NVL(u.ORACLE_MAINTAINED, NVL(gr.ORACLE_MAINTAINED, 'N')) = 'N'
    AND NVL(granted.ORACLE_MAINTAINED, 'N') = 'N'
    AND rp.GRANTEE NOT LIKE 'C##%'
    AND rp.GRANTED_ROLE IN ('DBA','SYSDBA','SYSOPER','EXP_FULL_DATABASE','IMP_FULL_DATABASE',
                            'DELETE_CATALOG_ROLE','EXECUTE_CATALOG_ROLE','SELECT_CATALOG_ROLE')
), summary_role AS (
  SELECT COUNT(*) AS total FROM role_privs
), sample_role AS (
  SELECT * FROM role_privs WHERE ROWNUM <= 30
)
SELECT (
  '[4.4] Excessive Role Assignments' || CHR(10) ||
  CASE
    WHEN (SELECT total FROM summary_role) > 0 THEN
      '  Issue  : ' || (SELECT total FROM summary_role) || ' elevated role grants detected' || CHR(10) ||
      '  Action :' || CHR(10) ||
      NVL((SELECT LISTAGG('    REVOKE ' || GRANTED_ROLE || ' FROM ' || GRANTEE || ';', CHR(10))
             WITHIN GROUP (ORDER BY GRANTEE, GRANTED_ROLE) FROM sample_role),
          '    -- Review DBA_ROLE_PRIVS for full grant details.') || CHR(10) ||
      CASE WHEN (SELECT total FROM summary_role) > 30 THEN '    -- Additional entries exist; query DBA_ROLE_PRIVS for full list.' || CHR(10) ELSE '' END
    ELSE
      '  Status : OK'
  END
) || CHR(10)
FROM summary_role;

WITH table_privs AS (
  SELECT tp.GRANTEE, tp.OWNER, tp.TABLE_NAME, tp.PRIVILEGE
  FROM DBA_TAB_PRIVS tp
  LEFT JOIN DBA_USERS u ON u.USERNAME = tp.GRANTEE
  LEFT JOIN DBA_ROLES r ON r.ROLE = tp.GRANTEE
  WHERE tp.OWNER = 'SYS'
    AND tp.TABLE_NAME IN ('USER$','LINK$','USER_HISTORY$','PROXY_DATA$','UNDO$','USER$MIG')
    AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
    AND tp.GRANTEE NOT LIKE 'C##%'
), summary_tab AS (
  SELECT COUNT(*) AS total FROM table_privs
), sample_tab AS (
  SELECT * FROM table_privs WHERE ROWNUM <= 30
)
SELECT (
  '[4.5] Sensitive Table Access' || CHR(10) ||
  CASE
    WHEN (SELECT total FROM summary_tab) > 0 THEN
      '  Issue  : ' || (SELECT total FROM summary_tab) || ' grant(s) against core data dictionary tables' || CHR(10) ||
      '  Action :' || CHR(10) ||
      NVL((SELECT LISTAGG('    REVOKE ' || PRIVILEGE || ' ON ' || OWNER || '.' || TABLE_NAME || ' FROM ' || GRANTEE || ';', CHR(10))
             WITHIN GROUP (ORDER BY GRANTEE, TABLE_NAME) FROM sample_tab),
          '    -- Review DBA_TAB_PRIVS for complete privilege details.') || CHR(10) ||
      CASE WHEN (SELECT total FROM summary_tab) > 30 THEN '    -- Additional entries exist; query DBA_TAB_PRIVS for full list.' || CHR(10) ELSE '' END
    ELSE
      '  Status : OK'
  END
) || CHR(10)
FROM summary_tab;

WITH cdb_info AS (
  SELECT NVL(CDB, 'NO') AS cdb_mode FROM V$DATABASE WHERE ROWNUM = 1
), exempt_priv AS (
  SELECT sp.GRANTEE
  FROM DBA_SYS_PRIVS sp
  LEFT JOIN DBA_USERS u ON u.USERNAME = sp.GRANTEE
  LEFT JOIN DBA_ROLES r ON r.ROLE = sp.GRANTEE
  WHERE sp.PRIVILEGE = 'EXEMPT ACCESS POLICY'
    AND NVL(u.ORACLE_MAINTAINED, NVL(r.ORACLE_MAINTAINED, 'N')) = 'N'
), summary_exempt AS (
  SELECT COUNT(*) AS total FROM exempt_priv
), sample_exempt AS (
  SELECT ep.GRANTEE, ci.cdb_mode
  FROM exempt_priv ep CROSS JOIN cdb_info ci
  WHERE ROWNUM <= 50
)
SELECT (
  '[4.6] EXEMPT ACCESS POLICY' || CHR(10) ||
  CASE
    WHEN (SELECT total FROM summary_exempt) > 0 THEN
      '  Issue  : ' || (SELECT total FROM summary_exempt) || ' grantee(s) bypass row-level security' || CHR(10) ||
      '  Action :' || CHR(10) ||
      NVL((SELECT LISTAGG('    REVOKE EXEMPT ACCESS POLICY FROM ' || GRANTEE ||
              CASE WHEN cdb_mode = 'YES' THEN ' CONTAINER=ALL;' ELSE ';' END, CHR(10))
             WITHIN GROUP (ORDER BY GRANTEE) FROM sample_exempt),
          '    -- Review DBA_SYS_PRIVS for EXEMPT ACCESS POLICY assignments.') || CHR(10) ||
      CASE WHEN (SELECT total FROM summary_exempt) > 50 THEN '    -- Additional entries exist; query DBA_SYS_PRIVS for full list.' || CHR(10) ELSE '' END
    ELSE
      '  Status : OK'
  END
) || CHR(10)
FROM summary_exempt;

PROMPT
PROMPT [5] Audit & Logging Policies
PROMPT   Enable traditional or unified auditing to capture privileged activity.

SELECT (
  '[5.1] Traditional Auditing (11g)' || CHR(10) ||
  CASE
    WHEN (SELECT version FROM V$INSTANCE) LIKE '11.%' THEN
      '  Action :' || CHR(10) ||
      '    AUDIT ALTER USER BY ACCESS;' || CHR(10) ||
      '    AUDIT CREATE USER BY ACCESS;' || CHR(10) ||
      '    AUDIT DROP USER BY ACCESS;' || CHR(10) ||
      '    AUDIT ROLE BY ACCESS;' || CHR(10) ||
      '    AUDIT SYSTEM PRIVILEGE BY ACCESS;' || CHR(10) ||
      '    AUDIT PROFILE BY ACCESS;' || CHR(10) ||
      '    AUDIT PUBLIC SYNONYM BY ACCESS;' || CHR(10) ||
      '    AUDIT SYNONYM BY ACCESS;' || CHR(10) ||
      '    AUDIT DATABASE LINK BY ACCESS;' || CHR(10) ||
      '    AUDIT DIRECTORY BY ACCESS;' || CHR(10) ||
      '    AUDIT ALL ON SYS.AUD$ BY ACCESS;'
    ELSE
      '  Status : Not applicable to version ' || (SELECT version FROM V$INSTANCE)
  END
) || CHR(10)
FROM DUAL;

SELECT (
  '[5.2] Unified Auditing (12c+)' || CHR(10) ||
  CASE
    WHEN (SELECT TO_NUMBER(SUBSTR(version,1,2)) FROM V$INSTANCE) >= 12 THEN
      '  Action :' || CHR(10) ||
      '    CREATE AUDIT POLICY cis_user_mgmt_policy ACTIONS CREATE USER, ALTER USER, DROP USER;' || CHR(10) ||
      '    AUDIT POLICY cis_user_mgmt_policy;' || CHR(10) ||
      '    CREATE AUDIT POLICY cis_role_mgmt_policy ACTIONS CREATE ROLE, ALTER ROLE, DROP ROLE, GRANT, REVOKE;' || CHR(10) ||
      '    AUDIT POLICY cis_role_mgmt_policy;' || CHR(10) ||
      '    CREATE AUDIT POLICY cis_profile_policy ACTIONS CREATE PROFILE, ALTER PROFILE, DROP PROFILE;' || CHR(10) ||
      '    AUDIT POLICY cis_profile_policy;' || CHR(10) ||
      '    CREATE AUDIT POLICY cis_synonym_policy ACTIONS CREATE SYNONYM, DROP SYNONYM;' || CHR(10) ||
      '    AUDIT POLICY cis_synonym_policy;' || CHR(10) ||
      '    CREATE AUDIT POLICY cis_dblink_policy ACTIONS CREATE DATABASE LINK, ALTER DATABASE LINK, DROP DATABASE LINK;' || CHR(10) ||
      '    AUDIT POLICY cis_dblink_policy;'
    ELSE
      '  Status : Not applicable to version ' || (SELECT version FROM V$INSTANCE)
  END
) || CHR(10)
FROM DUAL;

WITH restart_params AS (
  SELECT LOWER(NAME) AS name
  FROM V$PARAMETER
  WHERE (UPPER(NAME) = 'AUDIT_SYS_OPERATIONS' AND UPPER(VALUE) != 'TRUE')
     OR (UPPER(NAME) = 'REMOTE_OS_AUTHENT' AND UPPER(VALUE) != 'FALSE')
     OR (UPPER(NAME) = 'REMOTE_LOGIN_PASSWORDFILE' AND UPPER(VALUE) != 'NONE')
     OR (UPPER(NAME) = 'REMOTE_OS_ROLES' AND UPPER(VALUE) != 'FALSE')
     OR (UPPER(NAME) = 'SQL92_SECURITY' AND UPPER(VALUE) != 'TRUE')
     OR (UPPER(NAME) = 'O7_DICTIONARY_ACCESSIBILITY' AND UPPER(VALUE) != 'FALSE')
     OR (UPPER(NAME) = 'OS_ROLES' AND UPPER(VALUE) != 'FALSE')
), summary_restart AS (
  SELECT COUNT(*) AS total FROM restart_params
), list_restart AS (
  SELECT LISTAGG('    ' || name, CHR(10)) WITHIN GROUP (ORDER BY name) AS pretty,
         LISTAGG(''' || name || ''', ', ') WITHIN GROUP (ORDER BY name) AS csv
  FROM restart_params
)
SELECT (
  '[5.3] Restart Requirements' || CHR(10) ||
  CASE
    WHEN (SELECT total FROM summary_restart) > 0 THEN
      '  Action : Restart database after applying parameter changes to:' || CHR(10) ||
      (SELECT pretty FROM list_restart) || CHR(10) ||
      '    -- Sequence: SHUTDOWN IMMEDIATE; STARTUP;' || CHR(10) ||
      '    -- Verification: SELECT name, value FROM v$parameter WHERE name IN (' || (SELECT csv FROM list_restart) || ');'
    ELSE
      '  Status : No restart-required parameter changes detected.'
  END
) || CHR(10)
FROM summary_restart;

PROMPT
PROMPT [6] Post-Remediation Checklist
PROMPT   1. SHUTDOWN IMMEDIATE / STARTUP (if SPFILE parameters changed)
PROMPT   2. Validate parameter values with `SELECT name, value FROM v$parameter ...`
PROMPT   3. Retest application functionality
PROMPT   4. Update security documentation and change records
PROMPT   5. Schedule a follow-up CIS audit to confirm compliance

PROMPT [7] Multitenant Coverage
SET DEFINE ON
SELECT (
  CASE
    WHEN '&is_multitenant' = 'YES' THEN
      '  Run the script from CDB$ROOT for system controls and in each open PDB for database-level controls.' || CHR(10) ||
      CASE WHEN '&current_container' = 'CDB$ROOT' THEN
        '  Current run covers: CDB root. Remaining scope: each open PDB.'
      ELSE
        '  Current run covers: PDB ' || '&container_name' || '. Re-run from CDB$ROOT for system scope.'
      END
    ELSE
      '  Not a multitenant database; single execution covers all controls.'
  END
) || CHR(10)
FROM DUAL;
SET DEFINE OFF

PROMPT
PROMPT ============================================================================
PROMPT                    END OF REMEDIATION COMMANDS
PROMPT ============================================================================

-- Restore SQL*Plus settings
SET FEEDBACK ON
SET HEADING ON
SET PAGESIZE 24
SET LINESIZE 80

PROMPT
PROMPT ============================================================
PROMPT          CIS Oracle Database Audit Report Generated
PROMPT ============================================================
SET DEFINE ON
PROMPT Output file: CIS_&hostname._&instance_name..html
SET DEFINE OFF
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
