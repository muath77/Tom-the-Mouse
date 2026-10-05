# Tom the Mouse

Free macOS middle-button gestures and scroll-wheel reversal, created by **Muath Fathi Hussin Souki**.
No trial, payment, subscription, account, analytics, or network connection.

Hold your mouse's scroll wheel, drag in a direction, then release to act:

| Direction | Action |
| --- | --- |
| Left | Previous desktop |
| Right | Next desktop |
| Up | Mission Control |
| Down | Current app's windows (App Exposé) |

A short wheel click remains a normal middle click, delivered when you release.
Each hold fires one gesture. Pause from the menu bar, change the drag distance,
reverse horizontal direction, or exclude apps that need their normal mouse behavior.
Holding Shift, Control, Option, or Command **before pressing** bypasses gestures.

Enable **Reverse scroll wheel (up/down)** in the settings window to flip your
mouse wheel independently of desktop gestures. This option is off by default,
stays active when gestures are paused, and respects app exclusions. Trackpad,
momentum, horizontal scrolling, and scrolling while holding a modifier stay
unchanged. Smooth mouse drivers that emit continuous scrolling are also left
unchanged.

This is an independent implementation of desktop gestures using public macOS
APIs, not a fork of Mac Mouse Fix. It does not reproduce animated trackpad swipes
or smooth scrolling. The pointer stays in place while Tom measures relative mouse movement. Actions run on release, after the physical middle button is up.

## Install

Requires macOS 13 Ventura or later, on Apple Silicon or Intel.

1. Download `Tom-the-Mouse-macOS.zip` from your chosen release.
2. Unzip it and move **Tom the Mouse.app** into Applications before enabling permissions.
3. Open the app and click **macOS permission…**. Enable Tom the Mouse in
   Privacy & Security → Accessibility. On newer macOS versions this may be named
   **Device Control and Data Access**. This access lets the app intercept the
   middle mouse button, reverse wheel events, and send system keyboard shortcuts. Keyboard presses
   are not monitored or stored by this app.
4. Under System Settings → Keyboard → Keyboard Shortcuts → Mission Control,
   enable these shortcuts:
   - Move left a space: Control + Left
   - Move right a space: Control + Right
   - Application windows: Control + Down
   The upward gesture opens Mission Control directly.
5. Create at least two desktops in Mission Control for horizontal switching.
6. Quit or disable other utilities that remap middle clicks. Press the wheel in
   Tom the Mouse's settings; the button test should report **Middle button detected**.

If permission is enabled but the listener cannot start, quit and reopen Tom the Mouse. If a gesture is detected but macOS does nothing, check the shortcuts.
Some mouse drivers reassign the wheel press to a different action; configure
your mouse to send a normal middle click. The app intercepts button number 2,
so it also works with another device emitting that same button event.

## Build and test

Install Apple's Command Line Tools (`xcode-select --install`) or Xcode and accept
Apple's license yourself. No third-party dependencies are needed.

```sh
bash test.sh
bash build.sh
```

The build produces a universal Apple Silicon/Intel app and ZIP in `build/`.
The executable has a local ad-hoc signature. Building from source does not
require a paid Apple developer account.

## Publish for everyone

Create a public GitHub repository and upload this source directory. Keep the
LICENSE and credits. Push a version tag such as `v1.1.0` to run the included
workflow; it builds, tests, and attaches the app ZIP to a draft GitHub release.
Review it and publish the draft yourself. GitHub Actions availability depends
on your account's settings and limits.

For convenient downloads without Gatekeeper warnings, sign the app with your
own Developer ID Application certificate and notarize it with Apple before
release. The included build uses an ad-hoc signature and is **not notarized**;
downloaded builds can be blocked by Gatekeeper. Apple Developer ID distribution
requires your own developer membership. The app itself remains free.

## Privacy

The event tap observes middle-button down, drag, and up events, wheel events, and pointer movement as a fallback for mouse drivers. Ordinary pointer movement is passed through immediately unless a middle-button gesture is active.
No keyboard, screen, file, clipboard, or network data is collected. When an
app exclusion is checked, the frontmost app's bundle ID is read in memory.
Preferences are stored locally in UserDefaults. No data is transmitted.

## Validation

The automated checks cover click jitter, diagonal intent, all directions, one action per
hold, repeated holds, reversed motion, negative display coordinates, and accumulated
relative movement while the visible pointer stays still. Scroll tests verify all
three vertical delta formats, both directions, horizontal preservation, the
off switch, modifier bypass, and continuous/phase event preservation.
Full gesture behavior also requires a manual test on macOS with the permission
enabled. Test normal clicks, tab opening, all four gestures, pause during a hold,
modifier bypass, app exclusions, multiple displays, and sleep/wake before a
public release. The full desktop integration is not claimed by unit tests.

## License

MIT. You can use, share, modify, and redistribute it for free. The MIT license
also allows commercial reuse; this project's release is offered at no charge.

## Action troubleshooting

If the button counter changes but a gesture has no effect, try the four Test buttons in the app. Mission Control opens directly; the other three actions send a complete Control-key shortcut. Actions run after releasing the wheel. Disable Mac Mouse Fix with its **Enable Mac Mouse Fix** checkbox—closing its window does not disable its helper.
