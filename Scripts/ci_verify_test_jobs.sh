#!/usr/bin/env bash

set -euo pipefail

lint_result="${1:-}"
changes_result="${2:-}"
macos_tests_required="${3:-}"
macos_test_result="${4:-}"
macos_app_result="${5:-}"

if [[ "$lint_result" != "success" ]]; then
  printf 'lint job finished with %s\n' "${lint_result:-<empty>}" >&2
  exit 1
fi

if [[ "$changes_result" != "success" ]]; then
  printf 'changes job finished with %s\n' "${changes_result:-<empty>}" >&2
  exit 1
fi

case "${macos_tests_required}:${macos_test_result}:${macos_app_result}" in
  true:success:success)
    printf 'Lint, macOS Swift test shards, and macOS app package build passed.\n'
    ;;
  false:skipped:skipped)
    printf 'Lint passed; macOS Swift tests and app package build skipped for docs/site-only changes.\n'
    ;;
  *)
    printf 'macOS gate/result mismatch: required=%s test=%s app=%s\n' \
      "${macos_tests_required:-<empty>}" \
      "${macos_test_result:-<empty>}" \
      "${macos_app_result:-<empty>}" >&2
    exit 1
    ;;
esac
