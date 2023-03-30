param(
   [switch] $Force # force it to be built even if it is not enabled in the package.yml
) 

# Load the Package Data
Import-Module "$PSScriptRoot\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation

Load-PackageData



if (!$Force -and !$PackageData.BuildPackages.Plugins){
	Write-Host "Plugins Build is not enabled"
	exit
}

$pluginSolutionsFolder = "$PSScriptRoot\..\Plugins\"

# install nuget packages for all plugins
Build-MsBuildNuGet -solution "$pluginSolutionsFolder\$($PackageData.PluginSolution)"

# Build just the xRM Plugins
$buildResult = Build-MsBuild -solution "$pluginSolutionsFolder\$($PackageData.PluginSolution)"


if ($buildResult.BuildSucceeded -eq $true)
{
	Write-Output ("Build completed successfully in {0:N1} seconds." -f $buildResult.BuildDuration.TotalSeconds)
}
elseif ($buildResult.BuildSucceeded -eq $false)
{
	Write-Output ("Build failed after {0:N1} seconds. Check the build log file '$($buildResult.BuildLogFilePath)' for errors." -f $buildResult.BuildDuration.TotalSeconds)
	$logData = Get-Content -Path $buildResult.BuildLogFilePath
	Write-Host $logData
}
elseif ($null -eq $buildResult.BuildSucceeded)
{
	Write-Output "Unsure if build passed or failed: $($buildResult.Message)"
}
