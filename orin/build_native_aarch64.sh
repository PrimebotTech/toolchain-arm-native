#!/bin/bash
set -e

# 从项目根目录执行
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

TOTAL_STEPS=3
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

step() {
    local n=$1 desc=$2
    local pct=$((n * 100 / TOTAL_STEPS))
    local filled=$((pct / 5))
    local empty=$((20 - filled))
    local bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null) ; seq 1 $empty 2>/dev/null | while read; do printf '░'; done)
    printf "\n${BOLD}${CYAN}[Step %d/%d]${NC} ${GREEN}[%s %3d%%]${NC} %s\n" "$n" "$TOTAL_STEPS" "$bar" "$pct" "$desc"
}

# 清理可能残留的同名容器
step 1 "清理旧容器"
sudo docker rm -f native_container_aarch64 2>/dev/null || true

# 构建镜像
step 2 "构建 Docker 镜像 (native-aarch64-orin)"
sudo docker build -f orin/Dockerfile -t native-aarch64-orin --load .

# 运行容器
step 3 "启动编译容器"
printf "\n${BOLD}${GREEN}✅ 构建完成 [100%%]，进入容器...${NC}\n\n"
sudo docker run -it --rm --name native_container_aarch64 --net=host -v ~/workspace:/workspace -w /workspace native-aarch64-orin bash
