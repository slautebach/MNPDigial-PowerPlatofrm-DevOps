Param(  
    [string]$path = "$PSScriptRoot\..\"
)

# Load the Package Data
Import-Module "$PSScriptRoot\PS-Modules\Build-Package.psm1" -Force  -DisableNameChecking
Load-PackageData

# Set the version number
$majorVersion = $PackageData.MajorVersion
$minorVersion = $PackageData.MinorVersion
$buildVersion = $PackageData.BuildVersion
$revisionVersion = $PackageData.RevisionVersion

# Get-FileEncoding
# Modified by F.RICHARD August 2010
# add comment + more BOM
# http://unicode.org/faq/utf_bom.html
# http://en.wikipedia.org/wiki/Byte_order_mark
#
# Taken from: https://gist.github.com/jpoehls/2406504
#>
function Get-FileEncoding
{
  [CmdletBinding()] 
  Param (
    [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] 
    [string]$Path
  )

  [byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path
  #Write-Host Bytes: $byte[0] $byte[1] $byte[2] $byte[3]

  # EF BB BF (UTF8)
  if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf )
  { Write-Output 'UTF8' }

  # FE FF  (UTF-16 Big-Endian)
  elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff)
  { Write-Output 'Unicode UTF-16 Big-Endian' }

  # FF FE  (UTF-16 Little-Endian)
  elseif ($byte[0] -eq 0xff -and $byte[1] -eq 0xfe)
  { Write-Output 'Unicode UTF-16 Little-Endian' }

  # 00 00 FE FF (UTF32 Big-Endian)
  elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff)
  { Write-Output 'UTF32 Big-Endian' }

  # FE FF 00 00 (UTF32 Little-Endian)
  elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff -and $byte[2] -eq 0 -and $byte[3] -eq 0)
  { Write-Output 'UTF32 Little-Endian' }

  # 2B 2F 76 (38 | 38 | 2B | 2F)
  elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76 -and ($byte[3] -eq 0x38 -or $byte[3] -eq 0x39 -or $byte[3] -eq 0x2b -or $byte[3] -eq 0x2f) )
  { Write-Output 'UTF7'}

  # F7 64 4C (UTF-1)
  elseif ( $byte[0] -eq 0xf7 -and $byte[1] -eq 0x64 -and $byte[2] -eq 0x4c )
  { Write-Output 'UTF-1' }

  # DD 73 66 73 (UTF-EBCDIC)
  elseif ($byte[0] -eq 0xdd -and $byte[1] -eq 0x73 -and $byte[2] -eq 0x66 -and $byte[3] -eq 0x73)
  { Write-Output 'UTF-EBCDIC' }

  # 0E FE FF (SCSU)
  elseif ( $byte[0] -eq 0x0e -and $byte[1] -eq 0xfe -and $byte[2] -eq 0xff )
  { Write-Output 'SCSU' }

  # FB EE 28  (BOCU-1)
  elseif ( $byte[0] -eq 0xfb -and $byte[1] -eq 0xee -and $byte[2] -eq 0x28 )
  { Write-Output 'BOCU-1' }

  # 84 31 95 33 (GB-18030)
  elseif ($byte[0] -eq 0x84 -and $byte[1] -eq 0x31 -and $byte[2] -eq 0x95 -and $byte[3] -eq 0x33)
  { Write-Output 'GB-18030' }

  else
  { Write-Output 'ASCII' }
}


##############################################################################################################################
#  Update Version Number - Updtaes the version number of an assembly or nuspec file
##############################################################################################################################
function Update-VersionNumber ([string]$filePath, [string]$buildVersion) {
    Write-Host "Updating file: $filePath";
    Write-Host "Updating Version : $buildVersion";
    $assemblyVersionPattern = 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)';
    $fileVersionPattern = 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)';
	$assemblyVersion = 'AssemblyVersion("' + $buildVersion + '")';
    $fileVersion = 'AssemblyFileVersion("' + $buildVersion + '")';
	$nugetVersionPattern = '<NuGetVersion>[0-9]+(\.([0-9]+|\*)){1,3}</NuGetVersion>';
    $nugetVersion = '<NuGetVersion>'+$buildVersion+'</NuGetVersion>';
    $nugetSpecVersionPattern = '<version>[0-9]+(\.([0-9]+|\*)){1,3}</version>';
    $nugetSpecVersion = '<version>'+$buildVersion+'</version>';
    $fileEncoding = Get-FileEncoding $filePath;
    Write-Host "File encoding: $fileEncoding";
    Write-Host "Setting to version(s) $fileVersion, $assemblyVersion, $nugetVersion"
		(Get-Content $filePath) | ForEach-Object  { 
           % {$_ -replace $assemblyVersionPattern, $assemblyVersion } |
           % {$_ -replace $fileVersionPattern, $fileVersion } |
           % {$_ -replace $nugetVersionPattern, $nugetVersion } |
           % {$_ -replace $nugetVersionPattern, $nugetSpecVersion }
        } | Out-File $filePath -encoding $fileEncoding -force
}



