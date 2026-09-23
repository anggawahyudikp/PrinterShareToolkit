# Security Policy

## Sensitive Data

Do not publish the following in public issues or pull requests:

- Passwords or credential material.
- Credential Manager exports.
- Internal usernames/domain names when sensitive.
- Unsanitized internal IP/hostname inventories.
- Company-sensitive printer/share names.
- Logs or Profiles containing environment details that should remain private.

## Reporting a Security Issue

Use GitHub private vulnerability reporting for security issues. The repository owner must enable this feature before the first public release.

Do not open a public issue containing exploit details, credentials, internal environment information, or an undisclosed vulnerability. If private reporting is temporarily unavailable, contact the maintainer through the private contact method listed on the maintainer's GitHub profile.

## Security Design Requirements

- Credential testing must remain bounded to one attempt.
- Do not implement credential guessing or brute force.
- Passwords must not be written to toolkit logs or Profiles.
- Avoid printing SecureString/plaintext conversions to console or logs.
- Changes to account, firewall, registry, spooler, or printer state must be explicit in code and documented.

## Known Credential-Handling Limitation

Version 1.1.2 invokes the Windows `cmdkey.exe` and `net.exe` utilities for SMB
authentication. Windows requires the supplied password to be included in the
child process command line for these utilities. The toolkit does not write that
password to its logs or Profiles, but the command line may be observable during
execution by another sufficiently privileged local process or administrator.

Run the toolkit only on a trusted administrative workstation and avoid reusing
a highly privileged password. This limitation is tracked for replacement with
a credential flow that does not expose plaintext in process arguments.

## Supported Version

Security fixes are expected to target the latest release unless a maintainer explicitly backports them.
