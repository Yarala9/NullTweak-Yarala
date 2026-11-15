<#
    NullTweak - a simple, transparent Windows 10/11 optimizer & debloater
    -------------------------------------------------------------------------
    Everything this tool does is plain PowerShell: registry edits, service
    startup changes, scheduled-task toggles, and AppX removal. Nothing is
    hidden or obfuscated. Read it, change it, delete tweaks you don't want.

    Run it with the NullTweak.bat launcher (auto-elevates), or:
        powershell -ExecutionPolicy Bypass -File .\NullTweak.ps1

    A System Restore point is strongly recommended before applying (button
    is in the app). Tweaks are standard and reversible, but a restore point
    is your fastest undo if something misbehaves.
#>

# ---------------------------------------------------------------------------
# 0. Self-elevate to Administrator
# ---------------------------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    } catch { }
    return
}

# ---------------------------------------------------------------------------
# 1. Load WPF
# ---------------------------------------------------------------------------
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# ---------------------------------------------------------------------------
# 2. Detect OS (Win10 vs Win11) + edition info
# ---------------------------------------------------------------------------
$cv        = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$build     = [int]$cv.CurrentBuildNumber
$isWin11   = $build -ge 22000
$osName    = if ($isWin11) { 'Windows 11' } else { 'Windows 10' }
$displayVer = $cv.DisplayVersion
if (-not $displayVer) { $displayVer = $cv.ReleaseId }
$osLabel   = "$osName  ($displayVer, build $build)"
$verTabHeader = if ($isWin11) { 'Windows 11' } else { 'Windows 10' }

# ---------------------------------------------------------------------------
# 3. XAML - dark, minimal shell. Tweaks are injected into panels at runtime.
# ---------------------------------------------------------------------------
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="NullTweak" Height="720" Width="900"
        WindowStartupLocation="CenterScreen"
        Background="#FF161618" ResizeMode="CanResize" MinWidth="760" MinHeight="560">
    <Window.Resources>
        <!-- Scrollbar: thin dark, minimal thumb, no arrow buttons -->
        <Style TargetType="Thumb" x:Key="ScrollThumb">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Thumb">
                        <Border CornerRadius="4" Background="#FF484850" Margin="2,0,2,0"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Width" Value="12"/>
            <Setter Property="MinWidth" Value="12"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Background="Transparent">
                            <Track Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb Style="{StaticResource ScrollThumb}" MinHeight="30"/>
                                </Track.Thumb>
                                <Track.IncreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0"
                                                  Focusable="False" Background="Transparent"
                                                  BorderThickness="0"/>
                                </Track.IncreaseRepeatButton>
                                <Track.DecreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0"
                                                  Focusable="False" Background="Transparent"
                                                  BorderThickness="0"/>
                                </Track.DecreaseRepeatButton>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- CheckBox rendered as a modern toggle switch -->
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#FFE4E4E6"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="2,7,2,7"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <StackPanel Orientation="Horizontal" Background="Transparent">
                            <Border x:Name="track" Width="40" Height="22" CornerRadius="11"
                                    Background="#FF3A3A42" VerticalAlignment="Center">
                                <Border x:Name="knob" Width="16" Height="16" CornerRadius="8"
                                        Background="#FFCfCfD4" HorizontalAlignment="Left"
                                        Margin="3,0,0,0"/>
                            </Border>
                            <ContentPresenter VerticalAlignment="Center" Margin="12,0,0,0"
                                              TextElement.Foreground="{TemplateBinding Foreground}"/>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="track" Property="Background" Value="#FF2D6CDF"/>
                                <Setter TargetName="knob"  Property="HorizontalAlignment" Value="Right"/>
                                <Setter TargetName="knob"  Property="Margin" Value="0,0,3,0"/>
                                <Setter TargetName="knob"  Property="Background" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="track" Property="Opacity" Value="0.85"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Buttons -->
        <Style x:Key="Accent" TargetType="Button">
            <Setter Property="Background" Value="#FF2D6CDF"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="16,9"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="6"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FF3B7CF0"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="Ghost" TargetType="Button" BasedOn="{StaticResource Accent}">
            <Setter Property="Background" Value="#FF2A2A2E"/>
            <Setter Property="Foreground" Value="#FFE4E4E6"/>
            <Setter Property="FontWeight" Value="Normal"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FF37373C"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="Danger" TargetType="Button" BasedOn="{StaticResource Accent}">
            <Setter Property="Background" Value="#FFB23A3A"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#FFC94646"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Link-style small buttons for select all/none -->
        <Style x:Key="Link" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#FF6FA8FF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Padding" Value="6,2"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>

        <!-- TabItem -->
        <Style TargetType="TabItem">
            <Setter Property="Foreground" Value="#FF9A9AA2"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="bd" Background="Transparent" Padding="16,10" Margin="0,0,2,0"
                                CornerRadius="6,6,0,0">
                            <ContentPresenter ContentSource="Header" HorizontalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#FF232327"/>
                                <Setter Property="Foreground" Value="#FFFFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Foreground" Value="#FFD8D8DC"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="0">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Border Grid.Row="0" Background="#FF1C1C20" Padding="20,14">
            <Grid>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="Null" Foreground="#FFFFFFFF" FontSize="22" FontWeight="Bold"/>
                    <TextBlock Text="Tweak" Foreground="#FF6FA8FF" FontSize="22" FontWeight="Bold"/>
                </StackPanel>
                <TextBlock Name="OsLabel" HorizontalAlignment="Right" VerticalAlignment="Center"
                           Foreground="#FF9A9AA2" FontSize="12"/>
            </Grid>
        </Border>

        <!-- Tabs -->
        <TabControl Name="Tabs" Grid.Row="1" Background="#FF232327" BorderThickness="0" Padding="0">
            <TabItem Header="General">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="22,16">
                    <StackPanel Name="GeneralPanel"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Name="VersionTab" Header="Windows">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="22,16">
                    <StackPanel Name="VersionPanel"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="Privacy">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="22,16">
                    <StackPanel Name="PrivacyPanel"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="Performance">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="22,16">
                    <StackPanel Name="PerfPanel"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="Advanced">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="22,16">
                    <StackPanel Name="AdvancedPanel"/>
                </ScrollViewer>
            </TabItem>
            <TabItem Header="Debloat">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="22,14,22,4">
                        <TextBlock Text="Installed apps considered bloat (only removable ones are shown):"
                                   Foreground="#FF9A9AA2" FontSize="12" VerticalAlignment="Center"/>
                        <Button Name="BloatAll"  Style="{StaticResource Link}" Content="select all"/>
                        <Button Name="BloatNone" Style="{StaticResource Link}" Content="none"/>
                        <Button Name="BloatRefresh" Style="{StaticResource Link}" Content="refresh"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="22,4">
                        <StackPanel Name="DebloatPanel"/>
                    </ScrollViewer>
                    <Border Grid.Row="2" Background="#FF1C1C20" Padding="22,12">
                        <Button Name="RemoveApps" Style="{StaticResource Danger}"
                                Content="Remove Selected Apps" HorizontalAlignment="Left"/>
                    </Border>
                </Grid>
            </TabItem>
            <TabItem Header="Install">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="22,14,22,4">
                        <TextBlock Text="Pick apps to install (downloaded fresh via winget):"
                                   Foreground="#FF9A9AA2" FontSize="12" VerticalAlignment="Center"/>
                        <Button Name="InstallAll"  Style="{StaticResource Link}" Content="select all"/>
                        <Button Name="InstallNone" Style="{StaticResource Link}" Content="none"/>
                    </StackPanel>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="22,4">
                        <StackPanel Name="InstallPanel"/>
                    </ScrollViewer>
                    <Border Grid.Row="2" Background="#FF1C1C20" Padding="22,12">
                        <Button Name="InstallBtn" Style="{StaticResource Accent}"
                                Content="Install Selected Apps" HorizontalAlignment="Left"/>
                    </Border>
                </Grid>
            </TabItem>
            <TabItem Header="About">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="22,16">
                    <StackPanel>
                        <TextBlock Foreground="#FFE4E4E6" FontSize="14" FontWeight="SemiBold" Text="NullTweak"/>
                        <TextBlock Foreground="#FF9A9AA2" FontSize="12" TextWrapping="Wrap" Margin="0,8,0,0"
                                   Text="A transparent Windows 10/11 optimizer. Every action is a plain registry edit, service change, scheduled-task toggle, or AppX removal - no hidden behavior, no obfuscation. Tick what you want, click Apply."/>
                        <TextBlock Foreground="#FF9A9AA2" FontSize="12" TextWrapping="Wrap" Margin="0,12,0,0"
                                   Text="Tweaks are drawn from well-known community sources (Chris Titus WinUtil, WinAero, O&amp;O ShutUp10-style privacy defaults) and are reversible. Make a restore point first - the button is at the bottom of every tab."/>
                        <TextBlock Foreground="#FFCF8A5A" FontSize="12" TextWrapping="Wrap" Margin="0,12,0,0"
                                   Text="Items marked (!) reduce a security or safety feature (e.g. SmartScreen, Core Isolation, Defender). They're optional and off or clearly flagged. Only enable them if you understand the trade-off."/>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
        </TabControl>

        <!-- Footer / action bar -->
        <Border Grid.Row="2" Background="#FF1C1C20" Padding="20,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox Name="LogBox" Grid.Column="0" Height="70" Margin="0,0,16,0"
                         Background="#FF161618" Foreground="#FF8FC98F" BorderThickness="0"
                         FontFamily="Consolas" FontSize="11" IsReadOnly="True"
                         VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"
                         Text="Ready. Tip: create a restore point before applying."/>
                <StackPanel Grid.Column="1" Orientation="Vertical" VerticalAlignment="Center">
                    <Button Name="RestoreBtn" Style="{StaticResource Ghost}" Content="Create Restore Point" Margin="0,0,0,8"/>
                    <Button Name="ApplyBtn"   Style="{StaticResource Accent}" Content="Apply Selected Tweaks"/>
                </StackPanel>
            </Grid>
        </Border>
    </Grid>
