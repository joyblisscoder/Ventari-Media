# Ventari Media

**Loom sucks.**

Nobody should have to pay **$200 a year** just to record their own screen, unlimited, with a circle of their face in the corner. That is your computer. That is your camera. That is your voice. Subscription-for-a-webcam is not a product. It is a hostage note.

**Freedom to screen recording!**

[ventari.media](https://ventari.media) is home. The V in the app is a button. Click it — Mac, Windows, or phone — and you land on the site.

This repo is the **native macOS recorder**. It does the part you actually wanted:

- one screen at a time (all of your displays, pick one)
- a **draggable circular camera bubble**
- **3 · 2 · 1** countdown on the screen you chose
- optional mic (MacBook mic by default, switch anytime)
- **name the file before it saves**
- H.264 + AAC `.mp4` on your **Desktop**, ready for YouTube

No account. No cloud. No “you have 25 minutes left this month.” The file is on your machine when you hit Save.

<p align="center"><a href="https://ventari.media"><img src="Resources/Logo.png" width="96" alt="Ventari Media — ventari.media" /></a></p>

<p align="center"><strong>Freedom to screen recording!</strong><br /><a href="https://ventari.media">ventari.media</a></p>

---

## Why this exists

Screen recording with a face cam is not a SaaS. It is a rectangle, a circle, and a microphone.

Loom (and friends) wrapped that in a login wall, a seat license, and a yearly invoice. Fine if you want their sharing graph. Not fine if you just need a video of you talking over a browser tab.

Ventari Media is the version that lives on your Dock, uses Apple’s capture APIs, and gets out of the way.

Not affiliated with Loom. We just think charging rent on a screen recorder is a bit much.

---

## Mac and Windows

| | |
| --- | --- |
| **macOS 14+** | Native app in this repo. `make install` puts **Ventari Media** on the Desktop and in `/Applications`. |
| **Windows** | [ventari.media](https://ventari.media) is the same brand on any Windows browser. The clickable V in the Mac app opens that URL. A native Windows recorder is not in this release — the site is. |

Releases: [GitHub Releases](https://github.com/joyblisscoder/Ventari-recorder/releases)

---

## What it does

| You want | It does |
| --- | --- |
| Record **one** of several monitors | Pick it from the Screen menu |
| Face in a circle, Loom-style | Drag the bubble **before, during, and after** a take |
| Hide the camera | Toggle **Camera overlay** |
| Talk over the video | Toggle **Microphone**, pick any input |
| Not jump-cut into the take | **3-2-1** on the chosen display, then it rolls |
| A real filename | Stop → name it → Save. Or Don’t Save. |
| Upload to YouTube | Desktop `.mp4`, H.264 video, AAC audio |
| Keep the control panel out of the video | The app window is not captured. The bubble is. |
| Find Ventari | Click the **V** → [ventari.media](https://ventari.media) |

The orange-gold background on the Record window keeps moving — a continuous fade, no hard color bands. Reduce Motion in System Settings keeps it still.

---

## How it works

Short version: **the camera is a real window.** You drag it. macOS records the display, including that window.

```
┌─────────────────────────────────────────┐
│  Chosen display                         │
│                                         │
│                         ╭─────╮         │
│                         │ you │  ← bubble you can drag
│                         ╰─────╯         │
└─────────────────────────────────────────┘
        │
        ▼
  ScreenCaptureKit  +  optional mic
        │
        ▼
  temp .mp4  →  you name it  →  ~/Desktop
```

Under the hood, on macOS 14+:

1. **ScreenCaptureKit** captures the display you picked, cursor included, at the display’s real pixel size.
2. **AVFoundation** runs the FaceTime camera into a circular floating panel (gold ring, mirrored preview). The panel is a normal shared window, so it is in the recording wherever you parked it.
3. The control window and the countdown use `NSWindowSharingNone`, so they never appear in the file.
4. Hit Record → countdown on that screen → capture starts. Hit Stop → writer finishes a temp file → **name sheet** → move to Desktop as `Your Title.mp4`.
5. Audio is AAC 128k mono when the mic is on. Video is H.264.

---

## Use it

1. Double-click **Ventari Media** (after `make install` it is on the Desktop and in `/Applications`).
2. Grant **Screen Recording**. Camera and mic if you want those.
3. Pick a screen. Drag your face where it belongs.
4. **Record**. Wait through 3-2-1. Do the thing.
5. **Stop**. Name the video. Save.

Click the **V** anytime to open [ventari.media](https://ventari.media).

First launch on a new Mac: System Settings → Privacy & Security → Screen & System Audio Recording → enable Ventari Media. If macOS says quit and reopen, do that once. After that it sticks.

---

## Build

macOS 14+, Apple Command Line Tools, `clang` and `make`.

```sh
git clone https://github.com/joyblisscoder/Ventari-recorder.git
cd Ventari-recorder
make
make install
```

That builds `Ventari Media.app` and copies it to `/Applications` and `~/Desktop`.

```sh
make tests    # compositor unit test
make run      # install + open
make clean
```

Signing defaults to **ad-hoc** so anyone can build. To sign with your identity:

```sh
make SIGN="Apple Development: Your Name (TEAMID)"
```

---

## Permissions

| Permission | When |
| --- | --- |
| Screen Recording | Required to capture a display |
| Camera | Only if the bubble is on |
| Microphone | Only if audio is on |

Nothing leaves the Mac except when you click the logo (opens [ventari.media](https://ventari.media) in your browser). No analytics, no account, no upload unless **you** upload the file.

---

## Project layout

```
App/           native AppKit + ScreenCaptureKit + AVFoundation
Resources/     icon, logo, optional Horizon wordmark
Tests/         compositor checks (no camera required)
Makefile       build, install, tests
```

---

## License

[MIT](LICENSE). Record your screen. Keep the file. Don’t send Loom a birthday card.

**Freedom to screen recording!**

[ventari.media](https://ventari.media)
