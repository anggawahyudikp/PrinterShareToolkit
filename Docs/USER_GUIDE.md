# Printer Share Toolkit v1.1.2

## User Guide

Printer Share Toolkit helps administrators set up, repair, connect, diagnose,
and clean up native Windows printer sharing.

The CLIENT installation strategy is:

1. Try SSR with `PrintUIEntry /in`.
2. If the standard connection fails, use a Native Local Port UNC fallback.

The toolkit does not depend on PaperCut.

## A. Before You Start

1. Extract the entire ZIP file to a normal local folder, for example:

   ```text
   C:\PrinterShareToolkit_v1.1.2
   ```

2. Do not run `Core\Toolkit.ps1` directly. Start the toolkit with:

   ```text
   PrinterToolkit.bat
   ```

3. Approve the Administrator/UAC prompt when it appears.

4. Make sure the HOST and CLIENT can communicate over the network. The main
   ports are:

   - TCP 445 for SMB
   - TCP 135 for RPC

5. On the HOST, the built-in Administrator account identified by RID 500 must
   be ready. Another local administrator account is not accepted as a
   replacement for RID 500.

## B. Main Menu

`[1] Setup / Repair Printer HOST`
: Prepares the PC that has the physical printer connected directly.

`[2] Connect / Repair Printer CLIENT`
: Connects a CLIENT PC to a printer shared by the HOST.

`[3] Built-in Administrator Readiness`
: Checks whether the built-in Administrator RID 500 account is ready.

`[4] Full Diagnostic`
: Audits the network, services, printers, drivers, SMB, SSR, and related state.

`[5] Cleanup Printer Queue`
: Cleans up a selected printer queue or stuck print jobs.

`[6] Test Print`
: Sends a Windows test page to the selected printer.

`[7] Windows/SAM Health Check`
: Runs a read-only Windows/SAM and built-in Administrator audit.

`[8] Rollback Last HOST Setup`
: Restores reversible changes recorded by the latest HOST transaction.

`[T] Technician View`
: Toggles additional technical detail. Raw diagnostics are always kept in
  `Logs\`.

`[L] Open Logs Folder`
: Opens the toolkit log folder.

`[0] Exit`
: Closes the toolkit.

## C. Set Up a Printer HOST

Use Menu `[1]` on the PC where the physical printer is connected through a
local USB, LPT, or TCP/IP port.

The toolkit performs the following steps:

1. Finds the built-in Administrator account by RID 500.
2. Offers to enable the account if it is disabled.
3. Offers to unlock the account if it is locked.
4. Requests a password setup or reset if the account is not password-ready.
5. Prompts you to select a LOCAL printer.
6. Rejects `Type=Connection` printers to prevent chained sharing.
7. Backs up the printer registry state.
8. Creates or repairs the printer share.
9. Enables Server-Side Rendering (SSR).
10. Enables the required File and Printer Sharing firewall rules.
11. Restarts the Print Spooler with a controlled timeout.
12. Saves a password-free HOST profile in `Profiles\`.
13. Runs a final verification.

The target result is:

```text
[OK] RID 500 ready
[OK] Local printer
[OK] Printer shared
[OK] SSR enabled
[OK] Print Spooler running
[OK] TCP 445 available
```

If the toolkit asks for a `ShareName`, use a short and clear name without
special characters. Examples: `EPSONL3210`, `LX310`, or `XPRINTER`.

## D. Connect or Repair a CLIENT

Use Menu `[2]` on the PC that will use the printer shared by the HOST.

Required information:

- HOST IP address or hostname
- Printer `ShareName`

Example:

```text
HOST IP   : 192.168.10.10
ShareName : EPSON-L3210
```

The toolkit performs the following steps:

1. Tests TCP 445 and TCP 135.
2. Enables the CLIENT SSR policy.
3. Requests credentials for the HOST built-in Administrator RID 500 account.
4. Tests those credentials only once to reduce account-lockout risk.
5. Verifies SMB access and the printer share.
6. Tries the primary installation method with `PrintUIEntry /in`.
7. If successful, keeps the standard Windows printer connection with SSR.
8. If `/in` fails, tries a Native Local Port UNC fallback using the native
   printer driver installed on the CLIENT.
9. Runs a final health check.

Primary method:

```text
\\HOST\Share
  -> Point and Print
  -> SSR
```

Fallback method:

```text
Native CLIENT driver
  -> Local Port \\HOST\Share
  -> HOST Print Spooler
  -> Printer
