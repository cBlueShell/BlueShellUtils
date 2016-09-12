##############################################################################################################
# Use-NetworkShare
#   Mounts or Unmounts a file share via "net use" using the specified credentials 
##############################################################################################################
Function Use-NetworkShare {
    [CmdletBinding(SupportsShouldProcess=$False)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
    param (
        [parameter(Mandatory = $true)]
        [string] $SharePath,
        
        [parameter(Mandatory = $false)]
        [PSCredential] $SharePathCredential,
        
        [string] $Ensure = "Present",
        
        [switch] $MapToDrive
    )
    
    [string] $randomDrive = $null

    Write-Verbose -Message "Use-NetworkShare $SharePath ..."

    if ($Ensure -eq "Absent") {
        $cmd = 'net use "' + $SharePath + '" /DELETE'
    } else {
        $credCmdOption = ""
        if ($SharePathCredential) {
            $cred = $SharePathCredential.GetNetworkCredential()
            $pwd = $cred.Password
            $user = $cred.UserName
            if ($cred.Domain) {
                $user = $cred.Domain + "\" + $cred.UserName
            }
            $credCmdOption = " $pwd /user:$user"
        }
        
        if ($MapToDrive) {
            $randomDrive = Get-AvailableDrive
            $cmd = 'net use ' + $randomDrive + ' "' + $SharePath + '"' + $credCmdOption
        } else {
            $cmd = 'net use "' + $SharePath + '"' + $credCmdOption
        }
    }

    Invoke-Expression $cmd | Out-Null
    
    Return $randomDrive
}

##############################################################################################################
# Get-AvailableDrive
#   Get a random Drive letter.
##############################################################################################################
Function Get-AvailableDrive {
    $used   = Get-PSDrive | Select-Object -Expand Name |
          Where-Object { $_.Length -eq 1 }
    $unused = 90..65 | ForEach-Object { [string][char]$_ } |
              Where-Object { $used -notcontains $_ }
    $drive  = $unused[(Get-Random -Minimum 0 -Maximum $unused.Count)]
    return $drive
}