#!/usr/bin/env bash
# Run every server-side tournament/economy harness against local Supabase.
# Prereqs:
#   supabase start                       (local stack up, migrations applied)
#   admin@gathr.local / admin1234        seeded + in admin_users (see README)
# Usage: bash supabase/tests/run.sh [pattern]
set -uo pipefail
cd "$(dirname "$0")"
PATTERN="${1:-_test.sh}"
overall=0
for t in *${PATTERN}*; do
  [[ -f "$t" ]] || continue
  echo "════════════════════════ $t ════════════════════════"
  if bash "$t"; then echo "── $t OK"; else echo "── $t FAILED"; overall=1; fi
  echo
done
exit $overall
