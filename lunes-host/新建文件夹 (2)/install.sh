#!/usr/bin/env sh

# Default Configuration
DOMAIN="${DOMAIN:-node.lunes.host}"
PORT="${PORT:-9474}"
HY2_PASSWORD="${HY2_PASSWORD:-vevc.HY2.Password}"
# 限制最大带宽 (默认 50 mbps)，降低带宽可以有效降低 CPU 使用率
MAX_SPEED="${MAX_SPEED:-50 mbps}"

echo "Starting Hysteria 2 Installation..."

# 1. Create package.json
cat << EOF > package.json
{
  "name": "lunes-host-h2",
  "version": "1.0.0",
  "description": "Hysteria2 Startup Script",
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "author": "vevc",
  "license": "MIT"
}
EOF

# 2. Create app.js (Hysteria Only)
cat << EOF > app.js
const { spawn } = require("child_process");

const app = {
  name: "h2",
  binaryPath: "/home/container/h2/h2",
  args: ["server", "-c", "/home/container/h2/config.yaml"]
};

function runProcess(app) {
  const child = spawn(app.binaryPath, app.args, { stdio: "inherit" });

  child.on("exit", (code) => {
    console.log(\`[EXIT] \${app.name} exited with code: \${code}\`);
    console.log(\`[RESTART] Restarting \${app.name}...\`);
    setTimeout(() => runProcess(app), 3000);
  });
}

console.log("Starting Hysteria 2...");
runProcess(app);
EOF

# 3. Setup Hysteria Directory and Binary
mkdir -p /home/container/h2
cd /home/container/h2

# Download Hysteria 2 (Check for existing binary to save time if re-running)
if [ ! -f "h2" ]; then
    echo "Downloading Hysteria 2 binary..."
    curl -sSL -o h2 https://github.com/apernet/hysteria/releases/download/app%2Fv2.6.2/hysteria-linux-amd64
    chmod +x h2
else
    echo "Hysteria 2 binary already exists."
fi

# 4. Generate Self-Signed Cert
echo "Generating self-signed certificate for $DOMAIN..."
openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout key.pem -out cert.pem -subj "/CN=$DOMAIN" 2>/dev/null

# 5. Create config.yaml
echo "Creating Hysteria 2 configuration..."
cat << EOF > config.yaml
listen: :$PORT

# 限制带宽以降低 CPU 占用
bandwidth:
  up: $MAX_SPEED
  down: $MAX_SPEED

tls:
  cert: /home/container/h2/cert.pem
  key: /home/container/h2/key.pem

auth:
  type: password
  password: '$HY2_PASSWORD'

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com/
    rewriteHost: true
EOF

# 6. Generate Connection Link
# Encode password for URL
encodedHy2Pwd=$(node -e "console.log(encodeURIComponent('$HY2_PASSWORD'))")
hy2Url="hysteria2://$encodedHy2Pwd@$DOMAIN:$PORT?insecure=1&sni=$DOMAIN#lunes-hy2"

# Save node info
echo "$hy2Url" > /home/container/node.txt

echo "============================================================"
echo "🚀 Hysteria 2 Node Installed Successfully"
echo "------------------------------------------------------------"
echo "Domain:    $DOMAIN"
echo "Port:      $PORT"
echo "Password:  $HY2_PASSWORD"
echo "Max Speed: $MAX_SPEED"
echo ""
echo "Connection Link:"
echo "$hy2Url"
echo "============================================================"
