#!/usr/bin/env bash
# Runs flutter tests with coverage and produces a filtered report that
# excludes generated code (.g.dart, .freezed.dart), l10n delegates,
# main.dart and firebase_options.dart.
#
# Usage:
#   bash tool/coverage.sh
#
# Output:
#   coverage/lcov.info           — raw output from `flutter test --coverage`
#   coverage/lcov_filtered.info  — same, but with generated files removed
#   prints per-file and total coverage to stdout

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "Running flutter test --coverage…"
fvm flutter test --coverage

RAW="coverage/lcov.info"
FILTERED="coverage/lcov_filtered.info"

if [[ ! -f "$RAW" ]]; then
  echo "ERROR: $RAW not found — did the tests fail?" >&2
  exit 1
fi

# Strip out generated and entry-point files. We work record-by-record:
# each record is a block delimited by `end_of_record`. A record is dropped
# iff its SF line matches one of the exclusion patterns.
awk '
  BEGIN { record=""; skip=0 }
  /^SF:/ {
    record = $0 "\n"
    skip = 0
    if ($0 ~ /\.g\.dart$/) skip = 1
    else if ($0 ~ /\.freezed\.dart$/) skip = 1
    else if ($0 ~ /\/l10n\/app_localizations.*\.dart$/) skip = 1
    else if ($0 ~ /\/lib\/main\.dart$/) skip = 1
    else if ($0 ~ /\/lib\/firebase_options\.dart$/) skip = 1
    next
  }
  /^end_of_record/ {
    record = record $0 "\n"
    if (!skip) printf "%s", record
    record = ""
    skip = 0
    next
  }
  { record = record $0 "\n" }
' "$RAW" > "$FILTERED"

echo
echo "Wrote filtered report to $FILTERED"
echo

awk -F: '
  /^SF:/ { file=$2; lines_found=0; lines_hit=0 }
  /^DA:/ {
    split($2, a, ",")
    lines_found++
    if (a[2] > 0) lines_hit++
  }
  /^end_of_record/ {
    total_found += lines_found
    total_hit   += lines_hit
    files++
    if (lines_found > 0) {
      pct = (lines_hit / lines_found) * 100
      printf "%6.2f%%  %5d/%-5d  %s\n", pct, lines_hit, lines_found, file
    }
  }
  END {
    print ""
    if (total_found > 0) {
      printf "TOTAL (filtered): %.2f%%  (%d/%d lines, %d files)\n", \
        (total_hit/total_found)*100, total_hit, total_found, files
    } else {
      print "No covered lines reported."
    }
  }
' "$FILTERED" | sort -n
