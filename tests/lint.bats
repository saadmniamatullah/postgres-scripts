#!/usr/bin/env bats
# tests/lint.bats — Run shellcheck on all shell scripts

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "shellcheck: lib/common.sh" {
  run shellcheck -x "${PROJECT_ROOT}/lib/common.sh"
  [ "${status}" -eq 0 ]
}

@test "shellcheck: tasks/setup/install.sh" {
  run shellcheck -x "${PROJECT_ROOT}/tasks/setup/install.sh"
  [ "${status}" -eq 0 ]
}

@test "shellcheck: tasks/tune/oltp-nvme.sh" {
  run shellcheck -x "${PROJECT_ROOT}/tasks/tune/oltp-nvme.sh"
  [ "${status}" -eq 0 ]
}
