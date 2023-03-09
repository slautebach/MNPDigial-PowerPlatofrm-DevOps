
#Set the TLS to 1.2 so we can download files
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12



#####
# Functions
#####

$global:toolsPath = "$PSScriptRoot\..\Tools"

function IsNumeric ($Value) {
    return $Value -match "^[\d\.]+$"
}



function Load-Module ($m) {
    
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        write-host "Module $m is already imported."
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Write-Host "Importing Module: $m"
            Import-Module $m 
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Write-Host "Install Module: $m"
                Install-Module -Name $m -Force -Scope CurrentUser  -AllowClobber
                Write-Host "Importing Module: $m"
                Import-Module $m 
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $m not imported, not available and not in an online gallery, exiting."
                EXIT 1
            }
        }
    }
    $loadedModule = Get-Module -Name $m 
    Write-Host "Module $m, loaded version: $($loadedModule.Version)"
}
             
function Load-ModuleVersion ($m, $RequiredVersion) {
    
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m -and $_.Version -eq $RequiredVersion}) {
        write-host "Module $m, Version $RequiredVersion is already imported."
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m -and $_.Version -eq $RequiredVersion}) {
            Write-Host "Importing $m, $RequiredVersion"
            Import-Module $m -RequiredVersion $RequiredVersion
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m -and $_.Version -eq $RequiredVersion}) {
                Write-Host "Installing $m, $RequiredVersion"
                Install-Module -Name $m -Force -Scope CurrentUser  -AllowClobber -RequiredVersion $RequiredVersion  
                Write-Host "Importing $m, $RequiredVersion"
                Import-Module $m -RequiredVersion $RequiredVersion
            }
            else {

                # If the module is not imported, not available and not in the online gallery then abort
                write-host "Module $m, version $RequiredVersion not imported, not available and not in an online gallery, exiting."
                EXIT 1
            }
        }
    }
}

Load-Module powershell-yaml



function Resolve-Error ($ErrorRecord=$Error[0]) {
   $ErrorRecord | Format-List * -Force
   $ErrorRecord.InvocationInfo |Format-List *
   $Exception = $ErrorRecord.Exception
   for ($i = 0; $Exception; $i++, ($Exception = $Exception.InnerException)) {
       "$i" * 80
       $Exception |Format-List * -Force
   }
}

# Given a PSCustomObject, recursively convert it to a HashTable
function ConvertTo-HashtableFromPsCustomObject { 
    param ( 
        [Parameter(  
            Position = 0,   
            Mandatory = $true,   
            ValueFromPipeline = $true,  
            ValueFromPipelineByPropertyName = $true  
        )] [object] $psCustomObject 
    );
    $output = @{}; 
    $psCustomObject | Get-Member -MemberType *Property | % {
        $value = $psCustomObject.($_.name); 
        if ($value -eq $null){
            $value = ""
        }
        if ($value.GetType().FullName -eq "System.Management.Automation.PSCustomObject"){
            #recurse to set the value of value.
            $value = ConvertTo-HashtableFromPsCustomObject $value
        }
        $output.($_.name) = $value
    } 
    return  $output;
}


# Given a Hash Table Recursively Output it to console.
function Write-HashTable { 
    param ( 
        [Parameter(  
            Position = 0,   
            Mandatory = $true,   
            ValueFromPipeline = $true,  
            ValueFromPipelineByPropertyName = $true  
        )] $hashTable,
        $indent = 2
    );
    if ($hashTable -eq $null) {
        Write-Host "Null Hashtable.";
        return
    }
    if ($hashTable.Count -eq 0) {
        Write-Host "Empty Hashtable.";
        return
    }
    foreach ($key in $hashTable.Keys)
    {
        $value = $hashTable[$key]
        
        # if the value is a dictionary, convert it to hashtable
        if ($value -is [System.Collections.IDictionary]) {
            $value = [Hashtable]$value
        }
        # if the value is a custom object convert to to hashtable
        if ($value -is [pscustomobject]){
            # Extract it and convert it to a hashtable
            $value = ConvertTo-HashtableFromPsCustomObject  $value
        } 
        $indentStr = " " * ($indent - 1)
        if ($value -eq $null){
            Write-Host "$indentStr $key = [NULL]"
        }
        elseif ($value -is [System.Collections.Hashtable]){
            Write-Host "$indentStr $key = {"
            Write-HashTable $value -indent ($indent+2)
            Write-Host "$indentStr }"
        }
        elseif ($value.GetType().FullName.EndsWith("[]")){
            Write-Host "$indentStr $key = ["
            for ($i = 0; $i -lt $value.Length; $i++){
                if ($i -eq $value.Length -1){
                    Write-Host "$indentStr   $($value[$i])"
                }
                else{
                    Write-Host "$indentStr   $($value[$i]),"
                }
            }            
            Write-Host "$indentStr ]"
        }
        else{
            Write-Host "$indentStr $key = $value"
        }
    }
    
}

