#!/usr/bin/env bash
set -u

BASE_URL="http://localhost:8080"
REPORT_DIR="reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT="$REPORT_DIR/waf-validation-$TIMESTAMP.txt"

mkdir -p "$REPORT_DIR"

PASS=0
FAIL=0
WARN=0

log() {
    echo "$*" | tee -a "$REPORT"
}

check_code() {
    local name="$1"
    local expected="$2"
    shift 2

    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' \
        --max-time 10 "$@" 2>/dev/null) || code="ERROR"

    if [[ "$code" == "$expected" ]]; then
        log "[PASS] $name — HTTP $code"
        ((PASS+=1))
    else
        log "[FAIL] $name — expected HTTP $expected, got $code"
        ((FAIL+=1))
    fi
}

check_benign() {
    local name="$1"
    shift

    local code
    code=$(curl -sS -o /dev/null -w '%{http_code}' \
        --max-time 10 "$@" 2>/dev/null) || code="ERROR"

    if [[ "$code" =~ ^(2|3)[0-9][0-9]$ ]]; then
        log "[PASS] $name — HTTP $code"
        ((PASS+=1))
    else
        log "[FAIL] $name — expected 2xx/3xx, got $code"
        ((FAIL+=1))
    fi
}

log "WAF Security Validation Report"
log "Date: $(date -Is)"
log "Target: $BASE_URL"
log "----------------------------------------"

log ""
log "=== 1. SERVICE HEALTH ==="

health=$(docker inspect waf-nginx \
    --format '{{.State.Health.Status}}' 2>/dev/null || echo "unavailable")

if [[ "$health" == "healthy" ]]; then
    log "[PASS] Docker WAF health — $health"
    ((PASS+=1))
else
    log "[FAIL] Docker WAF health — $health"
    ((FAIL+=1))
fi

if docker exec waf-nginx nginx -t >/dev/null 2>&1; then
    log "[PASS] Nginx configuration test"
    ((PASS+=1))
else
    log "[FAIL] Nginx configuration test"
    ((FAIL+=1))
fi

if docker exec waf-nginx sh -c \
    'grep -RiqE "^[[:space:]]*SecRuleEngine[[:space:]]+on([[:space:]#]|$)" /etc/nginx/modsecurity.d /etc/modsecurity.d 2>/dev/null'; then
    log "[PASS] ModSecurity engine enabled"
    ((PASS+=1))
else
    log "[FAIL] ModSecurity engine setting not confirmed"
    ((FAIL+=1))
fi

log ""
log "=== 2. NORMAL REQUESTS ==="

check_benign "Benign GET /" "$BASE_URL/"
check_benign "Benign JSON POST" \
    -X POST \
    -H 'Content-Type: application/json' \
    --data '{"name":"John","status":"active"}' \
    "$BASE_URL/"

log ""
log "=== 3. ATTACK BLOCKING ==="

check_code "SQL Injection" "403" \
    --get --data-urlencode 'id=1 OR 1=1' "$BASE_URL/"

check_code "XSS" "403" \
    --get --data-urlencode 'q=<script>alert(1)</script>' "$BASE_URL/"

check_code "Path Traversal" "403" \
    --get --data-urlencode 'file=../../../../etc/passwd' "$BASE_URL/"

log ""
log "=== 4. FALSE-POSITIVE INVESTIGATION ==="

code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 \
    --get --data-urlencode 'data={"name":"John","status":"active"}' \
    "$BASE_URL/" 2>/dev/null) || code="ERROR"

if [[ "$code" == "403" ]]; then
    log "[WARN] Benign JSON query blocked — investigate CRS rule matches"
    ((WARN+=1))
else
    log "[INFO] Benign JSON query — HTTP $code; review application expectations"
fi

log ""
log "=== 5. SUMMARY ==="
log "PASS: $PASS"
log "FAIL: $FAIL"
log "WARN: $WARN"
log "Report saved to: $REPORT"

if (( FAIL > 0 )); then
    exit 1
fi
