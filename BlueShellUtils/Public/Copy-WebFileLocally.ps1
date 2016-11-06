<# 
 .Synopsis
  Copies a file from a website to a local destination

 .Description
  Utility function for copying files from URLs locally.

 .Parameter SourceURL
  The URL to the file to copy.

 .Parameter Destination
  The path to the destination folder.  This path should be local to the machine executing the script.  If not specified the item(s) will be copy to the temp folder

 .Example
   # Copy a remote file
   Copy-WebFileLocally "http:\\mywebsite.co\myfile.doc" "C:\Mydocs\"
#>
function Copy-WebFileLocally() { 
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$true,position=0)]
        [System.Uri] $SourceURL,
        
        [Parameter(Mandatory=$false,position=1)]
        [String] $Destination
    )
    [string] $RetDest = $Destination
	# Get temp file/folder if Destination is not providered
    if (!$Destination) {
    	$RetDest = $env:TEMP
    }
    
    try {
        $start_time = Get-Date
        Write-Verbose ("Downloading File $SourceURL To $RetDest")
        if(!(Test-Path($RetDest))){
            New-Item -ItemType Directory -Force -Path $RetDest | Out-Null
        }
        if (Test-Path $RetDest -PathType Container) {
            if ($SourceURL.Segments.Count -gt 1) {
                $RetDest = Join-Path $RetDest $SourceURL.Segments[$SourceURL.Segments.Count-1]
            } else {
                $RetDest = Join-Path $RetDest "DownloadedFile$(Get-Date -f yyyyMMddHHmmss)"
            }
        }
        
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($SourceURL, $RetDest)
        Write-Verbose "File downloaded in: $((Get-Date).Subtract($start_time).Seconds) second(s)"
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Error "An error occurred while downloading file: $SourceURL to $RetDest \n Error Message: $ErrorMessage"
    }

    return $RetDest
}