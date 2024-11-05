$ErrorActionPreference = 'Stop'

Write-Host @"
`n
                                ───▄▀▀▀▀▀───▄█▀▀▀█▄
                                ──▐▄▄▄▄▄▄▄▄██▌▀▄▀▐██
                                ──▐▒▒▒▒▒▒▒▒███▌▀▐███
                                ───▌▒▓▒▒▒▒▓▒██▌▀▐██
                                ───▌▓▐▀▀▀▀▌▓─▀▀▀▀▀

 __          _______ _        _    _                  _____      _               
 \ \        / / ____| |      | |  | |                / ____|    | |              
  \ \  /\  / / (___ | |      | |  | |___  ___ _ __  | (___   ___| |_ _   _ _ __  
   \ \/  \/ / \___ \| |      | |  | / __|/ _ \ '__|  \___ \ / _ \ __| | | | '_ \ 
    \  /\  /  ____) | |____  | |__| \__ \  __/ |     ____) |  __/ |_| |_| | |_) |
     \/  \/  |_____/|______|  \____/|___/\___|_|    |_____/ \___|\__|\__,_| .__/ 
                                                                          | |    
                                                                          |_|    
"@

# Set up modules
Write-Host "Importing required modules..." -ForegroundColor Cyan

if (-not(Test-Path -Path ".\modules\powershell-yaml\0.4.7\powershell-yaml.psm1")) {
    Save-Module -Name powershell-yaml -RequiredVersion 0.4.7 -Path ".\modules"
}
Import-Module -Name ".\modules\powershell-yaml\0.4.7\powershell-yaml.psm1"

Write-Host "Required modules imported`n" -ForegroundColor Green

# Load config
Write-Host "Loading config..." -ForegroundColor Cyan

$Config = Get-Content -Path .\config.yaml | ConvertFrom-Yaml

Write-Host "Config loaded`n" -ForegroundColor Green


$Distros = @($Config.distros)
$SudoUsers = @($Config.sudousers)

if ($SudoUsers.Length -gt $Distros.Length) {
    Write-Error "You have more sudo users than distros"
    exit 1
}

# Hash table of temp passwords
$TempPasswords = @{}

$characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'


foreach ($Dist in $Distros) {
    $Password = -join ((1..10) | ForEach-Object { $characters[(Get-Random -Maximum $characters.Length)] })

    if ($SudoUsers -contains $Dist) {
        $Output = wsl -d $Dist -u root -- bash -c "adduser --disabled-password --gecos '' $($Dist) && echo '$($Dist):$($Password)' | chpasswd && usermod -aG sudo $($Dist)"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error creating WSL user: $Dist - $Output"
            $LASTEXITCODE = 0
            exit 1
        }

        $TempPasswords[$Dist] = $Password

        Write-Host "User and password created for $Dist" -ForegroundColor Cyan
        Write-Host "User $Dist added to sudo group`n" -ForegroundColor Yellow
    } else {

        $Output = wsl -d $Dist -u root -- bash -c "adduser --disabled-password --gecos '' $($Dist) && echo '$($Dist):$($password)' | chpasswd"
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error creating WSL user: $Dist - $Output"
            $LASTEXITCODE = 0
            exit 1
        }
    
        $TempPasswords[$Dist] = $Password

        Write-Host "User and password created for $Dist`n" -ForegroundColor Cyan
    }
}

Write-Host "Users set up successfully`n" -ForegroundColor Green

Write-Host "Temp Passwords for all users.."

$TempPasswords