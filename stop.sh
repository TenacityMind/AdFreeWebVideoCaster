#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "=== Stopping AdFree Web Video Caster Stack ==="
for svc in web api media scraping; do
  if [ -f "logs/$svc.pid" ]; then
    PID=$(cat "logs/$svc.pid")
    if kill -0 "$PID" 2>/dev/null; then
      echo "Stopping $svc (PID $PID)..."
      kill "$PID" 2>/dev/null || true
    fi
    rm -f "logs/$svc.pid"
  fi
done

# Kill any leftover next or castor processes in this directory if any
pkill -f "castor (api-server|media-server|scraping-server)" 2>/dev/null || true
pkill -f "next dev --turbopack" 2>/dev/null || true

echo "All services stopped."
