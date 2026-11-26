#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
test_dir="$(mktemp -d /tmp/this-you-core.XXXXXX)"
swiftc -DTESTING -parse-as-library -module-cache-path "$test_dir/module-cache" ThisYou/Models.swift ThisYou/Store.swift Tests/CoreTests.swift -o "$test_dir/tests"
THISYOU_TEST_STORAGE="$test_dir/storage" "$test_dir/tests"
