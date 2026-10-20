# PointerDrop

Very simple app made in few hours.
Record clicks. Schedule them. They replay on their own.

## Use

1. **Record** — click through the steps you want to repeat, then **Stop**.
2. **Schedule** — pick a date and time, or 1h / 2h / 4h / 8h from now.
3. **Save** — keep a recording to reuse later.
4. **Log** — after a run, the menu bar shows a green check. Open it to see a screenshot of each click.

**Block clicks** — when on, hold Option while recording to capture a click without sending it.

## Requirements

- Apple silicon, macOS 27
- Accessibility and Screen Recording permission
- Mac awake and unlocked at run time. The app keeps it awake while a run is scheduled.

## Install

1. Download the DMG from [Releases](../../releases) and drag PointerDrop to Applications.
2. The app is not notarized. On first launch open **System Settings → Privacy & Security → Open Anyway**, or run:
   ```
   xattr -dr com.apple.quarantine /Applications/PointerDrop.app
   ```
3. Grant Accessibility and Screen Recording, then relaunch.

After an update, macOS treats the new build as a different app. Remove PointerDrop from both permission lists and add it again.

Check the download:

```
shasum -a 256 -c PointerDrop-<version>.dmg.sha256
```

## Build

Open `PointerDrop.xcodeproj` in Xcode and run.

## Release

Push a tag. GitHub Actions builds the app, packs it into a DMG and publishes a release.

```
git tag v1.0.0
git push origin v1.0.0
```

Tags look like `v1.2.3`. `v1.2.3-beta.1` is published as a pre-release. To test the build without a release, run **Release** from the Actions tab and download the DMG artifact.

Locally: `scripts/make-dmg.sh path/to/PointerDrop.app 1.0.0 dist`. `scripts/make-icon.swift` redraws the app icon.