```

The fallback still uses native Windows printing and does not depend on
PaperCut.

## E. Built-in Administrator RID 500

The toolkit identifies the built-in Administrator account by the SID ending in
`-500`, so the account may have been renamed.

RID 500 is mandatory for HOST setup. The account is ready when it is:

- Found
- Enabled
- Not locked
- Password-ready

HOST setup stops until all requirements are satisfied. Another local account,
even if it belongs to the `Administrators` group, does not replace RID 500.

## F. Normal View and Technician View

Normal View is the default. It keeps the output concise and focuses on
`[OK]`, `[WARN]`, and `[FAIL]` results.

Press `T` from the Main Menu to enable Technician View. This view shows more
technical detail for troubleshooting. Raw diagnostic information remains in
`Logs\` in either view.

Status tags:

```text
[OK]   Successful
[WARN] A condition needs attention
[FAIL] The operation failed or a requirement was not met
[..]   Work is in progress
[-]    The step was skipped or was not required
```

## G. Final Status

`READY`
: The printer is ready and all primary checks passed.

`DEGRADED`
: The printer was found or installed, but one or more health checks were not
  ideal.

`FAILED`
: The printer installation or connection did not succeed.

Using the Native Local Port fallback does not mean the printer failed. It means
the toolkit moved from the standard Point and Print method to the native Local
Port method.

## H. Test Print

Use Menu `[6]` after the printer reaches `READY`.

If the test page does not print:

1. Make sure the physical printer is powered on and ready.
2. Check the paper, ink, ribbon, or toner.
3. Check the HOST print queue.
4. Run Menu `[4] Full Diagnostic`.
5. Enable Technician View if more detail is needed.

## I. Full Diagnostic

Use Menu `[4]` when:

- The printer does not connect.
- The printer connects but does not print.
- SMB authentication fails.
- The driver is not working correctly.
- The Print Spooler is unhealthy.
- A queue is stuck in `PendingDeletion`.
- SSR is not active.
- The HOST and CLIENT cannot communicate.

Sanitize screenshots and logs before sharing them with another person or
posting them in a GitHub issue.

## J. Clean Up a Printer Queue

Use Menu `[5]` when:

- A print job is stuck.
- The printer status does not change.
- A queue is stuck in `PendingDeletion`.
- An old job or queue prevents a replacement printer from working.

The toolkit avoids an aggressive global spool purge and limits cleanup to the
selected queue whenever possible.

## K. Common Errors

### TCP 445 = False

Possible causes:

- Routing between subnets is missing.
- A firewall blocks SMB.
- The HOST is unreachable.
- File and Printer Sharing is disabled.

Check ping, routing, firewall rules, and File and Printer Sharing.

### TCP 135 = False

RPC may be blocked. Check firewall and routing between the HOST and CLIENT.

### SMB error 1326

The username or password is incorrect. The toolkit stops and does not retry the
password repeatedly.

### SMB error 1909

The HOST account is locked. Unlock RID 500 on the HOST before trying again.

### SMB error 1219

Another credential or SMB session already exists for the same HOST. Remove the
old session or stored credential, then perform one new pairing attempt.

### PrintUIEntry error 0x00000006

The standard `/in` connection failed. The toolkit tries the Native Local Port
fallback when a suitable native CLIENT driver is available.

### Error 0x000007D1: The specified driver is invalid

This usually points to a CLIENT-side Windows V3 driver or rendering problem.
Run Full Diagnostic and repair the native CLIENT driver.

### PrinterStatus = PendingDeletion

The toolkit tries to release related jobs and processes, cycle the Print
Spooler, and create a uniquely named replacement queue when necessary.

### Print Spooler does not start

The toolkit waits up to 30 seconds, then reports a clear failure instead of
restarting the service indefinitely. Use Full Diagnostic for further checks.

## L. Toolkit Files and Folders

`PrinterToolkit.bat`
: Main launcher.

`Core\Toolkit.ps1`
: Toolkit engine.

`Profiles\`
: Password-free HOST profile JSON files.

`Backup\`
: HOST printer registry and transaction backups created before selected
  changes.

`Logs\`
: Toolkit execution logs.

`README.md`
: Project overview and quick start.

`Docs\FLOWCHART.md`
: Text version of the internal workflow.

`Docs\USER_GUIDE.md`
: This guide.

## M. Recommended Workflow

For a new setup:

```text
HOST   -> Menu 1
CLIENT -> Menu 2
Test   -> Menu 6
```

If the process fails:

```text
Menu 4: Full Diagnostic
  -> Enable Technician View if needed
  -> Review Logs\
```

Do not run multiple toolkit instances in parallel on the same PC while a
printer is being installed or repaired.

### HOST Rollback

Menu `[8] Rollback Last HOST Setup` restores reversible changes recorded by the
transaction:

- The previous shared state, `ShareName`, printer permissions, and
  `RenderingMode`.
- File and Printer Sharing firewall state recorded before setup.
- RID 500 is disabled again only if that transaction enabled it.

A password reset and account unlock cannot be safely reversed. The toolkit
records them as non-reversible and displays that information before rollback.

## N. Security

- Passwords are not written to HOST profiles.
- CLIENT credentials may be stored in Windows Credential Manager.
- Credential testing is limited to one attempt to reduce account-lockout risk.
- Do not share `Logs\` or `Profiles\` with anyone who does not need access.
- Run the toolkit only on computers you manage or are authorized to administer.
- Review the known credential-handling limitation in `SECURITY.md`.

## Quick Start Summary

HOST:

1. Run `PrinterToolkit.bat`.
2. Select Menu `[1]`.
3. Make sure RID 500 is ready.
4. Select a local printer.
5. Choose the `ShareName`.
6. Wait for the `READY` result.

CLIENT:

1. Run `PrinterToolkit.bat`.
2. Select Menu `[2]`.
3. Enter the HOST IP address or hostname.
4. Enter the printer `ShareName`.
5. Enter the HOST RID 500 credentials.
6. Wait for the `READY` result.
7. Use Menu `[6]` to print a test page.
