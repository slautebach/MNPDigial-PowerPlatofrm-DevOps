Import-Module "$PSScriptRoot\Functions.psm1"  -DisableNameChecking -Force
Import-Module "$PSScriptRoot\PP-CLI.psm1"  -DisableNameChecking -Force



$rootPath = "$PSScriptRoot\..\..\"
$rootPath = (Get-Item -Path $rootPath).FullName

$buildScriptRoot = "$PSScriptRoot\..\"
$buildScriptRoot = (Get-Item -Path $buildScriptRoot).FullName


# Load the Build Variables
Import-Module "$PSScriptRoot\PP-CLI.psm1" -Force  -DisableNameChecking


#####
# Load the Package Data
#####
function Load-PackageData(){
    param ( 
       [switch] $logConfig 
    )
    if (!$env:BuildPackageFile)
    {
        # if the environment doesn't specify a build package file
        # then default it to the package.json
        $env:BuildPackageFile = "Package"
    }
    
    Write-Host ""
    Write-Host "================================"
    Write-Host "Loading-Package Data"
    Write-Host "================================"

    Write-Host "Using BuildPackageFile: $($env:BuildPackageFile)"


    Write-Host "Read the package data and replace any environment vars with their environment values"
	# update the the $($env:BuildPackageFile).json with the environment variable values
	ReplaceEnvVariables -inFile "$PSScriptRoot\..\$($env:BuildPackageFile).yml" -outFile "$PSScriptRoot\..\$($env:BuildPackageFile).build.yml"


    Write-Host ""
    Write-Host "================================"
    Write-Host "Build Package Config File"
    Write-Host "================================"
	cat "$PSScriptRoot\..\$($env:BuildPackageFile).build.yml"
        
    $PackageData = (Get-Content -Path "$PSScriptRoot\..\$($env:BuildPackageFile).build.yml" )  -join "`n" | ConvertFrom-Yaml 

    # if no Crm Data Package Config is specified
    # initialzie the default empty hashtables.
    if ($PackageData.CrmDataPackageConfig -eq $null){
        Write-Host "CrmDataPackageConfig is null"
        $PackageData.CrmDataPackageConfig =  @{}
        $PackageData.CrmDataPackageConfig.Identifiers = @{}
        $PackageData.CrmDataPackageConfig.DisablePlugins = @{}
    }

    if ($PackageData.CrmDataPackageConfig.Identifiers -eq $null){
        $PackageData.CrmDataPackageConfig.Identifiers = @{}
    }

    $PackageData.BuildVersion = Get-Date -Format "yyMM"
    $PackageData.RevisionVersion = Get-Date -Format "ddHH"



    if (!(Test-Path -Path "$rootPath\Solutions")){
        New-Item -ItemType Directory -Force -Path "$rootPath\Solutions" | Out-Null
    }
    $PackageData.SolutionsPath = (Get-Item -Path "$rootPath\Solutions").FullName 
    $PackageData.SolutionMappingFile  = "$($PackageData.SolutionsPath)\mapping.xml"

    Write-Host buildscript root: $buildScriptRoot
    Write-Host root: $rootPath

    if ($buildScriptRoot.EndsWith("\BuildScripts\")){
        if (!(Test-Path -Path "$rootPath\Build")){
            New-Item -ItemType Directory -Force -Path "$rootPath\Build" | Out-Null
        }
        # Set the build package path to the local builds path
        $PackageData.BuildPackagePath = (Get-Item -Path "$rootPath\Build").FullName 
    } else  {
        #otherwise we are running form a built package, and it is the buildscript root path.
        $PackageData.BuildPackagePath = $buildScriptRoot
    }

    if ($logConfig){
        # Write to Console the Hash Table and all its values so we can see what config is being used
        Write-Host "Loaded Build Package Data Configuration from $($env:BuildPackageFile).json:"
        Write-Object $PackageData
    }

    # Set it as an global variable in the global scope
    Set-Variable -Name "PackageData" -Visibility Public -Value $PackageData -Scope global 
}



Export-ModuleMember -Function * -Alias * -WarningAction SilentlyContinue 
