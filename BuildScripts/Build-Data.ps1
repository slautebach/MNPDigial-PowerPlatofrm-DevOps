param(
   [string] $solutionName = "",
   [switch] $Force # force it to be built even if it is not enabled in the package.yml
) 

# Load the Package Data
Import-Module "$PSScriptRoot\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation

Load-PackageData

if (!$Force -and !$PackageData.BuildPackages.Data){
	Write-Host "Data Build is not enabled"
	exit
}
# if solution is not specified, then get it from the version.json file.
if ($solutionName -eq ""){
	$solutionName = $PackageData.SolutionName
}


$buildPackagePath = $PackageData.BuildPackagePath
$ConfigDataExtractPath = "$PSScriptRoot\..\ConfigurationData\SolutionBuilds\$solutionName\"
$zipDataFile = "$buildPackagePath\$solutionName-Data.zip"

# remove any pre-existing zip file.
Remove-Item $zipDataFile -ErrorAction SilentlyContinue

Write-Host "Packaging Data Folder: '$ConfigDataExtractPath' to '$zipDataFile'"

if (Test-Path -Path "$ConfigDataExtractPath\data.xml"){
	Compress-Archive -LiteralPath  "$ConfigDataExtractPath\[Content_Types].xml","$ConfigDataExtractPath\data.xml","$ConfigDataExtractPath\data_schema.xml" -DestinationPath $zipDataFile
}
else {
	Write-Warning "Data Path: $ConfigDataExtractPath\data.xml does not exist, so no data package will be built"
}