function Write-Object { 
    param ( 
        [Parameter(  
            Position = 0,   
            Mandatory = $true,   
            ValueFromPipeline = $true,  
            ValueFromPipelineByPropertyName = $true  
        )] $object
    );
    if ($object -eq $null){
        Write-Host "Object is NULL"
        return
    }

    if ($object -is [System.Collections.IDictionary]) {
        $object = [Hashtable]$object
    }
    if (-not $object -is [System.Collections.Hashtable]){
        # Extract it and convert it to a hashtable
        $hashTable = ConvertTo-HashtableFromPsCustomObject  $object
    } 
    else {
       $hashTable = $object
    }
    Write-HashTable -hashTable $hashTable
}


function Build-InstallNuget ($package){   

    Write-Host "Tools Path: $($global:toolsPath) "

    $sourceNugetExe = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
    $targetNugetExe = "$global:toolsPath\nuget.exe"

    mkdir $global:toolsPath -Force -ErrorAction SilentlyContinue

    if (!(Test-Path -Path $targetNugetExe)){
        Invoke-WebRequest $sourceNugetExe -OutFile $targetNugetExe | Out-Null
    }
    Set-Alias nuget $targetNugetExe -Scope Global -Verbose | Out-Null
}

function Build-NuGet ($package){
    Build-InstallNuget
    # nuget install the PAC tools
    nuget install $package -OutputDirectory "$($global:toolsPath)\$package" | Out-Null

    # return the installed path
    return "$($global:toolsPath)\$package"
}


function Build-MsBuildNuGet {
    param(
        [string] $solution
    )
    # make sure the Invoke-MsBuild is installed and loaded
    Load-Module Invoke-MsBuild | Out-Null
    # make sure nuget is installed
    Build-InstallNuget | Out-Null

    # get the solution folder path
    $solutionDirectory = [System.IO.Path]::GetDirectoryName($solution)

    # restore nuget
    nuget restore $solution -SolutionDirectory $solutionDirectory 
}


function Build-MsBuild {
    param(
        [string] $solution
    )

    # make sure the Invoke-MsBuild is installed and loaded
    Load-Module Invoke-MsBuild | Out-Null


    Build-MsBuildNuGet -solution $solution | Out-Null


    # invoke msbuild logging the output to the console
    $buildResult = Invoke-MsBuild -Path $solution -MsBuildParameters "/target:Clean;Build /property:Configuration=Release" -ShowBuildOutputInCurrentWindow

    if ($buildResult.BuildSucceeded -eq $true)
    {
	    Write-Output ("Build completed successfully in {0:N1} seconds." -f $buildResult.BuildDuration.TotalSeconds)
    }
    elseif ($buildResult.BuildSucceeded -eq $false)
    {
	    throw ("Build failed after {0:N1} seconds. Check the build log  for errors." -f $buildResult.BuildDuration.TotalSeconds)
    }
    elseif ($null -eq $buildResult.BuildSucceeded)
    {
	    throw "Unsure if build passed or failed: $($buildResult.Message)"
    }
}

function Format-XML ([xml]$xml, $indent=2)
{
    $StringWriter = New-Object System.IO.StringWriter
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
    $xmlWriter.Formatting = “indented”
    $xmlWriter.Indentation = $Indent
    $xml.WriteContentTo($XmlWriter)
    $XmlWriter.Flush()
    $StringWriter.Flush()
    Write-Output $StringWriter.ToString()
}
# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
    $indent = 0;
    ($json -Split "`n" | % {
        if ($_ -match '[\}\]]\s*,?\s*$') {
            # This line ends with ] or }, decrement the indentation level
            $indent--
        }
        $line = ('  ' * $indent) + $($_.TrimStart() -replace '":  (["{[])', '": $1' -replace ':  ', ': ')
        if ($_ -match '[\{\[]\s*$') {
            # This line ends with [ or {, increment the indentation level
            $indent++
        }
        $line
    }) -Join "`n"
}

