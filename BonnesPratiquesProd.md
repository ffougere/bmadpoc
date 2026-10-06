# Bonnes pratiques minimales en prod
Externaliser secrets et clés (pas en clair dans script).
Activer TLS strict + validation certificat.
Ajouter idempotence (identifiant de lot unique).
Journaliser: horodatage, batch_id, hash, HTTP code, durée.
Mettre en place dossier failed + replay contrôlé.
Superviser via alertes (échec transfert, dépassement SLA).

# Ameliorations
Fichier de configuration séparé,
Gestion de DLQ locale,
Format de log standard pour audit,
Mapping direct vers un endpoint SAP précis (OData, BAPI wrapper, CPI).
