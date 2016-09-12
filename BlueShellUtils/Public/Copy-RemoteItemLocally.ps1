<# 
 .Synopsis
  Copies a remote file/folder to a local destination

 .Description
  Utility function for copying remote files locally.  It leverages windows net use to map a share folder and supports network credentials for mounting the share.

 .Parameter Source
  The path to the file/folder to copy.  It could be a network share or a local file path.

 .Parameter Destination
  The path to the destination folder.  This path should be local to the machine executing the script.  If not specified the item(s) will be copy to the temp folder

 .Parameter SourceCredential
  Used if the source is a network share for authentication.

 .Parameter Directory
  Specifies if the source is a directory or a file

 .Example
   # Copy a remote file
   Copy-RemoteItemLocally "\\otherpc\sharedfolder\myfile.doc" "C:\Mydocs\" (Get-Credential)

   # Copy a remote directory
   Copy-RemoteItemLocally "\\otherpc\sharedfolder\subfolder" "C:\Mydocs\" (Get-Credential) -Directory
#>
function Copy-RemoteItemLocally(){
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$true,position=0)]
        [String] $Source,
        
        [Parameter(Mandatory=$false,position=1)]
        [String] $Destination,
        
        [Parameter(Mandatory=$false,position=2)]
        [PSCredential] $SourceCredential,
        
        [switch] $Directory
    )
	# Get temp file/folder if Destination is not providered    
    if (!$Destination) {
    	$Destination = $env:TEMP
    	if (!$Directory) {
    		$Destination = (Join-Path $Destination -ChildPath (Split-Path -Path $Source -Leaf))
    	}
    }
    
	# Check the flag for networkshare
	$networkShare = $false
    try {
        if (($Source.StartsWith("\\")) -and (!(Test-Path $Source -ErrorAction SilentlyContinue))) {
            $networkShare = $true
        }
    } catch [System.UnauthorizedAccessException] {
        $networkShare = $true
    }
    # Go parent directory path for file copy 
    $sourceDir = $Source
    $destinationDir = $Destination
    if(!$Directory){
    	$sourceDir = (Split-Path($Source))
    	$destinationDir = (Split-Path($destinationDir))
    }
    
    # Mapping networkshare drive
    if($networkShare){
	    Write-Verbose "Network Share detected, need to map"
	    Use-NetworkShare -SharePath $sourceDir -SharePathCredential $SourceCredential -Ensure "Present" | Out-Null
    }
    
    try {
    	if (!$Directory) {
			Write-Verbose ("Copy File $Source $Destination")
			if(!(Test-Path($destinationDir))){
				New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
			}
        	Copy-Item $Source $Destination -Force | Out-Null
        } else {
        	Write-Verbose ("Copy Directory $Source $Destination")
        	if (!(Test-Path($destinationDir))) {
				New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
			}
    		Get-ChildItem $sourceDir | ForEach-Object {
                Copy-Item -Path $_.FullName -Destination  $destinationDir -Force -Container -Recurse | Out-Null
            }
    	}
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Error "An error occurred while copying files: $Source to $Destination \n Error Message: $ErrorMessage"
    } finally {
    	if ($networkShare) {
	        try {
	            Use-NetworkShare -SharePath $sourceDir -SharePathCredential $SourceCredential -Ensure "Absent" | Out-Null
	        } catch {
	            Write-Warning "Unable to disconnect share: $Source"
	        }
    	}
    }
    
    return $Destination
}