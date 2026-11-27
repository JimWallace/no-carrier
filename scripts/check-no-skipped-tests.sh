#!/usr/bin/env bash
set -euo pipefail

# Fails when a Swift Testing xUnit report holds a skipped test.
#
# A test that needs a host tool declares it with a `ConditionTrait`, so an
# absent tool shows as a skipped test with its reason, in the log and in the
# xUnit report that `swift test --xunit-output` writes. CI meets every
# condition, so on CI a skip is a defect in the runner image, never an
# expected state. This guard turns the skip into a red job with the test name
# and the reason on the same line.
#
# Usage: scripts/check-no-skipped-tests.sh REPORT...
# With no argument it reads the sample report under scripts/guard-fixtures/,
# which is how check-guards.sh proves the guard can fail.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ "$#" -eq 0 ]; then
    set -- scripts/guard-fixtures/samples/xunit-swift-testing.xml
fi

status=0
reports=0
for report in "$@"; do
    if [ ! -f "$report" ]; then
        echo "ERROR: no xUnit report at $report."
        echo "       Pass the path swift test --xunit-output wrote; Swift Testing adds"
        echo "       -swift-testing before the extension."
        exit 1
    fi
    reports=$((reports + 1))
    if ! grep -q "<testsuite " "$report"; then
        echo "ERROR: $report holds no <testsuite> element, so it is not an xUnit report."
        exit 1
    fi
    skipped="$(grep -c "<skipped" "$report" || true)"
    if [ "$skipped" -eq 0 ]; then
        echo "check-no-skipped-tests: OK ($report, 0 skipped)"
        continue
    fi
    status=1
    echo "ERROR: $skipped skipped test(s) in $report."
    echo "       Every condition a trait names must hold on CI. Install the missing"
    echo "       tool in the job in .github/workflows/swift-tests.yml."
    # Each <skipped>reason</skipped> belongs to the <testcase> line before it.
    awk '
        /<testcase / {
            name = $0
            sub(/.*classname="/, "", name); sub(/" name="/, ".", name); sub(/".*/, "", name)
        }
        /<skipped/ {
            reason = $0
            sub(/.*<skipped[^>]*>/, "", reason); sub(/<\/skipped>.*/, "", reason)
            printf "  skipped test %s: %s\n", name, reason
        }
    ' "$report"
done

if [ "$reports" -eq 0 ]; then
    echo "ERROR: no xUnit report was checked."
    exit 1
fi
exit "$status"
