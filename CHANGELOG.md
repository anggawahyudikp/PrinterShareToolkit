# Changelog

## Unreleased
- Standardized the toolkit interface, runtime messages, comments, and public documentation in English.
- Replaced the Indonesian usage guide with `Docs/USER_GUIDE.md` and updated release packaging references.
- Added the project background and native Windows sharing rationale, including where Mobility Print may be less suitable for specialized printer settings.

## v1.1.2
- Fixed elevation/startup from folders containing apostrophes, ampersands, spaces, exclamation marks, and Unicode characters by moving elevation into `Core/Launcher.ps1` and passing paths as data.
- Added a password-free HOST transaction journal and Menu 8 rollback for reversible printer, firewall, and RID-500 Enabled-state changes.
- Added authoritative `Get-Printer -Full` SSR verification through `RenderingMode=SSR` while retaining driver registry checks as supporting evidence.
- Added a non-mutating regression suite covering parsing, special-path startup, share parsing, safety contracts, and release packaging.
- Hardened the release builder with an explicit allowlist, manifest, SHA-256 sidecar, archive validation, and no-overwrite behavior.
- Pinned GitHub Actions, restricted workflow permissions, updated documentation, and added publication provenance gates.

## v1.1.1 Documentation update
- Added `Docs/USER_GUIDE.md`: quick start, HOST/CLIENT flow, menu guide, status explanation, common errors, security, and troubleshooting.

## v1.1.1
- UI hotfix Print Spooler: suppress warning flood "Waiting for service Print Spooler...".
- Added safe Start/Stop/Restart Spooler wrapper using sc.exe + controlled polling timeout.
- HOST/CLIENT critical setup stops cleanly if Spooler cannot reach Running within 30s.
- Normal View shows concise [..] Restart Print Spooler -> [OK]/[FAIL].

PRINTER SHARE TOOLKIT CHANGELOG

## v1.1.0
- UI/UX refresh only; core printer logic remains based on v1.0.12 STRICT RID500.
- Adds compact dashboard header with Computer, User, IP, and current View mode.
- Adds NORMAL VIEW (default) and TECHNICIAN VIEW toggle from Main Menu (T).
- Adds 5-step progress flow for HOST and CLIENT operations.
- Standardizes screen status tags: [OK], [WARN], [FAIL], [..], [-].
- Hides raw NET VIEW, object dumps, and stack traces in NORMAL VIEW; logs are still preserved.
- Adds final RESULT card with Status, Printer, Method, Driver, Port, and log path.
- Adds Main Menu shortcut L to open Logs folder.
- Keeps RID500 mandatory, one-attempt SMB credential guard, SSR-first /in, and Native Local Port fallback unchanged.

## v1.0.12
- Enforce STRICT Built-in Administrator RID 500 gate for HOST Setup / Repair.
- RID500 must exist, be Enabled, not Locked, and have PasswordLastSet/PasswordReady before HOST flow can continue.
- If Enable / Unlock / password setup is declined or fails, HOST Setup stops immediately.
- Other local users that are members of Administrators are intentionally NOT accepted as substitutes for RID500.
- Client credential prompt is explicitly RID500-only; when a Host Profile is present, a different account is rejected.
- PasswordRequired is no longer used as the decisive password-ready signal because Windows can report False even after a password is set.
- Keeps v1.0.11 SSR-first, one-attempt credential lockout guard, /in primary method, and Native Local Port fallback.


## v1.0.11
- Fixed a false DEGRADED/FAILED result when the Native Local Port fallback succeeded but an old queue remained in `PendingDeletion`.
- The fallback no longer treats a `PendingDeletion` queue as reusable.
- Added `PendingDeletion` self-healing: remove queued jobs on a best-effort basis, release `PrintIsolationHost`/`splwow64`, cycle the Print Spooler, and check again.
- If the stale queue remains in `PendingDeletion`, the toolkit ignores it and creates a uniquely named replacement queue.
- The final health check prioritizes a stable Local Port queue instead of selecting a stale pending-delete object.
- The recovery flow does not remove driver packages or purge the global spool folder.
- SSR with `PrintUIEntry /in` remains the primary method; Native Local Port remains a fallback only.


## v1.0.10
- Fixed the case where `PrintUIEntry /in` returned `Operation failed with error 0x00000006` and auto-correction repeated the same installer.
- If `/in` does not create a network `Connection`, the toolkit does not run a second `/in` installer.
- Added a Native Local Port UNC fallback (`\\HOST\Share`) using the vendor/native driver installed on the CLIENT, without PaperCut.
- If a driver package is staged but not registered, the toolkit attempts to register it with `Add-PrinterDriver`.
- Soft driver re-registration runs only when no other queue uses the driver; driver removal has a timeout so the toolkit cannot hang indefinitely.
- Added fallback health checks for SMB/TCP 445, the native driver, UNC Local Port, `Type=Local`, the expected port, and `PrinterStatus`.
- Retained the one-attempt lockout guard, the v1.0.8 `NET VIEW` parser, and the v1.0.9 empty-array fix.


## v1.0.9
- Fix CLIENT crash after printer share selection: "The property 'Name' cannot be found on this object".
- Root cause: with Set-StrictMode, `$before.Name` can fail when there are zero existing network-printer connections.
- Builds BeforeNames explicitly and safely, so a clean client with no prior printer connection proceeds to install normally.
- Keeps v1.0.8 NET VIEW parser fix, one-attempt credential lockout guard, SSR flow, and install strategy unchanged.

## v1.0.8
- Fix Windows PowerShell 5.1 runtime crash: "Argument types do not match" after NET VIEW succeeds.
- Replaces Generic List + @() conversion in NET VIEW printer-share parsers with native PowerShell arrays.
- Hardens both share-name and share-record parsing while preserving spaces in ShareName and comments.
- No change to credential retry policy or printer install strategy.

## v1.0.7
- Adds final verification and bounded auto-correction on HOST and CLIENT.
- Removes invalid stale per-machine (/ga) connections for non-existent shares on the selected host.
- Does not run /ga after a healthy /in connection.
- Uses host NET VIEW comment to identify the installed queue display name when ShareName differs.
- Adds optional physical Test Page confirmation for FULLY VERIFIED status.
- Preserves one-attempt credential lockout protection.
