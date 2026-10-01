#!/bin/bash
#
#  run_tests.sh
#  SIDPLAY Automated Test Runner
#
#  Compiles and executes the automated unit and regression test suite.
#

set -e

# Resolve repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

BUILD_DIR="$REPO_ROOT/build/tests"
mkdir -p "$BUILD_DIR"

MOCK_OBJ="$BUILD_DIR/MockSIDEngineBridge.o"
TEST_BIN="$BUILD_DIR/sidplay_tests"

echo -e "\033[1;34m[1/2] Compiling MockSIDEngineBridge...\033[0m"
clang -c "$REPO_ROOT/Tests/Mocks/MockSIDEngineBridge.m" \
    -I "$REPO_ROOT/Source/AudioCore" \
    -fobjc-arc \
    -o "$MOCK_OBJ"

echo -e "\033[1;34m[2/2] Compiling Test Suites and Application Swift Sources...\033[0m"
SWIFT_SOURCES=$(find "$REPO_ROOT/Source" -name "*.swift")
TEST_SOURCES=$(find "$REPO_ROOT/Tests" -name "*.swift")

swiftc -parse-as-library \
    $SWIFT_SOURCES \
    $TEST_SOURCES \
    "$MOCK_OBJ" \
    -import-objc-header "$REPO_ROOT/Source/App/SIDPLAY-Bridging-Header.h" \
    -I "$REPO_ROOT/Source/AudioCore" \
    -o "$TEST_BIN"

echo -e "\033[1;32mTest binary compiled successfully. Executing test suite...\033[0m\n"
"$TEST_BIN"
