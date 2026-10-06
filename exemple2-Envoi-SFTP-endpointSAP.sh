Exemple 2: Envoi via SFTP vers endpoint SAP managé (batch simple)
#!/usr/bin/ksh
set -euo pipefail

SAP_SFTP_HOST="sftp.sap-tenant.example.com"
SAP_SFTP_PORT="22"
SAP_SFTP_USER="sap_integration_user"
SAP_SFTP_KEY="/home/aixuser/.ssh/id_rsa_sap"
REMOTE_DIR="/inbound/aix"
LOCAL_FILE="/data/outbound/orders_$(date +%Y%m%d).dat"
LOG_FILE="/var/log/aix_to_sap_sftp.log"

log() {
  print -- "$(date '+%Y-%m-%d %H:%M:%S') | $1" | tee -a "$LOG_FILE"
}

if [ ! -f "$LOCAL_FILE" ]; then
  log "ERREUR: fichier introuvable: $LOCAL_FILE"
  exit 1
fi

log "INFO: transfert SFTP vers SAP"

sftp -oBatchMode=yes -oStrictHostKeyChecking=yes \
  -i "$SAP_SFTP_KEY" -P "$SAP_SFTP_PORT" \
  "${SAP_SFTP_USER}@${SAP_SFTP_HOST}" <<EOF
cd $REMOTE_DIR
put $LOCAL_FILE
bye
EOF

log "OK: transfert SFTP terminé"
