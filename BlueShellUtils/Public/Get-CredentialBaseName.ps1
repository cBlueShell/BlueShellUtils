<# 
 .Synopsis
  Returns the base part of a username in a credential object. See Get-UserBaseName

 .Description
  Returns the username of a credential object.  If the credential object is a distringuished name the first part of the user object is used
  
 .Parameter UserCredential
  The credential object
#>
Function Get-CredentialBaseName {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param ([parameter(Mandatory)][PSCredential] $UserCredential)
    
    [string] $credBaseName = Get-UserBaseName ($UserCredential.UserName)
    Return $credBaseName
}