function ConvertInvalidFileNames([string]$fileName){
    
    # replacing all "/" to "\" as folder separaters.
    $fileName = $fileName.replace("/",'-')
    [System.Collections.ArrayList]$invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $invalidChars.Remove([Char]'\')
    $invalidChars.Remove([Char]'/')
        
    # remove and replace any invalid file characters to '_'
    $invalidChars | % {$fileName = $fileName.replace($_,'_')}
    Write-Output $fileName
}

function ReplaceEnvVariables( [string]$inFile,[string]$outFile){
    # load the template file
    $inContent = Get-Content -Path $inFile
        
    # in the parameters file, search for environment variables to replace
    # this is where configuration can be specified securly on the pipeline.
    $regexPattern =  '\$\(\$env\:(?<varname>[\w]+)\)'
    $matches = [regex]::Matches($inContent, $regexPattern)
        Write-Host $inContent
    # for each match found
    foreach ($match in $matches){

        # get the env: keyname
        $key = $match.Groups['varname'].Value.ToUpper()
        Write-Host "Found Key: $key"
        # find an environment variable that matches the key
        $envVar = Get-ChildItem env: | Where-Object { $_.Name.ToUpper() -eq $key -or $_.Name.ToUpper() -eq "SECRET_$key"}
        #default value to "_NoValue_"
        $value = "_NoValue_"
        # if an environment variable update the $value to the variable's value.
        if ($envVar){
            $value = $envVar.Value            
            #Write-Host "Setting Value: $key = $value "
        } else {
             Write-Warning "No Value specified for key: $key"
        }
        # update the in memory json to replace the key  with the value
        $inContent = $inContent -replace "\`$\(\`$env:$key\)",$value
    }

    if ($inContent -contains "`$`(env:"){
        throw "$inFile contains varaible not replaced"
    }
    $inContent | Out-File -Encoding "UTF8" -FilePath $outFile
}

function Get-Parameters( [string]$parametersFile, [string] $environment, [string] $sharedEnvironmentGroup){
    # load the template file
    $content = Get-Content -Path $parametersFile

    
    $content = $content -replace "\`$\(\`$environment\)",$environment
    $content = $content -replace "\`$\(\`$sharedEnvironmentGroup\)",$sharedEnvironmentGroup


    # in the parameters file, search for environment variables to replace
    # this is where configuration can be specified securly on the pipeline.
    $regexPattern =  '\$\(\$env\:(?<varname>[\w]+)\)'
    $matches = [regex]::Matches($content, $regexPattern)

    # for each match found
    foreach ($match in $matches){

        # get the env: keyname
        $key = $match.Groups['varname'].Value.ToUpper()

        # find an environment variable that matches the key
        $envVar = Get-ChildItem env: | Where-Object { $_.Name.ToUpper() -eq $key -or $_.Name.ToUpper() -eq "SECRET_$key"}
        
        #default value to ""
        $value = ""
        # if an environment variable update the $value to the variable's value.
        if ($envVar){
            $value = $envVar.Value            
            #Write-Host "Setting Value: $key = $value "
        }
        elseif ($env:AllowMissingParameters -eq "allow"){
            Write-Warning "No Value specified for key: $key"
        } else {
            throw "No Value specified for key: $key"
        }
        # update the in memory json to replace the key  with the value
        $content = $content -replace "\`$\(\`$env:$key\)",$value
    }

    if ($content -contains "`$`("){
        throw "Parameters.yaml contains varaible not replaced"
    }
    return $content | ConvertFrom-Yaml
}




function Get-Variables( [string]$parametersFile){
    # load the template file
    $rawJson = Get-Content -Path $parametersFile

    # in the parameters file, search for environment variables to replace
    # this is where configuration can be specified securly on the pipeline.
    
    $varRegexPattern =  '\$\(\$(?<varname>[\w]+)\)'
    $varMatches = [regex]::Matches($rawJson, $varRegexPattern)

    $varibales = @()
    # for each match found
    foreach ($match in $varMatches){
        # get the env: keyname
        $varibales += $match.Groups['varname'].Value
    }


    $envRegexPattern =  '\$\(\$env\:(?<varname>[\w]+)\)'
    $envMatches = [regex]::Matches($rawJson, $envRegexPattern)
    $envVariables = @()
    # for each match found
    foreach ($match in $envMatches){
        # get the env: keyname
        $envVariables += $match.Groups['varname'].Value
    }

    $results = @{
        'variables' = $varibales | select -Unique
        'environmentVariables' = $envVariables | select -Unique
    }

    return $results
}


# Helper method for Sort-Xml
function SortChildNodes($node, $depth = 0, $maxDepth = 20) {
    if ($node.HasChildNodes -and $depth -lt $maxDepth) {
        foreach ($child in $node.ChildNodes) {
            SortChildNodes $child ($depth + 1) $maxDepth
        }
    }
 
    $sortedAttributes = $node.Attributes | Sort-Object { $_.Name }
    $sortedChildren = $node.ChildNodes | Sort-Object { $_.OuterXml }
 
    $node.RemoveAll()
 
    foreach ($sortedAttribute in $sortedAttributes) {
        [void]$node.Attributes.Append($sortedAttribute)
    }
 
    foreach ($sortedChild in $sortedChildren) {
        [void]$node.AppendChild($sortedChild)
    }
}
 
# sort the xml and return
function Sort-Xml {
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        # The path to the XML file to be sorted
       [xml]$xml
    )
    SortChildNodes $xml.DocumentElement
    return $xml
}

