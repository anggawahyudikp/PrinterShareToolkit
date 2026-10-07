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

Error 1326 is a generic authentication failure. It can indicate an incorrect
username or password, but it is not proof that the password is wrong.

The toolkit must **STOP**. Do not add automatic password retries because they
can cause an account lockout.

If the same password succeeds locally on the HOST, run Full Diagnostic on the
HOST and inspect the bounded LsaSrv Event 6167 section. Event 6167 confirms
that Windows rejected authentication because the HOST and CLIENT use the same
machine SID. A password-free HOST profile can also detect this collision on
the CLIENT before credential input.

For a confirmed duplicate SID:

1. Stop password resets and retries.
2. Inventory every PC deployed from the same image.
3. Back up data and application settings.
4. Use a Microsoft-supported rebuild or Sysprep generalization plan.
5. Recreate the HOST profile after Windows has a unique machine identity.

Do not edit the machine SID in the registry or use an unsupported SID-changing
utility. The toolkit deliberately does not automate Sysprep because it is a
machine-lifecycle operation, not a printer repair.

References:

- [Microsoft: Kerberos and NTLM authentication failures due to duplicate SIDs](https://support.microsoft.com/en-us/servicing/os/windows/docs/2025/10/kerberos-and-ntlm-authentication-failures-due-to-duplicate-sids)
- [Microsoft: Windows installation disk duplication and Sysprep](https://learn.microsoft.com/en-us/troubleshoot/windows-server/setup-upgrade-and-drivers/windows-installations-disk-duplication)

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
- Whether HOST Full Diagnostic found LsaSrv Event 6167. Do not publish the raw
  machine SID.
- The method that failed (`/in` or Native Local Port fallback).
- A sanitized log.
