# Oracle Database CIS Benchmark Audit Tool

This repository delivers a self-contained SQL*Plus audit that maps Oracle database hardening posture against the Center for Internet Security (CIS) benchmarks. The script auto-detects the connected database version and tenancy model, runs only applicable controls, and produces a human-friendly HTML report plus a copy/paste remediation plan.

## Key Capabilities

- **Version- and Tenancy-Aware Checks** – Supports Oracle 11g R2, 12c, 18c, 19c, and 23ai. Multi-tenant environments are detected automatically, and CDB/PDB scopes are handled independently. Controls for other versions are skipped instead of reporting false failures.
- **Executive Summary Dashboard** – The HTML report now opens with a dynamic overview that surfaces live counts for default passwords, parameter gaps, privilege issues, and auditing coverage, providing a quick risk snapshot before diving into sections 1–5.
- **Detailed CIS Mapping** – 100+ controls aligned to CIS benchmark categories (installation, parameters, authentication, privileges, auditing) with explanatory remediation text.
- **Actionable Remediation Output** – After the HTML report is spooled (`CIS_<host>_<instance>.html`), the script writes a raw remediation plan to the SQL*Plus session (capturable via `SPOOL` if desired). Entries are grouped by theme with ready-to-run SQL.
- **Pre-flight Privilege Checks** – A PL/SQL verification block stops the audit early if mandatory dictionary views or unified auditing views are not accessible, preventing misleading results.

## Supported Versions & Benchmarks

| Oracle Version | CIS Benchmark Version | Status |
| --- | --- | --- |
| 11g R2 | v2.2.0 | ✅ Supported |
| 12c (Non-CDB & CDB/PDB) | v2.0.0 / v3.0.0 | ✅ Supported |
| 18c | v1.0.0 / v1.1.0 | ✅ Supported |
| 19c | v1.0.0 / v1.2.0 | ✅ Supported |
| 23ai | v1.1.0 | ✅ Supported |

## Prerequisites

- SQL*Plus client with network connectivity to the target database.
- A dedicated audit user with dictionary access (see below) or DBA-equivalent privileges.
- Output directory write access for the generated HTML file.

## Creating the Audit User

### Non-Multitenant (11g, 12c Non-CDB)
```sql
CREATE ROLE cisscanrole;
GRANT CREATE SESSION TO cisscanrole;
GRANT SELECT ON V_$PARAMETER TO cisscanrole;
GRANT SELECT ON DBA_TAB_PRIVS TO cisscanrole;
GRANT SELECT ON DBA_TABLES TO cisscanrole;
GRANT SELECT ON DBA_PROFILES TO cisscanrole;
GRANT SELECT ON DBA_SYS_PRIVS TO cisscanrole;
GRANT SELECT ON DBA_ROLE_PRIVS TO cisscanrole;
GRANT SELECT ON DBA_OBJ_AUDIT_OPTS TO cisscanrole;
GRANT SELECT ON DBA_PRIV_AUDIT_OPTS TO cisscanrole;
GRANT SELECT ON DBA_PROXIES TO cisscanrole;
GRANT SELECT ON DBA_USERS TO cisscanrole;
GRANT SELECT ON DBA_USERS_WITH_DEFPWD TO cisscanrole;
GRANT SELECT ON DBA_DB_LINKS TO cisscanrole;
GRANT SELECT ON DBA_ROLES TO cisscanrole;
GRANT SELECT ON V_$INSTANCE TO cisscanrole;
GRANT SELECT ON V_$DATABASE TO cisscanrole;
GRANT SELECT ON V_$SYSTEM_PARAMETER TO cisscanrole;
GRANT AUDIT_VIEWER TO cisscanrole;

CREATE USER cisscan IDENTIFIED BY <strong_password>;
GRANT cisscanrole TO cisscan;
```

