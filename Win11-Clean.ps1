<#
    Win11-Clean.ps1
    ---------------------------------------------------------------
    Cleans up Windows 11:
      1. Creates a System Restore point (your "undo" button)
      2. Removes bloatware / sponsored apps (for all users + new users)
      3. Removes Copilot, Recall and other AI features
      4. Turns off ads everywhere (Start, lock screen, Explorer,
         Settings, notifications, search, widgets, Edge)
      5. Reduces telemetry / tracking
      6. Disables unnecessary services and scheduled tasks
      7. (Optional) Removes OneDrive and Xbox apps

    It does NOT touch: Windows Update, Windows Security/Defender,
    Microsoft Store, printing, Bluetooth, Wi-Fi, keyboard/language
    input, search indexing, drivers.

    Run as Administrator in Windows PowerShell 5.1 (the .bat file
    next to this script does that for you).
#>

# ================================================================
#  SETTINGS - change $true / $false to choose what gets removed
# ================================================================
$RemoveOneDrive   = $true    # Uninstall OneDrive (your files in the cloud stay safe)
$RemoveXbox       = $true    # Remove Xbox apps / Game Bar (set $false if you play PC games from Xbox/Game Pass)
$RemoveMailOutlook= $true    # Remove Mail/Calendar + new Outlook app
$DisableTelemetry = $true    # Reduce data sent to Microsoft
$ApplyToNewUsers  = $true    # Also apply ad-blocking settings to user accounts created later
# ================================================================

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ---------- Must run in Windows PowerShell 5.1 (Appx cmdlets) ----------
if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Host "Restarting in Windows PowerShell 5.1..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ---------- Self-elevate to Administrator ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator rights..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ---------- Windows 11 check ----------
$build = [int]((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber)
if ($build -lt 22000) {
    Write-Host "This script is made for Windows 11 (build 22000+). Detected build $build. Exiting." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# ---------- Logging ----------
$LogDir  = Join-Path $env:SystemDrive 'Win11-Clean'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile = Join-Path $LogDir ("log-{0:yyyyMMdd-HHmmss}.txt" -f (Get-Date))
Start-Transcript -Path $LogFile -Force | Out-Null

function Write-Step($text) { Write-Host "`n=== $text ===" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "  [OK]   $text" -ForegroundColor Green }
function Write-Skip($text) { Write-Host "  [--]   $text" -ForegroundColor DarkGray }
function Write-Fail($text) { Write-Host "  [FAIL] $text" -ForegroundColor Red }

# Create key if needed and set a value
function Set-Reg {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet('DWord','String','QWord','ExpandString','Binary','MultiString')][string]$Type = 'DWord'
    )
    try {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Fail "$Path\$Name -> $($_.Exception.Message)"
    }
}

# ---------- Confirmation ----------
Clear-Host
Write-Host @"
==============================================================
                    WINDOWS 11 CLEAN-UP
==============================================================
 This will:
   - Create a System Restore point
   - Remove unnecessary apps (News, Weather, Clipchamp, Teams,
     Solitaire, Tips, Phone Link, sponsored games, etc.)
   - Remove Copilot, Recall and AI features
   - Turn OFF ads in Start, lock screen, Explorer, Settings,
     search, notifications, widgets and Edge
   - Disable unnecessary services and telemetry
   - Remove OneDrive : $RemoveOneDrive
   - Remove Xbox     : $RemoveXbox

 Kept: Store, Calculator, Notepad, Photos, Paint, Snipping Tool,
       Camera, Terminal, Media Player, Windows Security, Edge.

 Log file: $LogFile
==============================================================
"@ -ForegroundColor White
$answer = Read-Host "Type Y and press Enter to start (anything else = cancel)"
if ($answer -notmatch '^[Yy]') {
    Write-Host "Cancelled. Nothing was changed." -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    exit
}

