# Oracle Database CIS Benchmark Audit Tool

A comprehensive Oracle Database security audit tool based on the Center for Internet Security (CIS) benchmarks. This tool automatically detects your Oracle Database version and applies the appropriate CIS benchmark checks for Oracle 11g R2, 12c, 18c, and 19c.

## 🚀 Features

- **Multi-Version Support**: Automatically detects and adapts to Oracle Database versions 11g R2 through 19c
- **CIS Compliance**: Based on official CIS Oracle Database Benchmarks
- **HTML Report Generation**: Creates professional, detailed HTML audit reports
- **Comprehensive Coverage**: Audits 100+ security controls across 5 major categories
- **Dynamic Remediation**: Provides specific SQL commands for fixing identified issues
- **Zero Configuration**: Works out-of-the-box with any Oracle Database connection
- **Built-in Privilege Verification**: Automatically checks permissions before starting the audit

## 📋 Supported Oracle Versions & CIS Benchmarks

| Oracle Version | CIS Benchmark Version | Status |
|---|---|---|
| Oracle Database 11g R2 | v2.2.0 | ✅ Supported |
| Oracle Database 12c | v2.0.0/v3.0.0 | ✅ Supported |
| Oracle Database 18c | v1.0.0/v1.1.0 | ✅ Supported |
| Oracle Database 19c | v1.0.0/v1.2.0 | ✅ Supported |
| Oracle Database 23ai | v1.1.0 | ✅ Supported |

## 🔍 Audit Categories

The tool performs comprehensive security checks across these CIS benchmark sections:

1. **Database Installation and Patching Requirements**
   - Version compliance
   - Patch level verification
   - Installation security settings

2. **Oracle Parameter Settings**
   - 25+ critical database parameters
   - Security-related initialization parameters
   - Network and authentication settings

3. **Connection and Login Restrictions**
   - Authentication mechanisms
   - Password policies
   - Connection limits and timeouts

4. **User Access and Authorization Restrictions**
   - User account management
   - Privilege assignments
   - Role-based access controls

5. **Audit and Logging Policies**
   - Audit trail configuration
   - Security event logging
   - Compliance monitoring

## 🛠️ Prerequisites

- Oracle Database (11g R2, 12c, 18c, 19c, or 23ai)
- Oracle SQL*Plus client
- Database administrator privileges to create the audit user and role
- Database user with appropriate privileges (see setup instructions below)

## 📦 Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd oracle
   ```

2. **Set up database permissions** (see Database Setup section below)

3. **Verify SQL*Plus connectivity:**
   ```bash
   sqlplus username/password@database
   ```

## 🔐 Database Setup

The CIS audit script requires specific database permissions to access all security-related views and tables. Choose the appropriate setup based on your Oracle Database architecture:

### Non-Multitenant Database (11g, 12c Non-CDB)

Connect as a privileged user (SYS, SYSTEM, or DBA role) and execute:

```sql
-- Create the audit role
CREATE ROLE CISSCANROLE;

-- Grant necessary system privileges
GRANT CREATE SESSION TO CISSCANROLE;

-- Grant specific view privileges
GRANT SELECT ON V_$PARAMETER TO CISSCANROLE;
GRANT SELECT ON DBA_TAB_PRIVS TO CISSCANROLE;
GRANT SELECT ON DBA_TABLES TO CISSCANROLE;
GRANT SELECT ON DBA_PROFILES TO CISSCANROLE;
GRANT SELECT ON DBA_SYS_PRIVS TO CISSCANROLE;
GRANT SELECT ON DBA_STMT_AUDIT_OPTS TO CISSCANROLE;
GRANT SELECT ON DBA_ROLE_PRIVS TO CISSCANROLE;
GRANT SELECT ON DBA_OBJ_AUDIT_OPTS TO CISSCANROLE;
GRANT SELECT ON DBA_PRIV_AUDIT_OPTS TO CISSCANROLE;
GRANT SELECT ON DBA_PROXIES TO CISSCANROLE;
GRANT SELECT ON DBA_USERS TO CISSCANROLE;
GRANT SELECT ON DBA_USERS_WITH_DEFPWD TO CISSCANROLE;
GRANT SELECT ON DBA_DB_LINKS TO CISSCANROLE;
GRANT SELECT ON DBA_ROLES TO CISSCANROLE;
GRANT SELECT ON V_$INSTANCE TO CISSCANROLE;
GRANT SELECT ON V_$DATABASE TO CISSCANROLE;
GRANT SELECT ON V_$PDBS TO CISSCANROLE;
GRANT SELECT ON V_$SYSTEM_PARAMETER TO CISSCANROLE;
GRANT SELECT ON AUDIT_UNIFIED_ENABLED_POLICIES TO CISSCANROLE;
GRANT SELECT ON DBA_AUDIT_POLICIES TO CISSCANROLE;
GRANT AUDIT_VIEWER TO CISSCANROLE; -- For 12c+ audit features

