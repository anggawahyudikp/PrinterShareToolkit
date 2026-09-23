# Contributing

Contributions are welcome through issues and pull requests.

## Before Opening a Bug

Run the latest stable release and collect a sanitized log.

Required information:
- Toolkit version.
- Windows version/build on HOST and CLIENT.
- Printer model.
- Printer driver name/version.
- HOST or CLIENT operation.
- TCP 445 / TCP 135 result.
- SMB error code if applicable.
- Printer error code.
- Exact reproduction steps.
- Sanitized toolkit log.

Never publish passwords, credential material, internal account names, or sensitive company data.

## Branch / Version Policy

- `main`: stable source.
- Bug fix: patch version, e.g. `1.1.1 -> 1.1.2`.
- Backward-compatible feature: minor version, e.g. `1.1.x -> 1.2.0`.
- Breaking behavior: major version.

## Core Behavior That Must Be Preserved

Unless a PR explicitly proposes and documents a design change:

1. HOST setup uses strict Built-in Administrator RID 500 readiness.
2. Other local Administrators do not replace RID 500.
3. CLIENT credential test is one attempt only.
4. SSR + `PrintUIEntry /in` is the primary CLIENT method.
5. Native Local Port UNC is fallback only.
6. Never add automatic password brute force or repeated credential guessing.
7. Avoid aggressive global spool-folder purge when targeted cleanup is possible.
8. Do not bundle third-party printer drivers without clear redistribution rights.

## PowerShell Compatibility

Target: **Windows PowerShell 5.1**.

Avoid syntax that only works in PowerShell 7, including ternary operators and newer language constructs.

Be careful with:
- `Set-StrictMode` and empty arrays.
- Generic collections converted through `@()` on Windows PowerShell 5.1.
- Service cmdlets that can flood the console with warnings.
- Printer object properties that differ by Windows build/driver.

## UI Style

Keep UI technical and compact:

```text
[OK]   Success
[WARN] Warning / fallback
[FAIL] Failed
[..]   Working
[-]    Skipped
```

Normal View should stay concise. Raw output, stack traces, and deep diagnostics belong in Technician View/logs.

## Pull Request Checklist

- [ ] PowerShell parses successfully on Windows PowerShell 5.1.
- [ ] No credentials or internal environment data were committed.
- [ ] HOST flow tested if HOST code changed.
- [ ] CLIENT `/in` flow tested if CLIENT code changed.
- [ ] Local Port fallback tested if fallback code changed.
- [ ] Normal View remains concise.
- [ ] Technician View/log retains sufficient diagnostics.
- [ ] `CHANGELOG.md` updated.
- [ ] `VERSION` updated when behavior changes.
