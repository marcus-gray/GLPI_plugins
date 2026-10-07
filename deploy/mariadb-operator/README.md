# MariaDB for GLPI via mariadb-operator

Vendor-neutral: only core Kubernetes plus the mariadb-operator CRDs are required.

## Prerequisites
- Kubernetes cluster, `kubectl` and `helm` (v3) pointed at it, plus `envsubst` and `openssl`
- A ReadWriteOnce StorageClass (any CSI driver; on NKP, the Nutanix CSI class)

## Install
```sh
NAMESPACE=glpi \
OPERATOR_VERSION=<chart version> \
DB_STORAGE_CLASS=<rwo-storageclass> \
./install.sh
```
Variables: `NAMESPACE`, `OPERATOR_NAMESPACE`, `OPERATOR_VERSION` (pin it),
`DB_IMAGE` (default `mariadb:11.4`), `DB_REPLICAS` (default 3), `DB_STORAGE_SIZE`
(default 20Gi), `DB_STORAGE_CLASS` (empty = cluster default).

The script is idempotent. It never overwrites existing password Secrets.
Air-gapped clusters: mirror the `mariadb` image and the operator images/chart, then
override `DB_IMAGE` and the operator image values in `values.yaml`.

## What it creates
- `mariadb-operator` (+ CRDs) in `mariadb-operator` namespace
- `MariaDB/glpi-db`: 3-node Galera cluster, utf8mb4, pod anti-affinity
- `Database/glpi`, `User/glpi`, and grants (all on `glpi`, `SELECT` on `mysql.time_zone_name`)
- Secrets `glpi-db-root` and `glpi-db-user` (key `password`)

GLPI connects to `glpi-db.<namespace>.svc.cluster.local:3306`.

## Verify
```sh
kubectl -n glpi get mariadb,database,user,grant
kubectl -n glpi get pods -l app.kubernetes.io/instance=glpi-db
```

## Status / to confirm on first real deploy
Written without access to a cluster, so check these against your operator version:
CRD field names (`kubectl explain mariadb.spec`), the primary Service name, and whether
timezone data needs loading (`mariadb-tzinfo-to-sql`) before running
`bin/console database:enable_timezones` in GLPI.
Backups (`Backup`/`PhysicalBackup` resources) are not configured yet.
