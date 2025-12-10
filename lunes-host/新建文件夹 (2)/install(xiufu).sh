#!/usr/bin/env sh

# --- 核心配置 ---
# 降低默认带宽到 30mbps 以防止 CPU 跑满 (你可以根据情况适当回调)
MAX_SPEED="${MAX_SPEED:-30 mbps}"
DOMAIN="${DOMAIN:-217.154.173.102}"
PORT="${PORT:-9474}"
HY2_PASSWORD="${HY2_PASSWORD:-vevc.HY2.Password}"

echo "Starting Optimized Hysteria 2 Installation..."

# 1. 生成 package.json (保持不变)
cat << EOF > package.json
{
  "name": "lunes-host-h2",
  "version": "1.0.0",
  "description": "Hysteria2 Server",
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "author": "vevc",
  "license": "MIT"
}
EOF

# 2. 生成运行时的 app.js (关键修改点！)
# 这里我们生成一个新的 app.js，它会在启动 h2 时强制加上 GOMAXPROCS=1
cat << EOF > app.js
const { spawn } = require("child_process");

const app = {
  name: "h2",
  binaryPath: "/home/container/h2/h2",
  args: ["server", "-c", "/home/container/h2/config.yaml"]
};

function runProcess(app) {
  // 关键修改：合并当前环境变量，并强制 GOMAXPROCS=1
  // 这限制 Go 语言只使用一个系统线程，防止 CPU 瞬时 100% 导致容器崩溃
  const env = { ...process.env, GOMAXPROCS: "1" };

  const child = spawn(app.binaryPath, app.args, { 
    stdio: "inherit",
    env: env 
  });

  child.on("exit", (code) => {
    console.log(\`[EXIT] \${app.name} exited with code: \${code}\`);
    console.log(\`[RESTART] Restarting \${app.name}...\`);
    setTimeout(() => runProcess(app), 3000);
  });
}

console.log("Starting Hysteria 2 with CPU Optimization (GOMAXPROCS=1)...");
runProcess(app);
EOF

# 3. 准备目录
mkdir -p /home/container/h2
cd /home/container/h2

# 下载 Hysteria 2 (如果不存在)
if [ ! -f "h2" ]; then
    echo "Downloading Hysteria 2 binary..."
    curl -sSL -o h2 https://github.com/apernet/hysteria/releases/download/app%2Fv2.6.2/hysteria-linux-amd64
    chmod +x h2
else
    echo "Hysteria 2 binary already exists."
fi

# 4. 生成自签名证书
echo "Generating self-signed certificate for $DOMAIN..."
openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout key.pem -out cert.pem -subj "/CN=$DOMAIN" 2>/dev/null

# 5. 生成配置文件 (关键修改点！)
echo "Creating Hysteria 2 configuration..."
cat << EOF > config.yaml
listen: :$PORT

bandwidth:
  up: $MAX_SPEED
  down: $MAX_SPEED

# 忽略客户端建议，强制由服务端控制速率
ignoreClientBandwidth: true

tls:
  cert: /home/container/h2/cert.pem
  key: /home/container/h2/key.pem

auth:
  type: password
  password: '$HY2_PASSWORD'

# 改为 404 模式，这是 CPU 占用最低的伪装方式
# 不要使用 proxy 模式去代理 Bing，那非常耗 CPU
masquerade:
  type: 404
EOF

# 6. 生成连接信息
encodedHy2Pwd=$(node -e "console.log(encodeURIComponent('$HY2_PASSWORD'))")
hy2Url="hysteria2://$encodedHy2Pwd@$DOMAIN:$PORT?insecure=1&sni=$DOMAIN#lunes-hy2"
echo "$hy2Url" > /home/container/node.txt

echo "============================================================"
echo "✅ 安装完成！Hysteria 2 已针对受限容器进行了优化"
echo "------------------------------------------------------------"
echo "Domain:    $DOMAIN"
echo "Max Speed: $MAX_SPEED"
echo "Mode:      Low CPU (GOMAXPROCS=1, Masquerade=404)"
echo ""
echo "Connection Link:"
echo "$hy2Url"
echo "============================================================"