</Window>
'@

# ---------------------------------------------------------------------------
# 4. Parse XAML
# ---------------------------------------------------------------------------
[xml]$xmlDoc = $xaml
$reader = New-Object System.Xml.XmlNodeReader $xmlDoc
$win    = [Windows.Markup.XamlReader]::Load($reader)

# grab named controls
$ctrl = @{}
foreach ($n in 'OsLabel','GeneralPanel','VersionPanel','VersionTab','PrivacyPanel','PerfPanel',
                'AdvancedPanel','DebloatPanel','LogBox','RestoreBtn','ApplyBtn','RemoveApps',
                'BloatAll','BloatNone','BloatRefresh',
                'InstallPanel','InstallBtn','InstallAll','InstallNone') {
    $ctrl[$n] = $win.FindName($n)
}
$ctrl.OsLabel.Text        = $osLabel
$ctrl.VersionTab.Header   = $verTabHeader

# ---------------------------------------------------------------------------
# 5. Logging helper
# ---------------------------------------------------------------------------
function Write-Log {
    param([string]$msg, [string]$level = 'ok')
    $time = (Get-Date).ToString('HH:mm:ss')
    $ctrl.LogBox.Dispatcher.Invoke([action]{
        $ctrl.LogBox.AppendText("`r`n[$time] $msg")
        $ctrl.LogBox.ScrollToEnd()
    })
}

# ---------------------------------------------------------------------------
# 6. Low-level action runners
# ---------------------------------------------------------------------------
function Set-Reg {
    param($Path, $Name, $Type, $Value)
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
}

function Set-ServiceStartup {
    param($Name, [ValidateSet('Disabled','Manual','Automatic')]$Start)
    $map = @{ Disabled = 4; Manual = 3; Automatic = 2 }
    # Registry-level change is the most reliable (works on protected services).
    $svcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    if (Test-Path $svcPath) {
        Set-ItemProperty -Path $svcPath -Name 'Start' -Value $map[$Start] -Type DWord -Force -ErrorAction SilentlyContinue
    }
    # Best-effort stop + Set-Service for the live state.
    try { Set-Service -Name $Name -StartupType $Start -ErrorAction SilentlyContinue } catch {}
    if ($Start -eq 'Disabled') {
        try { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue } catch {}
    }
}

function Disable-Task {
    param($TaskPath, $TaskName)
    try { Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop | Out-Null }
    catch { }
}

function Invoke-TweakAction {
    param($a)
    switch ($a.Type) {
        'Reg'      { Set-Reg -Path $a.Path -Name $a.Name -Type $a.PropType -Value $a.Value }
        'Service'  { Set-ServiceStartup -Name $a.Name -Start $a.Start }
        'SchTask'  { Disable-Task -TaskPath $a.Path -TaskName $a.Name }
        'Cmd'      { & $a.Script }
    }
}

# ---------------------------------------------------------------------------
# 7. Registry convenience builders (keep tweak defs short)
# ---------------------------------------------------------------------------
function RegD { param($p,$n,$v) @{ Type='Reg'; Path=$p; Name=$n; PropType='DWord';  Value=$v } }  # DWord
function RegS { param($p,$n,$v) @{ Type='Reg'; Path=$p; Name=$n; PropType='String'; Value=$v } }  # String
function Svc  { param($n,$s='Disabled') @{ Type='Service'; Name=$n; Start=$s } }
function Task { param($p,$n) @{ Type='SchTask'; Path=$p; Name=$n } }

# Common roots
$HKCU = 'HKCU:\Software'
$HKLM = 'HKLM:\SOFTWARE'

