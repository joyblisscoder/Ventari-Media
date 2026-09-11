# Contributing

Ventari Media is a small native Mac app. Keep it that way. The V opens https://ventari.media.

## Setup

Command Line Tools, not full Xcode:

```sh
make
make tests
make install
```

Ad-hoc sign is the default. Pass `SIGN="Your Identity"` if you have a certificate.

## Rules of the road

- macOS 14+ only. ScreenCaptureKit is the capture path.
- The camera bubble is a real window. Do not go back to post-compositing a face onto frames unless you are fixing a capture bug.
- The control window and countdown must not appear in recordings (`NSWindowSharingNone`).
- No accounts, no network, no analytics.
- Match Ventari’s dark OS look: near-black, gold `#ffaa00`, orange `#ff5000`.

## Tests

`make tests` runs a pixel-buffer compositor check. It does not need a camera or screen permission.

If you change capture or save behavior, say how you verified it (a short recording on one display is enough).