# ================================================================
# 1. RESTORE POINT
# ================================================================
Write-Step "1/8  Creating System Restore point"
try {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
    # Windows normally allows only one restore point per 24h - lift that limit
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0
    Checkpoint-Computer -Description "Before Win11-Clean" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-Ok "Restore point 'Before Win11-Clean' created"
} catch {
    Write-Fail "Could not create restore point: $($_.Exception.Message)"
    $c = Read-Host "Continue WITHOUT a restore point? (Y/N)"
    if ($c -notmatch '^[Yy]') { Stop-Transcript | Out-Null; exit }
}

# ================================================================
# 2. REMOVE APPS
# ================================================================
Write-Step "2/8  Removing unnecessary apps"

$Apps = @(
    # --- Microsoft bloat ---
    'Microsoft.BingNews'
    'Microsoft.BingWeather'
    'Microsoft.BingSearch'
    'Microsoft.BingFinance'
    'Microsoft.BingSports'
    'Microsoft.BingTranslator'
    'Microsoft.BingTravel'
    'Microsoft.BingFoodAndDrink'
    'Microsoft.BingHealthAndFitness'
    'Microsoft.Getstarted'                    # Tips
    'Microsoft.GetHelp'
    'Microsoft.MicrosoftOfficeHub'            # "Microsoft 365 (Office)" / "Microsoft 365 Copilot" app
    'Microsoft.Office.OneNote'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.MicrosoftStickyNotes'
    'Microsoft.MicrosoftJournal'
    'Microsoft.People'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.Todos'
    'Microsoft.WindowsAlarms'                 # Clock
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsMaps'
    'Microsoft.WindowsSoundRecorder'
    'Microsoft.YourPhone'                     # Phone Link
    'Microsoft.ZuneVideo'                     # Movies & TV
    'Microsoft.549981C3F5F10'                 # Cortana
    'Microsoft.Windows.DevHome'
    'Microsoft.MixedReality.Portal'
    'Microsoft.Microsoft3DViewer'
    'Microsoft.MSPaint'                       # Paint 3D (new Paint is kept)
    'Microsoft.Print3D'
    'Microsoft.SkypeApp'
    'Microsoft.Messaging'
    'Microsoft.OneConnect'
    'Microsoft.Wallet'
    'Microsoft.Advertising.Xaml'
    'Microsoft.NetworkSpeedTest'
    'Microsoft.News'
    'Clipchamp.Clipchamp'
    'MicrosoftCorporationII.QuickAssist'
    'MicrosoftCorporationII.MicrosoftFamily'
    'MicrosoftTeams'
    'MSTeams'
    'MicrosoftWindows.Client.WebExperience'   # Widgets (news feed with ads)
    'MicrosoftWindows.CrossDevice'
    'Microsoft.Windows.CrossDevice'
    # --- Copilot / AI ---
    'Microsoft.Copilot'
    'Microsoft.Windows.Ai.Copilot.Provider'
    # --- Sponsored / third-party ads apps ---
    '*CandyCrush*'
    '*BubbleWitch*'
    '*king.com*'
    '*MarchofEmpires*'
    '*HiddenCity*'
    '*Asphalt*'
    '*Disney*'
    '*Netflix*'
    '*SpotifyMusic*'
    '*Facebook*'
    '*Instagram*'
    '*TikTok*'
    '*BytedancePte*'
    '*Twitter*'
    '*LinkedInforWindows*'
    '*AmazonVideo*'
    '*Amazon.com.Amazon*'
    '*PrimeVideo*'
    '*PicsArt*'
    '*Duolingo*'
    '*AdobePhotoshopExpress*'
    '*Flipboard*'
    '*Shazam*'
    '*PandoraMedia*'
    '*iHeartRadio*'
    'CAF9E577.Plex'
    '*ESPN*'
    '*Booking.com*'
)

if ($RemoveXbox) {
    $Apps += @(
        'Microsoft.GamingApp'
        'Microsoft.XboxApp'
        'Microsoft.Xbox.TCUI'
        'Microsoft.XboxGameOverlay'
        'Microsoft.XboxGamingOverlay'
        'Microsoft.XboxSpeechToTextOverlay'
        'Microsoft.XboxIdentityProvider'
        'Microsoft.Edge.GameAssist'
    )
}
if ($RemoveMailOutlook) {
    $Apps += @(
        'microsoft.windowscommunicationsapps'  # Mail & Calendar
        'Microsoft.OutlookForWindows'          # new Outlook
    )
}

