#!/usr/bin/env bash
# Crée le Secret k8s "metabase-db" à partir des credentials de l'add-on PostgreSQL.
# Retrouve l'add-on automatiquement par son nom (pas d'ID à copier-coller).
# Usage : ./create-secret.sh [nom-addon]   (défaut: metabase-demo-db)
set -euo pipefail

ADDON_NAME="${1:-metabase-demo-db}"

# Cible l'orga si la variable ORG est posée (l'add-on n'est pas dans l'orga par défaut).
ORG_FLAG=()
[ -n "${ORG:-}" ] && ORG_FLAG=(--org "$ORG")

ADDON_ID="$(clever addon list "${ORG_FLAG[@]}" 2>/dev/null | grep -w "$ADDON_NAME" | head -1 | awk '{print $NF}')"
if [ -z "${ADDON_ID:-}" ]; then
  echo "❌ Add-on '$ADDON_NAME' introuvable. Vérifie 'clever addon list' (et la variable ORG)." >&2
  exit 1
fi

eval "$(clever addon env "$ADDON_ID" "${ORG_FLAG[@]}" --format shell 2>/dev/null)"

kubectl -n metabase create secret generic metabase-db \
  --from-literal=MB_DB_HOST="$POSTGRESQL_ADDON_HOST" \
  --from-literal=MB_DB_PORT="$POSTGRESQL_ADDON_PORT" \
  --from-literal=MB_DB_DBNAME="$POSTGRESQL_ADDON_DB" \
  --from-literal=MB_DB_USER="$POSTGRESQL_ADDON_USER" \
  --from-literal=MB_DB_PASS="$POSTGRESQL_ADDON_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret metabase-db créé (add-on $ADDON_NAME → $ADDON_ID)"
