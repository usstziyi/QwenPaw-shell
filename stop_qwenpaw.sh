#!/usr/bin/env bash
# 文件名: stop_qwenpaw.sh
# 用途: 停止 QwenPaw 后台服务

set -euo pipefail

# --- 配置 ---
PID_FILE="$HOME/QwenPaw/server.pid"  # 与启动脚本中的路径保持一致

# --- 停止服务 ---
if [ ! -f "$PID_FILE" ]; then
    echo "未找到 PID 文件 ($PID_FILE)，服务可能未运行。"
    exit 1
fi

PID=$(cat "$PID_FILE")
echo "正在停止 QwenPaw 服务 (PID: $PID)..."

if ps -p "$PID" > /dev/null 2>&1; then
    # 发送 TERM 信号，优雅地停止进程
    kill "$PID"
    echo "已发送停止信号，等待进程结束..."

    # 等待最多10秒，检查进程是否退出
    for i in {1..10}; do
        if ! ps -p "$PID" > /dev/null 2>&1; then
            echo "服务已成功停止。"
            rm -f "$PID_FILE"
            exit 0
        fi
        sleep 1
    done

    # 如果10秒后仍未退出，强制终止
    echo "服务未在时限内停止，正在强制终止..."
    kill -9 "$PID" 2>/dev/null || true
    echo "服务已被强制终止。"
else
    echo "PID $PID 对应的进程不存在，可能已自动结束。"
fi

# 清理PID文件
rm -f "$PID_FILE"