# Never remove these, even if a wildcard above matches them
$Protected = @(
    'Microsoft.WindowsStore','Microsoft.StorePurchaseApp','Microsoft.DesktopAppInstaller',
    'Microsoft.WindowsCalculator','Microsoft.WindowsNotepad','Microsoft.Windows.Photos',
    'Microsoft.Paint','Microsoft.ScreenSketch','Microsoft.WindowsCamera','Microsoft.WindowsTerminal',
    'Microsoft.ZuneMusic','Microsoft.SecHealthUI','Microsoft.MicrosoftEdge.Stable',
    'Microsoft.HEIFImageExtension','Microsoft.HEVCVideoExtension','Microsoft.VP9VideoExtensions',
    'Microsoft.WebMediaExtensions','Microsoft.WebpImageExtension','Microsoft.RawImageExtension',
    'Microsoft.AV1VideoExtension','Microsoft.MPEG2VideoExtension','Microsoft.AVCEncoderVideoExtension',
    'Microsoft.VCLibs*','Microsoft.UI.Xaml*','Microsoft.NET.Native*','Microsoft.WindowsAppRuntime*',
    'Microsoft.LanguageExperiencePack*','Microsoft.ApplicationCompatibilityEnhancements',
    '5319275A.WhatsAppDesktop','TelegramMessengerLLP.TelegramDesktop'
)
function Test-Protected($name) {
    foreach ($p in $Protected) { if ($name -like $p) { return $true } }
    return $false
}

$Provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)
$DeprovKey   = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned'

foreach ($pattern in $Apps) {
    $found = $false

    # Installed for any user
    $installed = @(Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue)
    foreach ($pkg in $installed) {
        if (Test-Protected $pkg.Name) { continue }
        $found = $true
        if ($pkg.NonRemovable) { Write-Skip "$($pkg.Name) (system app, cannot be removed)"; continue }
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
            Write-Ok "Removed $($pkg.Name)"
        } catch {
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Ok "Removed $($pkg.Name) (current user)"
            } catch {
                Write-Fail "$($pkg.Name): $($_.Exception.Message.Split("`n")[0])"
            }
        }
        # Stop Windows from re-installing it after feature updates
        if ($pkg.PackageFamilyName) {
            New-Item -Path (Join-Path $DeprovKey $pkg.PackageFamilyName) -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }

    # Provisioned (gets installed for every NEW user)
    foreach ($prov in ($Provisioned | Where-Object { $_.DisplayName -like $pattern })) {
        if (Test-Protected $prov.DisplayName) { continue }
        $found = $true
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null
            Write-Ok "Deprovisioned $($prov.DisplayName)"
        } catch {
            Write-Fail "Deprovision $($prov.DisplayName): $($_.Exception.Message.Split("`n")[0])"
        }
    }

    if (-not $found) { Write-Skip "$pattern (not installed)" }
}

# ================================================================
# 3. ONEDRIVE (optional)
# ================================================================
Write-Step "3/8  OneDrive"
if ($RemoveOneDrive) {
    Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    $removed = $false

    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        winget.exe uninstall --id Microsoft.OneDrive --silent --accept-source-agreements --disable-interactivity *> $null
        if ($LASTEXITCODE -eq 0) { $removed = $true }
    }
    if (-not $removed) {
        $setups = @(
            "$env:SystemRoot\System32\OneDriveSetup.exe",
            "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
        ) + @(Get-ChildItem "$env:LOCALAPPDATA\Microsoft\OneDrive\*\OneDriveSetup.exe","$env:ProgramFiles\Microsoft OneDrive\*\OneDriveSetup.exe" -ErrorAction SilentlyContinue | ForEach-Object FullName)
        foreach ($s in $setups) {
            if (Test-Path $s) {
                Start-Process -FilePath $s -ArgumentList '/uninstall' -Wait -ErrorAction SilentlyContinue
                $removed = $true
                break
            }
        }
    }
    if ($removed) { Write-Ok "OneDrive uninstalled (files already in your OneDrive folder were NOT deleted)" }
    else          { Write-Skip "OneDrive not found" }

    # Remove OneDrive from the Explorer sidebar
    foreach ($k in @('Registry::HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}',
                     'Registry::HKEY_CLASSES_ROOT\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}')) {
        if (Test-Path -LiteralPath $k) { Set-Reg $k 'System.IsPinnedToNameSpaceTree' 0 }
    }
    # Remove OneDrive auto-start for the current user
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -ErrorAction SilentlyContinue
} else {
    Write-Skip "Kept (RemoveOneDrive = `$false)"
}