function Get-VersionFromPattern ([string]$filePath, [string] $versionIdentifier) {
    $versionPattern = $versionIdentifier + '\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'
	$foundVersionPatterns = Select-String $filePath -pattern $versionPattern
   	foreach ($a in $foundVersionPatterns) {
		if (!$a.Line.StartsWith('//')) {
			$assemblyVersion = $a.Line
		}
	}
    if (-not $assemblyVersion){
        Write-Output ""
        break
    }
    $closeBracketPosition = $assemblyVersion.IndexOf('")')
    $openBracketPosition = $assemblyVersion.IndexOf('("') + 2
    $length = $closeBracketPosition - $openBracketPosition
    $version = $assemblyVersion.Substring($openBracketPosition, $length)
    $version = $version.Replace("*", "0") # change all * to "0"
    Write-Output $version
}

function Update-BuildVersionNumber ([string]$filePath) {
    Write-Host "Updating file: $filePath";
    
    # define the version identifiers to search and update the assembly versions.
    $verionsIdentifiers = @("AssemblyVersion", "AssemblyFileVersion")

    # iterate over the assembly versions identifiers
    foreach ($versionIdentifier in $verionsIdentifiers){

        # get the current file version for that identifier
        $currentFileVersion = Get-VersionFromPattern -filePath $filePath -versionIdentifier $versionIdentifier

        # get the current file version parts into an array
        $versionParts  = $currentFileVersion.Split(".")

        #declare the update version array
        # we will copy the version parts into this array
        # leaving a value of 0 for any indexes not defined in $versionParts
        $updateVersion = @("0", "0", "0", "0")
      
        for ($i = 0; $i -le $versionParts.Length-1; $i++){
            $updateVersion[$i] = $versionParts[$i]
        }

        # update the major version if specified from the command line
        if ($majorVersion){
            $updateVersion[0] = $majorVersion
        }

        # update the minor version if specified from the command line
        if ($minorVersion){
            $updateVersion[1] = $minorVersion
        }

        # update the build version if specified from the command line
        if ($buildVersion){
            $updateVersion[2] = $buildVersion
        }
        
        # update the revision version if specified from the command line
        if ($revisionVersion){
            $updateVersion[3] = $revisionVersion
        }

        # genreate the complete version string
        $newVersion =  [string]::Join(".", $updateVersion)

        # set the replacement string
      	$newVersionReplace = $versionIdentifier + '("' + $newVersion  + '")';

        #set the search pattern string
        $versionPattern = $versionIdentifier + '\("[0-9]+(\.([0-9]+|\*)){1,3}"\)'

        #get the file encoding
        $fileEncoding = Get-FileEncoding $filePath;

        # update the file contents doing the search and replace with the update version
	    Write-Host "==> Setting to version $versionIdentifier from $currentFileVersion => $newVersion"
	    (Get-Content $filePath) | ForEach-Object  { 
            % {$_ -replace $versionPattern, $newVersionReplace } 
        } | Out-File $filePath -encoding $fileEncoding -force
    }

}


##############################################################################################################################
#  Update all found Version Number - Updtaes the version number of an assembly file
##############################################################################################################################
function Update-VersionNumbers ($path) {
	Write-Host "Start updatVersionNumber $build"
	<# Versions for assembly #>
	$files = get-childitem -path $path -filter "AssemblyInfo.cs" -recurse
	foreach ($file in $files) {
	    Update-BuildVersionNumber $file.FullName $build
	}

	<# nuget versions for .nuspec files#>
	$NuSpecFiles = get-childitem -Path $path -filter "*.nuspec" -recurse
	foreach ($file in $NuSpecFiles) {
		  Update-BuildVersionNumber $file.FullName $build
	}
	
}

Update-VersionNumbers -path $path