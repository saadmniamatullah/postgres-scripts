#!/usr/bin/env bash
# tasks/setup/install.sh — Install PostgreSQL 18 on Ubuntu 26.04
# Idempotent: safe to re-run.

source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
require_root

log "Installing PostgreSQL ${PG_VERSION} from Ubuntu repos..."

apt-get update -qq
apt-get install -y -qq \
	"postgresql-${PG_VERSION}" \
	"postgresql-contrib-${PG_VERSION}" \
	"postgresql-common"

log "Enabling PostgreSQL service..."
systemctl enable postgresql

log "Install complete."
log "Next: run tasks/tune/oltp-nvme.sh to apply tuning."
