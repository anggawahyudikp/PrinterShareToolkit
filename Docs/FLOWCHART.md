# Flowchart

## Main Flow

```text
START
  |
  v
Elevation / Administrator
  |
  +-------------------------------+
  | HOST                          |
  |                               |
  | RID500 gate                   |
  |  |- Found?                    |
  |  |- Enabled?                  |
  |  |- Unlocked?                 |
  |  '- PasswordReady?            |
  |                               |
  | Select LOCAL printer          |
  | Reject Type=Connection        |
  | Backup registry               |
  | Share printer                 |
  | Enable SSR                    |
  | Firewall sharing              |
  | Restart Spooler               |
  | Save password-free profile    |
  |                               |
  '------------ READY ------------'
                  |
                  v
  +-------------------------------+
  | CLIENT                        |
  |                               |
  | TCP 445 / TCP 135             |
  | SSR policy                    |
  | RID500 credential             |
  | SMB auth ONCE                 |
  | Verify share                  |
  |                               |
  | PrintUIEntry /in              |
  |   |                           |
  |   +-- success -> Health Check |
  |   |                           |
  |   '-- fail                    |
  |        |                      |
  |        v                      |
  | Native Local Port fallback    |
  |   |- Native CLIENT driver     |
  |   |- \\HOST\Share port        |
  |   '- Local queue              |
  |                               |
  | PendingDeletion self-heal     |
  | Health Check                  |
  |                               |
  '---- READY / DEGRADED / FAIL --'
```

## Important Gates

- Credential test: one attempt only.
- `1326`: stop — bad credential.
- `1909`: stop — account locked.
- `1219`: stop / clean credential conflict.
- `/in` is not run twice in parallel.
- Native Local Port is fallback only.

A visual flowchart is available at `Docs/images/flowchart.png`.
