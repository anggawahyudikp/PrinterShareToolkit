# GitHub Publish Checklist

## First Publish

```powershell
git init
git add .
git commit -m "Initial open-source release v1.1.2"
git branch -M main
git remote add origin https://github.com/<OWNER>/<REPO>.git
git push -u origin main
```

Before push:
- Confirm every owner-attestation item and the authorization record in
  `Docs/PROVENANCE.md` remain complete and current.
- Retain any employer/client approval and contributor consent privately. Do not
  commit contracts, personal data, or private email to the public repository.
- Review repository for credentials and internal environment data.
- Confirm `Logs/`, `Profiles/`, and `Backup/` contain only `.gitkeep`.
- Confirm `Core/Toolkit.ps1` is the intended stable source.
- Confirm `VERSION` and `CHANGELOG.md` match.
- Run `Tests/Run-All.ps1` and retain its result.
- Confirm the generated ZIP SHA-256 matches its `.sha256` sidecar.

## GitHub Repository Settings

Recommended:
- Enable Issues.
- Enable Discussions if community support is desired.
- Enable Private vulnerability reporting.
- Protect `main` after the first stable publish.
- Require pull requests for changes to `main` when contributors increase.
- Enable Actions for CI syntax/build checks.

## Release

1. Run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\Build-Release.ps1
```

2. Test the ZIP from `dist\` on a clean folder.
3. Create a GitHub Release tag, e.g. `v1.1.2`.
4. Attach only the generated release ZIP.
5. Copy release notes from `CHANGELOG.md`.

Do not upload live `Logs`, `Profiles`, or `Backup` data.