-- Create the audit user
CREATE USER CISSCAN IDENTIFIED BY <strong_password>;
GRANT CISSCANROLE TO CISSCAN;
```
Ignore ERRORS if running the grants against a 11g database.

### Multitenant Database (12c+ CDB/PDB)

Connect to the **CDB root container** as a privileged user (SYS, SYSTEM, or C##DBA role) and execute:

```sql
-- Create the common audit role (available in all containers)
CREATE ROLE C##CISSCANROLE CONTAINER=ALL;

-- Grant necessary system privileges
GRANT CREATE SESSION TO C##CISSCANROLE CONTAINER=ALL;

-- Grant specific view privileges for CDB-wide access
GRANT SELECT ON V_$PARAMETER TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_TAB_PRIVS TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_TABLES TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_PROFILES TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_SYS_PRIVS TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_STMT_AUDIT_OPTS TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_ROLE_PRIVS TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_OBJ_AUDIT_OPTS TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_PRIV_AUDIT_OPTS TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_PROXIES TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_USERS TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_ROLES TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_USERS_WITH_DEFPWD TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON CDB_DB_LINKS TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON V_$INSTANCE TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON V_$DATABASE TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON V_$PDBS TO C##CISSCANROLE CONTAINER=ALL;
GRANT SELECT ON V_$SYSTEM_PARAMETER TO C##CISSCANROLE CONTAINER=ALL;
GRANT AUDIT_VIEWER TO C##CISSCANROLE CONTAINER=ALL;

-- Create the common audit user
CREATE USER C##CISSCAN IDENTIFIED BY <strong_password> CONTAINER=ALL;
GRANT C##CISSCANROLE TO C##CISSCAN CONTAINER=ALL;

-- Enable access to data from all containers
ALTER USER C##CISSCAN SET CONTAINER_DATA=ALL CONTAINER=CURRENT;
```

### Alternative Setup (Using DBA Role)

For simpler setup (with broader privileges), you can use the DBA role:

```sql
-- Non-multitenant
CREATE USER CISSCAN IDENTIFIED BY <strong_password>;
GRANT DBA TO CISSCAN;

-- Multitenant
CREATE USER C##CISSCAN IDENTIFIED BY <strong_password> CONTAINER=ALL;
GRANT C##DBA TO C##CISSCAN CONTAINER=ALL;
ALTER USER C##CISSCAN SET CONTAINER_DATA=ALL CONTAINER=CURRENT;
```

### Verification

After setup, verify the permissions:

```sql
-- Connect as the audit user
sqlplus cisscan/password@database
-- Or for multitenant: sqlplus c##cisscan/password@database

-- Test critical view access
SELECT COUNT(*) FROM DBA_USERS_WITH_DEFPWD;
SELECT COUNT(*) FROM DBA_TAB_PRIVS WHERE ROWNUM <= 5;
SELECT COUNT(*) FROM V$PARAMETER WHERE ROWNUM <= 5;
```

## 🚀 Usage

### Basic Usage

```bash
# Non-multitenant database
sqlplus cisscan/password@database @cis_benchmark_11g_through_19c.sql

# Multitenant database (from CDB root or specific PDB)
sqlplus c##cisscan/password@database @cis_benchmark_11g_through_19c.sql
```

### Privilege Verification

The script automatically verifies all required privileges before starting the audit:

- **✅ Success**: All required privileges available - audit proceeds normally
- **⚠️ Warnings**: Some optional features unavailable - audit continues with limited functionality  
- **❌ Critical Failure**: Missing essential privileges - audit stops with detailed setup instructions

If privilege issues are detected, the script provides specific commands to fix them based on your database architecture (multitenant vs non-multitenant).

### Example Output

The script generates two types of output:

1. **HTML Report**: `CIS_<hostname>_<instance_name>.html`
   - Professional web-based report
   - Color-coded results (Pass/Fail/Warning)
   - Detailed remediation steps
   - Executive summary

2. **Console Summary**:
   ```
   ============================================================
            CIS Oracle Database Audit Report Generated
   ============================================================
   Output file: CIS_hostname_ORCL.html
   
   Report includes comprehensive checks for:
   - Database installation and patching
   - Oracle parameter settings  
   - Connection and login restrictions
   - User access and authorization restrictions
   - Audit and logging policies
   ============================================================
   ```

## 📊 Report Features

### Visual Indicators
- 🟢 **PASS**: Compliant with CIS benchmark
- 🔴 **FAIL**: Non-compliant, immediate attention required
- 🟡 **WARNING**: Minor issues or recommendations
- ⚪ **MANUAL**: Requires manual verification

### Report Sections
- **Executive Summary**: High-level compliance overview
- **Database Information**: Environment details
- **Detailed Findings**: Control-by-control analysis
- **Remediation Guide**: Step-by-step fix instructions
- **Risk Assessment**: Priority recommendations

## 🔧 Configuration

The script is self-configuring but you can customize:

### SQL*Plus Settings
Modify the initial settings block for custom formatting:
```sql
SET PAGESIZE 0
SET LINESIZE 4000
SET HEADING OFF
SET FEEDBACK OFF
```

### Report Styling
Customize the HTML CSS section for corporate branding or different color schemes.

## 📁 Project Structure

```
oracle/
├── README.md                                    # This file
├── cis_benchmark_11g_through_19c.sql          # Main audit script
└── docs/                                        # CIS Benchmark PDFs
    ├── CIS_Oracle_Database_11g_R2_Benchmark_v2.2.0_ARCHIVE.pdf
    ├── CIS_Oracle_Database_12c_Benchmark_v3.0.0_ARCHIVE.pdf
    ├── CIS_Oracle_Database_18c_Benchmark_v1.1.0_ARCHIVE.pdf
    ├── CIS_Oracle_Database_19c_Benchmark_v1.2.0.pdf
    └── CIS_Oracle_Database_23ai_Benchmark_v1.1.0.pdf
