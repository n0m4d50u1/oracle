#!/usr/bin/env python3
"""
Script pour corriger automatiquement les sections 5.15 à 5.22 du script CIS
en appliquant la correction CTE pour les erreurs ORA-00937
"""

import re

def fix_cis_sections():
    """Corrige toutes les sections restantes avec le pattern CTE"""
    
    # Lire le fichier
    with open('cis_benchmark_11g_through_19c.sql', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Mapping des sections à corriger
    sections_to_fix = [
        {
            'section': '5.15',
            'audit_option': 'GRANT ANY OBJECT PRIVILEGE',
            'table': 'DBA_PRIV_AUDIT_OPTS',
            'column': 'PRIVILEGE',
            'remediation': 'AUDIT GRANT ANY OBJECT PRIVILEGE;'
        },
        {
            'section': '5.16', 
            'audit_option': 'ALTER SYSTEM',
            'table': 'DBA_STMT_AUDIT_OPTS',
            'column': 'AUDIT_OPTION',
            'remediation': 'AUDIT ALTER SYSTEM;'
        },
        {
            'section': '5.17',
            'audit_option': 'ALTER DATABASE',
            'table': 'DBA_STMT_AUDIT_OPTS', 
            'column': 'AUDIT_OPTION',
            'remediation': 'AUDIT ALTER DATABASE;'
        },
        {
            'section': '5.18',
            'audit_option': 'ALTER USER',
            'table': 'DBA_STMT_AUDIT_OPTS',
            'column': 'AUDIT_OPTION', 
            'remediation': 'AUDIT ALTER USER;'
        },
        {
            'section': '5.19',
            'audit_option': 'CREATE USER',
            'table': 'DBA_STMT_AUDIT_OPTS',
            'column': 'AUDIT_OPTION',
            'remediation': 'AUDIT CREATE USER;'
        },
        {
            'section': '5.20',
            'audit_option': 'DROP USER',
            'table': 'DBA_STMT_AUDIT_OPTS',
            'column': 'AUDIT_OPTION',
            'remediation': 'AUDIT DROP USER;'
        },
        {
            'section': '5.21', 
            'audit_option': 'CREATE ROLE',
            'table': 'DBA_STMT_AUDIT_OPTS',
            'column': 'AUDIT_OPTION',
            'remediation': 'AUDIT CREATE ROLE;'
        },
        {
            'section': '5.22',
            'audit_option': 'DROP ROLE', 
            'table': 'DBA_STMT_AUDIT_OPTS',
            'column': 'AUDIT_OPTION',
            'remediation': 'AUDIT DROP ROLE;'
        }
    ]
    
    for section_info in sections_to_fix:
        section = section_info['section']
        audit_option = section_info['audit_option']
        table = section_info['table']
        column = section_info['column']
        remediation = section_info['remediation']
        
        # Construire le pattern regex pour trouver la section problématique
        # Pattern pour trouver SELECT avec COUNT(*) et CASE avec CDB
        pattern = f"(-- {re.escape(section)} Enable '{re.escape(audit_option)}' Audit Option - Oracle 12c\\+ Non-multitenant OR when running from PDB\\n)" \
                 f"SELECT '<tr class=\"' \\|\\|\\n" \
                 f"  CASE \\n" \
                 f"    WHEN COUNT\\(\\*\\) > 0 THEN 'pass'\\n" \
                 f"    ELSE 'fail'\\n" \
                 f"  END \\|\\| '\">' \\|\\|\\n" \
                 f"  '<td>{re.escape(section)}</td>' \\|\\|\\n" \
                 f"  '<td>Enable {re.escape(audit_option)} Audit Option \\(Scored\\) - ' \\|\\| \\n" \
                 f"    CASE \\n" \
                 f"      WHEN \\(SELECT CDB FROM V\\$DATABASE\\) = 'YES' AND \\(SELECT SYS_CONTEXT\\('USERENV', 'CON_NAME'\\) FROM DUAL\\) != 'CDB\\$ROOT' \\n" \
                 f"      THEN '12c\\+ PDB \\(' \\|\\| \\(SELECT SYS_CONTEXT\\('USERENV', 'CON_NAME'\\) FROM DUAL\\) \\|\\| '\\)'\\n" \
                 f"      ELSE '12c\\+ Non-MT'\\n" \
                 f"    END \\|\\| '</td>' \\|\\|\\n" \
                 f"(.*?)\\n" \
                 f"FROM {re.escape(table)}\\n" \
                 f"(.*?)\\n" \
                 f"\\);"
        
        # Pour simplifier, utilisons un approach différent
        # Cherchons le pattern spécifique à chaque section
        
        old_pattern = f"-- {section} Enable '{audit_option}' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB"
        
        # Trouver la position du pattern
        start_pos = content.find(old_pattern)
        if start_pos == -1:
            print(f"Section {section} pattern not found")
            continue
            
        # Trouver la fin de cette section (jusqu'au prochain ';')
        section_start = start_pos
        brace_count = 0
        pos = section_start
        section_end = -1
        
        # Trouver la fin de la requête SQL
        while pos < len(content):
            char = content[pos]
            if char == '(':
                brace_count += 1
            elif char == ')':
                brace_count -= 1
            elif char == ';' and brace_count <= 0:
                section_end = pos + 1
                break
            pos += 1
        
        if section_end == -1:
            print(f"Section {section} end not found")
            continue
        
        # Extraire la section complète
        old_section = content[section_start:section_end]
        
        # Construire la nouvelle section avec CTE
        new_section = f"""-- {section} Enable '{audit_option}' Audit Option - Oracle 12c+ Non-multitenant OR when running from PDB
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
  '<td>{section}</td>' ||
  '<td>Enable {audit_option} Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  '<td>' || CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END || '</td>' ||
  '<td>' || 
    CASE WHEN COUNT(*) > 0 THEN"""
        
        if table == 'DBA_PRIV_AUDIT_OPTS':
            new_section += f"""
      LISTAGG(PRIVILEGE || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY PRIVILEGE)
    ELSE '{audit_option} audit not enabled'
    END || '</td>' ||
  '<td>{audit_option} audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">{remediation}</td>' ||
  '</tr>'
FROM {table}, CONTAINER_INFO CI
WHERE PRIVILEGE='{audit_option}'"""
        else:
            new_section += f"""
      LISTAGG(AUDIT_OPTION || ' (SUCCESS:' || SUCCESS || ', FAILURE:' || FAILURE || ')', ', ') WITHIN GROUP (ORDER BY AUDIT_OPTION)
    ELSE '{audit_option} audit not enabled'
    END || '</td>' ||
  '<td>{audit_option} audit enabled (SUCCESS=BY ACCESS, FAILURE=BY ACCESS)</td>' ||
  '<td class="remediation">{remediation}</td>' ||
  '</tr>'
FROM {table}, CONTAINER_INFO CI
WHERE USER_NAME IS NULL 
AND PROXY_NAME IS NULL
AND SUCCESS = 'BY ACCESS' 
AND FAILURE = 'BY ACCESS'
AND AUDIT_OPTION='{audit_option}'"""
        
        new_section += f"""
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
        
        # Remplacer la section
        content = content.replace(old_section, new_section)
        print(f"Fixed section {section}")
    
    # Écrire le fichier modifié
    with open('cis_benchmark_11g_through_19c.sql', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("All remaining sections have been fixed!")

if __name__ == "__main__":
    fix_cis_sections()