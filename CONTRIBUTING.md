# Contributing

Thanks for taking an interest in InputPilot. Bug reports, ideas, and pull requests are all welcome.

## Reporting bugs

Open an issue with the [bug report template](https://github.com/LucaGerlich/InputPilot/issues/new/choose). The single most useful thing you can attach is an exported debug log: menu bar icon → **Open Debug** → reproduce the problem → **Export…**. It contains device and status information only, never anything you typed.

Please include your macOS version, the InputPilot version (Settings → About), and which keyboards are involved — device-identity behaviour varies a lot between USB, Bluetooth, and built-in keyboards.

## Development setup

You need **Xcode 26** or newer.

```bash
xcodebuild -scheme InputPilot -destination 'platform=macOS' build test
```

One thing that will confuse you otherwise: an app launched from Xcode runs under the debugger, and macOS attributes Input Monitoring to **Xcode**, not to InputPilot. Anything touching the permission flow has to be tested with a build launched from Finder.

## Pull requests

- Branch from `main`, keep commits small and coherent, and use `feat:` / `fix:` / `docs:` / `chore:` prefixes.
- CI runs build and tests on every pull request; it must be green.
- Add tests for logic changes. `AppState` and the services are protocol-injected precisely so behaviour can be tested without HID hardware — see `InputPilotTests/ServiceMocks.swift`.
- Some areas cannot be covered by automated tests: the permission flow, the release pipeline, and anything TCC-related. If you touch those, say in the pull request how you verified it manually.

## Things worth knowing before you change them

**Device identity.** Keyboards are matched on vendor, product, transport, built-in status, and normalized product name, with location as a tie-breaker. `KeyboardDeviceKey.id` is the key under which mappings are persisted, so changing how it is composed silently breaks every existing user's configuration.

**Switch timing.** Debounce and cooldown live in `SwitchController` behind an injectable clock. Changes there should come with tests using `ControlledClock` rather than sleeps.

**Privacy.** The HID callback deliberately extracts only the device and a modifier flag. Please keep it that way; see [SECURITY.md](SECURITY.md).

## Releases

Releases are cut by the maintainer with `Scripts/release.sh`, which requires a Developer ID certificate, notarytool credentials, and the Sparkle signing key. Contributors do not need any of that.
