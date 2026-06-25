#!/usr/bin/env bash
# Upload the recorded UI-test video to Supabase Storage (public bucket
# `ui-test-videos`) and export its public URL for the PR comment step.
#
# Retention (versions): deletes any existing videos under pr-<n>/ before
# uploading, so each PR keeps only its latest recording. A scheduled workflow
# (.github/workflows/cleanup-ui-videos.yml) sweeps anything older than 30 days.
#
# Required env: SUPABASE_STORAGE_SERVICE_KEY, SUPABASE_STORAGE_PROJECT_REF,
#               PR_NUMBER, RUN_ID, OUT_DIR (dir containing run.mov)
#
# Always exits 0 — this is an auxiliary step and must never fail the test job.
# No-op when the secrets are absent (e.g. fork PRs), so the pipeline still runs.
set -uo pipefail

KEY="${SUPABASE_STORAGE_SERVICE_KEY:-}"
REF="${SUPABASE_STORAGE_PROJECT_REF:-}"
PR="${PR_NUMBER:-0}"
RUN="${RUN_ID:-local}"
OUT_DIR="${OUT_DIR:-ui-run-artifacts}"
MOV="$OUT_DIR/run.mov"
BUCKET="ui-test-videos"

if [[ -z "$KEY" || -z "$REF" ]]; then
  echo "[upload-ui-video] SUPABASE_STORAGE_* secrets not set — skipping upload."
  exit 0
fi
if [[ ! -f "$MOV" ]]; then
  echo "[upload-ui-video] no $MOV to upload — skipping."
  exit 0
fi

BASE="https://$REF.supabase.co/storage/v1"
PREFIX="pr-$PR"
OBJ="$PREFIX/run-$RUN.mov"

# Retention (versions): purge prior videos for this PR.
existing="$(curl -sS -X POST "$BASE/object/list/$BUCKET" \
  -H "Authorization: Bearer $KEY" -H "apikey: $KEY" -H "Content-Type: application/json" \
  -d "{\"prefix\":\"$PREFIX/\",\"limit\":100}" 2>/dev/null \
  | python3 -c "import sys,json;[print('$PREFIX/'+o['name']) for o in json.load(sys.stdin) if o.get('id')]" 2>/dev/null || true)"
if [[ -n "$existing" ]]; then
  prefixes="$(printf '%s\n' "$existing" | python3 -c "import sys,json;print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")"
  curl -sS -X DELETE "$BASE/object/$BUCKET" \
    -H "Authorization: Bearer $KEY" -H "apikey: $KEY" -H "Content-Type: application/json" \
    -d "{\"prefixes\":$prefixes}" -o /dev/null \
    -w "[upload-ui-video] purged prior PR videos (HTTP %{http_code})\n" || true
fi

# Upload the new recording.
code="$(curl -sS -X POST "$BASE/object/$BUCKET/$OBJ" \
  -H "Authorization: Bearer $KEY" -H "apikey: $KEY" \
  -H "Content-Type: video/quicktime" -H "x-upsert: true" \
  --data-binary @"$MOV" -o /dev/null -w "%{http_code}")"

URL="https://$REF.supabase.co/storage/v1/object/public/$BUCKET/$OBJ"
if [[ "$code" == "200" ]]; then
  echo "[upload-ui-video] uploaded → $URL"
  echo "$URL" > "$OUT_DIR/video-url.txt"
  [[ -n "${GITHUB_ENV:-}" ]] && echo "VIDEO_URL=$URL" >> "$GITHUB_ENV"
else
  echo "[upload-ui-video] upload failed (HTTP $code)"
fi
exit 0
