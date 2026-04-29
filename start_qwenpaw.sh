#!/usr/bin/env bash
# 文件名: start_qwenpaw.sh
# 用途: 后台启动 QwenPaw 服务，并记录进程ID
# 用法: ./start_qwenpaw.sh [--log-level <级别>]

set -euo pipefail

# --- 配置 ---
HOST="0.0.0.0"
PORT="8088"
LOG_FILE="$HOME/QwenPaw/server.log"       # 日志文件路径
PID_FILE="$HOME/QwenPaw/server.pid"       # PID文件路径
QWENPAW_BIN="$HOME/.qwenpaw/bin/qwenpaw"   # QwenPaw可执行文件路径

# --- 默认值 ---
LOG_LEVEL="warning"  # 默认日志级别：只显示警告和错误

# --- 解析参数 ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --log-level)
            if [[ -z "${2:-}" || "$2" == --* ]]; then
                echo "错误: --log-level 需要指定一个值"
                exit 1
            fi
            case "$2" in
                critical|error|warning|info|debug|trace)
                    LOG_LEVEL="$2"
                    shift 2
                    ;;
                *)
                    echo "错误: 无效的日志级别 '$2'"
                    echo "可选: critical, error, warning, info, debug, trace"
                    exit 1
                    ;;
            esac
            ;;
        -h|--help)
            cat <<EOF
用法: $0 [选项]

选项:
  --log-level <级别>   设置日志级别（默认: warning）
                       可选: critical, error, warning, info, debug, trace
  -h, --help           显示此帮助信息

示例:
  $0                              # 启动，默认只记录警告和错误
  $0 --log-level info             # 启动，记录普通信息（含请求日志）
  $0 --log-level debug            # 调试模式，输出最详细
  $0 --log-level critical         # 极其安静，只有严重错误才记录

日志文件: $LOG_FILE
可使用以下命令查看实时日志:
  tail -f $LOG_FILE
EOF
            exit 0
            ;;
        *)
            echo "未知选项: $1 (使用 --help 查看帮助)"
            exit 1
            ;;
    esac
done

# --- 检查是否已在运行 ---
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "错误: QwenPaw 似乎已在运行 (PID: $OLD_PID)。"
        echo "如需重启，请先运行停止脚本。"
        exit 1
    else
        echo "提示: 发现残留的PID文件，将自动清理。"
        rm -f "$PID_FILE"
    fi
fi

# --- 启动服务 ---
echo "正在后台启动 QwenPaw..."
echo "  监听地址: $HOST:$PORT"
echo "  日志级别: $LOG_LEVEL"
echo "  日志文件: $LOG_FILE"

# 后台运行，输出写入日志文件
nohup "$QWENPAW_BIN" app --host "$HOST" --port "$PORT" --log-level "$LOG_LEVEL" > "$LOG_FILE" 2>&1 &

NEW_PID=$!

# 将新进程的PID写入文件
echo "$NEW_PID" > "$PID_FILE"
echo "  PID 文件: $PID_FILE"

# 等待一小会儿，检查进程是否成功启动
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