#!/usr/bin/env bash
# tasks/tune/oltp-nvme.sh — Tune PostgreSQL 18 for OLTP on NVMe SSD
# Hardware: 2 CPUs, 12GB RAM, NVMe
# Idempotent: safe to re-run.

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
require_root
require_postgres_installed

# ─────────────────────────────────────────────
# 1. Backup configs
# ─────────────────────────────────────────────
log "Backing up existing configs..."
backup_conf "${PG_CONF}"
backup_conf "${PG_HBA}"

# ─────────────────────────────────────────────
# 2. postgresql.conf
# ─────────────────────────────────────────────
log "Writing postgresql.conf..."
cat >"${PG_CONF}" <<CONF
# ============================================================
# PostgreSQL 18 — Tuned for OLTP on NVMe, ${RAM_MB}MB RAM, ${CPUS} CPUs
# Generated $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# ============================================================

# ── Connection ──────────────────────────────────────────────
listen_addresses = '*'
port = ${PG_PORT}
max_connections = 200

# ── Memory ──────────────────────────────────────────────────
shared_buffers = ${SHARED_BUFFERS}
effective_cache_size = ${EFFECTIVE_CACHE_SIZE}
work_mem = ${WORK_MEM}
maintenance_work_mem = ${MAINTENANCE_WORK_MEM}
huge_pages = try

# ── WAL ─────────────────────────────────────────────────────
wal_buffers = ${WAL_BUFFERS}
min_wal_size = ${MIN_WAL_SIZE}
max_wal_size = ${MAX_WAL_SIZE}
wal_level = replica
wal_compression = on
checkpoint_timeout = 10min
checkpoint_completion_target = 0.9

# ── I/O (PG18 async I/O — NVMe tuned) ──────────────────────
io_method = worker
io_workers = 3
io_combine_limit = ${IO_COMBINE_LIMIT}
random_page_cost = ${RANDOM_PAGE_COST}
effective_io_concurrency = ${EFFECTIVE_IO_CONCURRENCY}
maintenance_io_concurrency = ${EFFECTIVE_IO_CONCURRENCY}
seq_page_cost = 1.0

# ── Parallelism (minimal — OLTP queries are short) ─────────
max_worker_processes = ${CPUS}
max_parallel_workers_per_gather = 0
max_parallel_workers = ${CPUS}
max_parallel_maintenance_workers = 1

# ── Background Writer (aggressive for write-heavy OLTP) ────
bgwriter_delay = 200ms
bgwriter_lru_maxpages = 100
bgwriter_lru_multiplier = 2.0
bgwriter_flush_after = 512kB

# ── Autovacuum ──────────────────────────────────────────────
autovacuum = on
autovacuum_max_workers = 3
autovacuum_naptime = 30s
autovacuum_vacuum_threshold = 50
autovacuum_vacuum_scale_factor = 0.05
autovacuum_analyze_threshold = 50
autovacuum_analyze_scale_factor = 0.025
autovacuum_vacuum_cost_delay = 2ms
autovacuum_vacuum_cost_limit = 1000

# ── Logging ─────────────────────────────────────────────────
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_min_duration_statement = 1000
log_checkpoints = on
log_connections = off
log_disconnections = off
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 0
log_line_prefix = '%m [%p] %q%u@%d '

# ── Planner ─────────────────────────────────────────────────
default_statistics_target = 100
jit = on

# ── Extensions ──────────────────────────────────────────────
shared_preload_libraries = 'pg_stat_statements'
CONF

# ─────────────────────────────────────────────
# 3. pg_hba.conf
# ─────────────────────────────────────────────
log "Writing pg_hba.conf..."
cat >"${PG_HBA}" <<HBA
# PostgreSQL Client Authentication Configuration
# TYPE  DATABASE  USER  ADDRESS      METHOD
local   all       all                peer
host    all       all  127.0.0.1/32  scram-sha-256
host    all       all  ::1/128       scram-sha-256
HBA

# Fix ownership (script runs as root, but pg_wrapper needs postgres:postgres)
chown postgres:postgres "${PG_CONF}" "${PG_HBA}"
chmod 640 "${PG_CONF}" "${PG_HBA}"

# ─────────────────────────────────────────────
# 4. Kernel tuning (sysctl)
# ─────────────────────────────────────────────
log "Applying kernel tuning..."
SYSCTL_FILE="/etc/sysctl.d/99-postgresql.conf"
cat >"${SYSCTL_FILE}" <<'SYSCTL'
# PostgreSQL kernel tuning — NVMe, 12GB RAM

# Huge pages (2MB pages — reduces TLB misses for shared_buffers)
vm.nr_hugepages = 1572       # 3GB shared_buffers / 2MB page + margin

# Dirty page management — flush more aggressively to avoid checkpoint spikes
vm.dirty_ratio = 10
vm.dirty_background_ratio = 3

# Swappiness — prefer keeping PG data in RAM
vm.swappiness = 1

# Increase max shared memory
kernel.shmmax = 3758096384   # ~3.5GB
kernel.shmall = 917504       # shmmax / 4096

# Semaphore limits (for max_connections=200)
kernel.sem = 250 32000 100 128
SYSCTL
sysctl -p "${SYSCTL_FILE}"

# ─────────────────────────────────────────────
# 5. Restart PostgreSQL
# ─────────────────────────────────────────────
log "Restarting PostgreSQL..."
systemctl restart postgresql

# ─────────────────────────────────────────────
# 6. Enable pg_stat_statements
# ─────────────────────────────────────────────
log "Enabling pg_stat_statements..."
su - postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS pg_stat_statements;'"

# ─────────────────────────────────────────────
# 7. Verification
# ─────────────────────────────────────────────
echo ""
echo "=== Verification ==="
echo ""
echo "--- PostgreSQL version ---"
su - postgres -c "psql -c 'SELECT version();'"
echo ""
echo "--- Key settings ---"
su - postgres -c "psql -c \"
SELECT name, setting, unit
FROM pg_settings
WHERE name IN (
  'shared_buffers', 'effective_cache_size', 'work_mem',
  'maintenance_work_mem', 'wal_buffers', 'max_connections',
  'io_method', 'io_workers', 'io_combine_limit', 'random_page_cost',
  'effective_io_concurrency', 'maintenance_io_concurrency', 'huge_pages',
  'max_worker_processes', 'max_parallel_workers_per_gather',
  'autovacuum_max_workers'
)
ORDER BY name;\""
echo ""
echo "--- Huge pages status ---"
su - postgres -c "psql -c \"SHOW huge_pages;\""
echo ""
echo "--- pg_stat_statements ---"
su - postgres -c "psql -c \"SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_stat_statements';\""
echo ""
echo "=== Done ==="
echo "Config: ${PG_CONF}"
echo "HBA:    ${PG_HBA}"
echo "Logs:   ${PG_DATA}/log/"
echo ""
echo "Next steps:"
echo "  - Review pg_hba.conf: add remote client IPs if needed"
echo "  - Monitor: SELECT * FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;"
echo "  - Tune work_mem up if sorts spill to disk (check log_temp_files)"
