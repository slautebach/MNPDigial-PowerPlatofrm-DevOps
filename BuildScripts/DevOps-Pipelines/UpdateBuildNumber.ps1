
# Load the Package Data
Import-Module "$PSScriptRoot\..\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking
Load-PackageData

# Set the version number
$majorVersion = $PackageData.MajorVersion
$minorVersion = $PackageData.MinorVersion
$buildVersion = $PackageData.BuildVersion
$revisionVersion = $PackageData.RevisionVersion

$buildVersionNumber = "$majorVersion.$minorVersion.$buildVersion.$revisionVersion"

Write-Host "Build Version Number: $buildVersionNumber"

[string]$buildNumber = $env:BUILD_BUILDNUMBER
# update the build number replacing the <BuildVersionNumber> key with the actual Build Version Number
$buildNumber = $buildNumber.Replace("`$BuildVersionNumber`$", $buildVersionNumber);


# Update The Build Number for the current running build.
Write-Host "##vso[build.updatebuildnumber]$buildNumber"

# Set the version Variables
Write-Host "##vso[task.setvariable variable=MajorVersion]$($PackageData.MajorVersion)"
Write-Host "##vso[task.setvariable variable=MinorVersion]$($PackageData.MinorVersion)"
Write-Host "##vso[task.setvariable variable=BuildVersion]$buildVersion"
Write-Host "##vso[task.setvariable variable=RevisionVersion]$revisionVersion"

# Set the full Build Version Number
Write-Host "##vso[task.setvariable variable=ReleaseVersion]$($buildVersionNumber)"


