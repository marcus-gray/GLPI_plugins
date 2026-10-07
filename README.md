# GLPI plugins

Private GLPI 11 plugins, built for Kubernetes (developed against Nutanix Kubernetes
Platform, kept vendor-agnostic).

- `deploy/mariadb-operator/` – HA MariaDB (Galera) for GLPI. See its README.
- Planned: `deploy/chart/` (Helm chart: GLPI Deployment, install/upgrade Job, cron, Redis
  sessions/cache, RWX files volume), `plugins/<name>/`, and an image build with plugins baked in.
