<# 
 .Synopsis
  Utility function for executing processes with advance output/error handling options

 .Description
  Utility function for executing processes with advance output/error handling options. This function
  leverages the System.Diagnostics.ProcessStartInfo and System.Diagnostics.Process for invoking an 
  executable/batch file.

 .Parameter ProcessFileName
  The path to the executable that will be invoked.

 .Parameter ProcessArguments
  The arguments that will be passed to the process if applicable.

 .Parameter WorkingDirectory
  The directory from which to invoke the process. It may be useful for batch files with relative paths.

 .Parameter LogToFile
  Determines whether or not the standard output/error should be logged to a file.  Default is to output to console/in-memory.

 .Parameter TempDirectory
  Path to a temporary directory to dump the standard out/err output.  Used when switch LogToFile is specified.

 .Parameter DiscardStandardOut
  If specified, the standard out will not be captured/returned.

 .Parameter DiscardStandardErr
  If specified, the standard err will not be captured/returned.

 .Parameter RunasAdmin
  If specified, the verb runas will be set on the ProcessStartInfo object.
  
 .Example
   # Get the version information of IBM Installation Manager using their command line tool
   Invoke-ProcessHelper "C:\IBM\IIM\eclipse\tools\imcl.exe" @("-version")

 .Example
   # Log the version information of IBM Installation Manager to a temp file
   Invoke-ProcessHelper "C:\IBM\IIM\eclipse\tools\imcl.exe" @("-version") -LogToFile
#>
Function Invoke-ProcessHelper() {
[CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$True, Position=0)]
        [String]
        [ValidateNotNullOrEmpty()]
        $ProcessFileName,

        [Parameter(Mandatory=$False, Position=1)]
        [String[]]
        $ProcessArguments,

        [Parameter(Mandatory=$False, Position=2)]
        [String]
        $WorkingDirectory,

        [Parameter(Mandatory=$False, Position=3)]
        [String]
        $TempDirectory,
		
        [switch]
        $DiscardStandardOut,

        [switch]
        $DiscardStandardErr,
        
        [switch]
        $LogToFile,
        
        [switch]
        $RunasAdmin
    )
	$currentLocation = Get-Location
    #Validate Parameters
    if (!(Test-Path($ProcessFileName) -PathType Leaf)) {
        Write-Error "Parameter ProcessFileName with value=$ProcessFileName could not be found or is not a valid process path"
    }
    #Compose procStartInfo
    $procStartInfo = New-object System.Diagnostics.ProcessStartInfo
    $procStartInfo.FileName = $ProcessFileName
    $procStartInfo.CreateNoWindow = $true
    $procStartInfo.WindowStyle = "Hidden"
    $procStartInfo.UseShellExecute = $false
    
    if (!($LogToFile.isPresent)) {
    	$procStartInfo.RedirectStandardOutput = (!($DiscardStandardOut.IsPresent))
  		$procStartInfo.RedirectStandardError = (!($DiscardStandardErr.IsPresent))
    }

    if ($RunasAdmin.isPresent) {
    	if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
			Write-Verbose("Invoke-ProcessHelper Run as Administrator")
            $procStartInfo.Verb = "runas"
		} else {
			Write-Warning("Current User doesn't have administrator privillages")
		}
    }
    
    #Log handling
    if ($LogToFile.isPresent) {
        $tempDir = (&{if($TempDirectory) {$TempDirectory} else {$env:TEMP}})
	    $tmpLog = Join-Path $tempDir "Invoke-Process-$(get-date -f yyyyMMddHHmmss)-$(Get-Random).tmp"
	    $stdLog = ($tmpLog + ".std")
	    $errLog = ($tmpLog + ".err")
	    $ProcessArguments += @("1> $stdLog","2> $errLog")
    }
    
    if (($null -ne $ProcessArguments) -and ($ProcessArguments.Count -gt 0)) {
        $procStartInfo.Arguments = $ProcessArguments
    }

    if ($WorkingDirectory -and (Test-Path $WorkingDirectory)) {
        Set-Location $WorkingDirectory
        $procStartInfo.WorkingDirectory = $WorkingDirectory
    }

    Write-Verbose ("Invoke-ProcessHelper executing: $WorkingDirectory>$ProcessFileName")

    $exitcode = $null 
    $stdout = $null
    $stderr = $null
    
    Try {
        $process = New-Object System.Diagnostics.Process
        Write-Debug ("procStartInfo:"+($procStartInfo | Out-String))
        $process.StartInfo = $procStartInfo
        $process.Start() | Out-Null
        	
        if (!($LogToFile.isPresent)) {
			if (!($DiscardStandardOut)) {
				$stdout = $process.StandardOutput.ReadToEnd()
			}
			if (!($DiscardStandardErr)) {
				$stderr = $process.StandardError.ReadToEnd()
			}
        }
        
        $process.WaitForExit()
        $exitcode = $process.ExitCode
    } Catch {
	    Write-Error "Invoke-ProcessHelper FAILED $($_.Exception | Out-String)"
    } finally {
        # Set location back
        if ($WorkingDirectory -and (Test-Path $WorkingDirectory)) {
            Set-Location $currentLocation
        }
		if ($LogToFile.isPresent) {
	        if (Test-Path($stdLog)) {
	        	$stdout = Get-Content $stdLog | Out-String
	            Remove-Item $stdLog -Force
	        }
	        
	        if (Test-Path($errLog)) {
	        	$stderr = Get-Content $errLog | Out-String
	            Remove-Item $errLog -Force
	        }
		}
    }
    
    return [PSCustomObject] @{
        PSTypeName = "BlueShell.Process.Info"
        StdOut = $stdout
        StdErr = $stderr
        ExitCode = $exitcode
    }
}