#!/usr/bin/env bash
# Run Firebase emulator integration tests for the service layer.
#
# Prerequisites:
#   npm install -g firebase-tools
#   firebase login
#   Java >= 21 on PATH (for Firebase emulators)
#
# Usage:
#   ./scripts/run_integration_tests.sh              # run all service tests
#   ./scripts/run_integration_tests.sh firestore   # run only firestore tests
#   ./scripts/run_integration_tests.sh auth        # run only auth tests
#   ./scripts/run_integration_tests.sh storage     # run only storage tests
#
# Notes:
#   - Each test file is run in its own firebase emulators:exec invocation so
#     that the macOS app process is fully restarted between suites (the
#     Firestore SDK's terminate() call in tearDownAll otherwise corrupts the
#     shared process for subsequent test files).
#   - Tests require macOS (`-d macos`) because FirebaseAuth, Firestore, and
#     Storage use Pigeon-based platform channels that do not work in the
#     headless Dart VM.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

run_suite() {
  local target="$1"
  echo ""
  echo "=== Running: flutter test $target -d macos ==="
  firebase emulators:exec \
    --only auth,firestore,storage \
    --project jdb-league-hub \
    "flutter test $target -d macos"
}

case "${1:-all}" in
  firestore)
    run_suite "integration_test/services/firestore_service_test.dart"
    ;;
  auth)
    run_suite "integration_test/services/auth_service_test.dart"
    ;;
  storage)
    run_suite "integration_test/services/storage_service_test.dart"
    ;;
  all)
    run_suite "integration_test/services/firestore_service_test.dart"
    run_suite "integration_test/services/auth_service_test.dart"
    run_suite "integration_test/services/storage_service_test.dart"
    echo ""
    echo "=== All integration test suites passed ==="
    ;;
  *)
    echo "Unknown target: $1"
    echo "Usage: $0 [all|firestore|auth|storage]"
    exit 1
    ;;
esac
