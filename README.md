# postgres-scripts

Versioned, tested PostgreSQL 18 setup and tuning scripts for Ubuntu 26.04 LTS.

## Quick start

```bash
make setup   # install PostgreSQL 18
make tune    # apply OLTP/NVMe tuning
```

## Structure

```
lib/common.sh              Shared config (PG version, RAM, derived values)
tasks/setup/install.sh     Install PostgreSQL 18 from Ubuntu repos
tasks/tune/oltp-nvme.sh    Tune for OLTP on NVMe SSD (2 CPU, 12GB RAM)
tests/                     bats tests: lint (shellcheck) + smoke (syntax)
```

## Testing

Requires [bats-core](https://github.com/bats-core/bats-core) and [shellcheck](https://www.shellcheck.net/).

```bash
make test   # run all tests
make lint   # shellcheck only
```

## Configuration

Edit `lib/common.sh` to change PG version, hardware specs, or derived tuning values. All tasks source this file.