# ================================================================
# 4. COPILOT, RECALL & AI FEATURES
# ================================================================
Write-Step "4/8  Turning off Copilot, Recall and AI features"

# Windows Copilot
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\Shell\Copilot' 'IsCopilotAvailable' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\Shell\Copilot\BingChat' 'IsUserEligible' 0

# Recall & Click to Do
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableClickToDo' 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableClickToDo' 1
try {
    $recall = Get-WindowsOptionalFeature -Online -FeatureName 'Recall' -ErrorAction Stop
    if ($recall -and $recall.State -eq 'Enabled') {
        Disable-WindowsOptionalFeature -Online -FeatureName 'Recall' -NoRestart -ErrorAction Stop | Out-Null
        Write-Ok "Recall feature disabled"
    } else { Write-Skip "Recall is not enabled on this PC" }
} catch { Write-Skip "Recall feature not present on this PC" }

# AI in Paint and Notepad
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' 'DisableCocreator' 1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' 'DisableGenerativeFill' 1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' 'DisableImageCreator' 1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' 'DisableGenerativeErase' 1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' 'DisableRemoveBackground' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\WindowsNotepad' 'DisableAIFeatures' 1

# Copilot / AI inside Edge
$Edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
Set-Reg $Edge 'HubsSidebarEnabled' 0                 # sidebar + Copilot button
Set-Reg $Edge 'CopilotPageContext' 0
Set-Reg $Edge 'CopilotCDPPageContext' 0
Set-Reg $Edge 'EdgeEntraCopilotPageContext' 0
Set-Reg $Edge 'Microsoft365CopilotChatIconEnabled' 0
Set-Reg $Edge 'NewTabPageBingChatEnabled' 0
Set-Reg $Edge 'ComposeInlineEnabled' 0
Set-Reg $Edge 'DiscoverPageContextEnabled' 0
Set-Reg $Edge 'GenAILocalFoundationalModelSettings' 1
Write-Ok "Copilot / AI policies applied"

# ================================================================
# 5. ADS - EVERYWHERE
# ================================================================
Write-Step "5/8  Turning off ads, suggestions and sponsored content"

# Machine-wide policies
$CC = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
Set-Reg $CC 'DisableWindowsConsumerFeatures' 1       # stops auto-installing sponsored apps
Set-Reg $CC 'DisableConsumerAccountStateContent' 1
Set-Reg $CC 'DisableCloudOptimizedContent' 1
Set-Reg $CC 'DisableSoftLanding' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0   # Widgets
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds' 0
$WS = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
Set-Reg $WS 'AllowCortana' 0
Set-Reg $WS 'DisableWebSearch' 1
Set-Reg $WS 'ConnectedSearchUseWeb' 0
Set-Reg $WS 'EnableDynamicContentInWSB' 0            # search "highlights"
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'HideRecommendedPersonalizedSites' 1

