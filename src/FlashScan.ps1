$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="FlashScan" Width="850" Height="740" MinWidth="680" MinHeight="620" Background="#101719" Foreground="#EEF3F1" WindowStartupLocation="CenterScreen" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="16,10"/>
            <Setter Property="Margin" Value="0,0,10,0"/>
            <Setter Property="Background" Value="#C9E5DA"/>
            <Setter Property="Foreground" Value="#162A23"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
    </Window.Resources>
    <Grid Margin="30">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <StackPanel>
            <TextBlock Text="FLASH / SECURITY TOOLS" Foreground="#8EBAA5" FontSize="11"/>
            <TextBlock Text="File inspection, made clear." FontSize="28" FontWeight="SemiBold" Margin="0,10,0,7"/>
            <TextBlock Text="Select one file. Inspect its details. Optionally request a Microsoft Defender scan." Foreground="#A9BAB3" TextWrapping="Wrap"/>
        </StackPanel>
        <Border Grid.Row="1" Background="#1C2929" CornerRadius="8" Padding="17" Margin="0,22,0,16">
            <StackPanel>
                <TextBlock Text="Know the limits" FontWeight="SemiBold"/>
                <TextBlock Margin="0,7,0,0" Foreground="#BCCAC4" TextWrapping="Wrap" Text="FlashScan is not an antivirus engine or a kernel-level anti-cheat. A hash or valid signature cannot prove a file is safe. Defender findings belong to Microsoft Defender. No selected file is executed by FlashScan."/>
            </StackPanel>
        </Border>
        <Grid Grid.Row="2" Margin="0,0,0,14">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBox x:Name="FilePath" IsReadOnly="True" Text="No file selected" Background="#192222" Foreground="#DAE5E0" BorderBrush="#3B4D46" Padding="10" VerticalContentAlignment="Center"/>
            <Button Grid.Column="1" x:Name="Choose" Content="Choose file" Margin="10,0,0,0"/>
        </Grid>
        <StackPanel Grid.Row="3">
            <CheckBox x:Name="UseDefender" Content="Also request a Microsoft Defender scan (detection only)" Foreground="#DEE8E2" Margin="0,0,0,10"/>
            <TextBlock Text="Defender may require administrator access and follows your Windows security and cloud settings. FlashScan does not change those settings or upload files itself." Foreground="#99AAA2" TextWrapping="Wrap" FontSize="11"/>
            <StackPanel Orientation="Horizontal" Margin="0,14,0,12">
                <Button x:Name="Inspect" Content="Inspect selected file" IsEnabled="False"/>
                <Button x:Name="Export" Content="Export report" IsEnabled="False"/>
            </StackPanel>
            <ProgressBar x:Name="Progress" Height="3" IsIndeterminate="False" Foreground="#91CBB1" Background="#283A31"/>
            <TextBlock x:Name="Status" Text="Ready. Choose a file to begin." Margin="0,9,0,12" Foreground="#ACCEBD" TextWrapping="Wrap"/>
        </StackPanel>
        <TextBox Grid.Row="4" x:Name="Results" Text="Results will appear here." IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#151F1F" Foreground="#D7E3DC" BorderBrush="#2E4037" Padding="14" FontFamily="Consolas" FontSize="12"/>
        <TextBlock Grid.Row="5" Text="Local file inspection / No threat-free guarantee / MIT licensed" Foreground="#7C9386" Margin="0,14,0,0" FontSize="11"/>
    </Grid>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xaml))
$ui = @{}
foreach ($name in @('FilePath','Choose','UseDefender','Inspect','Export','Progress','Status','Results')) { $ui[$name] = $window.FindName($name) }
$script:selected = $null
$script:report = $null
$script:job = $null
$core = Join-Path $PSScriptRoot 'Core.ps1'
$ui.Choose.Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Title = 'Choose a file to inspect'
    if ($dialog.ShowDialog() -eq $true) {
        $script:selected = $dialog.FileName
        $ui.FilePath.Text = $script:selected
        $script:report = $null; $ui.Export.IsEnabled = $false; $ui.Inspect.IsEnabled = $true
        $ui.Results.Text = 'File selected. Press Inspect selected file to begin.'
        $ui.Status.Text = 'Ready to inspect.'
    }
})
$ui.Inspect.Add_Click({
    try {
        $script:report = $null; $ui.Export.IsEnabled = $false
        $ui.Results.Text = 'Working. Large files or Defender scans can take several minutes.'
        $ui.Status.Text = 'Inspecting...'; $ui.Progress.IsIndeterminate = $true
        $ui.Choose.IsEnabled = $false; $ui.Inspect.IsEnabled = $false; $ui.UseDefender.IsEnabled = $false
        $script:job = Start-Job -ScriptBlock { param($corePath,$path,$scan) . $corePath; Invoke-FlashInspection -Path $path -UseDefender $scan } -ArgumentList $core,$script:selected,([bool]$ui.UseDefender.IsChecked)
    } catch { $ui.Status.Text = $_.Exception.Message; $ui.Progress.IsIndeterminate = $false; $ui.Choose.IsEnabled = $true; $ui.Inspect.IsEnabled = $true; $ui.UseDefender.IsEnabled = $true }
})
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(350)
$timer.Add_Tick({
    if ($null -eq $script:job -or $script:job.State -notin @('Completed','Failed','Stopped')) { return }
    try {
        $result = Receive-Job -Job $script:job -ErrorAction Stop
        if ($null -eq $result) { throw 'The inspection ended without a result.' }
        $script:report = $result
        $ui.Results.Text = "FILE`r`n$($result.File.Path)`r`n`r`nBytes: $($result.File.Bytes)`r`nSHA-256: $($result.File.SHA256)`r`nSignature: $($result.File.Signature)`r`nPublisher: $($result.File.Publisher)`r`n`r`n$($result.Summary)`r`n`r`n$($result.Output)"
        $ui.Status.Text = 'Finished. Read the result and any Defender output.'; $ui.Export.IsEnabled = $true
    } catch { $ui.Results.Text = $_.Exception.Message; $ui.Status.Text = 'Inspection failed. No safety verdict is available.' }
    finally { Remove-Job -Job $script:job -Force; $script:job = $null; $ui.Progress.IsIndeterminate = $false; $ui.Choose.IsEnabled = $true; $ui.Inspect.IsEnabled = $true; $ui.UseDefender.IsEnabled = $true }
})
$ui.Export.Add_Click({
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter = 'JSON report (*.json)|*.json'; $dialog.FileName = 'flashscan-report.json'
    if ($dialog.ShowDialog() -eq $true) {
        try { $script:report | Select-Object File,DefenderRequested,ExitCode,Summary,Output | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $dialog.FileName -Encoding UTF8; $ui.Status.Text = 'Report saved. It contains the selected file path.' }
        catch { $ui.Status.Text = "Could not save report: $($_.Exception.Message)" }
    }
})
$window.Add_Closing({ param($sender,$event)
    if ($null -ne $script:job) { $event.Cancel = $true; $ui.Status.Text = 'Wait for the inspection to finish before closing.' }
})
$timer.Start()
try { [void]$window.ShowDialog() } finally { $timer.Stop() }
