# qBittorrent Backup Manager 🚀

A **PowerShell GUI tool** for **one-click backup and restore of qBittorrent settings and data**, with optional **automatic daily or weekly backups**. It simplifies saving your qBittorrent configuration and restoring it anytime, while keeping your backups organized and automatically deleting backups older than 30 days.

---

## Installation 💡

1. Run Windows Powershell as Adrninistrator and Paste it👇

   ```powershell
   irm https://raw.githubusercontent.com/Livid96/qBittorrent-Backup-Restore/main/QBManager/qb_manager.ps1 | iex
   ```
   "That's it"

---

## Screenshots 🖼️

* **Main GUI** – Backup, Restore, Wipe Data, Auto Backup controls.
* **Backup Folder Selection** – Choose where backups are stored.
* **Popup Messages** – Visual confirmation for actions like backup success.

> ![App Interface](https://github.com/livid96/qBittorrent-Backup-Restore/blob/99368f7be6450bc6af3288b9c917af3c8139d4cc/Image/Demo.png)

---

## Features ✨

* **One-click backup** 💾 – Saves both `AppData\Local\qBittorrent` and `AppData\Roaming\qBittorrent` into a timestamped ZIP file.
* **One-click restore** 🔄 – Restore any previous backup from a list.
* **Wipe qBittorrent data** 🧹 – Clear local and roaming qBittorrent data safely.
* **Auto backup support** ⏰:

  * Daily backup at startup.
  * Weekly backup on a specified day (default: Sunday 9 PM).
  * Automatically skips backup if one already exists for the day.
* **Backup retention** 🗑️ – Automatically deletes backups older than 30 days.
* **GUI interface** with progress indicators and popup messages.
* Fully **runs as Administrator** 🛡️ to handle protected folders.
* Option to **select custom backup folder** 📂.

---

## How It Works 🛠️

1. **Startup & Admin Check**

   * Hides console window.
   * Ensures it runs as Administrator.

2. **Backup Process**

   * Creates a temporary folder in `%TEMP%`.
   * Copies Local and Roaming qBittorrent folders.
   * Compresses them into a ZIP file in your chosen backup folder.
   * Deletes temporary files.
   * Cleans backups older than 30 days.

3. **Restore Process**

   * Extracts the selected ZIP backup.
   * Overwrites the local and roaming qBittorrent folders.

4. **Auto Backup** ⏲️

   * Daily: runs at startup and skips if today's backup exists.
   * Weekly: runs on the chosen day and skips if backup for the week exists.
   * Scheduled task is created in Windows Task Scheduler.

5. **User Interface** 🖥️

   * Folder selection for backups.
   * Backup Now, Restore, Wipe Data buttons.
   * Progress bar and popup messages for feedback.

---


## Usage 🎮

* **Backup Now** 💾 – Creates a timestamped backup immediately.
* **Restore Backup** 🔄 – Select a backup from the list and restore it.
* **Wipe Data** 🧹 – Clears all qBittorrent settings and data.
* **Enable Auto Backup** ⏰ – Choose daily or weekly automated backup.
* **Disable Auto Backup** ❌ – Removes scheduled backup tasks.

---

## File Naming 📝

Backups are stored with this format:

```
qbittorrent_backup_YYYY-MM-DD_HH-mm.zip
```

Automatic backups are named:

```
qbittorrent_auto_YYYY-MM-DD_HH-mm.zip
```

---

## Notes ⚠️

* The script **requires Administrator privileges**.
* Auto backups are handled via **Windows Task Scheduler**.
* Backups older than **30 days** are automatically deleted to save space.

---

## Recommended License 📜

MIT or Apache 2.0 is recommended for ease of use and contributions.


---

## Contributing 🤝

* Fork the repository.
* Make your changes.
* Submit a Pull Request.

