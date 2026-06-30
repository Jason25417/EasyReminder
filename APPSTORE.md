# 上架 Mac App Store（本分支 = 无 Sparkle 变体）

`appstore` 分支已把 **Sparkle / 自更新 UI / mach-lookup 例外 / SU 键** 全部摘掉，专供 App Store 提交。
`main` 分支保持 **Developer ID + Sparkle 自更新**（开源直装那条线），两条线互不影响。

## 一次性准备
1. **App Store Connect** → My Apps → ➕ New App：平台选 macOS、填名称/主语言、Bundle ID 选 `com.jason.MyApp`、SKU 随意。
2. **Xcode**：用中国区账号（Team `D2KWHV599Z`）登录；签名保持 Automatic → 会自动生成 Apple Distribution 证书 + App Store 描述文件。

## 每次提交
1. `git checkout appstore`（如 main 有新功能：`git rebase main`，重新解掉 Sparkle 相关冲突）。
2. Xcode → Product → **Archive**。
3. Organizer → **Distribute App → App Store Connect → Upload**。
   - 或 CLI：`xcodebuild -exportArchive -archivePath <x>.xcarchive -exportPath out -exportOptionsPlist scripts/exportOptions-appstore.plist`，再用 Transporter 上传产出的 .pkg。
4. App Store Connect 网页：截图 + 描述 + 分类 + 分级 + **隐私标签**（读提醒数据但不收集/不外发 → 选「不收集数据」）→ **提交审核**（约 1–3 天）。

## 注意
- App Store 的版本号/构建号自成体系，和 Sparkle 那条线独立维护。
- **别动 Bundle ID** `com.jason.MyApp`。
- 摘 Sparkle 改动见本分支 diff；与 `main` 的唯一差异就是「去掉自更新」。
