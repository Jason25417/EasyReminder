# EasyReminder

A native macOS / iOS / iPadOS app that bridges **`.ics` files** with Apple's **Reminders and Calendar** — to-dos (VTODO) import into Reminders, calendar events (VEVENT) import into Calendar, and both directions export back to `.ics`. Notably, it fills a real system gap: iOS has **no native way to import VTODO tasks into Reminders** (mixed files even drop them silently).

> 一个把 **`.ics` 文件** 与 Apple **「提醒事项」和「日历」** 双向打通的原生 App（macOS / iOS / iPadOS）：待办（VTODO）导入提醒事项、日历事件（VEVENT）导入日历，两者也都能导出回 `.ics`。它补上了一个真实的系统空白——iOS 上**没有**任何原生途径把 VTODO 待办导入「提醒事项」（混合文件里的待办甚至会被系统静默丢弃）。

## Features

- **Import** `.ics` → to-dos become Reminders (pick / create a list), events become Calendar events (pick / create a calendar) — with correct **TZID time zones** and full **RRULE** recurrence (BYDAY/BYMONTHDAY/BYMONTH/BYSETPOS)
- **Open With / Share Sheet / Drag & Drop** — open `.ics` files with the app (Finder, Files, Mail attachments), or drag them onto the window
- **Honest fallback** — fields EventKit can't store (subtasks, tags, attachments, attendees, EXDATE…) and skipped blocks (recurrence overrides, cancelled events) are reported, never silently dropped
- **Export** — from Reminders (list or smart filter) *or* from Calendar (calendar + date range; repeating events export as rules) → multi-select items → write `.ics`; on iOS also share directly (AirDrop / Messages / Mail)
- **Dedup** — re-importing the same file offers "import all / only new"; Shortcuts automations skip previously imported items
- **Shortcuts** — Import ICS, Export ICS (Reminders), Export Calendar ICS; **CLI** — `easyreminder import/export/export-events`
- **Localized** in 简体中文 / English / Español

## Requirements

- macOS 14.0+ / iOS 17.0+ (iPadOS 17.0+)
- Reminders & Calendar full-access permissions (requested on first use)

## Install

- **App Store (macOS & iOS)**: [EasyReminder on the App Store](https://apps.apple.com/app/id6789404034)
- **Direct download (macOS)**: notarized `EasyReminder.app` with built-in auto-update, from [Releases](https://github.com/Jason25417/EasyReminder/releases)

### Build from source

The `main` branch uses the new Xcode project format — requires **Xcode 27**. Open `EasyReminder.xcodeproj`, select the `EasyReminder` scheme, and run (⌘R). Core logic lives in the local Swift package `EasyReminderKit/` (pure Foundation): `cd EasyReminderKit && swift test`.

## Architecture

Layered MVVM + service layer: `View → ViewModel (@Observable) → Service (protocol) ← EventKit implementation`. Models, ICS parser/exporter, and the Reminders/Calendar services live in the local Swift package **`EasyReminderKit`**; the app target is a thin UI shell, and the GUI, CLI, and Shortcuts all share the same engine. Platform differences are handled with compile-time guards — every Swift file is identical across the macOS-direct and App Store branches.

## Privacy

EasyReminder talks only to your local Reminders / Calendar database via EventKit; it does not send your data anywhere. Some fields are private to Apple or unsupported by EventKit (subtasks, tags, flags, attachments, attendees, …) — these are parsed but skipped on import, and the app tells you exactly what was skipped. See [PRIVACY.md](PRIVACY.md).

## License

[MIT](LICENSE) © 2026 Jason Tu (屠苏)

## Support · 赞助

If you find EasyReminder useful, you can support development on [爱发电 (afdian)](https://afdian.com/a/Jason25417). Thank you!