```

## 🔒 Security Considerations

### Database Privileges
- **Use the dedicated CISSCAN user** created with the setup instructions
- **Never use SYS or SYSTEM** accounts for routine auditing
- **Rotate audit user passwords regularly** (recommend 90 days)
- **Lock the audit user** when not actively performing audits:
  ```sql
  ALTER USER CISSCAN ACCOUNT LOCK;   -- Lock when not in use
  ALTER USER CISSCAN ACCOUNT UNLOCK; -- Unlock for auditing
  ```
- **Monitor audit user activity** through database audit logs
- **Remove unnecessary privileges** if using alternative setup methods

### Network Security
- Run audits from secure, authorized systems
- Use encrypted connections (SSL/TLS) when possible
- Limit network access to audit systems

### Report Handling
- Generated HTML reports may contain sensitive information
- Store reports in secure locations
- Implement appropriate access controls
- Consider report encryption for highly sensitive environments

## 🚨 Troubleshooting

### Common Issues

**"Insufficient Privileges" Error:**
```sql
-- Ensure you followed the Database Setup section properly
-- For missing specific views, grant explicitly:
GRANT SELECT ON DBA_USERS_WITH_DEFPWD TO cisscanrole;
GRANT SELECT ON V_$PARAMETER TO cisscanrole;
GRANT AUDIT_VIEWER TO cisscanrole; -- For 12c+ audit features
```

**"Table or View Does Not Exist" (DBA_USERS_WITH_DEFPWD):**
```sql
-- This view requires specific privileges beyond SELECT ANY DICTIONARY
-- Connect as SYS or SYSTEM and grant:
GRANT SELECT ON SYS.DBA_USERS_WITH_DEFPWD TO cisscanrole;
-- Or use the complete setup from Database Setup section
```

**"Table or View Does Not Exist" (AUDIT_UNIFIED_ENABLED_POLICIES):**
```sql
-- For 12c+ unified auditing features
GRANT AUDIT_VIEWER TO cisscanrole;
-- Or connect as privileged user for full audit access
```

**Script Hangs or Errors:**
- Check SQL*Plus version compatibility
- Verify database connectivity
- Review any custom modifications

### Debug Mode
Enable debug output by setting:
```sql
SET ECHO ON
SET TERMOUT ON
```

## 🤝 Contributing

Contributions are welcome! Please consider:

1. **New Oracle Versions**: Add support for newer Oracle releases
2. **Additional Checks**: Implement additional CIS controls
3. **Report Enhancements**: Improve HTML formatting or add features
4. **Bug Fixes**: Address any identified issues

### Development Setup
1. Fork the repository
2. Create a test Oracle environment
3. Test changes across multiple Oracle versions
4. Submit pull requests with detailed descriptions

## 📚 References

- [CIS Oracle Database Benchmarks](https://www.cisecurity.org/benchmark/oracle_database)
- [Oracle Database Security Guide](https://docs.oracle.com/en/database/oracle/oracle-database/)
- [Oracle Database Reference](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/)

## 📄 License

This project is provided as-is for educational and professional use. Please ensure compliance with:
- CIS Benchmark licensing terms
- Oracle Database licensing requirements
- Your organization's security and compliance policies

## ⚠️ Disclaimer

- This tool is based on CIS Oracle Database Benchmarks but may not cover all controls
- Some checks require manual verification of configuration files or additional privileges
- Always test in development environments before production use
- Results should be reviewed by qualified database security professionals
- Consider commercial database security tools for comprehensive enterprise assessments

## 🏷️ Version History

- **v1.0**: Initial release with support for Oracle 11g R2 through 19c
- **Latest**: Enhanced multi-version support and improved HTML reporting

---

**Author**: Alexis Boscher  
**Created**: 2025  
**Last Updated**: 2025
