param(
    [Parameter(Mandatory=$true)]
	[string] $targetEnvironment, # Cloud Environment name (*.crm3.dynamics.com)
    [string] $schemaFileName = "$PSScriptRoot\Configuration.xml", # path to schema file
    [string] $appId = "",
    [string] $clientSecret= "",
    [array] $excludeEntities
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


# find all entity nodes
$nodes = Select-Xml "/entities/entity" $schemaData
$nodes | ForEach-Object {
    $node = $_;
    $entityLogicalName = $node.Node.Attributes["name"].Value

    Write-Host ""
    Write-Host "**********************************************"
    Write-Host "Entity: $entityLogicalName"

    if ($excludeEntities -contains $entityLogicalName){
        Write-Host "$entityLogicalName in the list of excludeEntities list, skipping... "
        Write-Host "**********************************************"
        return
    }

    $field =  Select-Xml "/entities/entity[@name='$entityLogicalName']/fields" $schemaData
    
    $emd = $allEntityMetadata | Where-Object {$_.SchemaName -eq $entityLogicalName}
 
    # filter out all attributes that don't have deprecated
    $processedAmd = [System.Collections.ArrayList] $emd.Attributes 
    

    Write-Debug "  Processing Child Nodes: $($field.Node.ChildNodes.Count), Total Attributes $($processedAmd.Count)"

    # create an array list of all nodes so we can iterate and remove from the xml node list.
    $childNodes =[System.Collections.ArrayList]::new()
    foreach ($childField in $field.Node.ChildNodes)  {
         [void]$childNodes.Add($childField) 
    }
   
    # foreach child field
    foreach ($childField in $childNodes)  {
        $amd = $processedAmd | Where-Object {$_ -ne $null -and  $_.LogicalName.ToLower() -eq $childField.name.ToLower()}
        $displayName = $amd.DisplayName.UserLocalizedLabel.Label
        if ($displayName -eq $null) {
            $displayName = ""
        }

        # determine if it is deprecated
        $deprecated = $displayName.ToUpper().Contains("DEPRECATED")
        # if the attribute exists and is not deprecated
        # skip it and leave it in the xml
        if ($amd -and !$deprecated){
            Write-Debug "  $entityLogicalName.$($amd.LogicalName) already exists, skipping"
            [void]$processedAmd.Remove($amd) 
            # attribute is defined skip, no change
            continue;
        }
        # if it is deprecated, remove it fro the process list and log
        if ($deprecated){
            Write-Host "  -- Removing attribute $entityLogicalName.$($childField.name) '$displayName'  is deprecated**"
            # remove it from being processed
            [void]$processedAmd.Remove($amd)
        }
        else{
            Write-Host "  -- Removing attribute $entityLogicalName.$($childField.name) '$displayName'  not found int target environment**"
        }
        # Remove from xml
        [void]$childField.ParentNode.RemoveChild($childField)
    }


    # TODO update to use a configurable list of prefix schemas
    # re-filter process amd, for only rp_ and new_ fields
    $processedAmd =  $processedAmd | Where-Object {$_ -ne $null -and  ($_.LogicalName.StartsWith("rp_") -or $_.LogicalName.StartsWith("new_")) -and $_.AttributeOf -eq $null -and $_.CalculationOf -eq $null}
    if ($processedAmd.Count -eq 0){
        # No new Attributes we are done, move on to the next entity
        return
    }

    # List the attributes we are adding.
    Write-Host "  ++ New Attriubtes to Add:" $processedAmd.Count
    $processedAmd | ForEach-Object {

        $amd = $_
        Write-Host "      + Entity $entityLogicalName.$($amd.LogicalName)"
        $newField = $schemaData.CreateElement("field")

        $displayName = $amd.DisplayName.UserLocalizedLabel.Label
        if ($displayName -eq $null) {
            $displayName = ""
        }

        # if it is deprecated skip.
        $deprecated = $displayName.ToUpper().Contains("DEPRECATED")
        if ($deprecated){
            # skip deprecated fields
            return
        }

        # add the new field to migrate
        $newField.SetAttribute("displayname", $displayName)
        $newField.SetAttribute("name", $amd.LogicalName)
        $newField.SetAttribute("customfield", "true")
        if ($amd.IsPrimaryId){
            $newField.SetAttribute("updateCompare", "true")
            $newField.SetAttribute("primaryKey", "true")            
        }

        # convert the type
        if ($amd.AttributeType -eq "Boolean")
        {
            $newField.SetAttribute("type", "bool")
        }
        elseif ($amd.AttributeType -eq "Picklist")
        {
            $newField.SetAttribute("type", "optionsetvalue")
        }
        elseif ($amd.AttributeType -eq "String")
        {
            $newField.SetAttribute("type", "string")
        }
        elseif ($amd.AttributeType -eq "Memo")
        {
            $newField.SetAttribute("type", "string")
        }
        elseif ($amd.AttributeType -eq "Integer")
        {
            $newField.SetAttribute("type", "number")
        }
        elseif ($amd.AttributeType -eq "Money")
        {
            $newField.SetAttribute("type", "money")
        }
        elseif ($amd.AttributeType -eq "DateTime")
        {
            $newField.SetAttribute("type", "datetime")
        }
        elseif ($amd.AttributeType -eq "Uniqueidentifier")
        {
            $newField.SetAttribute("type", "guid")
        }
        elseif ($amd.AttributeType -eq "Lookup")
        {
            $newField.SetAttribute("type", "entityreference")
            $newField.SetAttribute("lookupType", $amd.Targets[0])
        }
        else {
            $amd | Format-List
            Write-Error " Unsupported Type: $($amd.AttributeType)"
        }
        # add the new field
        [void]$field.Node.AppendChild($newField) 
    }
    
    Write-Host "**********************************************"
}


# Function to sort the configuration data
function SortChildNodes($node, $depth = 0, $maxDepth = 30) {

    # recurse to all children
    if ($node.HasChildNodes -and $depth -lt $maxDepth) {
        foreach ($child in $node.ChildNodes) {
            SortChildNodes $child ($depth + 1) $maxDepth
        }
    }

    # sort all attributes, having the name first, then by order of the othe attriubte names
    $sortedAttributes = $node.Attributes | Sort-Object { 
        if ($_.Name -eq "name"){
            # make sure name is frits
            return "aaa_$($_.Name)"
        }
        return $_.Name
    }

    # sort all child nodes by the value of the name attribute (logical names), then by the xml
    $sortedChildren = $node.ChildNodes | Sort-Object { 
        if ($_.name) {
            return $_.name
        }
        return $_.OuterXml
    }
 
    # remove all attriubtes and children to apply the sort.
    $node.RemoveAll()
 
    # add all sorted attributes back
    foreach ($sortedAttribute in $sortedAttributes) {
        [void]$node.Attributes.Append($sortedAttribute)
    }
 
    # add all the sorted children back
    foreach ($sortedChild in $sortedChildren) {
        [void]$node.AppendChild($sortedChild)
    }
}

Write-Host ""
Write-Host "**********************************************"
Write-Host "Updating: $schemaFileName"
Write-Host "**********************************************"

# finally lets clean up and remove any entities that have no fields.
$fields =  Select-Xml "/entities/entity/fields" $schemaData

$fieldNodes =[System.Collections.ArrayList]::new()
$fields | ForEach-Object {
   $fieldNodes.Add($_.Node) | Out-Null
}
foreach ($field in $fieldNodes){
    # if a field
    if ($field.ChildNodes.Count -eq 0){
        Write-Host "Removing entity"  $field.ParentNode.name "no fields for migration"
        $field.ParentNode.ParentNode.RemoveChild($field.ParentNode) | Out-Null
        continue
    }
}

# sort the xml to make code comparisions easier
SortChildNodes($schemaData)
# save the updated schema file
$schemaData.Save("$schemaFileName")