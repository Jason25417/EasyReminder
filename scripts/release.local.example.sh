# 复制成 scripts/release.local.sh 并填好你的 App Store Connect API key 信息。
# release.local.sh 已被 .gitignore 忽略，不会入库。
export NOTARY_KEY="$HOME/Downloads/AuthKey_XXXXXXXXXX.p8"   # .p8 私钥文件路径（机密，勿入库）
export NOTARY_KEY_ID="XXXXXXXXXX"                            # Key ID
export NOTARY_ISSUER="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Issuer ID
