#!/usr/bin/env python3
"""
Script to fix ORA-00937 errors in CIS benchmark SQL file
by converting CDB subqueries in SELECT clauses to CTEs
"""

import re
import sys

def fix_cdb_queries_in_file(filename):
    """Fix all CDB queries that cause ORA-00937 errors"""
    
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to match problematic sections
    # Looking for sections with -- 5.X Enable ... Oracle 12c+ Non-multitenant OR when running from PDB
    # that have a SELECT with COUNT() and CDB subqueries in the same SELECT clause
    
    pattern = re.compile(
        r"(-- 5\.\d+ Enable '[^']+' Audit Option - Oracle 12c\+ Non-multitenant OR when running from PDB\n)"
        r"(SELECT '<tr class=\"' \|\|\n"
        r"  CASE \n"
        r"    WHEN COUNT\(\*\) > 0 THEN 'pass'\n"
        r"    ELSE 'fail'\n"
        r"  END \|\| '\">' \|\|\n"
        r"  '<td>5\.\d+</td>' \|\|\n"
        r"  '<td>Enable [^<]+ Audit Option \(Scored\) - ' \|\| \n"
        r"    CASE \n"
        r"      WHEN \(SELECT CDB FROM V\$DATABASE\) = 'YES' AND \(SELECT SYS_CONTEXT\('USERENV', 'CON_NAME'\) FROM DUAL\) != 'CDB\$ROOT' \n"
        r"      THEN '12c\+ PDB \(' \|\| \(SELECT SYS_CONTEXT\('USERENV', 'CON_NAME'\) FROM DUAL\) \|\| '\)'\n"
        r"      ELSE '12c\+ Non-MT'\n"
        r"    END \|\| '</td>' \|\|\n"
        r"  '<td>' \|\| CASE WHEN COUNT\(\*\) > 0 THEN 'PASS' ELSE 'FAIL' END \|\| '</td>' \|\|\n"
        r"  '<td>' \|\| \n"
        r"    CASE WHEN COUNT\(\*\) > 0 THEN \n"
        r"      LISTAGG\(AUDIT_OPTION \|\| ' \(SUCCESS:' \|\| SUCCESS \|\| ', FAILURE:' \|\| FAILURE \|\| '\)', ', '\) WITHIN GROUP \(ORDER BY AUDIT_OPTION\)\n"
        r"    ELSE '[^']+audit not enabled'\n"
        r"    END \|\| '</td>' \|\|\n"
        r"  '<td>[^<]+audit enabled \(SUCCESS=BY ACCESS, FAILURE=BY ACCESS\)</td>' \|\|\n"
        r"  '<td class=\"remediation\">AUDIT [^;]+;</td>' \|\|\n"
        r"  '</tr>'\n"
        r"FROM DBA_STMT_AUDIT_OPTS\n"
        r"WHERE USER_NAME IS NULL \n"
        r"AND PROXY_NAME IS NULL\n"
        r"AND SUCCESS = 'BY ACCESS' \n"
        r"AND FAILURE = 'BY ACCESS'\n"
        r"AND AUDIT_OPTION='[^']+'\n"
        r"AND TO_NUMBER\(SUBSTR\(\(SELECT VERSION FROM V\$INSTANCE\), 1, 2\)\) >= 12\n"
        r"AND \(\n"
        r"  -- Non-multitenant database\n"
        r"  NOT EXISTS \(SELECT 1 FROM V\$DATABASE WHERE CDB = 'YES'\)\n"
        r"  OR \n"
        r"  -- Running from PDB \(not CDB\$ROOT\)\n"
        r"  \(EXISTS \(SELECT 1 FROM V\$DATABASE WHERE CDB = 'YES'\) AND \n"
        r"   \(SELECT SYS_CONTEXT\('USERENV', 'CON_NAME'\) FROM DUAL\) != 'CDB\$ROOT'\)\n"
        r"\);)",
        re.MULTILINE | re.DOTALL
    )
    
    def replace_function(match):
        """Replace the problematic pattern with CTE version"""
        comment = match.group(1)
        
        # Extract the section number and audit option
        section_match = re.search(r"-- (5\.\d+) Enable '([^']+)'", comment)
        if not section_match:
            return match.group(0)
        
        section_num = section_match.group(1)
        audit_option = section_match.group(2)
        
        # Generate the replacement with CTE
        replacement = f"""{comment}WITH CONTAINER_INFO AS (
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
  '<td>{section_num}</td>' ||
  '<td>Enable {audit_option} Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN 
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE '{audit_option} audit not enabled'
    END || '</td>' ||
  '<td>{audit_option} audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">AUDIT {audit_option};</td>' ||
  '</tr>'
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='{audit_option}'
AND TO_NUMBER(SUBSTR((SELECT VERSION FROM V$INSTANCE), 1, 2)) >= 12
AND (
  -- Non-multitenant database
  NOT EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES')
  OR 
  -- Running from PDB (not CDB$ROOT)
  (EXISTS (SELECT 1 FROM V$DATABASE WHERE CDB = 'YES') AND 
   (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT')
)
GROUP BY CI.container_desc;"""
        
        return replacement
    
    # Apply the replacements
    modified_content = pattern.sub(replace_function, content)
    
    # Write back to file
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(modified_content)
    
    print(f"Fixed ORA-00937 errors in {filename}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python fix_ora937_errors.py <sql_file>")
        sys.exit(1)
    
    fix_cdb_queries_in_file(sys.argv[1])