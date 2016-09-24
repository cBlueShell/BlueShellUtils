<# 
 .Synopsis
  Utility function for executing batch jobs using Invoke-Command

 .Description
  Utility function for executing batch jobs using Invoke-Command

 .Parameter BatchFile
  The path to the batch file that will be executed.

 .Parameter Arguments
  The arguments that will be passed to the process if applicable.

 .Parameter WorkingDirectory
  The directory from which to invoke the process. It may be useful for batch files with relative paths.

 .Parameter RunAsCredential
  If specified, it will be passed to the Invoke-Command cmdlet
  
 .Parameter UseNewSession
  If specified, the batch job will be invoked in a new PSSession
  
 .Example
   # Invokes a hello world batch file that echos the first argument
   Invoke-Batch "C:\TEMP\hello.bat" @("Hello World")
#>
Function Invoke-Batch(){
	[CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$True, Position=0)]
        [String]
        [ValidateNotNullOrEmpty()]
        $BatchFile,

        [Parameter(Mandatory=$False, Position=1)]
        [String[]]
        $Arguments,

        [Parameter(Mandatory=$False, Position=2)]
        [String]
        $WorkingDirectory,
        
        [Parameter(Mandatory=$False, Position=3)]
        [PSCredential]
        $RunAsCredential,
        
        [switch]
        $UseNewSession
    )
    $currentLocation = Get-Location
    
   	if (!(Test-Path $batchFile)) {
   		Write-Error ("$batchFile is not recognized as the name of a cmdlet, function, script file, or operable program. Check the spelling of the name, or if a path was included, verify that the path is correct and try again")
   	}
    if ($UseNewSession -and (!($RunAsCredential))) {
        Write-Error "In order to use a new session you need to specify the RunAsCredential"
    }
	Write-Debug ("Invoke-Batch:"+($batchFile + " " + ($arguments  | & {"$input"})))
    
	[PSCustomObject] $returnObject = $null
    
	Try{
		if ($WorkingDirectory -and (Test-Path $WorkingDirectory)) {
	        Set-Location $WorkingDirectory
	    }
		
		[Hashtable] $argList = @{
			"batchFile" = $BatchFile
			"arguments" = $Arguments
		}
		
		$scriptBlock = {
	    	param($argList)
	    	[Int] $exitcode
		    [String] $stdout
		    [String] $stderr
			    	
	    	$console = & $argList.batchFile $argList.arguments
	    	$exitcode = $LASTEXITCODE
		    if ($exitcode -eq 0) {
		       $stdout = $console
		    } else {
		       $stderr = $console
		    }
	    	
	    	return [PSCustomObject] @{
		        StdOut = $stdout
		        StdErr = $stderr
		        ExitCode = $exitcode
		    }
	    }
	    
	    if ($UseNewSession) {
	    	$session = New-PSSession -ComputerName $env:COMPUTERNAME -Credential $RunAsCredential
		    $returnObject = Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $argList
	    } else {
	    	$returnObject = Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $argList
	    }
	} finally {
        # Set location back
        if ($WorkingDirectory -and (Test-Path $WorkingDirectory)) {
            Set-Location $currentLocation
        }
        
        if ($session){
        	Remove-PSSession $session
        }
    }
    
	return $returnObject
}