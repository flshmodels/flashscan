# FlashScan

A Windows dashboard for checking one file. View its SHA-256 hash and signature, optionally ask Microsoft Defender to scan it, and save a JSON report.

**FlashScan is not an antivirus engine, a kernel driver, or a complete anti-cheat.** It does not identify unknown malware itself. An unsigned file isn't automatically malicious, and a valid signature or successful scan cannot prove a file is safe.

## Setup

Windows 10/11 with Windows PowerShell 5.1 and the built-in desktop .NET components is required. No third-party packages are needed.

1. Download or clone this repository and extract all files if using a ZIP.
2. Double-click **Start FlashScan.cmd**.
3. Click **Choose file**, select one actual file, then press **Inspect selected file**.
4. To also request malware scanning, select the Defender option before starting. Inspecting without that option only reads file information.
5. Read the result and, if wanted, use **Export report**.

If Windows blocks a downloaded script, inspect the source and follow your organization's script policy. The launcher does not bypass execution policy. Defender commands can require elevation: if access is denied, launch Windows PowerShell as administrator and run `./src/FlashScan.ps1` from the project folder. FlashScan does not request elevation automatically.

## What happens to the file?

Inspection reads the file and never executes it. FlashScan does not install a service or driver, delete or quarantine files, change Defender settings, or upload the selected file itself. The optional Defender custom scan uses `-DisableRemediation`, which requests detection without applying remediation. Windows real-time protection and cloud protection continue to operate under their existing settings and can independently act on files. Defender activity may create its own system logs.

The UI remains responsive while a background job runs. It does not offer cancellation of a Defender scan; wait for it to finish before closing.

## Reading results

- **SHA-256:** a file fingerprint, not a malware verdict.
- **Signature:** Windows Authenticode status and publisher, when available. Not all file types support signatures.
- **Defender exit 0:** command completed; read the output. Do not interpret it as a guarantee of safety.
- **Defender exit 2:** detection, required action, or a scan error. The app does not call this a confirmed infection.
- **Other exit codes / exceptions:** failure; no clean result is claimed.

Only the selected file is requested. This isn't a whole-PC, memory, bootkit, or kernel scan. Locked files, unavailable Defender installations, disabled protection, and permission problems can prevent completion. Results apply to the inspected contents and time, not future changes to the file.

See [Microsoft's MpCmdRun documentation](https://learn.microsoft.com/en-us/defender-endpoint/command-line-arguments-microsoft-defender-antivirus) for scan options and exit-code meanings.

## Inputs and outputs

| File / function | Input | Output |
| --- | --- | --- |
| `src/FlashScan.ps1` | File selected in a native dialog; optional Defender checkbox | Dashboard result; optional JSON report chosen through a save dialog |
| `Get-FlashFileInfo` | One literal file path | Path, size, SHA-256, signature, publisher, inspection time |
| `Invoke-FlashInspection` | Path and `UseDefender` boolean | File information, requested-scan flag, optional exit code, summary, raw Defender output |
| `Get-FlashDefenderSummary` | Integer exit code | Explanation of that exit code |

Reports include local paths and may include publisher details and Defender output. Choose where to save them and review them before sharing. Reports are ignored by Git by default.

## Tests

Run `powershell -NoProfile -File tests/Run.Tests.ps1`. Tests use a harmless text fixture; they don't download malware, invoke Defender, or change security settings. GitHub Actions runs the same checks on Windows. These tests don't establish malware-detection quality or compatibility with every Windows/Defender configuration.

MIT licensed. This repository contains source code, not bundled antivirus definitions or third-party binaries.