# Sort the xml in a file
function Sort-XmlFile {
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        # The path to the XML file to be sorted
        [string]$XmlPath
    )
    if (-not (Test-Path $XmlPath)) {
        throw "File: $XmlPath, as it was not found."
    }
 
    $fullXmlPath = (Resolve-Path $XmlPath)
    [xml]$xml = Get-Content $fullXmlPath
    Sort-Xml -xml $xml 
    $xml.Save($fullXmlPath)
}

function LogInvocationDetails($Invocation){
    $secretParameters = @("clientSecret", "password")
    Write-Host "******************************************************************************************************"
    Write-Host "* Script: $($Invocation.MyCommand.Path)"
    Write-Host "*  Arguments:"
    #$Invocation.BoundParameters | Format-List
    foreach ($key in $Invocation.BoundParameters.keys ){
        $value = $Invocation.BoundParameters[$key]
        if ($key.ToLower().Contains("password") -or $secretParameters.Contains($key)){
            Write-Host "*     $key = ********"
        } else {
            Write-Host "*     $key = $value"
        }
    }
    Write-Host "******************************************************************************************************"
}

function Set-Environment-Variable ($name, $value, [switch]$noLog) {
    Write-Host "Setting Env Varaible: $name to: $value"
    [Environment]::SetEnvironmentVariable($name, $value)
}


function ConvertTo-PsCustomObjectFromHashtable { 
    param ( 
        [Parameter(  
            Position = 0,   
            Mandatory = $true,   
            ValueFromPipeline = $true,  
            ValueFromPipelineByPropertyName = $true  
        )] [object[]]$hashtable 
    ); 

    begin { $i = 0; } 

    process { 
        foreach ($myHashtable in $hashtable) { 
            if ($myHashtable.GetType().Name -eq 'hashtable') { 
                $output = New-Object -TypeName PsObject; 
                Add-Member -InputObject $output -MemberType ScriptMethod -Name AddNote -Value {  
                    Add-Member -InputObject $this -MemberType NoteProperty -Name $args[0] -Value $args[1]; 
                }; 
                $myHashtable.Keys | Sort-Object | % {  
                    $output.AddNote($_, $myHashtable.$_);  
                } 
                $output
            } else { 
                Write-Warning "Index $i is not of type [hashtable]"; 
            }
            $i += 1;  
        }
    } 
}

function XmlNodeToPsCustomObject ($node){
    $hash = @{}
    foreach($attribute in $node.attributes){
        $hash.$($attribute.name) = $attribute.Value
    }
    $childNodesList = ($node.childnodes | ?{$_ -ne $null}).LocalName
    foreach($childnode in ($node.childnodes | ?{$_ -ne $null})){
        if(($childNodesList | ?{$_ -eq $childnode.LocalName}).count -gt 1){
            if(!($hash.$($childnode.LocalName))){
                $hash.$($childnode.LocalName) += @()
            }
            if ($childnode.'#text' -ne $null) {
                $hash.$($childnode.LocalName) += $childnode.'#text'
            }
            $hash.$($childnode.LocalName) += XmlNodeToPsCustomObject($childnode)
        }else{
            if ($childnode.'#text' -ne $null) {
                $hash.$($childnode.LocalName) = $childnode.'#text'
            }else{
                $hash.$($childnode.LocalName) = XmlNodeToPsCustomObject($childnode)
            }
        }   
    }
    return $hash | ConvertTo-PsCustomObjectFromHashtable
}


Export-ModuleMember -Function * -WarningAction SilentlyContinue