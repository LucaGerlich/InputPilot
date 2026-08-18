# InputPilot Production-Readiness Audit

Audited: 2026-08-18 · Scope: full repo · Method: 4 specialized reviews (correctness/concurrency, security/privacy, distribution, tests) + empirical verification
Verification baseline: **build ✓ · all 30 tests pass ✓ · no third-party dependencies · security review clean (no keystroke logging, no network calls)**

## Summary

| Severity | Count | Theme |
|----------|-------|-------|
| Critical | 5 | All distribution blockers — none are code bugs |
| High | 5 | 2 code bugs, 3 release infrastructure |
| Medium | 9 | Behavior decisions, metadata, test gaps |
| Low | 4 | Robustness polish |

## Critical — blocks any public release

- [ ] **C1 · No Developer ID certificate / notarization** — only "Apple Development" certs exist on this machine; every downloaded copy will be blocked by Gatekeeper. Needs paid Developer Program cert "Developer ID Application", then `notarytool submit` + `stapler staple`. *Effort: medium*
- [ ] **C2 · No release pipeline** — no CI, no ExportOptions.plist, no DMG/zip packaging, no git tags. Add: archive → Developer ID export → notarize → staple → DMG → tagged GitHub Release. *Effort: large*
- [ ] **C3 · No LICENSE file** — public distribution is legally "all rights reserved". Add MIT/Apache-2.0 or explicit EULA + README section. *Effort: small*
- [x] **C4 · Bundle ID `lucagerlich.InputPilot` is not reverse-DNS** (`project.pbxproj`) — must become e.g. `com.lucagerlich.InputPilot` **before** the first public build; changing later resets users' Input Monitoring TCC grant and UserDefaults. *Effort: small*
- [x] **C5 · `MACOSX_DEPLOYMENT_TARGET = 15.7`** — excludes macOS 13, 14, and 15.0–15.6 users. MenuBarExtra needs only 13.0; verify API floor and lower. *Effort: medium*

## High

- [x] **H1 · Stale `currentInputSourceId` breaks switch decisions and Undo** — `AppState.swift:14,528-533,675-695`. No `kTISNotifySelectedKeyboardInputSourceChanged` observer; cache refreshes at most every 6 s. Manual source change → next keypress compares against stale value → switch wrongly suppressed, and Undo can record the wrong "previous" source. Fix: force-read `currentInputSourceId()` before evaluating, or observe the TIS distributed notification. *Effort: medium*
- [x] **H2 · Silent decode failure wipes all mappings on next write** — `MappingStore.swift:119,141-164`. Undecodable stored data → `loadConfigurations()` returns `[:]` silently → next `setMapping` overwrites the blob, destroying every other device's config. Fix: log the failure, back up raw data to a `.corrupted` key, refuse blind overwrite. *Effort: small*
- [ ] **H3 · No update mechanism** — direct-download users are stranded on v1.0 forever. Integrate Sparkle 2 (or minimum: in-app "check latest release" link). *Effort: medium*
- [x] **H4 · Repo hygiene** — no `.gitignore`; `xcuserdata`/`UserInterfaceState.xcuserstate` tracked (leaks local usernames, perpetual dirty diffs); untracked `build/` + `.DS_Store`. Fix: add Swift/Xcode .gitignore, `git rm -r --cached` the user files. *Effort: small*
- [ ] **H5 · No shared Xcode scheme** — schemes live only in per-user xcuserdata; CI and other machines cannot run the documented `xcodebuild -scheme InputPilot` commands. Mark scheme Shared and commit it. *Effort: small*

## Medium

