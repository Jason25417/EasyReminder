#!/usr/bin/env bash
# EasyReminder 一键发版脚本
# 自动：升 build 号(+1) → archive → Developer ID 导出 → 公证 → staple
#       → 干净 zip(--norsrc --noextattr) → 生成 EdDSA 签名 appcast → 打 tag → 发 GitHub Release
#
# 用法:  scripts/release.sh <营销版本号>      例:  scripts/release.sh 1.3
# 前置:  先手动改好 EasyReminder/Models/Changelog.swift 加这一版的更新日志；
#        scripts/release.local.sh 里填好公证凭证(见 release.local.example.sh)。
set -euo pipefail

MARKETING="${1:?用法: $0 <营销版本号>   例: $0 1.3}"
REPO="Jason25417/EasyReminder"
SCHEME="EasyReminder"
PROJECT="EasyReminder.xcodeproj"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# 公证凭证(不入库): NOTARY_KEY / NOTARY_KEY_ID / NOTARY_ISSUER
source "$ROOT/scripts/release.local.sh"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

WORK="$(mktemp -d)"
TAG="v${MARKETING}.0"
ASSET="EasyReminder-v${MARKETING}.zip"
PBX="$PROJECT/project.pbxproj"

echo "==> 1/6 升 build 号 + 设营销版本号"
CUR_BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PBX" | grep -oE '[0-9]+')
NEW_BUILD=$((CUR_BUILD + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = ${NEW_BUILD};/g" "$PBX"
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = ${MARKETING};/g" "$PBX"
echo "    build ${CUR_BUILD} → ${NEW_BUILD}；marketing → ${MARKETING}"
git add "$PBX" EasyReminder/Models/Changelog.swift
git commit -m "chore: release v${MARKETING} (build ${NEW_BUILD})"

echo "==> 2/6 archive + Developer ID 导出"
xcodebuild archive -project "$PROJECT" -scheme "$SCHEME" -destination 'generic/platform=macOS' -archivePath "$WORK/app.xcarchive" >/dev/null
xcodebuild -exportArchive -archivePath "$WORK/app.xcarchive" -exportPath "$WORK/export" -exportOptionsPlist "$ROOT/scripts/exportOptions.plist" >/dev/null
APP="$WORK/export/EasyReminder.app"

echo "==> 3/6 公证(--wait，约几分钟)"
ditto -c -k --keepParent --norsrc --noextattr "$APP" "$WORK/submit.zip"
xcrun notarytool submit "$WORK/submit.zip" --key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER" --wait

echo "==> 4/6 staple"
xcrun stapler staple "$APP"
spctl -a -t install "$APP"

echo "==> 5/6 干净 zip + EdDSA 签名 appcast"
mkdir -p "$WORK/cast"
ditto -c -k --keepParent --norsrc --noextattr "$APP" "$WORK/cast/$ASSET"
GA=$(find ~/Library/Developer/Xcode/DerivedData -path "*artifacts/sparkle*" -name generate_appcast 2>/dev/null | head -1)
"$GA" --download-url-prefix "https://github.com/$REPO/releases/download/$TAG/" "$WORK/cast"

echo "==> 6/6 打 tag + 发 Release"
git tag -a "$TAG" -m "v${MARKETING}"
git push origin HEAD "$TAG"
gh release create "$TAG" --repo "$REPO" --title "v${MARKETING}" \
  --notes "本版更新见应用内「更新日志」。下载 \`$ASSET\` 解压拖入「应用程序」即可（已公证）。" \
  "$WORK/cast/$ASSET" "$WORK/cast/appcast.xml"

echo "✅ v${MARKETING} (build ${NEW_BUILD}) 已发布：https://github.com/$REPO/releases/tag/$TAG"
