param(
    [Parameter(Mandatory=$true)]
	[string] $targetEnvironment, # Cloud Environment name (*.crm3.dynamics.com)
    [string] $schemaFileName = "$PSScriptRoot\Configuration.xml", # path to schema file
    [string] $appId = "",
    [string] $clientSecret= "",
    [array] $initializeWithEntities
) 

Import-Module "$PSScriptRoot\..\BuildScripts\PS-Modules\Dataverse-API.psm1" -Force  -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation


#load the schema file
$schemaData = [xml](Get-Content -Path $schemaFileName)

Write-Host ""
Write-Host "=================================================================="
Write-Host "Connecting to Dataverse API"
Write-Host "=================================================================="
ConnectDataverseApi  -targetEnvironment $targetEnvironment  -appId $appId -clientSecret $clientSecret


Write-Host "Retireving Entity Metadata"
# retreive all metadata
$allEntityMetadata = Get-CrmEntityAllMetadata -conn $Conn -OnlyPublished $True -EntityFilters attributes


$allEntityMetadata | ForEach-Object {
    $entityLogicalName = $_.LogicalName
    if ($initializeWithEntities -notcontains $entityLogicalName){
        Write-Host "$entityLogicalName in the list of initializeWithEntities list, skipping... "
        Write-Host "**********************************************"
        return
    }
    #TODO - create entity xml nodes for the enity and add to the list.
}
