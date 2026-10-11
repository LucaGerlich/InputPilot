# InputPilot Post-Launch Audit

Audited: 2026-10-11 · Scope: `main` @ `7574e1a` (v1.0.1, live since 2026-08-18), the website, the release pipeline, the Homebrew tap, and public reach
Method: 5 parallel reviews (correctness/concurrency, security/privacy/claims, distribution/release, tests/coverage, UI/first-run), then every High and most Medium findings re-verified against the code by hand. Discoverability was measured directly (GitHub API, web search, competitor data).

Verification baseline: **build ✓ · 35 unit + 2 UI tests pass ✓ · stable over 100 runs and under CPU load ✓ · shipped DMG verified (sha256 = cask = release asset, Developer ID, notarized, stapled, EdDSA signature valid) ✓ · line coverage 48.9 % ✗**

Previous audit: [pre-release-audit.md](pre-release-audit.md) (23 findings, all resolved before 1.0.0).

## Resolution status (2026-10-11)

Fixed in three pull requests and shipped as **1.1.0**: [#13](https://github.com/LucaGerlich/InputPilot/pull/13) (public claims, log flood, F6), [#14](https://github.com/LucaGerlich/InputPilot/pull/14) (the 1.1.0 product work), and the release-hardening PR that adds this section. Ticked boxes below are resolved. Unit tests went from 35 to 69, all written test first.

- **Partly done:** T1's coverage target (logic is tested; SwiftUI views stay low by design). L9: the always-true assertion and the empty UI test are fixed, but the test host still boots the real app. L12: the team is asserted and the DMG identifier is fixed, but the notary log is not fetched. L14: AppState is 1,150 lines, still over the 800-line limit. L15: gitignore and entitlement are fixed; stale branches remain. M2: signed feed done; branch protection on `main` is pending Luca's go-ahead.
- **Needs a human at the hardware:** P4 with Karabiner-Elements actually installed, and the per-policy check with two keyboards.
- **Needs Luca (DNS, payment, accounts, his voice):** R1 launch, R2 Search Console and Bing, R3 AlternativeTo and the awesome-list PRs, R4 repo metadata, M12 Pages domain verification, L11 the cask's `uninstall quit:` (done at release time in the tap repo).
- **Deferred on purpose:** L2 CJK activation (needs a repro), L3 refusing a blind overwrite, L4 the blocking permission request, L8 Swift 6 mode, L13 Sparkle 2.10, and before-keypress switching (it would need the Accessibility permission, a separate product decision).

## Summary

The shipped artifact is sound, and the privacy core holds up: nothing derived from a keystroke reaches the log, storage, clipboard or network. The problems fall into three groups:

1. **Nobody is finding it.** In 8 weeks: 8 DMG downloads, 0 stars, 0 issues. The launch was never carried out, and the site isn't in the search index. Meanwhile a direct competitor, Keychange (public 3 weeks earlier), has about 5,900 downloads.
2. **Gaps a first-time user hits in the first hour:**
   - no launch at login;
   - a manual layout change is undone on the next keystroke;
   - after the permission relaunch, nothing tells the user what to do;
   - a single failed keyboard (e.g. Karabiner-Elements) disables everything.
3. **Public claims that the code doesn't back up.** This repeats the precision problem fixed in August. One of the claims is the very sentence that was corrected then.

| Severity | Count | Theme |
|----------|-------|-------|
| High | 7 | 1 reach, 4 first-hour product gaps, 1 false claims, 1 untested regression |
| Medium | 12 | Same-model keyboards, update-feed trust, release script, UI flow |
| Low | 16 | Robustness, CI, hygiene, wording |

---

## Reach and discoverability

### Data (2026-10-11)

| Signal | InputPilot | Keychange (`dennistimmermann/keychange`) |
|---|---|---|
| Public since | 2026-08-18 | 2026-07-29 |
| Downloads | 8 (v1.0.1: 6, v1.0.0: 2) | ~5,900 (v0.11.0 alone) |
| Stars | 0 | 17 |
| Repo views, last 14 days | 4 (2 unique) | — |
| Search: own name | **No result** | Ranks, with AlternativeTo page |
| Search: "mac switch keyboard layout per keyboard" | Absent | #1 recommendation |
| AlternativeTo | Not listed | Listed |
| Launch at login | ✗ | ✓ |
| Switch before keypress | ✗ (400 ms after) | ✓ optional (Accessibility) |
| Respects manual layout change | ✗ (reverts) | ✓ 4 policies |
| macOS floor | **13** | 14 |

Neither big open-source Mac list ([open-source-mac-os-apps](https://github.com/serhii-londar/open-source-mac-os-apps), [awesome-mac](https://github.com/jaywcjlove/awesome-mac)) contains any per-keyboard switcher yet, including Keychange and autokbisw.

### Findings

- [ ] **R1 · High · The launch never happened.** The channel plan from 2026-08-18 (Show HN, r/macapps, Product Hunt, AlternativeTo) was never executed. The on-page SEO is fine (title, description, canonical, OG, JSON-LD, sitemap), but a direct search for the product name and the domain returns nothing. On-page tags do nothing until something links to the page.
  - **Fix order:**
    1. Fix P1–P4 and C1 first. A Show HN thread is a one-shot event, and those are exactly what a commenter would find in the first hour.
    2. Do the zero-cost items below.
    3. Then launch.
- [ ] **R2 · Medium · Not submitted to search engines.** Verify the domain in Google Search Console and Bing Webmaster Tools, then submit `sitemap.xml`. Bing also feeds DuckDuckGo and ChatGPT search. *Needs Luca: a DNS TXT record at Namecheap.*
- [ ] **R3 · Medium · Absent from the pages that already rank.**
  - Add InputPilot on AlternativeTo as an alternative to Keychange and autokbisw, and pay the $5 priority review. "Keychange Alternatives" is itself a ranking result for this niche.
  - Open PRs to both open-source Mac lists, in their input-source sections. InputPilot would be the first per-keyboard switcher in either.
- [ ] **R4 · Medium · Repo metadata works against discovery.**
  - The homepage URL still points to the old `lucagerlich.github.io/InputPilot/` (redirect). Change it to `https://inputpilot.lucagerlich.dev`.
  - The description says "tracks what keyboard you use". For an app that asks for Input Monitoring, that reads like spyware, and it misses the phrase people search for. Proposed: *"Automatic keyboard layout switching for macOS: one input source per physical keyboard, switched as you type."*
  - Add the topics `input-method`, `keyboard-switcher`, `menubar-app` and `multilingual`.
  - Upload a custom social-preview image (1280×640) rendered from the ASCII keyboard. `Scripts/generate-keyboard-art.py` already produces the art. Links shared on HN, Reddit or X currently show GitHub's generic card, and the site's `og:image` is the square icon with `twitter:card=summary`.
- [x] **R5 · Medium · The README doesn't mention Homebrew.** Commit `c651524` ("docs: document Homebrew installation") sits unmerged on `docs/public-polish`. Homebrew users read the README, not the site.
- [x] **R6 · Medium · Positioning ignores the main competitor.**
  - The site's "How is this different from…" FAQ names autokbisw, OctoKeys and Input Source Pro, but not Keychange. Keychange is the one a reader will actually compare against.
  - The honest differentiators today are weak: macOS 13 support, explicit mapping with per-device and global fallbacks, and the debug log.
  - Closing P1 and P2 removes the reasons to pick Keychange instead. Fixing M1 (same-model keyboards) would give InputPilot a real differentiator.
  - Name Keychange in the FAQ. Being named first reads as confidence; being corrected in a launch thread doesn't.

---

## High

- [x] **P1 · No launch at login.** There is no `SMAppService` or login-item code anywhere. After a reboot, switching silently stops until the user starts the app by hand. Every menu bar utility is expected to have this, and Keychange does.
  - Fix: add an "Open at Login" toggle (Settings, plus the final Welcome state) backed by `SMAppService.mainApp.register()/unregister()` (macOS 13+). Show `.requiresApproval` when it applies.
  - *Verified.*
- [x] **P2 · A manual input-source change, Undo, or an IME mode toggle is undone by the next keystroke.**
  - `AppState.swift:745-749` and `:789-794` re-evaluate the mapping on every non-modifier keyDown, reading the current source fresh. The TIS change observer (`:641-650`) only refreshes the display.
  - Effects:
    - a multilingual user who presses ⌃Space to type one word in another language is switched back 400 ms later;
    - "Undo last switch" has no lasting effect (`:363-379`);
    - a keyboard mapped to Kotoeri loses Eisu/Kana, and Caps Lock "switch to ABC" is reverted mid-word.
  - Fix:
    - After a manual change, Undo, or a change not made by InputPilot, suppress auto-switching for that device until the active keyboard changes. That is Keychange's "Ignore" policy and the narrowest fix that keeps H1's fresh-read.
    - Treat input modes of the same input method (same `kTISPropertyBundleID`) as already satisfying the mapping.
  - *Verified.*
- [x] **P3 · The most common first-run path ends with no guidance.**
  - The Welcome window only opens while permission is missing (`InputPilotApp.swift:46`). The typical path is: grant, then macOS asks for "Quit & Reopen". After that relaunch, no window appears. The user sees a keyboard icon, has no mappings, and gets no hint.
  - The relaunch state's only button is "Quit InputPilot" (`WelcomeView.swift:87`). The app has no Dock icon, so it simply disappears.
  - Fix:
    - Persist `hasCompletedOnboarding` and show the Welcome window until it is set.
    - Turn the button into "Relaunch InputPilot".
    - Add "Open Settings" to the final state.
  - *Verified.*
- [x] **P4 · One keyboard that can't be opened disables all monitoring (Karabiner-Elements).**
  - `HIDKeyboardMonitor.swift:53-63` discards the whole manager when `IOHIDManagerOpen` returns any error.
  - Per Apple's IOHIDManager.c, that call returns the first per-device error even though the other devices opened. Karabiner-Elements seizes physical keyboards, so the open returns `kIOReturnExclusiveAccess`. InputPilot then shows "HID monitor start failed with IOReturn -536870203", and its "relaunch" advice can never help.
  - Karabiner users who own several keyboards are a core audience for this app.
  - Fix:
    - Keep the manager when `IOHIDManagerCopyDevices` is non-empty.
    - Map `kIOReturnExclusiveAccess` to "A keyboard is held exclusively by another app (e.g. Karabiner-Elements)".
    - Document the interaction.
  - *Code path verified; the IOKit behaviour comes from Apple's source; not reproduced with Karabiner installed.*
- [x] **C1 · Public claims the code contradicts.** The product's pitch is precision about the scariest macOS permission. The verified false sentences:

  | Where | Says | Reality | Replace with |
  |---|---|---|---|
  | `docs/index.html:202` (JSON-LD `featureList`, the text search engines quote) | "Reads only the source device and modifier flag, **never key codes** or typed text" | `HIDKeyboardMonitor.swift:108` reads the usage code. This is the exact claim corrected on 2026-08-18. | "Reads the source device and a modifier flag; the key's usage code is checked only to detect modifiers and is never stored, logged or transmitted" |
  | `WelcomeView.swift:35`, shown at the moment of trust | "Nothing leaves your Mac." | Sparkle checks GitHub automatically every day (`SUEnableAutomaticChecks`=true) | "Nothing you type leaves your Mac. The only network request is a daily update check." |
  | `docs/index.html:497`, `CHANGELOG.md:27` (`README.md:40` is already accurate) | "Modifier-only presses are ignored, so ⌘-Tab never changes your layout" | Tab is not a modifier; ⌘-Tab on the other keyboard switches | "Modifier-only presses (a lone ⇧ or ⌘) are ignored; any other key, including the Tab in ⌘-Tab, counts as typing on that keyboard." |
  | `docs/index.html` FAQ ("German external keyboard…") | "the layout is right **the moment you start typing**" | The switch fires 400 ms after the first keypress, so the first character or two land in the old layout | "within half a second of the first key press" |
  | `CHANGELOG.md:29` | "over a signed appcast" | Only the enclosure is EdDSA-signed; the feed is not (see M2) | "every update archive is EdDSA-signed and verified before install" |
  | `SECURITY.md:24` | "…and Apple's notarization of the downloaded app" | Sparkle checks EdDSA plus the code signature, not notarization | "Sparkle verifies an EdDSA signature over the archive and that the new app is code-signed by the same Developer ID team. Each release is also notarized." |
  | `docs/pre-release-audit.md:8` | "user-initiated update checks are now the app's only network activity" | Checks are automatic | Add a correction note |

  Wording cleanups (true, but easy to quote against you):
  - "never reads what you type" sits next to "the usage code is read": say "never **records** what you type".
  - `SECURITY.md:12`: the usage code "is never assigned", yet it is assigned to a local constant.
  - `SECURITY.md:18`: describes redaction "at export"; in fact a 5-word filter runs when each entry is recorded.
  - `SECURITY.md:16`: the storage list ends "That is all" but leaves out the flags, the fallbacks, the `.corrupted` backup and Sparkle's keys.
  - "read every line of the thing you are granting access to": Sparkle runs in the same process, so add "plus the open-source Sparkle framework".
- [x] **T1 · The v1.0.1 first-run fix has no regression test, and coverage is 48.9 %.**
  - Mutation check: removing `openWindow(id: "welcome")`, or making `requestInputMonitoringPermission()` never call `IOHIDRequestAccess`, leaves all 35 tests green. That is exactly the 1.0.0 failure, where no new user could grant the permission.
  - Overall: 7 of 10 deliberate mutations went undetected.
  - Coverage: overall 48.9 %; testable logic 76.4 %; `HIDKeyboardMonitor` 1.1 %; `SettingsView` 0.3 %. The WelcomeView and InputPilotApp numbers come from the test host booting the real app, not from assertions.
  - Smallest fixes:
    - a unit test from `kIOHIDAccessTypeUnknown` asserting the request count is 1;
    - a UI test asserting `app.windows["Welcome to InputPilot"].waitForExistence(timeout: 5)`. This is deterministic on CI, because ad-hoc-signed builds never hold Input Monitoring.

## Medium

- [x] **M1 · Two keyboards of the same model can't be mapped separately.**
  - `AppState.swift:957-959`: when there is exactly one primary match, the new device is folded into it whatever its LocationID. Example: two Magic Keyboards, one US and one German, share one Settings row and one mapping.
  - The location tie-breaker (`:930-933`) only runs when both keys already exist, which the UI can't produce. The test inserts both directly.
  - Fix: fold only when no currently attached device holds the existing key's location (query `IOHIDManagerCopyDevices`). This keeps "recognised again after moving to another port" working.
  - *Verified.*
- [x] **M2 · Anyone who can push to `main` controls the update dialog.**
  - The appcast is unsigned: neither `SURequireSignedFeed` nor `SUVerifyUpdateBeforeExtraction` is set.
  - It is served from `main`, which is unprotected (`branches/main.protected=false`, no rulesets).
  - Without the EdDSA key nobody can ship a malicious binary. But a stolen GitHub token could put phishing links into the release notes, or add an informational item that opens any URL.
  - Fix:
    - set both keys;
    - add a `sign_update appcast.xml` step to `release.sh` (once enabled, every future feed must be signed or updates stop);
    - protect `main`.
- [x] **M3 · Automatic update checks can't be turned off and aren't disclosed** (see C1). Add a Settings toggle bound to `updater.automaticallyChecksForUpdates`.
- [x] **M4 · Non-keyboard "input sources" can be chosen as mapping targets.**
  - On the audit machine, the enabled-sources query returns Emoji & Symbols, Dictation, PressAndHold and EmojiFunctionRowIM, and all of them appear in the pickers.
  - If one is mapped, `TISSelectInputSource` "succeeds" but the current keyboard source never matches, so the source is re-selected after every 1.5 s cooldown.
  - Fix: filter results to `kTISCategoryKeyboardInputSource`. Also, `listAllInputSources` passes `includeAllInstalled: false`, so conflict rows show raw IDs.
- [x] **M5 · Each release wipes the appcast history and the old dSYMs** (`Scripts/release.sh:78` `rm -rf "$DIST"` before `generate_appcast`).
  - 1.0.0 is already gone from the feed. That means no delta updates, no fallback item once a release raises the minimum macOS, and crash logs from old versions can't be symbolicated.
  - Fix: `cp appcast.xml "$DIST/"` before generating, and keep archives in a git-ignored `releases/$VERSION/`.
  - *Verified.*
- [x] **M6 · A release isn't tied to a pushed commit or tag.**
  - The script doesn't check the branch, that HEAD equals `origin/main`, or that the tag or GitHub release doesn't already exist.
  - Re-running after uploading produces a DMG with a different hash and signature, which mismatches the cask and Sparkle.
  - Fix: add all of these to the preflight checks.
- [x] **M7 · Two security checks in `release.sh` only warn and let the release continue.**
  - An empty `SUPublicEDKey` (`:47`) only prints a warning.
  - A missing `generate_appcast` (`:140-147`) is reported after both notarizations, and the script still prints "Done". The tool is found with an unpinned glob over all of DerivedData, and it reads the EdDSA private key.
  - Fix: make both fatal in preflight, resolve the tool from this project's SourcePackages, and copy the appcast to the repo root.
- [x] **M8 · Windows opened from the menu aren't brought to the front** (`MenuBarMenuView.swift:65, 115, 171`). The app is LSUIElement, so Settings can open behind the frontmost app, with no Dock icon or ⌘-Tab entry to reach it. Fix: call `NSApp.activate(ignoringOtherApps: true)` after `openWindow`.
- [x] **M9 · The core task can't be found from the menu.**
  - The menu has about 20 items, mostly diagnostics (Vendor/Product/Location ID, source IDs).
  - There is no "Typing on X → Not mapped" row. "Settings…" comes after "Quit". Mappings are the 6th section in Settings, below the fold.
  - With only one keyboard attached, nothing explains that the app needs a second one.
  - Fix:
    - show the active-keyboard row first, with "Use current input source for X";
    - move the IDs into Debug;
    - put mappings at the top of Settings and Quit last.
- [x] **M10 · After a denial, the main button does nothing** (`WelcomeView.swift:54-71`). TCC prompts only once. Fix: in the `.denied` state, make "Open System Settings" the default button and change the text to "switch InputPilot on".
- [x] **M11 · The debug log floods while the monitor can't start.**
  - `AppState.swift:684-685` logs the error on every 1 s poll, outside the deduplication check at `:680`.
  - Within about 200 s the 200-entry log, which users are asked to attach to bug reports, contains nothing else.
  - Fix: move both lines inside the `if`.
  - *Verified; three reviewers reported it independently.*
- [ ] **M12 · The GitHub Pages domain is not verified** (`protected_domain_state: null`). If Pages is ever disabled, `inputpilot → lucagerlich.github.io` dangles, and anyone could serve a fake download page that the About screen links to. Fix: verify `lucagerlich.dev` under GitHub → Settings → Pages. *Needs Luca: a DNS TXT record.*

## Low

- [x] **L1 · F6 is treated as a modifier.** `HIDKeyboardMonitor.swift:171` `usage == 0x3F`. On the HID keyboard page, `0x3F` is F6 (confirmed: `kHIDUsage_KeyboardF6`); `0x3F` is Fn only as a Carbon *virtual* keycode. The real Fn/Globe key is on Apple's vendor page and is already filtered out. Fix: delete the line.
- [ ] **L2 · CJK switches can be recorded as done without taking effect.** This is a known macOS bug, documented by Kawa and macism. Reproduce it, then work around it or document it. *Medium confidence, not reproduced.*
- [ ] **L3 · H2 is only partly fixed** (`MappingStore.swift:119-129, 176-178`). Corrupt data still loads as `[:]`, and the next write overwrites it. The user isn't told, and only the first corruption is backed up. The audit's "refuse blind overwrite" was never implemented.
- [ ] **L4 · `IOHIDRequestAccess` blocks the main thread** until the prompt is answered (`PermissionService.swift:10`). Call it from a detached task.
- [x] **L5 · The Settings "Pause" toggle pauses for 365 days**, and the menu shows only "Paused until 14:32", with no date. Two on/off concepts overlap. Use one "Enabled" toggle.
- [x] **L6 · Accessibility.** The menu bar image has no `accessibilityLabel`. Per-device pickers share identical labels. Decorative icons aren't hidden. The icon itself never changes when paused or when permission is missing, so `README.md:64` ("Check the menu bar icon: it shows…") only works if you read it as "open the menu". A status-tinted icon would make it literally true.
- [x] **L7 · Jargon in user-facing strings.** Examples: "VID 1452 | PID 641 | Location 336592896", "kIOReturnNotPermitted", "missing/disabled", "Device Fallback (Advanced)".
- [ ] **L8 · Swift 5 language mode.** With `SWIFT_STRICT_CONCURRENCY=complete` there are 3 warnings that become errors in Swift 6: `AppState.swift:141` (non-Sendable observer in a nonisolated deinit) and `HIDKeyboardMonitor.swift:95` (main-actor `stop()` called from deinit).
- [ ] **L9 · Test hygiene.**
  - The test host boots the real `AppState`, starts Sparkle and uses the real `com.lucagerlich.InputPilot` defaults domain.
  - The UI test asserts nothing.
  - `AppStateFailurePathTests.swift:33` compares a non-optional value to `nil`, so the assertion is always true.
  - `waitFor` helpers time out silently.
  - Untested: M2's "wrong device removed" case, same-device repeated keys in SwitchController (`:59-62`), and Settings persistence.
- [x] **L10 · CI floats `macos-latest`** plus "newest Xcode", which will pick up a beta. `actions/checkout@v5` is tag-pinned and two majors behind. There's no `permissions:`, `concurrency:` or `timeout-minutes`, and no coverage gate.
- [ ] **L11 · The cask has no `uninstall quit: "com.lucagerlich.InputPilot"`.** `brew uninstall` removes the bundle while the agent keeps running. *(Fix this in the tap repo.)*
- [ ] **L12 · `release.sh` diagnostics.**
  - A rejected notarization is only caught when stapling fails, and the notary log is never fetched.
  - The team (`T5M4XW2T24`) is never asserted after export.
  - The DMG's signing identifier is `InputPilot-1`.
  - `:11` points to a "Parked section" of an `AUDIT.md` that doesn't exist.
- [ ] **L13 · Sparkle 2.10.0 is available** (you ship 2.9.6). It has no security fixes; bump it at the next release.
- [ ] **L14 · AppState.swift is 1,115 lines** (the limit is 800). Extract a pure `DeviceKeyResolver` (~130 lines, which also makes M1 testable), the permission and monitor lifecycle, and the display strings.
- [ ] **L15 · Repo hygiene.**
  - Merged branches still exist: `origin/chore/appcast-1.0.0`, `origin/chore/homebrew-tap`, plus local ones.
  - `origin/dev` is the known stale V2.
  - `.claude/settings.local.json` is ignored only by the global gitignore.
  - The app has an unused `files.user-selected.read-only` entitlement.
- [x] **L16 · `docs/pre-release-audit.md` is served publicly** and names the work account's team ID. Team IDs aren't secret, but this one links the personal project to the employer's account.

## Verified good

- **Shipped artifact:**
  - The DMG sha256 matches across `dist/`, the cask and the GitHub asset digest.
  - Developer ID T5M4XW2T24, timestamped, notarized and stapled.
  - `spctl` accepts both the DMG and the app.
  - Universal binary, hardened runtime; `--deep --strict` passes, including Sparkle's XPC services.
  - The appcast EdDSA signature verifies against the shipped `SUPublicEDKey`.
  - Version, build and minimum OS (13.0) are consistent across project, binary, appcast and cask.
- **Privacy core:**
  - Only device properties and one Bool leave the HID callback.
  - There is no per-keystroke logging and no networking outside Sparkle.
  - Every opened URL is a constant.
  - Export and clipboard happen only on explicit user action, and the log is in memory and capped.
  - The site loads no third-party scripts, fonts or analytics.
- **Previous fixes hold:** H1 (fresh source read, TIS observer fires for a background agent), M1, M2, M3, and HID callback lifetime (no use-after-free on stop or restart).
- **Concurrency and robustness:**
  - Main-run-loop callbacks hop to `@MainActor`, and no data races were found.
  - Debounce cancellation is correct, and rapid A/B keyboard alternation ends in the right state.
  - Hot-plug works, and key repeat generates no events.
- **No switch loop** with macOS's "Automatically switch to a document's input source".
- **macOS 13 compatibility:** every SwiftUI and ServiceManagement API used is 13.0 or older.
- **Tests:** 35 + 2 green, with zero flakes over 100 iterations and 50 iterations under CPU saturation.
- **Sparkle 2.9.6** includes the latest security fixes.
- **CI:** read-only token, no secrets, no `pull_request_target`. `brew audit --strict` and `brew style` pass on the cask.

## Suggested order

1. **One small PR fixing the claims:** C1 (all rows), R5 (merge the Homebrew docs), L1 (F6), M11 (log flood). That's about 30 minutes, with no behaviour change apart from two one-line fixes.
2. **Product PR, released as 1.1.0:** P1 launch at login, P2 respect manual changes, P3 onboarding completion, P4 partial HID open, M4 keyboard-only sources, M8 window activation. Add T1's two regression tests alongside.
3. **Release hardening, before cutting 1.1.0:** M2, M5, M6, M7. Protecting `main` (M2) is a GitHub setting and takes a minute.
4. **Luca, no code involved:** R2 (Search Console and Bing), M12 (Pages domain verification), R4 (repo metadata), R3 (AlternativeTo and the list PRs).
5. **Launch,** following the August plan.
