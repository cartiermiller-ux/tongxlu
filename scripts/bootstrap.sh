#!/usr/bin/env bash
# ============================================================
# 暗夜社区 iOS —— 一键准备脚本（必须在 macOS 上运行）
#
# 做三件事：
#   1. 拉取腾讯云官方 TUIKit_iOS 源码，把 chat/ 和 call/ 复制到本工程根目录
#   2. pod install
#   3. 生成 Xcode 工程
#
# 依据官方文档《UIKit 集成》：
#   https://trtc.io/zh/document/50056?platform=ios+and+macos&product=chat&menulabel=uikit
#
# 前置要求（官方原文）：
#   - Xcode 16.0 或以上（推荐 16.x 系列）
#   - iOS 14.0 及以上**真机**（官方明确：**暂时不支持模拟器**）
#   - CocoaPods 1.12.0+（推荐 1.16.x）
#   - macOS（iOS 构建只能在 macOS 上做）
# ============================================================
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
echo "工程根目录：$ROOT"

# ---------- 0) 环境自检 ----------
echo ""
echo "== 环境自检 =="
command -v xcodebuild >/dev/null 2>&1 || { echo "❌ 找不到 xcodebuild —— 必须在 macOS + Xcode 上运行"; exit 1; }
command -v pod        >/dev/null 2>&1 || { echo "❌ 找不到 CocoaPods —— 请先 gem install cocoapods"; exit 1; }

XCODE_VER="$(xcodebuild -version | head -1 | awk '{print $2}')"
echo "   Xcode: $XCODE_VER"
echo "   CocoaPods: $(pod --version)"

# 官方要求 Xcode 16+
MAJOR="${XCODE_VER%%.*}"
if [ "$MAJOR" -lt 16 ]; then
  echo "⚠️  官方要求 Xcode 16.0+，当前是 $XCODE_VER —— 可能会编译失败"
fi

# ---------- 1) 拉 TUIKit 源码 ----------
echo ""
echo "== 拉取腾讯云官方 TUIKit_iOS =="
TUIKIT_DIR="$ROOT/.tuiKitSrc"

if [ -d "$TUIKIT_DIR/.git" ]; then
  echo "   已存在，拉取更新…"
  git -C "$TUIKIT_DIR" pull --ff-only || echo "   ⚠️ pull 失败，沿用本地已有版本"
else
  # 官方两个源，GitHub 失败就换 CNB
  if ! git clone --depth 1 https://github.com/Tencent-RTC/TUIKit_iOS.git "$TUIKIT_DIR"; then
    echo "   GitHub 失败，改用 CNB…"
    git clone --depth 1 https://cnb.cool/tencent/cloud/trtc/TUIKit_iOS.git "$TUIKIT_DIR"
  fi
fi

# ---------- 2) 复制 chat/ 与 call/ ----------
echo ""
echo "== 复制 chat/ 与 call/ 到工程根目录（官方指定做法）=="
for d in chat call; do
  if [ -d "$TUIKIT_DIR/$d" ]; then
    rm -rf "$ROOT/$d"
    cp -R "$TUIKIT_DIR/$d" "$ROOT/$d"
    echo "   ✅ $d/ 已复制"
  else
    echo "   ❌ 源码里找不到 $d/ —— TUIKit 仓库结构可能变了"
    exit 1
  fi
done

# 只保留我们需要的部分，减小体积（可选）
# demo 工程不用，删掉避免 pod install 误解析
rm -rf "$ROOT/chat/demo" 2>/dev/null || true

# ---------- 3) pod install ----------
echo ""
echo "== pod install =="
# 首次可能需要更新本地 spec 仓库
if ! pod install --repo-update; then
  echo "   ⚠️ --repo-update 失败，重试不带该参数"
  pod install
fi

# ---------- 4) 生成 Xcode 工程 ----------
echo ""
echo "== 生成 Xcode 工程 =="
if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
  echo "   ✅ Anyeshequ.xcodeproj 已生成"
else
  echo "   ⚠️ 未安装 xcodegen"
  echo "      安装：brew install xcodegen"
  echo "      装好后执行：xcodegen generate"
fi

# ---------- 5) 屏幕共享扩展的额外依赖 ----------
echo ""
echo "== 屏幕共享扩展检查 =="
if [ -d "$ROOT/AnyeshequScreenShare" ]; then
  echo "   ✅ 扩展目录存在（ReplayKit Broadcast Upload Extension）"
  echo ""
  echo "   ⚠️ 还需要手动做两件事（无法脚本化）："
  echo "      1. 把 TXLiteAVSDK_ReplayKitExt.framework 拖进扩展 Target"
  echo "         来源：TRTC SDK 压缩包，或 TUICallKit_Swift 依赖的 TXLiteAVSDK_Professional 包里"
  echo "      2. 到 https://developer.apple.com 创建 App Group：group.cn.anyeshequ.app"
  echo "         并给【主 App 和扩展两个 App ID 都勾上】，然后重新下载两份 Provisioning Profile"
  echo ""
  echo "   详见：Anyeshequ/ScreenShare/README-屏幕共享集成.md"
else
  echo "   ❌ 找不到 AnyeshequScreenShare 目录"
fi

# ---------- 完成 ----------
echo ""
echo "============================================================"
echo " 准备完成"
echo "============================================================"
echo ""
echo " 下一步："
echo "   open Anyeshequ.xcworkspace    # ⚠️ 一定要开 .xcworkspace，不是 .xcodeproj"
echo ""
echo " 在 Xcode 里："
echo "   1. 选 Anyeshequ target → Signing & Capabilities → 选你的 Team"
echo "   2. 同样给 AnyeshequScreenShare target 配好 Team 和 App Group"
echo "   3. 选一台**真机**（模拟器跑不了通话，官方明确说明）"
echo "   4. Product → Archive → Distribute App → 导出**未签名 ipa** 给第三方签名"
echo ""
echo " 导出未签名 ipa 的另一种方式（命令行）："
echo "   xcodebuild -workspace Anyeshequ.xcworkspace -scheme Anyeshequ \\"
echo "     -configuration Release -sdk iphoneos -archivePath build/Anyeshequ.xcarchive archive"
echo "   然后从 .xcarchive/Products/Applications/ 里把 .app 打包成 ipa："
echo "     mkdir -p Payload && cp -R build/Anyeshequ.xcarchive/Products/Applications/Anyeshequ.app Payload/"
echo "     zip -r Anyeshequ-unsigned.ipa Payload"
echo ""