### Multitenant (12c+ CDB/PDB)
```sql
CREATE ROLE C##cisscanrole CONTAINER=ALL;
GRANT CREATE SESSION TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON V_$PARAMETER TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON CDB_TAB_PRIVS TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON CDB_PROFILES TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON CDB_SYS_PRIVS TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON CDB_ROLE_PRIVS TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON CDB_OBJ_AUDIT_OPTS TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON CDB_PRIV_AUDIT_OPTS TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON CDB_USERS TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON CDB_ROLES TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON CDB_USERS_WITH_DEFPWD TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON CDB_DB_LINKS TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON V_$INSTANCE TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON V_$DATABASE TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON V_$PDBS TO C##cisscanrole CONTAINER=ALL;
GRANT SELECT ON V_$SYSTEM_PARAMETER TO C##cisscanrole CONTAINER=ALL;
GRANT AUDIT_VIEWER TO C##cisscanrole CONTAINER=ALL;

CREATE USER C##cisscan IDENTIFIED BY <strong_password> CONTAINER=ALL;
GRANT C##cisscanrole TO C##cisscan CONTAINER=ALL;
ALTER USER C##cisscan SET CONTAINER_DATA=ALL CONTAINER=CURRENT;
```

### Fast Track (Full DBA Role)
```sql
-- Non-CDB
CREATE USER cisscan IDENTIFIED BY <strong_password>;
GRANT DBA TO cisscan;

-- CDB/PDB
CREATE USER C##cisscan IDENTIFIED BY <strong_password> CONTAINER=ALL;
GRANT C##DBA TO C##cisscan CONTAINER=ALL;
ALTER USER C##cisscan SET CONTAINER_DATA=ALL CONTAINER=CURRENT;
```

## Running the Audit

```bash
# Non-CDB example
sqlplus cisscan/<password>@//host/service @cis_benchmark_11g_through_19c.sql

# CDB root (system-wide checks)
sqlplus C##cisscan/<password>@//host/cdb_service @cis_benchmark_11g_through_19c.sql

# Individual PDB (database-specific checks)
sqlplus C##cisscan/<password>@//host/pdb_service @cis_benchmark_11g_through_19c.sql
```

### Output Artifacts

- `CIS_<host>_<instance>.html` – Primary HTML report with:
  - Executive Summary (dynamic metrics and priority actions).
  - Risk drill-down by category and tenancy-aware control tables.
  - Detailed CIS sections 1–5 with pass/fail status, current/expected values, and remediation guidance.
- Console Remediation Plan – SQL*Plus output (redirect via `SPOOL` if desired) containing grouped, copy/paste-ready SQL to close identified gaps. Optional findings (warnings/manual) are clearly labeled.

## How Version Detection Works

The script defines SQL*Plus substitution variables (`&version_num`, `&is_multitenant`, `&is_cdb_root`, etc.) based on `V$INSTANCE` and `V$DATABASE`. Every version-specific control uses these variables to show only the relevant rows, preventing noisy failures from controls that do not apply. Multitenant runs should be executed both from CDB$ROOT and each PDB to obtain complete coverage.

## Validation Tips

- Run the script first as SYS or a DBA role to confirm privileges; once verified, switch to the least-privilege audit user.
- Compare the HTML executive summary counts with your change management records (e.g., default passwords or PUBLIC privileges) to validate accuracy.
- When running in CDB environments, verify `CONTAINER_DATA` is set appropriately so cross-container views return rows.

## Troubleshooting

| Symptom | Likely Cause | Resolution |
| --- | --- | --- |
| `ORA-01031: insufficient privileges` during preflight | Missing grants on `DBA_*` or `CDB_*` views | Re-run the privilege grant script; ensure `AUDIT_VIEWER` is included for 12c+ |
| HTML report missing data tables | SQL*Plus `SET TERMOUT OFF` not honored | Use the provided script without modification and run in a SQL*Plus terminal (not SQL Developer) |
| Controls still show “FAIL” after remediation | Statement requires restart or rerun | Restart the database if SPFILE parameters changed, then re-execute the audit |
| Legacy control rows appear for wrong version | Script not updated | Pull latest changes; version filters rely on substitution variables set near the top of the script |

## Contributing

1. Fork the repository and create a feature branch.
2. Update the SQL script and `README.md` or supporting docs as needed.
3. Run the audit against target versions (CDB root & representative PDB where applicable) and attach relevant output or summaries in your PR.
4. Open a PR describing the change, testing performed, and any new privileges required.

For agent-specific guidance see `AGENTS.md`, `CLAUDE.md`, or `WARP.md` in the root directory.

