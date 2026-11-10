#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

mkdir -p logs

export PATH="$DIR/bin:/Users/aereddy/.nvm/versions/node/v24.15.0/bin:$PATH"
export SSL_CERT_FILE="/private/etc/ssl/cert.pem"
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
export NO_PROXY="*"
export no_proxy="*"


cleanup() {
  echo "Stopping services..."
  kill $(jobs -p) 2>/dev/null || true
  ./stop.sh 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Stop any previous instances
./stop.sh 2>/dev/null || true
sleep 1

# 1. Scraping Server
echo "Starting Scraping Server (:8412)..."
env CASTOR_SERVERS__SCRAPING__LISTEN="127.0.0.1:8412" \
  "$DIR/bin/castor" scraping-server > logs/scraping.log 2>&1 &
echo $! > logs/scraping.pid

# Detect local LAN IP for media advertisement
LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")

# 2. Media Server
echo "Starting Media Server (:8410)..."
env CASTOR_SERVERS__MEDIA__LISTEN=":8410" \
  CASTOR_SERVERS__MEDIA__ADVERTISE="http://${LAN_IP}:8410" \
  "$DIR/bin/castor" media-server > logs/media.log 2>&1 &
echo $! > logs/media.pid

# 3. API Server
echo "Starting API Server (:8411)..."
env CASTOR_SERVERS__API__LISTEN="127.0.0.1:8411" \
  CASTOR_SERVERS__MEDIA__URL="http://127.0.0.1:8410" \
  CASTOR_SERVERS__SCRAPING__URL="http://127.0.0.1:8412" \
  "$DIR/bin/castor" api-server > logs/api.log 2>&1 &
echo $! > logs/api.pid

# Wait for API server
for i in {1..20}; do
  if curl -s http://127.0.0.1:8411/castor.v1.DeviceService/ListDevices -H "Content-Type: application/json" -d '{}' >/dev/null 2>&1; then
    echo "Castor API server is ready."
    break
  fi
  sleep 0.5
done

# 4. Web Dashboard (runs in foreground to keep daemon alive)
echo "Starting Web Dashboard (:3000)..."
env CASTOR_WEB__TRUSTED_LAN="true" \
  CASTOR_SERVERS__API__URL="http://127.0.0.1:8411" \
  node node_modules/next/dist/bin/next dev app --turbopack --hostname 127.0.0.1 2>&1 | tee logs/web.log
