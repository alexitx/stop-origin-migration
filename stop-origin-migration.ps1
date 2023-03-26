<#
.SYNOPSIS
    Origin configuration & installation script

.DESCRIPTION
    Configure Origin to not update automatically and optionally install the last
    known stable version to avoid being forced to migrate to the new EA app.

.LINK
    https://github.com/alexitx/stop-origin-migration
#>

$ErrorActionPreference = "Stop"

$VERSION = "0.1.0"
$SCRIPT_DIR = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$SEPARATOR = "-" * 80

function Test-Administrator {
    $CurrentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $CurrentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function New-TemporaryDirectory {
    $TempDir = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ([Guid]::NewGuid())
    return New-Item -Path $TempDir -ItemType Directory
}

function Join-Files {
    param (
        [parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]] $Files,

        [parameter(Mandatory=$true)]
        [string] $Destination
    )

    begin {
        $OutFile = [IO.File]::Create($Destination)
    }

    process {
        try {
            foreach ($File in $Files) {
                $InFile = [IO.File]::OpenRead($File)
                try {
                    $InFile.CopyTo($OutFile)
                } finally {
                    $InFile.Dispose()
                }
            }
        } catch {
            $OutFile.Dispose()
            throw
        }
    }

    end {
        $OutFile.Dispose()
    }
}

