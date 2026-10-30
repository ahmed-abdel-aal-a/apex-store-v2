#!/bin/bash
# ==============================================================================
# Apex Store - Production Watchdog & Auto-Recovery Script (Enhanced)
# ==============================================================================

export PATH=/opt/cpanel/ea-nodejs22/bin:$HOME/.npm-global/bin:/usr/local/bin:/usr/bin:/bin:$PATH
export NODE_ENV=production

LOCKFILE="/home/kyanfash/.apex_watchdog.lock"

# 1. Prevent concurrent runs & stale lock cleanup
if [ -e "$LOCKFILE" ]; then
    PID=$(cat "$LOCKFILE" 2>/dev/null)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        exit 0
    fi
fi

# 2. Acquire lock and guarantee cleanup on exit
echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT INT TERM

# 3. Verify PM2 God Daemon - resurrect if down
if ! pm2 ping >/dev/null 2>&1; then
    pm2 resurrect >/dev/null 2>&1 || pm2 start /home/kyanfash/ecosystem.config.js
    pm2 save --force
    exit 0
fi

# 4. Deep Health Check Function (HTTP Code Analysis)
check_and_recover() {
    local port=$1
    local app_name=$2
    local http_code

    http_code=$(curl -s -m 5 -o /dev/null -w "%{http_code}" "http://127.0.0.1:${port}")

    # Check for dead socket (000) or server/proxy crash (>= 500)
    if [ "$http_code" = "000" ] || [ "$http_code" -ge 500 ] 2>/dev/null; then
        pm2 restart "$app_name" --update-env
    fi
}

# 5. Monitor Storefront (Port 2000) & Dashboard (Port 2050)
check_and_recover 2000 "apex-storefront"
check_and_recover 2050 "apex-dashboard"
