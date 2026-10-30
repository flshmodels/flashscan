$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\src\Core.ps1')
function Assert-True($Condition, $Message) { if (-not $Condition) { throw $Message } }
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('flashscan-' + [guid]::NewGuid().ToString('N') + ' sample.ps1')
try {
    [IO.File]::WriteAllText($fixture, 'abc', (New-Object Text.UTF8Encoding $false))
    $result = Get-FlashFileInfo -Path $fixture
    Assert-True ($result.Bytes -eq 3) 'Wrong file size'
    Assert-True ($result.SHA256 -eq 'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD') 'SHA-256 mismatch'
    Assert-True ((Get-Content -LiteralPath $fixture -Raw) -eq 'abc') 'Inspection changed the file'
    Assert-True ($result.Signature -in @('NotSigned','UnknownError')) 'Unsigned or unsupported fixture should retain the Windows signature status'
    $rejected = $false
    try { Get-FlashFileInfo -Path ($fixture + '.missing') | Out-Null } catch { $rejected = $true }
    Assert-True $rejected 'Missing file was accepted'
    $rejected = $false
    try { Get-FlashFileInfo -Path (Split-Path $fixture) | Out-Null } catch { $rejected = $true }
    Assert-True $rejected 'Folder was accepted'
    Assert-True ((Get-FlashDefenderSummary 2) -match 'scan error') 'Exit 2 must remain ambiguous'
    Assert-True ((Get-FlashDefenderSummary 0) -match 'not a guarantee') 'Exit 0 must not guarantee safety'
    Assert-True ((Get-FlashDefenderSummary 5) -match 'No clean result') 'Unknown exit code must not claim clean'
    Write-Output 'PASS: file hash, size, unchanged content, signature, invalid paths and Defender exit summaries.'
} finally { if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture } }
