<# 
 .Synopsis
  Extracts the content of a zip file to a target folder.

 .Description
  Extracts the content of a zip file to a target folder. For performance reasons, 
  it leverages 7-zip if its found in the path.  Otherwise, it'll use the Expand-Archive,
  the PowerShell built-in CmdLet.  If DestinationPath is not set, it'll create a random
  folder in the temp directory.

 .Parameter Path
  The path to the zip file that will be extracted.

 .Parameter DestinationPath
  The path to the target folder where the extracted files will be saved.

 .Parameter Force
  If specified it'll override existing content of the target folder

 .Example
   # Expands the zipfile to a temporary folder
   Expand-ZipFile "C:\Mydocs\temp.zip" "C:\Mydocs\"
#>
Function Expand-ZipFile() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    [OutputType([String])]
    Param (
        [Parameter(Mandatory=$True, Position=0)]
        [String]
        [ValidateNotNullOrEmpty()]
        $Path,

        [Parameter(Mandatory=$False, Position=1)]
        [String]
        $DestinationPath,
		
        [switch]
        $Force,

        [switch]
        $Clean
    )

    if ($DestinationPath -and !(Test-Path -Path $DestinationPath -PathType Container)) {
        Write-Error "Invalid directory specified: $DestinationPath"
        Return $null
    }

    $TargetPath = $DestinationPath

    if (!$DestinationPath) {
        $folderName = ([char[]]([char]'a'..[char]'z') + 0..9 | Sort-Object {Get-Random})[0..10] -join ''
        $TargetPath = Join-Path $env:TEMP $folderName
        New-Item -ItemType directory -Path $TargetPath | Out-Null
    }

    if ($Clean) {
        if (Test-Path -Path $TargetPath) {
            Write-Verbose "Clearing directory before extracting archive: $TargetPath"
            Remove-Item $TargetPath -Recurse -Force
        }
        New-Item -ItemType directory -Path $TargetPath | Out-Null
    }
    
	
    $sevenZipExe = Get-SevenZipExecutable
    if (!([string]::IsNullOrEmpty($sevenZipExe)) -and (Test-Path($sevenZipExe))) {
        Set-Alias zip $sevenZipExe -Scope 'Script'
        Write-Verbose "Extracting zipfile via 7zip to $TargetPath"
        if ($Force) {
            zip x "-aoa" "-o$TargetPath" "$Path" | Out-Null
        } else {
            zip x "-o$TargetPath" "$Path" | Out-Null
        }
    } else {
        Write-Verbose "Extracting zipfile via PowerShell to $TargetPath"
        Expand-Archive -Path $Path -DestinationPath $TargetPath -Force:$Force.isPresent
    }

    Return $TargetPath
}