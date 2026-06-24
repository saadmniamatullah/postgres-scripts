#!/usr/bin/env bats
# tests/smoke.bats — Syntax checks and source-path validation

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "bash -n: all .sh scripts parse" {
  while IFS= read -r f; do
    run bash -n "$f"
    [ "${status}" -eq 0 ]
  done < <(find "${PROJECT_ROOT}" -name '*.sh' -not -path '*.bats*')  
}

@test "lib/common.sh is sourceable" {
  run bash -c "source '${PROJECT_ROOT}/lib/common.sh' && echo OK"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"OK"* ]]
}
