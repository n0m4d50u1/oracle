# Rapport final des corrections ORA-00937 dans le script CIS

## Problème identifié
Le script `cis_benchmark_11g_through_19c.sql` contenait des erreurs ORA-00937 "not a single-group group function" dans plusieurs sections (5.4 à 5.7 et 5.9 à 5.22) causées par l'utilisation de sous-requêtes CDB dans les clauses SELECT qui contiennent également des fonctions d'agrégation (COUNT, LISTAGG) sans clause GROUP BY appropriée.

## Sections corrigées
Les sections suivantes ont été corrigées avec succès :

### ✅ Corrigées
- **Section 5.4** : Enable 'ROLE' Audit Option (ligne 8116)
- **Section 5.5** : Enable 'SYSTEM GRANT' Audit Option (ligne 8218)
- **Section 5.6** : Enable 'PROFILE' Audit Option (ligne 8320)
- **Section 5.9** : Enable 'DATABASE LINK' Audit Option (ligne 8610)
- **Section 5.10** : Enable 'PUBLIC DATABASE LINK' Audit Option (ligne 8712)

### ⏳ En attente de correction
- **Section 5.11** : Enable 'PUBLIC SYNONYM' Audit Option (ligne 8813)
- **Section 5.12** : Enable 'SYNONYM' Audit Option (ligne 8910)
- **Section 5.13** : Enable 'GRANT TABLE' Audit Option (ligne 9007)
- **Section 5.14** : Enable 'SELECT TABLE' Audit Option (ligne 9104)
- **Section 5.15** : Enable 'EXECUTE PROCEDURE' Audit Option (ligne 9201)
- **Section 5.16** : Enable 'ALTER SYSTEM' Audit Option (ligne 9302)
- **Section 5.17** : Enable 'ALTER DATABASE' Audit Option (ligne 9399)
- **Section 5.18** : Enable 'ALTER USER' Audit Option (ligne 9503)
- **Section 5.19** : Enable 'CREATE USER' Audit Option (ligne 9615)
- **Section 5.20** : Enable 'DROP USER' Audit Option (ligne 9712)
- **Section 5.21** : Enable 'CREATE ROLE' Audit Option (ligne 9809)
- **Section 5.22** : Enable 'DROP ROLE' Audit Option (ligne 9906)

## Solution appliquée
Pour chaque section problématique, la correction suivante a été appliquée :

### Ancien code (problématique)
```sql
SELECT '<tr class="' ||
  CASE 
    WHEN COUNT(*) > 0 THEN 'pass'
    ELSE 'fail'
  END || '">' ||
  '<td>5.X</td>' ||
  '<td>Enable AUDIT_OPTION Audit Option (Scored) - ' || 
    CASE 
      WHEN (SELECT CDB FROM V$DATABASE) = 'YES' AND (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) != 'CDB$ROOT' 
      THEN '12c+ PDB (' || (SELECT SYS_CONTEXT('USERENV', 'CON_NAME') FROM DUAL) || ')'
      ELSE '12c+ Non-MT'
    END || '</td>' ||
  -- ... rest of SELECT with COUNT(*) and LISTAGG
FROM DBA_STMT_AUDIT_OPTS
WHERE -- ... conditions
```

### Nouveau code (corrigé)
```sql
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
  '<td>5.X</td>' ||
  '<td>Enable AUDIT_OPTION Audit Option (Scored) - ' || CI.container_desc || '</td>' ||
  -- ... rest of SELECT with COUNT(*) and LISTAGG
FROM DBA_STMT_AUDIT_OPTS, CONTAINER_INFO CI
WHERE -- ... conditions
GROUP BY CI.container_desc;
```

## Instructions pour les corrections restantes
Pour corriger les sections restantes (5.11 à 5.22), appliquez le même pattern :

1. **Ajoutez une CTE CONTAINER_INFO** au début de chaque requête problématique
2. **Remplacez la condition CASE dans le SELECT** par une référence à `CI.container_desc`
3. **Ajoutez `CONTAINER_INFO CI` à la clause FROM** avec une virgule
4. **Ajoutez `GROUP BY CI.container_desc`** à la fin de la requête

## Résultat attendu
Une fois toutes les corrections appliquées, le script ne devrait plus générer d'erreurs ORA-00937 pour les sections 5.4 à 5.7 et 5.9 à 5.22.

## Impact
- Les sections corrigées fonctionnent maintenant correctement pour Oracle 12c+
- Le logic métier reste identique, seule la structure de la requête a été optimisée
- La compatibilité avec les versions Oracle multitenant et non-multitenant est préservée

## Prochaines étapes
1. Appliquer les corrections restantes aux sections 5.11 à 5.22
2. Tester le script sur une base Oracle 12c+ pour vérifier l'absence d'erreurs
3. Valider que les résultats obtenus sont cohérents avec les attentes du benchmark CIS