# Edge ads
Set-Reg $Edge 'ShowRecommendationsEnabled' 0
Set-Reg $Edge 'EdgeShoppingAssistantEnabled' 0
Set-Reg $Edge 'ShowMicrosoftRewards' 0
Set-Reg $Edge 'SpotlightExperiencesAndRecommendationsEnabled' 0
Set-Reg $Edge 'PersonalizationReportingEnabled' 0
Set-Reg $Edge 'PromotionalTabsEnabled' 0
Set-Reg $Edge 'NewTabPageContentEnabled' 0           # MSN news feed on new tab
Set-Reg $Edge 'NewTabPageHideDefaultTopSites' 1      # sponsored tiles
Set-Reg $Edge 'DefaultBrowserSettingsCampaignEnabled' 0
Set-Reg $Edge 'EdgeFollowEnabled' 0
Set-Reg $Edge 'ShowAcrobatSubscriptionButton' 0
Set-Reg $Edge 'ShowPDFDefaultRecommendationsEnabled' 0
Set-Reg $Edge 'WalletDonationEnabled' 0
Set-Reg $Edge 'HideFirstRunExperience' 1
Set-Reg $Edge 'StartupBoostEnabled' 0
Set-Reg $Edge 'BackgroundModeEnabled' 0
Set-Reg $Edge 'UserFeedbackAllowed' 0
Set-Reg $Edge 'DiagnosticData' 0

# Per-user ad settings - applied to a registry root (current user or default profile)
function Set-UserAdTweaks([string]$Root) {
    $CDM = "$Root\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    foreach ($n in @(
        'ContentDeliveryAllowed','FeatureManagementEnabled','OemPreInstalledAppsEnabled',
        'PreInstalledAppsEnabled','PreInstalledAppsEverEnabled','SilentInstalledAppsEnabled',
        'SoftLandingEnabled','SystemPaneSuggestionsEnabled','RotatingLockScreenEnabled',
        'RotatingLockScreenOverlayEnabled',
        'SubscribedContent-202914Enabled',
        'SubscribedContent-280815Enabled',
        'SubscribedContent-310093Enabled',   # welcome experience after updates
        'SubscribedContent-314559Enabled',
        'SubscribedContent-338387Enabled',   # lock screen fun facts / tips
        'SubscribedContent-338388Enabled',   # Start suggestions
        'SubscribedContent-338389Enabled',   # tips and suggestions
        'SubscribedContent-338393Enabled',   # suggested content in Settings
        'SubscribedContent-353694Enabled',
        'SubscribedContent-353696Enabled',
        'SubscribedContent-353698Enabled',   # timeline suggestions
        'SubscribedContent-88000326Enabled'
    )) { Set-Reg $CDM $n 0 }
    Remove-Item "$CDM\Subscriptions" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$CDM\SuggestedApps" -Recurse -Force -ErrorAction SilentlyContinue

    $Adv = "$Root\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-Reg $Adv 'Start_IrisRecommendations' 0        # Start: tips, shortcuts, new apps
    Set-Reg $Adv 'Start_AccountNotifications' 0       # Start: account "notifications"
    Set-Reg $Adv 'ShowSyncProviderNotifications' 0    # Explorer: OneDrive/M365 ads
    Set-Reg $Adv 'TaskbarMn' 0                        # Taskbar: Teams chat
    Set-Reg $Adv 'ShowCopilotButton' 0
    try { Set-ItemProperty -LiteralPath $Adv -Name 'TaskbarDa' -Value 0 -Type DWord -ErrorAction Stop } catch { }  # Widgets button (policy above also hides it)

    Set-Reg "$Root\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" 'Enabled' 0
    Set-Reg "$Root\Software\Microsoft\Windows\CurrentVersion\Privacy" 'TailoredExperiencesWithDiagnosticDataEnabled' 0
    Set-Reg "$Root\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" 'ScoobeSystemSettingEnabled' 0   # "Finish setting up your PC"
    Set-Reg "$Root\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested" 'Enabled' 0
    Set-Reg "$Root\Software\Microsoft\Windows\CurrentVersion\Search" 'BingSearchEnabled' 0
    Set-Reg "$Root\Software\Microsoft\Windows\CurrentVersion\Search" 'CortanaConsent' 0
    Set-Reg "$Root\Software\Microsoft\Windows\CurrentVersion\SearchSettings" 'IsDynamicSearchBoxEnabled' 0
    Set-Reg "$Root\Software\Policies\Microsoft\Windows\Explorer" 'DisableSearchBoxSuggestions' 1   # no web/Bing results in Start search
    Set-Reg "$Root\Software\Policies\Microsoft\Windows\CloudContent" 'DisableWindowsSpotlightFeatures' 1
    Set-Reg "$Root\Software\Policies\Microsoft\Windows\CloudContent" 'DisableTailoredExperiencesWithDiagnosticData' 1
    Set-Reg "$Root\Software\Policies\Microsoft\Windows\CloudContent" 'DisableThirdPartySuggestions' 1
    Set-Reg "$Root\Software\Policies\Microsoft\Windows\CloudContent" 'DisableSpotlightCollectionOnDesktop' 1
    Set-Reg "$Root\Software\Policies\Microsoft\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' 1
    Set-Reg "$Root\Software\Microsoft\Siuf\Rules" 'NumberOfSIUFInPeriod' 0     # feedback pop-ups
    Set-Reg "$Root\Control Panel\International\User Profile" 'HttpAcceptLanguageOptOut' 1 -Type DWord
    Set-Reg "$Root\Software\Microsoft\InputPersonalization" 'RestrictImplicitInkCollection' 1
    Set-Reg "$Root\Software\Microsoft\InputPersonalization" 'RestrictImplicitTextCollection' 1
    Set-Reg "$Root\Software\Microsoft\Personalization\Settings" 'AcceptedPrivacyPolicy' 0
    if ($RemoveXbox) {
        Set-Reg "$Root\System\GameConfigStore" 'GameDVR_Enabled' 0
        Set-Reg "$Root\Software\Microsoft\Windows\CurrentVersion\GameDVR" 'AppCaptureEnabled' 0
    }
    if ($RemoveOneDrive) {
        Remove-ItemProperty "$Root\Software\Microsoft\Windows\CurrentVersion\Run" -Name 'OneDriveSetup' -ErrorAction SilentlyContinue
        Remove-ItemProperty "$Root\Software\Microsoft\Windows\CurrentVersion\Run" -Name 'OneDrive' -ErrorAction SilentlyContinue
    }
}

