#!/usr/bin/env sh
# ------------------------------------------------------------------------------
# cronlint.sh — validate system crontab-like files (e.g. /etc/crontab)
# https://github.com/alphapialpha/cronlint
# Copyright (c) 2025 André P. Appel
# Licensed under the MIT License. See LICENSE file for details.
# ------------------------------------------------------------------------------

set -e

usage() {
  echo "Usage: $0 /path/to/crontab-file" >&2
  exit 2
}

[ $# -eq 1 ] || usage
FILE=$1

[ -r "$FILE" ] || { echo "ERROR: Cannot read '$FILE'." >&2; exit 1; }

errors=0
warnings=0

# --- Check for Windows CRLFs --------------------------------------------------
if grep -q $'\r' "$FILE"; then
  echo "ERROR: File contains Windows CRLF line endings (\\r). Convert to LF only." >&2
  errors=$((errors+1))
fi

# --- Check for final newline ---------------------------------------------------
if [ -s "$FILE" ]; then
  last_char_hex=$(tail -c 1 "$FILE" | od -An -t x1 | tr -d ' \n')
  if [ "$last_char_hex" != "0a" ]; then
    echo "WARNING: File does not end with a newline character." >&2
    warnings=$((warnings+1))
  fi
fi

# --- awk validator -------------------------------------------------------------
awk -v FILE="$FILE" '
BEGIN {
  IGNORECASE = 1
  errors = 0; warnings = 0;

  monName = "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"
  dowName = "(sun|mon|tue|wed|thu|fri|sat)"

  num_min = "([0-9]|[0-5][0-9])"
  num_hour = "([0-9]|1[0-9]|2[0-3])"
  num_dom = "([1-9]|[12][0-9]|3[01])"
  num_mon = "([1-9]|1[0-2])"
  num_dow = "([0-7])"

  val_min = "(" "*" "|" num_min ")"
  val_hour = "(" "*" "|" num_hour ")"
  val_dom = "(" "*" "|" num_dom ")"
  val_mon = "(" "*" "|" num_mon "|" monName ")"
  val_dow = "(" "*" "|" num_dow "|" dowName ")"

  piece_min  = "(" val_min  ")(/" "[0-9]+" ")?"
  piece_hour = "(" val_hour ")(/" "[0-9]+" ")?"
  piece_dom  = "(" val_dom  ")(/" "[0-9]+" ")?"
  piece_mon  = "(" val_mon  ")(/" "[0-9]+" ")?"
  piece_dow  = "(" val_dow  ")(/" "[0-9]+" ")?"

  list_min  = "^" piece_min  "(," piece_min  ")*$"
  list_hour = "^" piece_hour "(," piece_hour ")*$"
  list_dom  = "^" piece_dom  "(," piece_dom  ")*$"
  list_mon  = "^" piece_mon  "(," piece_mon  ")*$"
  list_dow  = "^" piece_dow  "(," piece_dow  ")*$"

  specials["reboot"]=1; specials["yearly"]=1; specials["annually"]=1
  specials["monthly"]=1; specials["weekly"]=1; specials["daily"]=1
  specials["midnight"]=1; specials["hourly"]=1

  # preload /etc/passwd if available
  have_passwd = 0
  while ((getline pline < "/etc/passwd") > 0) {
    split(pline, p, ":"); if (p[1] != "") users[p[1]] = 1
    have_passwd = 1
  }
  close("/etc/passwd")
}

function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }

function is_env_assign(s) { return (s ~ /^[A-Za-z_][A-Za-z0-9_]*[ \t]*=/) }

function check_fields(m,h,dom,mon,dow,   ok) {
  ok = 1
  if (m   !~ list_min)  { print "ERROR: minute field invalid: " m; ok=0 }
  if (h   !~ list_hour) { print "ERROR: hour field invalid: " h; ok=0 }
  if (dom !~ list_dom)  { print "ERROR: day-of-month field invalid: " dom; ok=0 }
  if (mon !~ list_mon)  { print "ERROR: month field invalid: " mon; ok=0 }
  if (dow !~ list_dow)  { print "ERROR: day-of-week field invalid: " dow; ok=0 }
  return ok
}

function user_token_looks_like_cmd(u) {
  return (u ~ /\//) || (u ~ /=/) || (u ~ /^(\.\/|\/|\$\()/)
}

function user_valid_syntax(u) {
  return (u ~ /^[A-Za-z_][A-Za-z0-9_-]*[$]?$/)
}

function user_exists(u,    rc,cmd) {
  cmd = "command -v getent >/dev/null 2>&1"
  rc = system(cmd)
  if (rc == 0) {
    cmd = "getent passwd " u " >/dev/null 2>&1"
    rc = system(cmd)
    return (rc == 0)
  }
  if (have_passwd) return (u in users)
  return 0
}

{
  line = trim($0)
  ln = NR

  if (line == "") next
  if (match(line, /^#/)) next
  if (is_env_assign(line)) next

  n = split(line, tok, /[ \t]+/)

  # @special line
  if (substr(tok[1],1,1) == "@") {
    key = substr(tok[1],2)
    if (!(key in specials)) { printf("Line %d: ERROR: unknown @special: %s\n", ln, tok[1]); errors++; next }
    if (n < 3) { printf("Line %d: ERROR: @%s lines need: @%s USER COMMAND...\n", ln, key, key); errors++; next }
    u = tok[2]
    if (!user_valid_syntax(u)) { printf("Line %d: ERROR: invalid USER token: %s\n", ln, u); errors++ }
    else if (user_token_looks_like_cmd(u)) { printf("Line %d: ERROR: USER looks like a command: %s\n", ln, u); errors++ }
    else if (!user_exists(u)) { printf("Line %d: ERROR: user not found: %s\n", ln, u); errors++ }
    next
  }

  # standard line
  if (n < 7) {
    printf("Line %d: ERROR: expected at least 7 fields (min hr dom mon dow USER COMMAND)\n", ln)
    errors++; next
  }

  if (!check_fields(tok[1], tok[2], tok[3], tok[4], tok[5])) {
    printf("Line %d: ERROR: invalid schedule fields.\n", ln); errors++; next
  }

  u = tok[6]
  if (!user_valid_syntax(u)) { printf("Line %d: ERROR: invalid USER token: %s\n", ln, u); errors++; next }
  if (user_token_looks_like_cmd(u)) { printf("Line %d: ERROR: USER looks like a command: %s\n", ln, u); errors++; next }
  if (!user_exists(u)) { printf("Line %d: ERROR: user not found: %s\n", ln, u); errors++; next }

  cmd = ""
  for (i=7; i<=n; i++) { cmd = cmd (i==7?"":" ") tok[i] }
  if (cmd == "") { printf("Line %d: ERROR: missing COMMAND after USER.\n", ln); errors++ }
}

END {
  if (errors == 0) {
    if (warnings > 0) printf("OK: no errors, %d warning(s).\n", warnings); else print "OK: no errors."
    exit 0
  } else {
    printf("Found %d error(s)", errors)
    if (warnings > 0) printf(" and %d warning(s)", warnings)
    print "."
    exit 1
  }
}
' "$FILE" || exit 1

if [ $warnings -gt 0 ]; then
  echo "Note: $warnings warning(s) reported." >&2
fi

exit 0
