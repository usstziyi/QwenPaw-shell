#!/usr/bin/env bash
# 文件名: update_qwenpaw.sh
# 用途: 强制更新 QwenPaw 主程序（使用阿里云镜像源，避开网络检测阻塞）

set -euo pipefail

# --- 配置 ---
QWENPAW_HOME="${QWENPAW_HOME:-$HOME/.qwenpaw}"
QWENPAW_VENV="$QWENPAW_HOME/venv"
# 国内用户推荐直接固定使用阿里云镜像，速度快且能避免 install.sh 脚本里的网络检测卡顿
PYPI_MIRROR="https://mirrors.aliyun.com/pypi/simple/"

# --- 预检 ---
if [ ! -f "$QWENPAW_VENV/bin/python" ]; then
    echo "错误: 未找到 QwenPaw 虚拟环境，请先完成安装。" >&2
    echo "安装命令: curl -fsSL https://qwenpaw.agentscope.io/install.sh | bash" >&2
    exit 1
fi

echo "========================================="
echo " QwenPaw 强制更新脚本"
echo "========================================="
echo "安装目录: $QWENPAW_HOME"
echo "镜像源:   $PYPI_MIRROR"
echo ""

# --- 执行更新 ---
echo "正在使用 uv 强制更新 qwenpaw 包..."
uv pip install --upgrade qwenpaw \
    --python "$QWENPAW_VENV/bin/python" \
    --index-url "$PYPI_MIRROR" \
    --quiet

# --- 验证更新 ---
echo ""
echo "更新完成！当前版本信息："
"$QWENPAW_VENV/bin/qwenpaw" --version

echo ""
echo "提示: 直接运行 'qwenpaw app' 或你的启动脚本即可使用最新版。"