Set-UserAdTweaks 'HKCU:'
Write-Ok "Ads turned off for current user ($env:USERNAME)"

if ($ApplyToNewUsers) {
    $hive = "$env:SystemDrive\Users\Default\NTUSER.DAT"
    if (Test-Path $hive) {
        & reg.exe load 'HKU\Win11Clean_Default' $hive *> $null
        if ($LASTEXITCODE -eq 0) {
            Set-UserAdTweaks 'Registry::HKEY_USERS\Win11Clean_Default'
            [gc]::Collect(); [gc]::WaitForPendingFinalizers(); Start-Sleep -Milliseconds 500
            & reg.exe unload 'HKU\Win11Clean_Default' *> $null
            Write-Ok "Ads turned off for new user accounts"
        } else {
            Write-Skip "Could not load default user profile"
        }
    }
}

if ($RemoveXbox) {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
}

# ================================================================
# 6. TELEMETRY & TRACKING
# ================================================================
Write-Step "6/8  Reducing telemetry and tracking"
if ($DisableTelemetry) {
    $DC = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
    Set-Reg $DC 'AllowTelemetry' 0                   # Home/Pro use the lowest allowed level
    Set-Reg $DC 'DoNotShowFeedbackNotifications' 1
    Set-Reg $DC 'AllowDeviceNameInTelemetry' 0
    Set-Reg $DC 'LimitDiagnosticLogCollection' 1
    Set-Reg $DC 'LimitDumpCollection' 1
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
    $SYS = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
    Set-Reg $SYS 'EnableActivityFeed' 0              # Activity history
    Set-Reg $SYS 'PublishUserActivities' 0
    Set-Reg $SYS 'UploadUserActivities' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'DisableInventory' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC' 'PreventHandwritingDataSharing' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports' 'PreventHandwritingErrorReports' 1
    Write-Ok "Telemetry policies applied"
} else {
    Write-Skip "Kept (DisableTelemetry = `$false)"
}

# ================================================================
# 7. SERVICES
# ================================================================
Write-Step "7/8  Disabling unnecessary services"

