$thisDirectory = (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$env:PWSH_HOME = $env:PWSH_HOME ?? (Join-Path $HOME pwsh)
Import-Module (Join-Path $thisDirectory modules Core Output.psm1)

$endBlock   = "# > PWSH"

function New-PowershellProfile {
    $ErrorActionPreference = 'Stop'
    $unixPath = Join-Path $HOME .config powershell
    if (!$IsWindows -and !(Test-Path($unixPath))) {
        New-Item $unixPath -ItemType Directory -Force
    }

    Write-InfoMessage "Profile-file missing. Adding '$PROFILE'"
    New-Item $PROFILE -ItemType File
}

function Install-Pwsh {
    $ErrorActionPreference = 'Stop'
    if (!(Test-Path $PROFILE)) {
        New-PowershellProfile
    }

    $pwshrc = Get-Item (Convert-Path (Join-Path $thisDirectory "pwshrc.ps1")).Replace("\", "/")
    $pwshHomePath = Join-Path $HOME "pwsh"

    if (!(Test-Path $pwshHomePath)) {
        New-Item $pwshHomePath -ItemType Directory -Force
    }

    $pwshrcDestination = (Join-Path $pwshHomePath $pwshrc.Name)

    # Copy pwshrc
    Copy-Item -Force $pwshrc.FullName $pwshrcDestination

    # Copy init-scripts
    Copy-Item -Recurse -Force (Join-Path $thisDirectory init) $pwshHomePath

    # Copy modules
    Copy-Item -Recurse -Force (Join-Path $thisDirectory modules) $pwshHomePath

    # Copy default pwsh.yaml
    Copy-Item -Force (Join-Path $thisDirectory pwsh.yaml) $pwshHomePath

    # Source pwshrc in profile automatically?
    $profileText = Get-Content $PROFILE
    $containsSource = (Select-String -Path $PROFILE -Pattern $endBlock -SimpleMatch)
    if (!$containsSource) {
        $sourceProfile = Read-Boolean "Source in profile?"
        if ($sourceProfile) {
            $profileText = Get-Content $PROFILE

            if (!($null -eq $profileText) -and $profileText.Contains($startBlock)) {
                return
            }

            $profileText = "$pwshrcDestination $endBlock"

            Add-Content $PROFILE "`n. $($profileText)" -NoNewline
            Write-InfoMessage "Sourced file in profile: $pwshrcDestination"
        }
    }
}

function Invoke-EnsurePwshConfigDir {
    $pwshConfigDir = $IsWindows `
        ? (Join-Path $env:LOCALAPPDATA pwsh)
        : (Join-Path $HOME .config pwsh)

    if (!(Test-Path $pwshConfigDir)) {
        New-Item $pwshConfigDir -Force -ItemType Directory
    }

    return $pwshConfigDir
}

function Install-EmptyConfig {
    $ErrorActionPreference = 'Stop'
    $pwshConfigDir = Invoke-EnsurePwshConfigDir
    $pwshUserConfigPath = (Join-Path $pwshConfigDir pwsh.yaml)

    if (!(Test-Path($pwshUserConfigPath))) {
        New-Item $pwshUserConfigPath
        Write-OkMessage "Added empty config to $pwshConfigDir"
    } elseif ((Read-Boolean "Config file already exists. Replace with empty file?")) {
        New-Item $pwshUserConfigPath -Force
        Write-OkMessage "Replaced $pwshUserConfigPath with emtpy file"
    }
}

function Install-DefaultConfig {
    $ErrorActionPreference = 'Stop'

    $pwshConfigDir = Invoke-EnsurePwshConfigDir
    $pwshUserConfigPath = (Join-Path $pwshConfigDir pwsh.yaml)

    if (!(Test-Path($pwshUserConfigPath))) {
        # Copy default pwsh.yaml
        Copy-Item (Join-Path $thisDirectory pwsh.yaml) $pwshConfigDir
        Write-OkMessage "Added config to $pwshConfigDir"
    } elseif ((Read-Boolean "Config file already exists. Replace?")) {
        Copy-Item (Join-Path $thisDirectory pwsh.yaml) $pwshConfigDir -Force
        Write-OkMessage "Replaced $pwshUserConfigPath with default config"
    }
}

function Uninstall-Pwsh {
    $ErrorActionPreference = 'Stop'
    $pwshHomeDir = (Join-Path $HOME pwsh)

    if (Test-Path $pwshHomeDir) {
        Remove-Item -Recurse (Join-Path $HOME pwsh)
    }

    # Un-source pwshrc in the profile?
    $containsSource = (Select-String -Path $PROFILE -Pattern $endBlock -SimpleMatch)
    if ($containsSource) {
        $unsourceProfile = Read-Boolean "Un-source in profile?"
        if ($unsourceProfile) {
            Set-Content $PROFILE (Get-Content $PROFILE | Where-Object { !( $_ -match $endBlock )})
        }
    }

    $pwshConfigDir = $IsWindows `
        ? (Join-Path $env:LOCALAPPDATA pwsh)
        : (Join-Path $HOME .config pwsh)

    if (Test-Path(Join-Path $pwshConfigDir .\pwsh.yaml)) {
        $keepConfig = Read-Boolean "Keep config?"

        if (!$keepConfig) {
            Remove-Item -Recurse $pwshConfigDir
        }
    }
}

# Init any git submodules
git submodule init
git submodule update

$option = Read-Host "Pick an option`n(1) Install`n(2) Uninstall`n(3) Install default config`n(4) Install empty config`n"

switch($option) {
    "1" {
        Install-Pwsh
        Write-OkMessage "Installed"
    }
    "2" {
        Uninstall-Pwsh
        Write-OkMessage "Uninstalled"
    }
    "3" {
        Install-DefaultConfig
    }
    "4" {
        Install-EmptyConfig
    }
    default {
        Write-ErrorMessage "Invalid option"
    }
}

