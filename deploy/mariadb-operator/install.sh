#!/usr/bin/env bash
# Installs mariadb-operator and provisions a Galera MariaDB cluster for GLPI.
# Works on any conformant Kubernetes cluster; needs only helm, kubectl, envsubst, openssl.
#
# Usage:  NAMESPACE=glpi DB_STORAGE_CLASS=<rwo-class> ./install.sh
set -euo pipefail

NAMESPACE="${NAMESPACE:-glpi}"
OPERATOR_NAMESPACE="${OPERATOR_NAMESPACE:-mariadb-operator}"
OPERATOR_VERSION="${OPERATOR_VERSION:-}"          # pin this for reproducible installs
export DB_IMAGE="${DB_IMAGE:-mariadb:11.4}"
export DB_REPLICAS="${DB_REPLICAS:-3}"            # Galera needs an odd number >= 3 for quorum
export DB_STORAGE_SIZE="${DB_STORAGE_SIZE:-20Gi}"
export DB_STORAGE_CLASS="${DB_STORAGE_CLASS:-}"   # empty = cluster default StorageClass
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for bin in helm kubectl envsubst openssl; do
  command -v "$bin" >/dev/null || { echo "missing required tool: $bin" >&2; exit 1; }
done
[ -n "$OPERATOR_VERSION" ] || echo "WARNING: OPERATOR_VERSION not set; installing latest chart version." >&2
ver=(); [ -z "$OPERATOR_VERSION" ] || ver=(--version "$OPERATOR_VERSION")

helm repo add mariadb-operator https://helm.mariadb.com/mariadb-operator >/dev/null
helm repo update mariadb-operator >/dev/null

helm upgrade --install mariadb-operator-crds mariadb-operator/mariadb-operator-crds \
  --namespace "$OPERATOR_NAMESPACE" --create-namespace "${ver[@]}"
helm upgrade --install mariadb-operator mariadb-operator/mariadb-operator \
  --namespace "$OPERATOR_NAMESPACE" -f "$DIR/values.yaml" "${ver[@]}" --wait

kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

# Create secrets only if absent, so re-runs never rotate live passwords.
ensure_secret() {
  kubectl -n "$NAMESPACE" get secret "$1" >/dev/null 2>&1 || \
    kubectl -n "$NAMESPACE" create secret generic "$1" \
      --from-literal=password="$(openssl rand -base64 32 | tr -d '/+=\n')"
}
ensure_secret glpi-db-root
ensure_secret glpi-db-user

render() {
  if [ -z "$DB_STORAGE_CLASS" ]; then sed '/storageClassName:/d' "$DIR/glpi-mariadb.yaml"
  else cat "$DIR/glpi-mariadb.yaml"; fi | envsubst '${DB_IMAGE} ${DB_REPLICAS} ${DB_STORAGE_SIZE} ${DB_STORAGE_CLASS}'
}
render | kubectl -n "$NAMESPACE" apply -f -

echo "Waiting for the MariaDB cluster to become Ready (can take several minutes)..."
kubectl -n "$NAMESPACE" wait --for=condition=Ready mariadb/glpi-db --timeout=15m

cat <<MSG

Done. GLPI database connection:
  host:     glpi-db.${NAMESPACE}.svc.cluster.local   (primary service)
  database: glpi
  user:     glpi
  password: secret '${NAMESPACE}/glpi-db-user', key 'password'
MSG
