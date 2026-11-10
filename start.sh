#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

mkdir -p logs

export PATH="$DIR/bin:/Users/aereddy/.nvm/versions/node/v24.15.0/bin:$PATH"
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
export NO_PROXY="*"
export no_proxy="*"

echo "=== Starting AdFree Web Video Caster Stack ==="


# Stop existing instances if running
./stop.sh 2>/dev/null || true
sleep 1

# 1. Scraping Server (:8412)
echo "-> Starting Scraping Server (:8412)..."
nohup env CASTOR_SERVERS__SCRAPING__LISTEN="127.0.0.1:8412" \
  "$DIR/bin/castor" scraping-server > logs/scraping.log 2>&1 < /dev/null &
PID_SCRAPE=$!
echo $PID_SCRAPE > logs/scraping.pid
disown $PID_SCRAPE 2>/dev/null || true

# Detect local LAN IP for media advertisement
LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")

# 2. Media Server (:8410)
echo "-> Starting Media Server (:8410)..."
nohup env CASTOR_SERVERS__MEDIA__LISTEN=":8410" \
  CASTOR_SERVERS__MEDIA__ADVERTISE="http://${LAN_IP}:8410" \
  "$DIR/bin/castor" media-server > logs/media.log 2>&1 < /dev/null &
PID_MEDIA=$!
echo $PID_MEDIA > logs/media.pid
disown $PID_MEDIA 2>/dev/null || true

# 3. API Server (:8411)
echo "-> Starting API Server (:8411)..."
nohup env CASTOR_SERVERS__API__LISTEN="127.0.0.1:8411" \
  CASTOR_SERVERS__MEDIA__URL="http://127.0.0.1:8410" \
  CASTOR_SERVERS__SCRAPING__URL="http://127.0.0.1:8412" \
  "$DIR/bin/castor" api-server > logs/api.log 2>&1 < /dev/null &
PID_API=$!
echo $PID_API > logs/api.pid
disown $PID_API 2>/dev/null || true

# Wait for API server to become ready
echo "-> Waiting for Castor API Server..."
for i in {1..30}; do
  if curl -s http://127.0.0.1:8411/castor.v1.DeviceService/ListDevices -H "Content-Type: application/json" -d '{}' >/dev/null 2>&1; then
    echo "   API server is ready."
    break
  fi
  sleep 0.5
done

# 4. Web Dashboard (:3000)
echo "-> Starting Web Dashboard (:3000)..."
nohup env CASTOR_WEB__TRUSTED_LAN="true" \
  CASTOR_SERVERS__API__URL="http://127.0.0.1:8411" \
  node node_modules/next/dist/bin/next dev app --turbopack --hostname 127.0.0.1 > logs/web.log 2>&1 < /dev/null &
PID_WEB=$!
echo $PID_WEB > logs/web.pid
disown $PID_WEB 2>/dev/null || true

# Wait for Web server to become ready
echo "-> Waiting for Web Dashboard..."
for i in {1..30}; do
  if curl -s http://127.0.0.1:3000/ >/dev/null 2>&1; then
    echo "   Web dashboard is ready."
    break
  fi
  sleep 0.5
done

echo ""
echo "=========================================================="
echo "  AdFree Web Video Caster is running!"
echo "  Open in your browser: http://localhost:3000"
echo "  To stop:              ./stop.sh"
echo "=========================================================="
