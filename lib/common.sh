#!/usr/bin/env bash
# Shared config and helpers for all postgres-scripts tasks.
# Source this file:  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

set -euo pipefail

# ── Project root ────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── PostgreSQL paths ────────────────────────────────────────
PG_VERSION="${PG_VERSION:-18}"
PG_PORT="${PG_PORT:-5432}"
PG_DATA="/var/lib/postgresql/${PG_VERSION}/main"
PG_CONF="/etc/postgresql/${PG_VERSION}/main/postgresql.conf"
PG_HBA="/etc/postgresql/${PG_VERSION}/main/pg_hba.conf"

# ── Hardware (edit for your server) ─────────────────────────
RAM_MB="${RAM_MB:-12288}" # 12GB
CPUS="${CPUS:-2}"

# ── Derived tuning values ───────────────────────────────────
SHARED_BUFFERS="3GB"
EFFECTIVE_CACHE_SIZE="9GB"
WORK_MEM="16MB"
MAINTENANCE_WORK_MEM="1GB"
WAL_BUFFERS="64MB"
MAX_WAL_SIZE="4GB"
MIN_WAL_SIZE="1GB"
EFFECTIVE_IO_CONCURRENCY=200
RANDOM_PAGE_COST="1.1"
IO_COMBINE_LIMIT="131072"

# ── Helpers ─────────────────────────────────────────────────

log() { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*" >&2; }
err() {
	echo "[ERROR] $*" >&2
	exit 1
}

require_root() {
	[[ "${EUID}" -eq 0 ]] || err "This script must be run as root (use sudo)."
}

require_postgres_installed() {
	pg_lsclusters -h >/dev/null 2>&1 || err "PostgreSQL ${PG_VERSION} is not installed."
}

backup_conf() {
	local file="$1"
	if [[ -f "${file}" ]]; then
		cp "${file}" "${file}.bak.$(date +%Y%m%d%H%M%S)"
		log "Backed up ${file}"
	fi
}

psql_as_postgres() {
	su - postgres -c "psql -At -c '$*'"
}
