#####
#
#  Prep Script to make sure all other build scripts are setup.
#
######

param(
	[string]$buildPackageFile = "Package" # The Build Package file to use
)

$env:BuildPackageFile = $buildPackageFile

# Load the Package Data
Import-Module "$PSScriptRoot\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking
Import-Module "$PSScriptRoot\PS-Modules\PP-CLI.psm1" -Force  -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation

Load-PackageData

Write-Host ""
Write-Host "********************************"
Write-Host "Preping $buildPackagePath"
Write-Host "********************************"

$buildPackagePath = $PackageData.BuildPackagePath
Write-Host ""
Write-Host "============================"
Write-Host "Cleaning $buildPackagePath"
Write-Host "============================"
Remove-Item -Recurse -Force -Path $buildPackagePath -ErrorAction SilentlyContinue | Out-Null
New-Item -ItemType Directory -Force -Path $buildPackagePath | Out-Null


Write-Host ""
Write-Host "=============================================================="
Write-Host "Copying Build/Deploy Scripts to: $buildPackagePath"
Write-Host "=============================================================="

# Copy the Package.yml
Copy-Item -Path "$PSScriptRoot\Package*.yml" -Destination $buildPackagePath | Out-Null

# Create the deployscripts folder
$buildPSModulesPath = "$buildPackagePath\PS-Modules\"
New-Item -ItemType Directory -Force -Path $buildPSModulesPath | Out-Null

# Copy all the Deploy Scripts
Copy-Item -Path "$PSScriptRoot\PS-Modules\*" -Destination $buildPSModulesPath  -Recurse | Out-Null

# Create the deployscripts folder
$buildDeployScriptsPath = "$buildPackagePath\DeployScripts\"
New-Item -ItemType Directory -Force -Path $buildDeployScriptsPath | Out-Null

# Copy all the Deploy Scripts
Copy-Item -Path "$PSScriptRoot\DeployScripts\*" -Destination $buildDeployScriptsPath -Recurse | Out-Null

InstallPAC


