# EasyReminder

A native macOS app that bridges **`.ics` (VTODO) files** and Apple's **Reminders** — import an `.ics` to create reminders, export reminders back to `.ics`, and open `.ics` files directly with the app.

> 一个把 **`.ics`(VTODO)文件** 与 macOS **「提醒事项」** 双向打通的原生 App:导入 `.ics` 建提醒、把提醒导出为 `.ics`、并支持用本 App 直接打开 `.ics`。

## Features

- **Import** `.ics` → creates lists & reminders in Reminders (via EventKit)
- **Open With** — set EasyReminder as the handler for `.ics`, double-click to import
- **Fields**: title, notes, due / start, priority, completion, URL, alarms (time / location), recurrence (RRULE)
- **Export** — pick a list or smart filter → choose items → write `.ics`

## Requirements

- macOS 14.0 (Sonoma) or later
- Reminders full-access permission (requested on first use)

## Install

### Download (recommended)

Grab the notarized `EasyReminder.app` from the [Releases](https://github.com/Jason25417/EasyReminder/releases) page, move it to **Applications**, and open it.

### Build from source

Requires **Xcode 27** (the project uses the new project file format). Open `EasyReminder.xcodeproj`, select the `EasyReminder` scheme, and run (⌘R).

## Architecture

Layered MVVM + service layer: `View → ViewModel (@Observable) → Service (protocol) ← implementation`. ICS parsing/export and the EventKit bridge live under `Services/`, behind protocols — the UI never imports system frameworks directly. The Models + Services layer is intentionally UI-agnostic so it can later be factored into a reusable Swift package.

## Privacy

EasyReminder talks only to your local Reminders database via EventKit; it does not send your data anywhere. Some Reminders fields are private to Apple (subtasks, tags, flags, attachments, …) and cannot be written through EventKit — these are parsed but skipped on import.

## License

[MIT](LICENSE) © 2026 Jason Tu (屠苏)

## Support · 赞助

If you find EasyReminder useful, you can support development on [爱发电 (afdian)](https://afdian.com/a/Jason25417). Thank you!
