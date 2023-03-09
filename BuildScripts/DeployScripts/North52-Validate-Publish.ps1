# Connect to CRM and get an Org Service
param(
    [string] $targetEnvironment,
    [string] $appId, # optional app id to connect to dataverse
    [string] $clientSecret , #  client secret for the app id
    [int]$queryWait = 10000,
    [int] $timeoutMintues = 10
) 

Import-Module "$PSScriptRoot\..\PS-Modules\Functions.psm1" -DisableNameChecking -Force
Import-Module "$PSScriptRoot\..\PS-Modules\Build-Package.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot\..\PS-Modules\Dataverse-API.psm1" -Force -DisableNameChecking

# Log Script Invcation Details
LogInvocationDetails $MyInvocation

SetPACConnections  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret  -resetAuth:$resetAuth -requireAdmin

# Publish Solutions to trigger N52
PublishSolutions

ConnectDataverseApi  -targetEnvironment $targetEnvironment -appId $appId -clientSecret $clientSecret

WaitForNorth52 -timeout $timeoutMintues -queryWait $queryWait