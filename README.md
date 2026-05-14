# File-Deselector

A macOS background utility that automatically deselects PDF and video files in Finder whenever you switch away from it — preventing Quick Look from locking those files and blocking other apps from accessing them.

## What it does

When you switch away from Finder, any selected PDFs or video files are silently deselected. This stops Quick Look from holding file handles open, which can block Premiere, After Effects, and other apps from accessing the same files.

**Handled file types:** `.pdf` · `.mp4` · `.mov` · `.avi` · `.mkv` · `.m4v` · `.wmv` · `.flv` · `.webm` · `.mpg` · `.mpeg` · `.m2v` · `.3gp` · `.3g2` · `.ts` · `.mts` · `.m2ts` · `.vob` · `.ogv` · `.rm` · `.rmvb` · `.divx` · `.asf`

## Prerequisites

- macOS (tested on macOS 13+)
- Xcode Command Line Tools

Install Command Line Tools if needed:
```bash
xcode-select --install
```

## Install

1. Clone or download this repo
2. In Terminal, drag `install-finder-pdf-deselector.sh` onto the window and press Enter:
```bash
bash /path/to/install-finder-pdf-deselector.sh
```
3. When prompted, grant **Accessibility** permission to the installed binary

If no prompt appears, add it manually:
**System Settings → Privacy & Security → Accessibility → add** `~/bin/finder-pdf-deselector`

The utility runs as a LaunchAgent and starts automatically at login.

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.debruehe.finder-pdf-deselector.plist
rm ~/Library/LaunchAgents/com.debruehe.finder-pdf-deselector.plist ~/bin/finder-pdf-deselector
```
