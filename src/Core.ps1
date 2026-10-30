Set-StrictMode -Version Latest

function Get-FlashFileInfo {
    param([Parameter(Mandatory)][string]$Path)
    $file = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($file.PSIsContainer) { throw 'Choose a file, not a folder.' }
    if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Choose the original file instead of a link.' }
    $before = $file.LastWriteTimeUtc
    $size = $file.Length
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
    $signature = Get-AuthenticodeSignature -LiteralPath $file.FullName -ErrorAction Stop
    $file.Refresh()
    if ($file.Length -ne $size -or $file.LastWriteTimeUtc -ne $before) { throw 'The file changed during inspection. Try again.' }
    $publisher = if ($null -ne $signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { 'Not available' }
    [pscustomobject]@{
        Path = $file.FullName; Bytes = $size; SHA256 = $hash
        Signature = [string]$signature.Status; Publisher = $publisher
        InspectedUtc = [DateTime]::UtcNow.ToString('o')
    }
}

function Find-FlashDefender {
    $platform = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'Microsoft\Windows Defender\Platform'
    if (Test-Path -LiteralPath $platform) {
        $versions = Get-ChildItem -LiteralPath $platform -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        foreach ($version in $versions) {
            $candidate = Join-Path $version.FullName 'MpCmdRun.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    $fallback = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'Windows Defender\MpCmdRun.exe'
    if (Test-Path -LiteralPath $fallback -PathType Leaf) { return $fallback }
    throw 'Microsoft Defender command-line tool was not found on this PC.'
}

function Get-FlashDefenderSummary {
    param([int]$ExitCode)
    if ($ExitCode -eq 0) { return 'Defender completed (exit 0). Review its output below; this is not a guarantee that the file is safe.' }
    if ($ExitCode -eq 2) { return 'Defender returned exit 2: a detection, required action, or scan error. Review the output; this does not prove malware was found.' }
    return "Defender did not complete successfully (exit $ExitCode). No clean result is claimed."
}

function Invoke-FlashInspection {
    param([string]$Path, [bool]$UseDefender = $false)
    $info = Get-FlashFileInfo -Path $Path
    $summary = 'Inspection complete. No malware scan was requested.'
    $output = ''
    $exitCode = $null
    if ($UseDefender) {
        $defender = Find-FlashDefender
        # Array arguments and the call operator avoid shell-string interpretation of the selected path.
        $output = (& $defender '-Scan' '-ScanType' '3' '-File' $info.Path '-DisableRemediation' 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
        $summary = Get-FlashDefenderSummary -ExitCode $exitCode
        $after = (Get-FileHash -LiteralPath $info.Path -Algorithm SHA256 -ErrorAction Stop).Hash
        if ($after -ne $info.SHA256) { throw 'The file changed during the scan. Results cannot be associated with the inspected hash.' }
    }
    [pscustomobject]@{ File = $info; DefenderRequested = $UseDefender; ExitCode = $exitCode; Summary = $summary; Output = $output }
}
