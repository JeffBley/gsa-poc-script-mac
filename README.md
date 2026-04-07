# macOS Global Secure Access POC Installer

Shell scripts to install and roll back the [Microsoft Global Secure Access](https://learn.microsoft.com/en-us/entra/global-secure-access/overview-what-is-global-secure-access) client on macOS for a proof-of-concept deployment.

| Script | Purpose |
|--------|---------|
| `install_gsa.sh` | Downloads and installs the GSA client, unhides all system tray buttons, and disables QUIC in Chrome and Edge |
| `rollback_gsa.sh` | Uninstalls the GSA client and reverses all configuration changes made by `install_gsa.sh` |

## Prerequisites

- macOS (Intel or Apple Silicon)
- Administrator (`sudo`) access on the machine

## Download the scripts

**Option 1 — curl (no git required)**

```bash
curl -LO https://raw.githubusercontent.com/JeffBley/gsa-poc-script-mac/main/install_gsa.sh
curl -LO https://raw.githubusercontent.com/JeffBley/gsa-poc-script-mac/main/rollback_gsa.sh
```

**Option 2 — clone the repo**

```bash
git clone https://github.com/JeffBley/gsa-poc-script-mac.git
cd gsa-poc-script-mac
```

## Usage

Make the scripts executable before running them (one-time step):

```bash
chmod +x install_gsa.sh rollback_gsa.sh
```

### Install

```bash
sudo ./install_gsa.sh
```

What it does:
1. Downloads the GSA `.pkg` installer from Microsoft (`https://aka.ms/GlobalSecureAccess-macOS`)
2. Installs the package
3. Unhides all four system tray menu buttons (Disable Private Access, Disable, Pause, Quit)
4. Writes a managed policy to disable QUIC in Google Chrome and Microsoft Edge

After installation, you may need to approve the system extension:  
**System Settings > Privacy & Security**

Restart any open Chrome or Edge windows for the QUIC policy to take effect.

### Roll back

```bash
sudo ./rollback_gsa.sh
```

What it does:
1. Runs the GSA uninstaller (or removes the application folder if the uninstaller is missing)
2. Removes the GSA button visibility preferences
3. Removes the QUIC managed policy for Chrome and Edge (QUIC re-enables on next browser restart)

## Notes

- Safari is not affected by the QUIC policy — QUIC in Safari is managed at the OS network layer and cannot be disabled via a plist.
- Both scripts must be run as root (`sudo`). They will exit with an error if run as a standard user.
- The QUIC policy is written even if Chrome or Edge is not currently installed; it will apply automatically if the browser is installed later.
