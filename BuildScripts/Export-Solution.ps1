param(
	[Parameter(Mandatory=$true)]
    [string]$targetEnvironment, # Cloud Environment name (*.crm3.dynamics.com)
	[string]$solutionName, # solution name to extract
	[switch]$UpdateSolutionMasterOnly, # used to extract and update solution master, then delete the extracted solution.
	[string]$appId = "", # optional app id to connect to dataverse
	[string]$clientSecret = "", #  client secret for the app id
	[switch]$Force # if the package.yml enables the component to build
	
) 


Import-Module "$PSScriptRoot\PS-Modules\Extract-Solution-Components.psm1" -Force  -DisableNameChecking
Import-Module "$PSScriptRoot\PS-Modules\Build-Package.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\PS-Modules\PP-CLI.psm1" -Force -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation

SetPACConnections  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret -logConfig


if (!$Force -and !$PackageData.BuildPackages.Solution){
	Write-Host "Solution Export is not enabled in package.yml"
	exit
}

# if solution is not specified, then get it from the version.json file.
if ($solutionName -eq ""){
	$solutionName = $PackageData.SolutionName
}


Write-Host "Publishing Solutions ..."
pac solution publish 

ExportSolution -solutionName $solutionName -managed
ExportSolution -solutionName $solutionName 

$solutionExtractPath = "$($PackageData.SolutionsPath)\$($solutionName)\"
Process-Solution-Folder -solutionFilesPath $solutionExtractPath


if ($UpdateSolutionMasterOnly){
	Remove-Item –path $solutionExtractPath –recurse
}