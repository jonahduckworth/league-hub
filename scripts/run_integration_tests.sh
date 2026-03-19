#!/usr/bin/env bash
# Run Firebase emulator integration tests for the service layer.
#
# Prerequisites:
#   npm install -g firebase-tools
#   firebase login
#
# Usage:
#   ./scripts/run_integration_tests.sh              # run all service tests
#   ./scripts/run_integration_tests.sh firestore   # run only firestore tests
#   ./scripts/run_integration_tests.sh auth        # run only auth tests
#   ./scripts/run_integration_tests.sh storage     # run only storage tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Determine which test file(s) to run.
case "${1:-all}" in
  firestore)
    TEST_TARGET="test/services/firestore_service_test.dart"
    ;;
  auth)
    TEST_TARGET="test/services/auth_service_test.dart"
    ;;
  storage)
    TEST_TARGET="test/services/storage_service_test.dart"
    ;;
  all)
    TEST_TARGET="test/services/"
    ;;
  *)
    echo "Unknown target: $1"
    echo "Usage: $0 [all|firestore|auth|storage]"
    exit 1
    ;;
esac

echo "Starting Firebase emulators and running: flutter test $TEST_TARGET"
echo ""

firebase emulators:exec \
  --only auth,firestore,storage \
  --project jdb-league-hub \
  "flutter test $TEST_TARGET --tags emulator"