function Invoke-DownloadFile {
    param (
        [Parameter(Mandatory=$true)]
        [uri]
        $Uri,

        [Parameter(Mandatory=$true)]
        [IO.FileInfo]
        $Destination,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $MaxRetries = 0,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $Timeout = 10000
    )

    $RetryCount = 0
    while ($true) {
        if ($RetryCount -ge 1) {
            Write-Host "Retrying download ($RetryCount / $MaxRetries)"
        }

        try {
            $Request = [System.Net.HttpWebRequest]::Create($Uri)
            $Request.Timeout = $Timeout

            $Response = $Request.GetResponse()
            $ResponseStream = $Response.GetResponseStream()
            $ContentLength = $Response.ContentLength

            $TargetStream = [IO.File]::Create($Destination.FullName)

            $BufferSize = 16 * 1024 # 16 KiB
            $Buffer = New-Object byte[] $BufferSize;

            $Count = 0
            $DownloadedBytes = 0

            $UpdateRate = 500 # 500 ms
            $LastProgress = [datetime] 0

            while ($true) {
                $Now = Get-Date
                $TimeElapsed = (New-TimeSpan -Start $LastProgress -End $Now).TotalMilliseconds
                if ($TimeElapsed -ge $UpdateRate) {
                    $PercentComplete = $DownloadedBytes / $ContentLength * 100
                    Write-Progress `
                        -Activity "Downloading '$($Destination.Name)'" `
                        -Status "Percent complete: $($PercentComplete.ToString("0.00"))%" `
                        -PercentComplete $PercentComplete
                    $LastProgress = $Now
                }

                $Count = $ResponseStream.Read($Buffer, 0, $Buffer.Length)
                if ($Count -le 0) {
                    break
                }

                $TargetStream.Write($Buffer, 0, $Count)
                $DownloadedBytes += $Count
            }

            Write-Progress -Activity "Downloading '$($Destination.Name)'" -Completed

            break
        } catch [Net.WebException] {
            if ($RetryCount -ge $MaxRetries) {
                throw
            }

            Write-Host -ForegroundColor Red "Download error: $($_.Exception.Message)"
            $RetryCount++
        } finally {
            if ($ResponseStream) {
                $ResponseStream.Dispose()
            }
            if ($TargetStream) {
                $TargetStream.Dispose()
            }
        }
    }
}

function Set-FileOwnership {
    param (
        [Parameter(Mandatory=$true)]
        [IO.FileInfo] $Path
    )

    $ACL = $Path.GetAccessControl()
    $CurrentUser = New-Object Security.Principal.NTAccount([Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $ACL.SetOwner($CurrentUser)
    $ACL.SetAccessRuleProtection($false, $true) # Preserve inheritance
    $Path.SetAccessControl($ACL)
}

function Update-Settings {
    param (
        [Parameter(Mandatory=$true)]
        [xml] $TargetXml,

        [Parameter(Mandatory=$true)]
        [xml] $BaseXml
    )

    $BaseXml.SelectNodes("/Settings/Setting[@key]") | ForEach-Object {
        $BaseSetting = $_
        $TargetSetting = $TargetXml.SelectSingleNode("/Settings/Setting[@key='$($BaseSetting.GetAttribute("key"))']")
        $ImportedTargetSetting = $TargetXml.ImportNode($BaseSetting, $false)
        if ($TargetSetting) {
            # Replace existing target setting element
            [void] $TargetXml.SelectSingleNode("/Settings").ReplaceChild($ImportedTargetSetting, $TargetSetting)
        } else {
            # Add new setting element to target
            [void] $TargetXml.SelectSingleNode("/Settings").AppendChild($ImportedTargetSetting)
        }
    }
}

function Remove-Settings {
    param (
        [Parameter(Mandatory=$true)]
        [xml] $TargetXml,

        [Parameter(Mandatory=$true)]
        [string[]] $Keys
    )

    foreach ($Key in $Keys) {
        $TargetSetting = $TargetXml.SelectSingleNode("/Settings/Setting[@key='$Key']")
        if ($TargetSetting) {
            [void] $TargetXml.SelectSingleNode("/Settings").RemoveChild($TargetSetting)
        }
    }
}

function Show-Prompt {
    param (
        [Parameter(Mandatory=$true)]
        [string] $Caption,

        [Parameter(Mandatory=$true)]
        [string] $Message,

        [Parameter()]
        [string[]] $Choices = @("&Yes", "&No"),

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $DefaultChoice = 0
    )

    Write-Host -ForegroundColor Green "`n$Caption"

    $Decision = $Host.UI.PromptForChoice($null, $Message, $Choices, $DefaultChoice)

    Write-Host -NoNewLine "`n"

    return $Decision
}

# Elevate if not running as administrator
if (-not (Test-Administrator)) {
    Write-Host "Elevating to administrator"

    $ScriptPath = $MyInvocation.MyCommand.Definition
    if (-not $ScriptPath) {
        Write-Host -ForegroundColor Red "You need to run this script as an administrator"
        exit 1
    }

    try {
        $ShellArguments = @("-NoLogo", "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath)
        Start-Process powershell.exe -ArgumentList $ShellArguments -Verb RunAs
    } catch [InvalidOperationException] {
        Write-Host -ForegroundColor Red "You need to run this script as an administrator"
        Read-Host
        exit 1
    }

    exit 0
}

# Startup information
Write-Host -NoNewline -Separator "" @(
    "`n",
    "$SEPARATOR`n"
)
Write-Host -NoNewline -Separator "" -ForegroundColor Green @(
    "`n",
    "Origin configuration & installation script v$VERSION`n"
)
Write-Host -NoNewline -Separator "" @(
    "`n",
    "This will help you configure Origin to not update automatically and optionally`n",
    "install the last known stable version to avoid being forced to migrate`n",
    "to the new EA app.`n",
    "`n",
    "See manual instructions and report issues at:`n",
    "https://github.com/alexitx/stop-origin-migration`n",
    "`n",
    "$SEPARATOR`n",
    "`n"
)

# --------------------
# Step 1 - Preparation
# --------------------

$Caption = "Proceed with configuration?"
$Message = -join @(
    "Yes - Terminate Origin if it is currently running`n",
    "      and proceed with the configuration`n",
    "No  - Quit"
)
$Decision = Show-Prompt -Caption $Caption -Message $Message
if ($Decision -ne 0) {
    exit 0
}

Write-Host "Stopping Origin processes"

$OriginProcesses = @(
    "Origin",
    "OriginClientService",
    "OriginWebHelperService",
    "OriginThinSetupInternal",
    "OriginSetup"
)
foreach ($Process in $OriginProcesses) {
    Stop-Process -Name $Process -Force -ErrorAction SilentlyContinue
}

# --------------------------------------
# Step 2 - Disable updates and migration
# --------------------------------------

$OriginConfigDir = Join-Path `
    -Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)) `
    -ChildPath "Origin"
$OriginConfigFile = Join-Path -Path $OriginConfigDir -ChildPath "local.xml"

# Create config file if it doesn't exist
if (-not (Test-Path -Path $OriginConfigDir -PathType Container)) {
    Write-Host "Creating config directory '$OriginConfigDir'"

    New-Item -Path $OriginConfigDir -ItemType Directory | Out-Null
    Set-FileOwnership -Path $OriginConfigDir
}
if (-not (Test-Path -Path $OriginConfigFile -PathType Leaf)) {
    Write-Host "Creating config file '$OriginConfigFile'"

    New-Item -Path $OriginConfigFile -ItemType File | Out-Null
    Set-FileOwnership -Path $OriginConfigFile
}

# "Base" configuration with updates and migration disabled
$BaseConfigXml = [Xml.XmlDocument] -join @(
    "<?xml version='1.0' encoding='utf-8'?>`n",
    "<Settings>`n",
    "  <Setting key='AutoPatchGlobal' value='false' type='1'/>`n",
    "  <Setting key='AutoUpdate' value='false' type='1'/>`n",
    "  <Setting key='MigrationDisabled' value='true' type='1'/>`n",
    "  <Setting key='UpdateURL' value='' type='10'/>`n",
    "</Settings>`n"
)
$MigrationKeys = @("MigrationDisabled", "UpdateURL")

# Current Origin configuration
$ConfigXml = New-Object Xml.XmlDocument
$ConfigRaw = Get-Content -Path $OriginConfigFile
if (-not [String]::IsNullOrWhiteSpace($ConfigRaw)) {
    # Load raw config XML string
    $ConfigXml.LoadXml($ConfigRaw)
} else {
    # Create XML declaration and root element
    $Declaration = $ConfigXml.CreateXmlDeclaration("1.0", $null, $null)
    [void] $ConfigXml.InsertBefore($Declaration, $ConfigXml.DocumentElement)

    $RootElement = $ConfigXml.CreateElement("Settings")
    [void] $ConfigXml.AppendChild($RootElement)
}

$Caption = "Disable updates and migration?"
$Message = -join @(
    "Yes - Disable automatic updates and prevent forced migration`n",
    "No  - Allow migration"
)
$Decision = Show-Prompt -Caption $Caption -Message $Message
if ($Decision -eq -1) {
    exit 0
} elseif ($Decision -eq 0) {
    Write-Host "Disabling automatic updates and migration"
    Update-Settings -TargetXml $ConfigXml -BaseXml $BaseConfigXml
} else {
    Write-Host "Removing migration-blocking settings"
    Remove-Settings -TargetXml $ConfigXml -Keys $MigrationKeys
}

Write-Host "Saving modified configuration"

try {
    $UTF8NoBomEncoding = New-Object Text.UTF8Encoding($false)
    $ConfigStreamWriter = New-Object IO.StreamWriter($OriginConfigFile, $false, $UTF8NoBomEncoding)

    $ConfigXml.Save($ConfigStreamWriter)
} finally {
    if ($ConfigStreamWriter) {
        $ConfigStreamWriter.Dispose()
    }
}

# ----------------------------------------------
# Step 3 - Install the last known stable version
# ----------------------------------------------

$StableOriginVersion = "10.5.119.52718"
$OriginRegKey = "HKLM:\SOFTWARE\WOW6432Node\Origin"
$OriginVersionRegValue = "ClientVersion"

# Get the currently installed version
$InstalledOriginVersion = (
    Get-ItemProperty `
        -Path $OriginRegKey `
        -Name $OriginVersionRegValue `
        -ErrorAction SilentlyContinue
).$OriginVersionRegValue

$DefaultChoice = 0
if ($InstalledOriginVersion -eq $StableOriginVersion) {
    # Installed version is the same as the stable version
    Write-Host "Installed Origin version $InstalledOriginVersion found"
    $Caption = -join @(
        "You have the last known stable version of Origin already installed.`n",
        "Would you like to download and install it again anyway?"
    )
    $DefaultChoice = 1
} elseif ($InstalledOriginVersion) {
    # Installed version is different from the stable version
    Write-Host "Installed Origin version $InstalledOriginVersion found"
    $Caption = -join @(
        "The currently installed version of Origin is $StableOriginVersion.`n",
        "Would you like to download and install the last known`n",
        "stable version ${StableOriginVersion}?"
    )
} else {
    # No version value found or Origin is not installed
    Write-Host "No current Origin installation found"
    $Caption = -join @(
        "Would you like to download and install the last known`n",
        "stable version of Origin ${StableOriginVersion}?"
    )
}

$InstallerParts = @(
    @{
        Url = "https://raw.githubusercontent.com/alexitx/stop-origin-migration/master/setup/OriginSetup-10.5.119.52718.zip.001"
        Filename = "OriginSetup-10.5.119.52718.zip.001"
    },
    @{
        Url = "https://raw.githubusercontent.com/alexitx/stop-origin-migration/master/setup/OriginSetup-10.5.119.52718.zip.002"
        Filename = "OriginSetup-10.5.119.52718.zip.002"
    },
    @{
        Url = "https://raw.githubusercontent.com/alexitx/stop-origin-migration/master/setup/OriginSetup-10.5.119.52718.zip.003"
        Filename = "OriginSetup-10.5.119.52718.zip.003"
    }
)

$InstallerArchiveFilename = "OriginSetup-10.5.119.52718.zip"
$InstallerFilename = "OriginSetup-10.5.119.52718.exe"
$InstallerHash = "ed6ee5174f697744ac7c5783ff9021da603bbac42ae9836cd468d432cadc9779"

$ShouldInstall = $false

$Message = -join @(
    "Yes - Download and install Origin $StableOriginVersion`n",
    "No  - Skip installation"
)
$Decision = Show-Prompt -Caption $Caption -Message $Message -DefaultChoice $DefaultChoice
if ($Decision -eq -1) {
    exit 0
} elseif ($Decision -eq 0) {
    # Before downloading, check if a valid installer is already present in the script directory
    $FinalInstallerPath = Join-Path -Path $SCRIPT_DIR -ChildPath $InstallerFilename
    $ShouldDownload = $true

    if (Test-Path -Path $FinalInstallerPath) {
        Write-Host "Verifying installer integrity"

        $ComputedInstallerHash = (Get-FileHash -Path $FinalInstallerPath -Algorithm SHA256).Hash
        if ($ComputedInstallerHash -eq $InstallerHash) {
            Write-Host "Valid installer found at '$FinalInstallerPath'"
            $ShouldDownload = $false
            $ShouldInstall = $true
        } else {
            Write-Host "Installer integrity validation failed (SHA256: $ComputedInstallerHash)"
        }
    }

    if ($ShouldDownload) {
        try {
            $TempDir = New-TemporaryDirectory
            $TempInstallerPath = Join-Path -Path $TempDir -ChildPath $InstallerFilename

            # Download installer in multiple parts
            foreach ($Part in $InstallerParts) {
                $Url = $Part.Url
                $Destination = Join-Path -Path $TempDir -ChildPath $Part.Filename

                Write-Host "Downloading '$Url'"
                Invoke-DownloadFile -Uri $Url -Destination $Destination -MaxRetries 3
            }

            $InstallerArchiveParts = $InstallerParts | ForEach-Object {
                return Join-Path -Path $TempDir -ChildPath $_.Filename
            }
            $InstallerArchive = Join-Path -Path $TempDir -ChildPath $InstallerArchiveFilename

            # Concatenate installer parts to a single file
            Write-Host "Combining downloaded installer parts"
            Join-Files -Files $InstallerArchiveParts -Destination $InstallerArchive

            # Delete temporary installer archive parts
            $InstallerArchiveParts | ForEach-Object {
                Remove-Item -Path $_ -Force -ErrorAction SilentlyContinue
            }

            # Extract installer from archive
            Write-Host "Extracting installer"
            Expand-Archive -Path $InstallerArchive -DestinationPath $TempDir

            # Delete temporary installer archive
            Remove-Item -Path $InstallerArchive -Force -ErrorAction SilentlyContinue

            Write-Host "Verifying installer integrity"

            $ComputedInstallerHash = (Get-FileHash -Path $TempInstallerPath -Algorithm SHA256).Hash
            if ($ComputedInstallerHash -eq $InstallerHash) {
                Write-Host "Saving installer to '$FinalInstallerPath'"

                Copy-Item -Path $TempInstallerPath -Destination $FinalInstallerPath -Force
                Set-FileOwnership -Path $FinalInstallerPath

                $ShouldInstall = $true
            } else {
                Write-Host "Installer integrity validation failed (SHA256: $ComputedInstallerHash)"
                Write-Host -NoNewLine -Separator "" -ForegroundColor Red @(
                    "`n",
                    "The installation cannot continue because the downloaded installer is corrupt`n",
                    "or is the wrong version.`n",
                    "`n",
                    "Follow the instructions on the README page to download and install it manually."
                )
            }
        } finally {
            # Delete temporary directory
            if ($TempDir) {
                Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    if (-not $ShouldInstall) {
        exit 1
    }

    Write-Host "Launching installer"
    Start-Process -FilePath $FinalInstallerPath
}

# Final information
Write-Host -NoNewline -Separator "" @(
    "`n",
    "$SEPARATOR`n"
)
Write-Host -NoNewline -Separator "" -ForegroundColor Green @(
    "`n",
    "Done`n"
)
if ($ShouldInstall) {
    Write-Host -NoNewline -Separator "" @(
        "`n",
        "You can re-run the saved Origin installer manually without this script`n",
        "at any time.`n"
    )
}
Write-Host -NoNewline -Separator "" @(
    "`n",
    "To disable data collection, reduce resource usage and more, see:`n",
    "https://github.com/alexitx/stop-origin-migration#additional-configuration`n",
    "`n",
    "$SEPARATOR`n",
    "`n"
)
