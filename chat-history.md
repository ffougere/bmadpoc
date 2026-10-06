Historique des echanges

 exemples concrets côté AIX (ksh) pour transférer des données vers SAP en mode SaaS.

Hypothèses:

Serveur source: AIX avec ksh + curl + openssl
Cible SAP SaaS: API HTTPS (ex: SAP S/4HANA Cloud, SAP Integration Suite) ou SFTP managé
Authentification: OAuth2, Basic Auth, ou certificat

# Exemple 1: Envoi fichier CSV vers API SAP SaaS avec OAuth2 (Client Credentials)
#!/usr/bin/ksh
set -euo pipefail

# =======================
# Paramètres
# =======================
TOKEN_URL="https://your-subdomain.authentication.sap.hana.ondemand.com/oauth/token"
API_URL="https://your-tenant-api.example.com/sap/opu/odata/sap/API_DATA_SRV/UploadSet"
CLIENT_ID="__A_REMPLACER__"
CLIENT_SECRET="__A_REMPLACER__"

SRC_FILE="/data/outbound/customers_$(date +%Y%m%d).csv"
LOG_FILE="/var/log/aix_to_sap_api.log"
WORK_DIR="/data/work"
ARCHIVE_DIR="/data/archive"
FAILED_DIR="/data/failed"

mkdir -p "$WORK_DIR" "$ARCHIVE_DIR" "$FAILED_DIR"

log() {
  print -- "$(date '+%Y-%m-%d %H:%M:%S') | $1" | tee -a "$LOG_FILE"
}

if [ ! -f "$SRC_FILE" ]; then
  log "ERREUR: fichier introuvable: $SRC_FILE"
  exit 1
fi

# =======================
# 1) Récupérer token OAuth2
# =======================
log "INFO: récupération du token OAuth2"
TOKEN_RESPONSE=$(curl -sS -X POST "$TOKEN_URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET")

ACCESS_TOKEN=$(print -- "$TOKEN_RESPONSE" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')

if [ -z "$ACCESS_TOKEN" ]; then
  log "ERREUR: impossible d'obtenir access_token"
  log "DEBUG: $TOKEN_RESPONSE"
  exit 1
fi

# =======================
# 2) Envoyer le fichier
# =======================
BASENAME=$(basename "$SRC_FILE")
TMP_FILE="$WORK_DIR/$BASENAME"

cp "$SRC_FILE" "$TMP_FILE"

log "INFO: envoi du fichier $BASENAME vers SAP API"
HTTP_CODE=$(curl -sS -o "$WORK_DIR/response.json" -w "%{http_code}" \
  -X POST "$API_URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: text/csv" \
  -H "Slug: $BASENAME" \
  --data-binary "@$TMP_FILE")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  log "OK: transfert réussi (HTTP $HTTP_CODE)"
  mv "$TMP_FILE" "$ARCHIVE_DIR/$BASENAME"
else
  log "ERREUR: transfert échoué (HTTP $HTTP_CODE)"
  log "DEBUG réponse SAP: $(cat "$WORK_DIR/response.json")"
  mv "$TMP_FILE" "$FAILED_DIR/$BASENAME"
  exit 2
fi

Exemple 2: Envoi via SFTP vers endpoint SAP managé (batch simple)
