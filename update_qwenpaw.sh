#!/usr/bin/env bash
# 文件名: update_qwenpaw.sh
# 用途: 强制更新 QwenPaw 主程序（使用阿里云镜像源，避开网络检测阻塞）
#      更新前自动停止运行中的服务，更新后自动重启（如果之前是在运行状态）

set -euo pipefail

# --- 配置 ---
QWENPAW_HOME="${QWENPAW_HOME:-$HOME/.qwenpaw}"
QWENPAW_VENV="$QWENPAW_HOME/venv"
PID_FILE="$HOME/QwenPaw/server.pid"  # 与启动脚本中的路径保持一致
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

# --- 检查并停止正在运行的 QwenPaw 进程 ---
WAS_RUNNING=false

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        WAS_RUNNING=true
        echo "检测到正在运行的 QwenPaw 服务 (PID: $PID)，正在停止..."
        
        # 发送 TERM 信号，优雅地停止进程
        kill "$PID"
        echo "已发送停止信号，等待进程结束..."

        # 等待最多10秒，检查进程是否退出
        STOPPED=false
        for i in {1..10}; do
            if ! ps -p "$PID" > /dev/null 2>&1; then
                echo "服务已成功停止。"
                STOPPED=true
                break
            fi
            sleep 1
        done

        # 如果10秒后仍未退出，强制终止
        if [ "$STOPPED" = false ]; then
            echo "服务未在时限内停止，正在强制终止..."
            kill -9 "$PID" 2>/dev/null || true
            sleep 1
            echo "服务已被强制终止。"
        fi
        
        rm -f "$PID_FILE"
    else
        echo "提示: 发现残留的PID文件 (PID: $PID 已不存在)，将自动清理。"
        rm -f "$PID_FILE"
    fi
else
    echo "未检测到运行中的 QwenPaw 服务。"
fi

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

# --- 如果更新前服务在运行，则重新启动 ---
if [ "$WAS_RUNNING" = true ]; then
    echo ""
    echo "检测到更新前 QwenPaw 服务在运行，正在重新启动..."
    
    # 查找启动脚本
    START_SCRIPT=""
    if [ -f "$(dirname "$0")/start_qwenpaw.sh" ]; then
        START_SCRIPT="$(dirname "$0")/start_qwenpaw.sh"
    elif [ -f "$HOME/start_qwenpaw.sh" ]; then
        START_SCRIPT="$HOME/start_qwenpaw.sh"
    elif command -v start_qwenpaw.sh > /dev/null 2>&1; then
        START_SCRIPT="start_qwenpaw.sh"
    fi
    
    if [ -n "$START_SCRIPT" ]; then
        echo "使用启动脚本: $START_SCRIPT"
        bash "$START_SCRIPT"
    else
        # 如果找不到启动脚本，直接使用 nohup 启动
        echo "未找到启动脚本，直接启动 QwenPaw 服务..."
        HOST="0.0.0.0"
        PORT="8088"
        LOG_FILE="$HOME/QwenPaw/server.log"
        
        nohup "$QWENPAW_VENV/bin/qwenpaw" app --host "$HOST" --port "$PORT" --log-level warning > "$LOG_FILE" 2>&1 &
        NEW_PID=$!
        echo "$NEW_PID" > "$PID_FILE"
        
        sleep 2
        if ps -p "$NEW_PID" > /dev/null 2>&1; then
            echo "启动成功！(PID: $NEW_PID)"
            echo "使用以下命令查看实时日志："
            echo "  tail -f $LOG_FILE"
        else
            echo "启动失败！请查看日志文件获取详细信息："
            echo "  cat $LOG_FILE"
            rm -f "$PID_FILE"
            exit 1
        fi
    fi
else
    echo ""
    echo "服务未在运行，不进行自动重启。"
    echo "提示: 需要使用服务时，请运行启动脚本: ./start_qwenpaw.sh"
fi