- [x] **M1 · Modifier-only keypress triggers a real switch** — `SwitchController.swift:128-131`. `sawNonModifierKeyDown` is tracked but only selects a log label; it never gates the switch. Lone Shift/Cmd (e.g. during Cmd+Tab) fires a switch after the 400 ms debounce. Decide intended behavior and wire the flag into `flushPending`. *Effort: small*
- [x] **M2 · No HID device-removal callback** — `HIDKeyboardMonitor.swift`. Unplugged keyboard stays displayed as active until another key event arrives. Register removal callback or label the UI "last seen". *Effort: medium*
- [x] **M3 · Missing VID/PID defaults to 0** — `HIDKeyboardMonitor.swift:106-113`. Two metadata-less virtual/composite keyboards collide into one fingerprint and share a mapping. Treat missing IDs as unidentified (`Int?`), exclude from primary-match canonicalization. *Effort: medium*
- [x] **M4 · No `NSInputMonitoringUsageDescription`** — System Settings shows no justification for the scariest macOS permission. Add `INFOPLIST_KEY_NSInputMonitoringUsageDescription`. *Effort: small*
- [ ] **M5 · App icon set 8/10 slots empty** — 16pt slot is a leftover `AppIcon-11 (verschoben).png`; dead unreferenced `AppIcon.dataset/AppIcon.icns`. Regenerate all sizes from the 1024px master; delete strays. *Effort: small*
- [x] **M6 · Uncommitted About/Settings work + release TODO** — `SettingsView.swift` modified, `AboutSection.swift` untracked, `AboutSection.swift:10` TODO: verify links; `supportEmail` is blank (no user contact channel). Finish, resolve TODO, commit on dev branch. *Effort: small*
- [x] **M7 · Empty `NSHumanReadableCopyright`, no `LSApplicationCategoryType`** — Finder Get Info shows nothing. Set copyright + `public.app-category.utilities`. *Effort: small*
- [ ] **M8 · README wrong/incomplete for end users** — says "Xcode 15+" but project format requires Xcode 26.x; no Install/Download section, no Gatekeeper note, no license section. *Effort: small*
- [x] **M9 · Zero failure-path test coverage** — permission denied/revoked transitions, HID start failure (`startResult=false` never exercised), `selectInputSource` failure, corrupt-UserDefaults recovery: all 0 %. Mocks exist for each — the hooks are unused. Also: `InputPilotTests.swift` is an empty template (delete), UI test target is stock boilerplate. *Effort: medium*

## Low

- [x] **L1 · `unsafeBitCast` on TIS properties** — `InputSourceService.swift:91-97`. Empirically verified safe (200k iterations, retain count stable 3→3, no crash) but relies on unspecified behavior; switch to `Unmanaged.fromOpaque(raw).takeUnretainedValue()` for the documented contract. *Effort: small*
- [x] **L2 · Force cast `$0 as! TISInputSource`** — dismissed: CF casts are unchecked at runtime (compiler: conditional cast "always succeeds"), so `as?` adds a warning and no safety. Documented with a comment instead.
- [x] **L3 · Test infra nits** — `MockMappingStore.validateMappings` doesn't replicate real sort order; `waitForSleepRegistration` uses a magic 20-yield heuristic instead of a condition-driven wait. *Effort: small*
- [ ] **L4 · No crash reporting** — optional; the existing privacy-first log export + a GitHub issue template asking for it is a reasonable substitute. *Effort: medium*

## Verified good

- Hardened runtime ON, sandbox correctly OFF for IOHID, `LSUIElement` menubar-only — notarization prerequisites already in place
- Privacy: no keystroke content ever leaves the HID callback (only a boolean `isModifier`); debug log is in-memory, capped at 200 entries, with token redaction defense-in-depth; export/clipboard only on explicit user action; no network calls, no telemetry, zero dependencies
- Concurrency architecture sound: `@MainActor` isolation, HID→main hops, weak captures — no data races or retain cycles found
- Test isolation exemplary (fresh `UserDefaults` suites, no pollution); debounce/cooldown algorithm well tested; full suite green
- README honest and accurate to the code; all UI strings English; version display reads from bundle so it always matches build settings

## False positives (investigated, dismissed)

- L2: `as?` on CF types is not checkable at runtime; the force cast is the idiomatic, non-trapping form.

- "CF over-release in `propertyValue(for:key:)` will crash the app" — disproven empirically; see L1.
