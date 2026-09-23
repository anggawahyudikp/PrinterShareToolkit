# Troubleshooting

## TCP 445 = False

Possible causes:

- Routing between subnets is unavailable.
- A firewall blocks SMB.
- The HOST is unreachable.
- File and Printer Sharing is not enabled.

Check routing, firewall rules, and HOST connectivity before installing the
printer.

## TCP 135 = False

RPC is unreachable. Check firewall rules and routing between the HOST and
CLIENT.

## SMB error 1326

The username or password is incorrect.

The toolkit must **STOP**. Do not add automatic password retries because they
can cause an account lockout.

## SMB error 1909

The HOST account is locked out. Unlock the RID 500 account on the HOST before
trying again.

## SMB error 1219

Another credential or SMB session already exists for the same server. Remove
the old session or stored credential, then perform one new pairing attempt.

## Error 0x00000006

The standard shared-printer method did not create a connection object.

Toolkit flow:

1. Try SSR with `PrintUIEntry /in` once.
2. If no connection is created, move to the Native Local Port UNC fallback.
3. Do not run a second `/in` installer in parallel.

## Error 0x000007D1: The specified driver is invalid

This usually indicates a Windows V3 driver registration or rendering problem.

Diagnostic steps:

- Create a local queue with the same driver and the `FILE:` port.
- If that local queue also returns `0x7D1`, focus on the CLIENT driver and V3
  printing components.
- Re-register the driver in a controlled way before changing the HOST.

## PrinterStatus = PendingDeletion

The toolkit tries to:

- Remove jobs from the selected queue on a best-effort basis.
- Release `PrintIsolationHost` or `splwow64` when needed.
- Cycle the Print Spooler.
- Ignore the stale queue and create a replacement if Windows has not removed
  the old object.

## Print Spooler is not Running

The toolkit uses controlled polling. If the Print Spooler does not reach
`Running` before the timeout, the operation stops with `[FAIL]`.

Do not restart the service in an unlimited loop.

## ShareName differs from the display name

Use the printer **ShareName** shown by `net view \\HOST`, not only the display
name shown in Settings or Control Panel.

## Before opening a GitHub issue

Remove or redact:

- Passwords and credential material.
- Internal hostnames.
- Internal IP addresses when they are not needed.
- User, domain, or company names.
- Sensitive content from `Profiles\` and `Logs\`.

Include:

- Toolkit version.
- HOST and CLIENT Windows builds.
- Printer model.
- Driver name and version.
- Exact error code.
- The method that failed (`/in` or Native Local Port fallback).
- A sanitized log.