# ---------------------------------------------------------------------------
# 8. Tweak catalog
#    Each tweak = @{ Name; Desc; Default; Warn; Actions=@(...) }
# ---------------------------------------------------------------------------

# ---- GENERAL (preference / cosmetic - safe to toggle to taste) ----
$generalTweaks = @(
    @{ Name='Show file extensions'; Default=$true; Desc='Always show file extensions in Explorer.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'HideFileExt' 0) ) }

    @{ Name='Show hidden files'; Default=$false; Desc='Show hidden files and folders.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'Hidden' 1) ) }

    @{ Name='Enable dark mode'; Default=$true; Desc='System and app dark theme.'
       Actions=@(
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Themes\Personalize" 'AppsUseLightTheme' 0),
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Themes\Personalize" 'SystemUsesLightTheme' 0) ) }

    @{ Name='Disable transparency / blur'; Default=$false; Desc='Turns off the acrylic blur on Start, taskbar and windows. Tiny GPU saving; purely a look choice.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Themes\Personalize" 'EnableTransparency' 0) ) }

    @{ Name='Disable window animations'; Default=$false; Desc='No minimize/maximize and taskbar animations - feels snappier.'
       Actions=@(
           (RegS 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0'),
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'TaskbarAnimations' 0) ) }

    @{ Name='Faster menus'; Default=$true; Desc='Removes the delay before menus open (MenuShowDelay = 0).'
       Actions=@( (RegS 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0') ) }

    @{ Name='Remove startup app delay'; Default=$true; Desc='Startup apps launch right away instead of being held back after login.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Explorer\Serialize" 'StartupDelayInMSec' 0) ) }

    @{ Name='Hide the taskbar Search box'; Default=$true; Desc='Removes the big search field from the taskbar.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Search" 'SearchboxTaskbarMode' 0) ) }

    @{ Name='Disable web/Bing results in Start search'; Default=$true; Desc='Start menu searches your PC only, not the web.'
       Actions=@(
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Search" 'BingSearchEnabled' 0),
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Search" 'CortanaConsent' 0),
           (RegD "$HKLM\Policies\Microsoft\Windows\Explorer" 'DisableSearchBoxSuggestions' 1) ) }

    @{ Name='Disable "My People" on taskbar'; Default=$true; Desc='Hide the People band.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" 'PeopleBand' 0) ) }

    @{ Name='Disable Sticky Keys shortcut'; Default=$true; Desc='Stop the 5x-Shift Sticky Keys popup.'
       Actions=@( (RegS 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' '506') ) }

    @{ Name='Disable Windows Ink Workspace'; Default=$false; Desc='Pen workspace off (safe on non-touch).'
       Actions=@( (RegD "$HKLM\Policies\Microsoft\WindowsInkWorkspace" 'AllowWindowsInkWorkspace' 0) ) }
)

# ---- PRIVACY / TELEMETRY (O&O ShutUp10-style defaults, mostly ON) ----
$privacyTweaks = @(
    @{ Name='Disable telemetry services (DiagTrack)'; Default=$true; Desc='Stops Connected User Experiences & Telemetry + dmwappushservice.'
       Actions=@( (Svc 'DiagTrack'), (Svc 'dmwappushservice') ) }

    @{ Name='Disable telemetry level (policy)'; Default=$true; Desc='Sets AllowTelemetry to the lowest value.'
       Actions=@(
           (RegD "$HKLM\Policies\Microsoft\Windows\DataCollection" 'AllowTelemetry' 0),
           (RegD "$HKLM\Microsoft\Windows\CurrentVersion\Policies\DataCollection" 'AllowTelemetry' 0) ) }

    @{ Name='Disable telemetry scheduled tasks'; Default=$true; Desc='CEIP + Compatibility Appraiser tasks.'
       Actions=@(
           (Task '\Microsoft\Windows\Application Experience\' 'Microsoft Compatibility Appraiser'),
           (Task '\Microsoft\Windows\Application Experience\' 'ProgramDataUpdater'),
           (Task '\Microsoft\Windows\Customer Experience Improvement Program\' 'Consolidator'),
           (Task '\Microsoft\Windows\Customer Experience Improvement Program\' 'UsbCeip'),
           (Task '\Microsoft\Windows\DiskDiagnostic\' 'Microsoft-Windows-DiskDiagnosticDataCollector') ) }

    @{ Name='Disable Advertising ID & tailored experiences'; Default=$true; Desc='No ad ID, no diagnostic-based personalization.'
       Actions=@(
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\AdvertisingInfo" 'Enabled' 0),
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Privacy" 'TailoredExperiencesWithDiagnosticDataEnabled' 0) ) }

    @{ Name='Disable activity history / Timeline'; Default=$true; Desc='Stop collecting and uploading activity history.'
       Actions=@(
           (RegD "$HKLM\Policies\Microsoft\Windows\System" 'EnableActivityFeed' 0),
           (RegD "$HKLM\Policies\Microsoft\Windows\System" 'PublishUserActivities' 0),
           (RegD "$HKLM\Policies\Microsoft\Windows\System" 'UploadUserActivities' 0) ) }

    @{ Name='Disable Cortana'; Default=$true; Desc='Turn off Cortana via policy.'
       Actions=@( (RegD "$HKLM\Policies\Microsoft\Windows\Windows Search" 'AllowCortana' 0) ) }

    @{ Name='Disable Start menu ads & suggestions'; Default=$true; Desc='No "recommended" app ads / tips.'
       Actions=@(
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-338388Enabled' 0),
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-338389Enabled' 0),
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SystemPaneSuggestionsEnabled' 0),
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SilentInstalledAppsEnabled' 0) ) }

    @{ Name='Disable News & Interests / Widgets'; Default=$true; Desc='Turn off the taskbar news feed / widgets.'
       Actions=@(
           (RegD "$HKLM\Policies\Microsoft\Dsh" 'AllowNewsAndInterests' 0),
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Feeds" 'ShellFeedsTaskbarViewMode' 2) ) }

    @{ Name='Disable Edge telemetry & Discover'; Default=$true; Desc='No Edge diagnostic data, no Discover sidebar.'
       Actions=@(
           (RegD "$HKLM\Policies\Microsoft\Edge" 'DiagnosticData' 0),
           (RegD "$HKLM\Policies\Microsoft\Edge" 'HubsSidebarEnabled' 0),
           (RegD "$HKLM\Policies\Microsoft\Edge" 'PersonalizationReportingEnabled' 0) ) }

    @{ Name='Disable Error Reporting'; Default=$true; Desc='Stops Windows Error Reporting service.'
       Actions=@( (Svc 'WerSvc'),
           (RegD "$HKLM\Policies\Microsoft\Windows\Windows Error Reporting" 'Disabled' 1) ) }

    @{ Name='Disable Program Compatibility Assistant'; Default=$true; Desc='Stops the PcaSvc nag service.'
       Actions=@( (Svc 'PcaSvc') ) }

    @{ Name='Disable location sensor services'; Default=$true; Desc='Turns off sensor + geolocation services.'
       Actions=@( (Svc 'SensrSvc'), (Svc 'SensorService'), (Svc 'SensorDataService'), (Svc 'lfsvc') ) }

    @{ Name='Disable Media Player network sharing'; Default=$true; Desc='Stops WMPNetworkSvc.'
       Actions=@( (Svc 'WMPNetworkSvc') ) }

    @{ Name='Disable Fax service'; Default=$true; Desc='Stops the Fax service - useless on nearly every modern PC.'
       Actions=@( (Svc 'Fax') ) }

    @{ Name='Disable Remote Registry'; Default=$true; Desc='Stops remote editing of your registry (safe, rarely used).'
       Actions=@( (Svc 'RemoteRegistry') ) }

    @{ Name='Disable Office telemetry'; Default=$true; Desc='No Office usage logging/upload.'
       Actions=@(
           (RegD "$HKCU\Policies\Microsoft\office\16.0\osm" 'Enablelogging' 0),
           (RegD "$HKCU\Policies\Microsoft\office\16.0\osm" 'EnableUpload' 0) ) }

    @{ Name='Disable Firefox telemetry'; Default=$true; Desc='Policy-level Firefox telemetry off.'
       Actions=@( (RegD "$HKLM\Policies\Mozilla\Firefox" 'DisableTelemetry' 1) ) }

    @{ Name='Disable Chrome telemetry'; Default=$true; Desc='Policy-level Chrome metrics reporting off.'
       Actions=@( (RegD "$HKLM\Policies\Google\Chrome" 'MetricsReportingEnabled' 0) ) }

    @{ Name='Disable NVIDIA telemetry'; Default=$true; Desc='Disables NvTmRep / NvTmMon scheduled tasks.'
       Actions=@( @{ Type='Cmd'; Script={
            Get-ScheduledTask -ErrorAction SilentlyContinue |
                Where-Object { $_.TaskName -like '*NvTm*' } |
                ForEach-Object { Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue | Out-Null }
       } } ) }

    @{ Name='Disable Visual Studio telemetry'; Default=$true; Desc='Opt out of VS SQM.'
       Actions=@( (RegD "$HKLM\Policies\Microsoft\VisualStudio\SQM" 'OptIn' 0) ) }

    @{ Name='Disable SmartScreen  (!)'; Default=$false; Warn=$true
       Desc='(!) Turns off SmartScreen app/file reputation checks. Reduces protection against malicious downloads.'
       Actions=@(
           (RegD "$HKLM\Policies\Microsoft\Windows\System" 'EnableSmartScreen' 0),
           (RegS 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled' 'Off') ) }
)

# ---- PERFORMANCE ----
$perfTweaks = @(
    @{ Name='NullTweak Competitive power plan'; Default=$true
       Desc='Custom plan based on Ultimate Performance: CPU always 100%, no core parking, aggressive boost, USB/PCIe power saving off, no disk/sleep timeouts. Best for competitive games. Uses more power - on a laptop, applies only when plugged in.'
       Actions=@( @{ Type='Cmd'; Script={
            $planName = 'NullTweak Competitive'
            $list = powercfg /list | Out-String
            $g = $null
            if ($list -match "([0-9a-fA-F\-]{36})\s+\($planName\)") { $g = $matches[1] }
            if (-not $g) {
                # Ultimate Performance base; fall back to High Performance
                $out = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null | Out-String
                if ($out -notmatch '([0-9a-fA-F\-]{36})') {
                    $out = powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null | Out-String
                }
                if ($out -match '([0-9a-fA-F\-]{36})') { $g = $matches[1] }
                if ($g) { powercfg -changename $g $planName 'Low-latency plan for competitive gaming (NullTweak)' | Out-Null }
            }
            if (-not $g) { Write-Log '  ! Could not create power plan.'; return }

            # CPU: min/max 100%, aggressive boost, no core parking
            powercfg -setacvalueindex $g SUB_PROCESSOR PROCTHROTTLEMIN 100 | Out-Null
            powercfg -setacvalueindex $g SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
            powercfg -setacvalueindex $g SUB_PROCESSOR PERFBOOSTMODE 2      | Out-Null
            powercfg -setacvalueindex $g SUB_PROCESSOR CPMINCORES 100       | Out-Null
            # USB selective suspend off
            powercfg -setacvalueindex $g 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
            # PCIe link state power management off
            powercfg -setacvalueindex $g SUB_PCIEXPRESS ASPM 0 | Out-Null
            # Never turn off disk, never sleep/hibernate
            powercfg -setacvalueindex $g SUB_DISK DISKIDLE 0       | Out-Null
            powercfg -setacvalueindex $g SUB_SLEEP STANDBYIDLE 0   | Out-Null
            powercfg -setacvalueindex $g SUB_SLEEP HIBERNATEIDLE 0 | Out-Null

            powercfg -setactive $g | Out-Null
            Write-Log "  Power plan '$planName' active."
       } } ) }

    @{ Name='Enable Game Mode'; Default=$true; Desc='Prioritize the active game.'
       Actions=@(
           (RegD "$HKCU\Microsoft\GameBar" 'AutoGameModeEnabled' 1),
           (RegD "$HKCU\Microsoft\GameBar" 'AllowAutoGameMode' 1) ) }

    @{ Name='Disable Game Bar & GameDVR capture'; Default=$true; Desc='Stops background game recording overhead.'
       Actions=@(
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\GameDVR" 'AppCaptureEnabled' 0),
           (RegD 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0),
           (RegD "$HKLM\Policies\Microsoft\Windows\GameDVR" 'AllowGameDVR' 0) ) }

    @{ Name='Disable Xbox Live services'; Default=$true; Desc='Disable Xbox auth/save/networking services.'
       Actions=@( (Svc 'XblAuthManager'), (Svc 'XblGameSave'), (Svc 'XboxGipSvc'), (Svc 'XboxNetApiSvc') ) }

    @{ Name='Win32PrioritySeparation = 40 (foreground responsiveness)'; Default=$true
       Desc='Short/fixed quantum, no boost - snappier input for gaming (decimal 40 / 0x28). Try 38 or 26 if you prefer smoothness.'
       Actions=@( (RegD 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 40) ) }

    @{ Name='Disable background apps'; Default=$true; Desc='Stop UWP apps running in the background.'
       Actions=@(
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" 'GlobalUserDisabled' 1),
           (RegD "$HKLM\Policies\Microsoft\Windows\AppPrivacy" 'LetAppsRunInBackground' 2) ) }

    @{ Name='Disable power throttling'; Default=$true
       Desc='Stops Windows from slowing down background/game processes to save power.'
       Actions=@( (RegD 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1) ) }

    @{ Name='Disable fullscreen optimizations'; Default=$true
       Desc='Gives games true exclusive fullscreen - can lower input lag in competitive titles.'
       Actions=@(
           (RegD 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehaviorMode' 2),
           (RegD 'HKCU:\System\GameConfigStore' 'GameDVR_HonorUserFSEBehaviorMode' 1),
           (RegD 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehavior' 2),
           (RegD 'HKCU:\System\GameConfigStore' 'GameDVR_DXGIHonorFSEWindowsCompatible' 1) ) }

    @{ Name='Prioritize games (CPU/GPU scheduling)'; Default=$true
       Desc='Raises the Games multimedia profile to high CPU/GPU priority and reserves less CPU for background tasks.'
       Actions=@(
           (RegD 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 0),
           (RegD 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' 0xffffffff),
           (RegD 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'GPU Priority' 8),
           (RegD 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'Priority' 6),
           (RegS 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'Scheduling Category' 'High'),
           (RegS 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'SFIO Priority' 'High') ) }

    @{ Name='Disable mouse acceleration'; Default=$true
       Desc='Turns off "Enhance pointer precision" - 1:1 raw aim, standard for FPS games.'
       Actions=@(
           (RegS 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0'),
           (RegS 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0'),
           (RegS 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0') ) }

    @{ Name='Hardware-accelerated GPU scheduling'; Default=$false
       Desc='Lets the GPU manage its own memory. Helps on many RTX/RX cards, hurts on some - try it and compare. Reboot required.'
       Actions=@( (RegD 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2) ) }

    @{ Name='Lower network latency (disable Nagle)'; Default=$false
       Desc='Sends small packets immediately on all network adapters. Can reduce ping jitter in online games.'
       Actions=@( @{ Type='Cmd'; Script={
            Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction SilentlyContinue |
                ForEach-Object {
                    New-ItemProperty -Path $_.PSPath -Name 'TcpAckFrequency' -PropertyType DWord -Value 1 -Force | Out-Null
                    New-ItemProperty -Path $_.PSPath -Name 'TCPNoDelay'      -PropertyType DWord -Value 1 -Force | Out-Null
                }
       } } ) }

    @{ Name='Disable SysMain (Superfetch)'; Default=$false
       Desc='Stops background preloading. Good on SSDs to cut random disk/CPU usage; leave on for HDDs.'
       Actions=@( (Svc 'SysMain') ) }

    @{ Name='Disable hibernation'; Default=$false
       Desc='Removes hiberfil.sys (frees several GB) and disables Fast Startup. Laptops lose hibernate.'
       Actions=@( @{ Type='Cmd'; Script={ powercfg -h off | Out-Null } } ) }

    @{ Name='Disable Delivery Optimization P2P'; Default=$true
       Desc='Stops Windows using your upload bandwidth to share updates with other PCs.'
       Actions=@( (RegD "$HKLM\Policies\Microsoft\Windows\DeliveryOptimization" 'DODownloadMode' 0) ) }

    @{ Name='Enable Long Paths (>260 chars)'; Default=$true; Desc='Allow long file paths.'
       Actions=@( (RegD 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1) ) }

    @{ Name='Restore classic Photo Viewer'; Default=$false; Desc='Re-register Windows Photo Viewer for common image types.'
       Actions=@( @{ Type='Cmd'; Script={
            $assoc = 'HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations'
            if (-not (Test-Path $assoc)) { New-Item -Path $assoc -Force | Out-Null }
            foreach ($ext in '.jpg','.jpeg','.png','.bmp','.gif','.tif','.tiff','.ico') {
                New-ItemProperty -Path $assoc -Name $ext -Value 'PhotoViewer.FileAssoc.Tiff' -PropertyType String -Force | Out-Null
            }
            $cmd = '%SystemRoot%\System32\rundll32.exe "%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll", ImageView_Fullscreen %1'
            $shellKey = 'HKLM:\SOFTWARE\Classes\PhotoViewer.FileAssoc.Tiff\shell\open\command'
            if (-not (Test-Path $shellKey)) { New-Item -Path $shellKey -Force | Out-Null }
            New-ItemProperty -Path $shellKey -Name '(Default)' -Value $cmd -PropertyType ExpandString -Force | Out-Null
       } } ) }

    @{ Name='Remove "Cast to Device" context menu'; Default=$false; Desc='Hide the Cast shell extension.'
       Actions=@( (RegS 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked' '{7AD84985-87B4-4a16-BE58-8B72A5B390F7}' 'Play to menu') ) }

    @{ Name='Set non-essential services to Manual'; Default=$false
       Desc='Sets a curated list of rarely-needed services to Manual (they start on demand). Conservative, reversible.'
       Actions=@(
           (Svc 'MapsBroker' 'Manual'), (Svc 'RetailDemo' 'Manual'), (Svc 'RemoteRegistry' 'Disabled'),
           (Svc 'WbioSrvc' 'Manual'), (Svc 'Fax' 'Manual'), (Svc 'PhoneSvc' 'Manual'),
           (Svc 'WpcMonSvc' 'Manual'), (Svc 'SharedAccess' 'Manual') ) }

    @{ Name='Disable Print Spooler  (!)'; Default=$false; Warn=$true
       Desc='(!) Disables printing entirely. Only if you never print.'
       Actions=@( (Svc 'Spooler') ) }
)

# ---- ADVANCED (security trade-offs / power-user) ----
$advancedTweaks = @(
    @{ Name='Disable Core Isolation / Memory Integrity  (!)'; Default=$false; Warn=$true
       Desc='(!) Disables HVCI. Microsoft suggests this for gaming performance, but it lowers kernel protection. Reboot required.'
       Actions=@( (RegD 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 0) ) }

    @{ Name='Disable Virtualization Based Security  (!)'; Default=$false; Warn=$true
       Desc='(!) Turns off VBS. Can improve performance; lowers security. Reboot required.'
       Actions=@( (RegD 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity' 0) ) }

    @{ Name='Disable Modern Standby (S0)'; Default=$false
       Desc='Forces legacy sleep handling (PlatformAoAcOverride). Helps some desktops.'
       Actions=@( (RegD 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'PlatformAoAcOverride' 0) ) }

    @{ Name='Allow upgrade on unsupported TPM/CPU'; Default=$false
       Desc='Sets AllowUpgradesWithUnsupportedTPMOrCPU for Win11 upgrades on older hardware.'
       Actions=@( (RegD 'HKLM:\SYSTEM\Setup\MoSetup' 'AllowUpgradesWithUnsupportedTPMOrCPU' 1) ) }

    @{ Name='Disable SMBv1 protocol'; Default=$true; Desc='Removes the legacy, insecure SMBv1 feature (keeps SMBv2/3).'
       Actions=@( @{ Type='Cmd'; Script={
            Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null
       } } ) }

    @{ Name='Disable Windows Defender real-time  (!!)'; Default=$false; Warn=$true
       Desc='(!!) Turns off Microsoft Defender real-time protection. REQUIRES Tamper Protection to be OFF first (Windows Security > Virus & threat protection > Manage settings). Leaves your PC unprotected unless you run another AV. You will be asked to confirm.'
       Confirm=$true
       Actions=@(
           (RegD "$HKLM\Policies\Microsoft\Windows Defender" 'DisableAntiSpyware' 1),
           (RegD "$HKLM\Policies\Microsoft\Windows Defender\Real-Time Protection" 'DisableRealtimeMonitoring' 1),
           @{ Type='Cmd'; Script={
                try { Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue } catch {}
           } } ) }
)

# ---------------------------------------------------------------------------
# 9. Version-specific tweaks
# ---------------------------------------------------------------------------
$win11Tweaks = @(
    @{ Name='Restore classic right-click context menu'; Default=$true; Desc='Brings back the full Win10-style menu.'
       Actions=@( (RegS 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '(Default)' '') ) }

    @{ Name='Align taskbar to the left'; Default=$false; Desc='Classic left-aligned taskbar.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'TaskbarAl' 0) ) }

    @{ Name='Hide Task View button'; Default=$true; Desc='Remove Task View from the taskbar.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'ShowTaskViewButton' 0) ) }

    @{ Name='Hide Widgets button'; Default=$true; Desc='Remove the Widgets icon (policy method - works on 24H2+).'
       Actions=@(
           (RegD "$HKLM\Policies\Microsoft\Dsh" 'AllowNewsAndInterests' 0),
           @{ Type='Cmd'; Script={
                try { Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa' -Value 0 -Type DWord -ErrorAction Stop } catch {}
           } } ) }

    @{ Name='Hide Chat / Teams button'; Default=$true; Desc='Remove the consumer Teams Chat icon.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'TaskbarMn' 0) ) }

    @{ Name='Disable Copilot'; Default=$true; Desc='Turn off Windows Copilot via policy.'
       Actions=@(
           (RegD "$HKCU\Policies\Microsoft\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' 1),
           (RegD "$HKLM\Policies\Microsoft\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' 1) ) }

    @{ Name='Disable Recall / AI data collection'; Default=$true; Desc='Policy opt-out of Windows Recall snapshots.'
       Actions=@( (RegD "$HKLM\Policies\Microsoft\Windows\WindowsAI" 'DisableAIDataAnalysis' 1) ) }

    @{ Name='Disable "Recommended" Start section ads'; Default=$true; Desc='Hide suggested content in Start.'
       Actions=@( (RegD "$HKLM\Policies\Microsoft\Windows\Explorer" 'HideRecommendedSection' 1) ) }

    @{ Name='Show "End Task" on taskbar right-click'; Default=$false; Desc='Enable the dev End Task option.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\TaskbarDeveloperSettings" 'TaskbarEndTask' 1) ) }
)

$win10Tweaks = @(
    @{ Name='Disable Meet Now on taskbar'; Default=$true; Desc='Hide the Meet Now icon.'
       Actions=@( (RegD "$HKLM\Policies\Microsoft\Windows\Explorer" 'HideSCAMeetNow' 1) ) }

    @{ Name='Disable Cortana taskbar button'; Default=$true; Desc='Hide Cortana from the taskbar.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'ShowCortanaButton' 0) ) }

    @{ Name='Disable Task View button'; Default=$true; Desc='Remove Task View from the taskbar.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Explorer\Advanced" 'ShowTaskViewButton' 0) ) }

    @{ Name='Disable People band'; Default=$true; Desc='Hide the People taskbar feature.'
       Actions=@( (RegD "$HKCU\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" 'PeopleBand' 0) ) }

    @{ Name='Disable lock screen Spotlight ads'; Default=$true; Desc='No "fun facts / tips" on the lock screen.'
       Actions=@(
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'RotatingLockScreenOverlayEnabled' 0),
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SubscribedContent-338387Enabled' 0) ) }

    @{ Name='Disable "Suggested apps" auto-install'; Default=$true; Desc='Stop silent promo app installs.'
       Actions=@(
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'SilentInstalledAppsEnabled' 0),
           (RegD "$HKCU\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" 'PreInstalledAppsEnabled' 0) ) }

    @{ Name='Disable Edge desktop shortcut recreation'; Default=$false; Desc='Stop Edge re-adding its shortcut.'
       Actions=@( (RegD "$HKLM\Microsoft\Windows\CurrentVersion\Explorer" 'DisableEdgeDesktopShortcutCreation' 1) ) }
)

$versionTweaks = if ($isWin11) { $win11Tweaks } else { $win10Tweaks }

# ---------------------------------------------------------------------------
# 10. Render tweaks into panels
# ---------------------------------------------------------------------------
$script:AllCheckBoxes = New-Object System.Collections.ArrayList

function Add-SectionHeader {
    param($panel, $text)
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text = $text
    $tb.Foreground = '#FF6FA8FF'
    $tb.FontSize = 12
    $tb.FontWeight = 'SemiBold'
    $tb.Margin = '0,6,0,2'
    [void]$panel.Children.Add($tb)
}

function Add-Tweaks {
    param($panel, $tweaks)
    foreach ($t in $tweaks) {
        $cb = New-Object Windows.Controls.CheckBox
        $cb.Content   = $t.Name
        $cb.IsChecked = [bool]$t.Default
        $cb.ToolTip   = $t.Desc
        if ($t.Warn) { $cb.Foreground = '#FFCF8A5A' }
        $cb.Tag = $t
        [void]$panel.Children.Add($cb)

        # small description line under the checkbox
        $d = New-Object Windows.Controls.TextBlock
        $d.Text = $t.Desc
        $d.Foreground = '#FF77777E'
        $d.FontSize = 11
        $d.TextWrapping = 'Wrap'
        $d.Margin = '24,-4,0,4'
        [void]$panel.Children.Add($d)

        [void]$script:AllCheckBoxes.Add($cb)
    }
}

Add-Tweaks $ctrl.GeneralPanel  $generalTweaks
Add-Tweaks $ctrl.VersionPanel  $versionTweaks
Add-Tweaks $ctrl.PrivacyPanel  $privacyTweaks
Add-Tweaks $ctrl.PerfPanel     $perfTweaks
Add-Tweaks $ctrl.AdvancedPanel $advancedTweaks

# ---------------------------------------------------------------------------
# 11. Debloat tab - list only installed, removable, "bloat" AppX packages
# ---------------------------------------------------------------------------
# Friendly-name map for known packages (anything matched shows a clean label).
$bloatMap = [ordered]@{
    'Microsoft.BingNews'                    = 'Microsoft News'
    'Microsoft.BingWeather'                 = 'Weather'
    'Microsoft.BingSearch'                  = 'Web Search (Bing)'
    'Microsoft.GamingApp'                   = 'Xbox App'
    'Microsoft.XboxGamingOverlay'           = 'Xbox Game Bar Overlay'
    'Microsoft.XboxGameOverlay'             = 'Xbox Game Overlay'
    'Microsoft.Xbox.TCUI'                   = 'Xbox TCUI'
    'Microsoft.XboxIdentityProvider'        = 'Xbox Identity Provider'
    'Microsoft.XboxSpeechToTextOverlay'     = 'Xbox Speech-To-Text'
    'Microsoft.MicrosoftSolitaireCollection'= 'Solitaire Collection'
    'Microsoft.People'                      = 'People'
    'Microsoft.windowscommunicationsapps'   = 'Mail and Calendar'
    'Microsoft.YourPhone'                   = 'Phone Link'
    'Microsoft.ZuneMusic'                   = 'Media Player (Groove)'
    'Microsoft.ZuneVideo'                   = 'Movies & TV'
    'Microsoft.MixedReality.Portal'         = 'Mixed Reality Portal'
    'Microsoft.Getstarted'                  = 'Tips / Get Started'
    'Microsoft.GetHelp'                     = 'Get Help'
    'Microsoft.Microsoft3DViewer'           = '3D Viewer'
    'Microsoft.MicrosoftOfficeHub'          = 'Office Hub'
    'Microsoft.Office.OneNote'              = 'OneNote (Store)'
    'Microsoft.SkypeApp'                    = 'Skype'
    'Microsoft.Todos'                       = 'Microsoft To Do'
    'Microsoft.PowerAutomateDesktop'        = 'Power Automate'
    'Microsoft.WindowsFeedbackHub'          = 'Feedback Hub'
    'Microsoft.WindowsMaps'                 = 'Maps'
    'MicrosoftTeams'                        = 'Teams (consumer)'
    'MSTeams'                               = 'Teams (consumer)'
    'Clipchamp.Clipchamp'                   = 'Clipchamp'
    'Microsoft.549981C3F5F10'               = 'Cortana'
    'Microsoft.Windows.DevHome'             = 'Dev Home'
    'Microsoft.OutlookForWindows'           = 'Outlook (new)'
    'Microsoft.MicrosoftStickyNotes'        = 'Sticky Notes'
    'Microsoft.WindowsSoundRecorder'        = 'Sound Recorder'
    'Microsoft.MicrosoftJournal'            = 'Journal'
    'Microsoft.Whiteboard'                  = 'Whiteboard'
    'Microsoft.Wallet'                      = 'Wallet'
    'Microsoft.BingFinance'                 = 'Finance'
    'Microsoft.BingSports'                  = 'Sports'
    'king.com.CandyCrushSaga'               = 'Candy Crush'
    'Microsoft.Advertising.Xaml'            = 'Microsoft Advertising'
    'Microsoft.QuickAssist'                 = 'Quick Assist'
}
# Never offer these (core/essential) - defensive even though not in map.
$bloatProtect = @('Store','Calculator','Photos','Terminal','Notepad','Paint','ScreenSketch',
                  'SnippingTool','VCLibs','NET.Native','DesktopAppInstaller','StorePurchaseApp',
                  'ShellExperience','StartExperiences','WindowsNotepad','SecHealthUI','Immersive',
                  'XboxGameCallableUI','AAD.BrokerPlugin','AccountsControl','LockApp','NarratorQuickStart')

$script:BloatCheckBoxes = New-Object System.Collections.ArrayList

function Load-Bloat {
    $ctrl.DebloatPanel.Children.Clear()
    $script:BloatCheckBoxes.Clear()
    $installed = @{}
    try {
        Get-AppxPackage -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -and -not $_.NonRemovable) { $installed[$_.Name] = $_.PackageFullName }
        }
    } catch {}

    $shown = 0
    foreach ($key in $bloatMap.Keys) {
        # match by prefix (package names carry publisher suffixes)
        $match = $installed.Keys | Where-Object { $_ -like "$key*" } | Select-Object -First 1
        if ($match) {
            $protected = $false
            foreach ($p in $bloatProtect) { if ($match -like "*$p*") { $protected = $true; break } }
            if ($protected) { continue }

            $cb = New-Object Windows.Controls.CheckBox
            $cb.Content   = $bloatMap[$key]
            $cb.IsChecked = $false
            $cb.ToolTip   = $match
            $cb.Tag       = $match
            [void]$ctrl.DebloatPanel.Children.Add($cb)
            [void]$script:BloatCheckBoxes.Add($cb)
            $shown++
        }
    }
    if ($shown -eq 0) {
        $tb = New-Object Windows.Controls.TextBlock
        $tb.Text = 'No known bloat apps found installed. Nice - your system is already pretty clean.'
        $tb.Foreground = '#FF77777E'; $tb.FontSize = 12; $tb.Margin = '0,8,0,0'
        [void]$ctrl.DebloatPanel.Children.Add($tb)
    }
    Write-Log "Debloat list loaded: $shown app(s) found."
}
Load-Bloat

# ---------------------------------------------------------------------------
# 11b. Install tab - winget apps, grouped by category
# ---------------------------------------------------------------------------
$installApps = [ordered]@{
    'Browsers' = @(
        @{ N='Brave';                Id='Brave.Brave' },
        @{ N='Mozilla Firefox';      Id='Mozilla.Firefox' },
        @{ N='Google Chrome';        Id='Google.Chrome' }
    )
    'Compression & Tools' = @(
        @{ N='7-Zip';                Id='7zip.7zip' },
        @{ N='WinRAR';               Id='RARLab.WinRAR' },
        @{ N='Notepad++';            Id='Notepad++.Notepad++' },
        @{ N='VLC Media Player';     Id='VideoLAN.VLC' }
    )
    'Gaming & Social' = @(
        @{ N='Roblox';               Id='Roblox.Roblox'; Src='msstore' },
        @{ N='Roblox Studio';        Id='Roblox.RobloxStudio' },
        @{ N='Steam';                Id='Valve.Steam' },
        @{ N='Discord';              Id='Discord.Discord' },
        @{ N='Epic Games Launcher';  Id='EpicGames.EpicGamesLauncher' }
    )
    'Extras' = @(
        @{ N='PowerToys';            Id='Microsoft.PowerToys' },
        @{ N='Spotify';              Id='Spotify.Spotify' }
    )
}
$script:InstallCheckBoxes = New-Object System.Collections.ArrayList

function Load-Install {
    $ctrl.InstallPanel.Children.Clear()
    $script:InstallCheckBoxes.Clear()
    $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    if (-not $hasWinget) {
        $tb = New-Object Windows.Controls.TextBlock
        $tb.Text = "winget (Windows Package Manager) isn't available on this PC. Install 'App Installer' from the Microsoft Store, then reopen NullTweak."
        $tb.Foreground = '#FFCF8A5A'; $tb.FontSize = 12; $tb.TextWrapping = 'Wrap'; $tb.Margin = '0,8,0,0'
        [void]$ctrl.InstallPanel.Children.Add($tb)
        return
    }
    foreach ($group in $installApps.Keys) {
        Add-SectionHeader $ctrl.InstallPanel $group
        foreach ($app in $installApps[$group]) {
            $cb = New-Object Windows.Controls.CheckBox
            $cb.Content   = $app.N
            $cb.IsChecked = $false
            $cb.ToolTip   = "winget id: $($app.Id)"
            $cb.Tag       = $app
            [void]$ctrl.InstallPanel.Children.Add($cb)
            [void]$script:InstallCheckBoxes.Add($cb)
        }
    }
}
Load-Install

# ---------------------------------------------------------------------------
# 12. Button handlers
# ---------------------------------------------------------------------------
$ctrl.RestoreBtn.Add_Click({
    Write-Log 'Creating system restore point...'
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # allow more than one restore point per 24h
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 'DWord' 0
        Checkpoint-Computer -Description 'NullTweak - before tweaks' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Log 'Restore point created.'
    } catch {
        Write-Log "Restore point failed: $($_.Exception.Message). (System Protection may be off - enable it in System Properties.)"
    }
})

$ctrl.ApplyBtn.Add_Click({
    $selected = $script:AllCheckBoxes | Where-Object { $_.IsChecked }
    if (-not $selected) { Write-Log 'Nothing selected.'; return }

    # Confirm gate for any tweak that asks for it (e.g. Defender).
    foreach ($cb in $selected) {
        if ($cb.Tag.Confirm) {
            $r = [Windows.MessageBox]::Show(
                "You enabled:`n`n$($cb.Tag.Name)`n`n$($cb.Tag.Desc)`n`nContinue?",
                'Confirm security change', 'YesNo', 'Warning')
            if ($r -ne 'Yes') { $cb.IsChecked = $false }
        }
    }
    $selected = $script:AllCheckBoxes | Where-Object { $_.IsChecked }

    $ctrl.ApplyBtn.IsEnabled = $false
    Write-Log "Applying $($selected.Count) tweak(s)..."
    $done = 0; $fail = 0
    foreach ($cb in $selected) {
        $t = $cb.Tag
        foreach ($a in $t.Actions) {
            try { Invoke-TweakAction $a }
            catch { $fail++; Write-Log "  ! $($t.Name): $($_.Exception.Message)" }
        }
        $done++
    }
    # restart explorer so taskbar/visual tweaks show
    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    } catch {}
    Write-Log "Done. Applied $done tweak(s)$(if($fail){", $fail action(s) had issues"}). Some changes need a reboot."
    $ctrl.ApplyBtn.IsEnabled = $true
})

$ctrl.RemoveApps.Add_Click({
    $sel = $script:BloatCheckBoxes | Where-Object { $_.IsChecked }
    if (-not $sel) { Write-Log 'No apps selected.'; return }
    $r = [Windows.MessageBox]::Show(
        "Remove $($sel.Count) app(s)? This uninstalls them for the current user and deprovisions them so they don't come back on new accounts.",
        'Confirm removal', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }

    $ctrl.RemoveApps.IsEnabled = $false
    foreach ($cb in $sel) {
        $full = $cb.Tag
        $label = $cb.Content
        try {
            Get-AppxPackage -Name ($full -replace '_.*$','') -ErrorAction SilentlyContinue |
                Remove-AppxPackage -ErrorAction SilentlyContinue
            # deprovision from the image so it won't reinstall for new users
            $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName -eq ($full -replace '_.*$','') }
            if ($prov) { Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null }
            Write-Log "Removed: $label"
        } catch {
            Write-Log "  ! Could not remove ${label}: $($_.Exception.Message)"
        }
    }
    $ctrl.RemoveApps.IsEnabled = $true
    Load-Bloat
})

$ctrl.InstallBtn.Add_Click({
    $sel = $script:InstallCheckBoxes | Where-Object { $_.IsChecked }
    if (-not $sel) { Write-Log 'No apps selected to install.'; return }

    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add('$ErrorActionPreference = "Continue"')
    [void]$lines.Add('Write-Host "NullTweak installer - installing selected apps..." -ForegroundColor Cyan')
    foreach ($cb in $sel) {
        $a = $cb.Tag
        $src = if ($a.Src) { " --source $($a.Src)" } else { '' }
        [void]$lines.Add("Write-Host ''")
        [void]$lines.Add("Write-Host '>> $($a.N)' -ForegroundColor Yellow")
        [void]$lines.Add("winget install --id $($a.Id) -e --accept-package-agreements --accept-source-agreements$src")
    }
    [void]$lines.Add('Write-Host ""')
    [void]$lines.Add('Write-Host "All done. You can close this window." -ForegroundColor Green')

    $tmp = Join-Path $env:TEMP 'NullTweak-install.ps1'
    $lines | Set-Content -Path $tmp -Encoding UTF8 -Force
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList '-NoExit','-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$tmp`"" | Out-Null
    Write-Log "Launched installer window for $($sel.Count) app(s). Watch that window for progress."
})

$ctrl.InstallAll.Add_Click({  foreach ($c in $script:InstallCheckBoxes) { $c.IsChecked = $true } })
$ctrl.InstallNone.Add_Click({ foreach ($c in $script:InstallCheckBoxes) { $c.IsChecked = $false } })

$ctrl.BloatAll.Add_Click({  foreach ($c in $script:BloatCheckBoxes) { $c.IsChecked = $true } })
$ctrl.BloatNone.Add_Click({ foreach ($c in $script:BloatCheckBoxes) { $c.IsChecked = $false } })
$ctrl.BloatRefresh.Add_Click({ Load-Bloat })

# ---------------------------------------------------------------------------
# 13. Go
# ---------------------------------------------------------------------------
# Make the mouse wheel reliably scroll the ScrollViewer under the cursor.
function Get-ScrollViewerAncestor($element) {
    $cur = $element
    while ($null -ne $cur) {
        if ($cur -is [System.Windows.Controls.ScrollViewer]) { return $cur }
        if ($cur -is [System.Windows.DependencyObject]) {
            $cur = [System.Windows.Media.VisualTreeHelper]::GetParent($cur)
        } else { return $null }
    }
    return $null
}
$win.Add_PreviewMouseWheel({
    param($s, $e)
    $over = [System.Windows.Input.Mouse]::DirectlyOver
    if ($over -is [System.Windows.DependencyObject]) {
        $sv = Get-ScrollViewerAncestor $over
        if ($null -ne $sv) {
            $sv.ScrollToVerticalOffset($sv.VerticalOffset - $e.Delta)
            $e.Handled = $true
        }
    }
})

Write-Log "Detected $osLabel. Review the tabs, then Apply."
$win.ShowDialog() | Out-Null