$Services = [ordered]@{
    'DiagTrack'        = 'Disabled'   # Connected User Experiences and Telemetry
    'dmwappushservice' = 'Disabled'   # WAP push (telemetry routing)
    'RetailDemo'       = 'Disabled'   # Store demo mode
    'MapsBroker'       = 'Disabled'   # Downloaded maps manager
    'Fax'              = 'Disabled'
    'RemoteRegistry'   = 'Disabled'   # security: nobody should edit your registry remotely
    'WMPNetworkSvc'    = 'Disabled'   # Windows Media Player network sharing
    'AJRouter'         = 'Disabled'   # AllJoyn router (IoT)
    'wisvc'            = 'Disabled'   # Windows Insider service
    'WpcMonSvc'        = 'Disabled'   # Parental controls
    'WalletService'    = 'Disabled'
    'lfsvc'            = 'Manual'     # Geolocation (starts only when needed)
    'WerSvc'           = 'Manual'     # Error reporting
    'diagnosticshub.standardcollector.service' = 'Manual'
}
if (-not $DisableTelemetry) { $Services.Remove('DiagTrack'); $Services.Remove('dmwappushservice') }
if ($RemoveXbox) {
    $Services['XblAuthManager'] = 'Disabled'
    $Services['XblGameSave']    = 'Disabled'
    $Services['XboxNetApiSvc']  = 'Disabled'
    $Services['XboxGipSvc']     = 'Manual'      # keeps Xbox controllers working
}

foreach ($name in $Services.Keys) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Skip "$name (not present)"; continue }
    try {
        if ($Services[$name] -eq 'Disabled') {
            Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
        }
        Set-Service -Name $name -StartupType $Services[$name] -ErrorAction Stop
        Write-Ok "$name -> $($Services[$name])"
    } catch {
        # Some services are protected from Set-Service; fall back to sc.exe
        $mode = if ($Services[$name] -eq 'Disabled') { 'disabled' } else { 'demand' }
        & sc.exe config $name start= $mode *> $null
        if ($LASTEXITCODE -eq 0) { Write-Ok "$name -> $($Services[$name])" }
        else { Write-Fail "$name : $($_.Exception.Message)" }
    }
}

# Scheduled tasks that only collect / send usage data
$Tasks = @(
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp'
    '\Microsoft\Windows\Application Experience\ProgramDataUpdater'
    '\Microsoft\Windows\Application Experience\MareBackup'
    '\Microsoft\Windows\Autochk\Proxy'
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'
    '\Microsoft\Windows\Feedback\Siuf\DmClient'
    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'
    '\Microsoft\Windows\Windows Error Reporting\QueueReporting'
    '\Microsoft\Windows\Maps\MapsToastTask'
    '\Microsoft\Windows\Maps\MapsUpdateTask'
)
if (-not $DisableTelemetry) { $Tasks = @() }
foreach ($t in $Tasks) {
    $path = ($t.Substring(0, $t.LastIndexOf('\') + 1))
    $tn   = ($t.Substring($t.LastIndexOf('\') + 1))
    $task = Get-ScheduledTask -TaskPath $path -TaskName $tn -ErrorAction SilentlyContinue
    if (-not $task) { Write-Skip "Task $tn (not present)"; continue }
    try {
        Disable-ScheduledTask -TaskPath $path -TaskName $tn -ErrorAction Stop | Out-Null
        Write-Ok "Task disabled: $tn"
    } catch {
        Write-Fail "Task $tn : $($_.Exception.Message.Split("`n")[0])"
    }
}

# ================================================================
# 8. FINISH
# ================================================================
Write-Step "8/8  Restarting Explorer"
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 4
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }

Write-Host @"

==============================================================
  DONE!  Please RESTART your computer now.

  Log file : $LogFile
  Undo     : Start > type "Create a restore point" >
             System Restore > choose "Before Win11-Clean"
  Removed apps can be reinstalled anytime from Microsoft Store.
==============================================================
"@ -ForegroundColor Green

Stop-Transcript | Out-Null
$r = Read-Host "Restart now? (Y/N)"
if ($r -match '^[Yy]') { Restart-Computer -Force }
