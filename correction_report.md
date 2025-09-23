# Rapport de correction des erreurs ENABLED_OPT dans le script CIS

## Problème identifié
Le script `cis_benchmark_11g_through_19c.sql` contenait de nombreuses références à la colonne invalide `ENABLED_OPT` dans les sections Oracle 12c Unified Auditing, causant l'erreur Oracle ORA-00904 "invalid identifier".

## Corrections effectuées

### 1. Remplacement de ENABLED_OPT par ENABLED_OPTION
Toutes les occurrences suivantes ont été corrigées :

- **Lignes 9976-9978** : Section 5.2 Oracle 12c
- **Lignes 10045-10047** : Section 5.3 Oracle 12c  
- **Lignes 10102-10104** : Section 5.7 Oracle 12c
- **Lignes 10159-10161** : Section 5.8 Oracle 12c
- **Lignes 10216-10218** : Section 5.2 (suite) Oracle 12c
- **Lignes 10273-10275** : Section 5.3 (suite) Oracle 12c
- **Lignes 10330-10332** : Section 5.7 (suite) Oracle 12c
- **Lignes 10377** : Section ALTER PROFILE Oracle 12c
- **Lignes 10403** : Section DROP PROFILE Oracle 12c
- **Lignes 10429** : Section CREATE DATABASE LINK Oracle 12c
- **Lignes 10455** : Section ALTER DATABASE LINK Oracle 12c
- **Lignes 10481** : Section DROP DATABASE LINK Oracle 12c
- **Lignes 10507** : Section CREATE SYNONYM Oracle 12c
- **Lignes 10533** : Section ALTER SYNONYM Oracle 12c
- **Lignes 10559** : Section DROP SYNONYM Oracle 12c

### 2. Modification de la logique conditionnelle
La condition complexe :
```sql
AND (ENABLED.ENABLED_OPT = 'BY' OR ENABLED.ENABLED_OPTION = 'BY USER')
```

A été simplifiée en :
```sql
AND ENABLED.ENABLED_OPTION = 'BY USER'
```

### 3. Vérifications effectuées
- ✅ Aucune occurrence de `ENABLED_OPT` ne subsiste dans le fichier
- ✅ Aucune référence problématique à `USER_NAME` dans les sections Oracle 12c
- ✅ Toutes les colonnes utilisées sont valides pour Oracle 12c Unified Auditing

## Résultat
Le script est maintenant compatible avec Oracle 12c Unified Auditing et ne devrait plus générer d'erreurs ORA-00904 liées aux colonnes invalides `ENABLED_OPT` ou `USER_NAME` dans les sections spécifiques à Oracle 12c.

## Sections concernées
- Section 5.2 : Ensure 'FAILED_LOGIN_ATTEMPTS' Is Less than or Equal to '5' (Automated)
- Section 5.3 : Ensure 'PASSWORD_LOCK_TIME' Is Greater than or Equal to '1' (Automated)
- Section 5.7 : Ensure 'PASSWORD_LIFE_TIME' Is Less than or Equal to '90' (Automated)
- Section 5.8 : Ensure 'PASSWORD_GRACE_TIME' Is Less than or Equal to '5' (Automated)
- Plus toutes les sections d'audit des profils et synonymes dans Oracle 12c