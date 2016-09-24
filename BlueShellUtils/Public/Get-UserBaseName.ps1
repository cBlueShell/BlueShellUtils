<# 
 .Synopsis
  Returns the base part of the username given a full username

 .Description
  Returns the base part of the username given a full username.  If its a distringuished name the first part of the user object is used

 .Parameter UserName
  The full username that will be parsed

 .Example
   # Returns myuserid from the fullusername provided
   Get-UserBaseName "LOCALDOMAIN\myuserid"
#>
Function Get-UserBaseName {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param ([parameter(Mandatory)][String]$UserName)
    
    [string] $credBaseName = $UserName
    if ($credBaseName.Contains(",")) {
        $credParts = $credBaseName.Split(",")
        if ($credParts -and ($credParts.Count -gt 0)) {
            $credBaseName = $credParts[0].Substring(($credParts[0].IndexOf('='))+1)
        } else {
            Write-Error "Unable to parse username $credBaseName"
        }
    } elseif ($credBaseName.Contains('\')) {
        $credBaseName = $credBaseName.Substring(($credBaseName.IndexOf('\'))+1)
    }
    Return $credBaseName
}