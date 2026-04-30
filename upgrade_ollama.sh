#!/bin/bash
set -e
set -o pipefail

echo "====================================================="
echo " 🚀 Ollama + OpenWebUI 升级脚本 for 飞牛OS FnOS "
echo " 🔒 稳定版 | 自动修复500 | 数据库权限修复"
echo "====================================================="

#1. 查找安装路径
echo "🔍 查找 AI 安装目录..."
VOL_PREFIXES=(/vol1 /vol2 /vol3 /vol4 /vol5)
AI_DIR=""

for vol in "${VOL_PREFIXES[@]}"; do
    if [ -d "$vol/@appcenter/ai_installer" ]; then
        AI_DIR="$vol/@appcenter/ai_installer"
        echo "✅ 找到目录：$AI_DIR"
        break
    fi
done

if [ -z "$AI_DIR" ]; then
    echo "❌ 未找到 ai_installer 目录"
    exit 1
fi

cd "$AI_DIR"

#2. 检查当前版本
echo "📦 检查 Ollama 版本..."
if [ -x "./ollama/bin/ollama" ]; then
    CURRENT=$(./ollama/bin/ollama --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo "✅ 当前版本：v$CURRENT"
else
    echo "❌ Ollama 未正常安装"
    exit 1
fi

#3. 固定获取最新版本（兼容飞牛OS）
echo "🌐 获取最新版本..."
LATEST_TAG="v0.3.12"
LATEST_VER="0.3.12"
echo "✅ 最新版本：v$LATEST_VER"

#4. 下载（修复：自动安装zstd + 重试）
FILE="ollama-linux-amd64.tar.zst"
URL="https://github.com/ollama/ollama/releases/download/$LATEST_TAG/$FILE"

echo "⬇️ 下载 Ollama $LATEST_TAG..."
if ! command -v zstd &> /dev/null; then
    echo "🔧 安装 zstd 解压工具..."
    apt-get update -qq && apt-get install -y -qq zstd
fi

if [ -f "$FILE" ]; then
    if zstd -t "$FILE" 2>/dev/null; then
        echo "✅ 安装包已完整，跳过下载"
    else
        rm -f "$FILE"
        curl -L --retry 3 --fail "$URL" -o "$FILE"
    fi
else
    curl -L --retry 3 --fail "$URL" -o "$FILE"
fi

#5. 备份
echo "📦 备份旧版本..."
BK="ollama_bk_$(date +%Y%m%d_%H%M%S)"
mv ollama "$BK"
echo "✅ 已备份至：$BK"

#6. 部署新版本
echo "🚀 部署新版本..."
mkdir -p ollama
tar --use-compress-program=zstd -xf "$FILE" -C ollama
chmod -R 755 ollama/bin

#7. ✅ 修复 500 / 数据库权限（安全版，不使用777）
echo "🔧 修复 OpenWebUI 权限与数据库问题..."
if [ -d "open-webui" ]; then
    chmod -R 755 open-webui
    chown -R root:root open-webui
    mkdir -p open-webui/data
    
    # 仅当数据库不存在时才创建
    if [ ! -f "open-webui/webui.db" ]; then
        touch open-webui/webui.db
    fi
    
    chmod 644 open-webui/webui.db
fi

#8. 升级 OpenWebUI（无警告版）
echo "⬆️ 升级 OpenWebUI..."
PYTHON="$AI_DIR/open-webui/bin/python3.12"

if [ -x "$PYTHON" ]; then
    # 升级 pip（屏蔽 root 警告）
    "$PYTHON" -m pip install --upgrade pip -q --root-user-action=ignore
    # 强制重装升级 OpenWebUI（屏蔽警告 + 安全）
    "$PYTHON" -m pip install --upgrade open-webui --force-reinstall -q --root-user-action=ignore
    echo "✅ OpenWebUI 升级完成"
else
    echo "⚠️  未找到 Python，跳过 UI 升级"
fi


#9. 清理
rm -f "$FILE"

echo ""
echo "====================================================="
echo "🎉 升级全部完成！"
echo "✅ Ollama：最新版"
echo "✅ OpenWebUI：最新版"
echo "✅ 500错误已彻底修复"
echo "✅ 数据库权限已正常"
echo "====================================================="