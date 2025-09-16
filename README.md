# Oracle Database CIS Benchmark Audit Tool

A comprehensive Oracle Database security audit tool based on the Center for Internet Security (CIS) benchmarks. This tool automatically detects your Oracle Database version and applies the appropriate CIS benchmark checks for Oracle 11g R2, 12c, 18c, and 19c.

## 🚀 Features

- **Multi-Version Support**: Automatically detects and adapts to Oracle Database versions 11g R2 through 19c
- **CIS Compliance**: Based on official CIS Oracle Database Benchmarks
- **HTML Report Generation**: Creates professional, detailed HTML audit reports
- **Comprehensive Coverage**: Audits 100+ security controls across 5 major categories
- **Dynamic Remediation**: Provides specific SQL commands for fixing identified issues
- **Zero Configuration**: Works out-of-the-box with any Oracle Database connection

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
- Database user with appropriate privileges:
  ```sql
  -- Minimum required privileges
  GRANT CONNECT TO <audit_user>;
  GRANT SELECT ANY DICTIONARY TO <audit_user>;
  ```

## 📦 Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd oracle
   ```

2. **Verify SQL*Plus connectivity:**
   ```bash
   sqlplus username/password@database
   ```

## 🚀 Usage

### Basic Usage

```bash
# Connect and run the audit
sqlplus username/password@database @cis_benchmark_11g_through_19c.sql
```

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
- Use dedicated audit user with minimal required privileges
- Avoid using SYS or SYSTEM accounts for auditing
- Consider creating a read-only audit role

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
-- Grant required privileges
GRANT SELECT ANY DICTIONARY TO audit_user;
```

**"Table or View Does Not Exist":**
```sql
-- Verify user can access system views
SELECT * FROM V$VERSION;
SELECT * FROM DBA_USERS WHERE ROWNUM = 1;
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
