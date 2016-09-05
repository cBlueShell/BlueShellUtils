##############################################################################################################
########                                 Blue Shell Utility Module                                   #########
##############################################################################################################

$BS_PSDSC_SEQ_DEBUG = "BLUESHELL_PSDSC_SEQ_DEBUG"

##############################################################################################################
# Get-SevenZipExecutable
#   Gets the path to the 7-zip executable if present, otherwise returns null
##############################################################################################################
Function Get-SevenZipExecutable {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param()
    
	$sevenZipExe = $null
	if (Test-Path("HKLM:\Software\7-Zip")) {
		$sevenZipExe = (Get-ItemProperty -Path "HKLM:\SOFTWARE\7-Zip").Path + "7z.exe"
	} else {
		if (Test-Path("HKCU:\Software\7-Zip")) {
			$sevenZipExe = (Get-ItemProperty -Path "HKCU:\SOFTWARE\7-Zip").Path + "7z.exe"
		}
	}
	return $sevenZipExe
}

##############################################################################################################
# Invoke-ProcessHelper
#   Process utility method that provides error handling, output buffering, etc
##############################################################################################################
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
    if(!($LogToFile.isPresent)){
    	$procStartInfo.RedirectStandardOutput = (!($DiscardStandardOut.IsPresent))
  		$procStartInfo.RedirectStandardError = (!($DiscardStandardErr.IsPresent))
    }

    if($RunasAdmin.isPresent){
    	if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")){   
			Write-Verbose("Invoke-ProcessHelper Run as Administrator")
            $procStartInfo.Verb = "runas"
		}else{
			Write-Warning("Current User doesn't have administrator privillages")
		}
		    	
    }
    
    #Log handling
    if($LogToFile.isPresent){
        $tempDir = (&{if($TempDirectory) {$TempDirectory} else {$env:TEMP}})
	    $tmpLog = Join-Path $tempDir "Invoke-Process-$(get-date -f yyyyMMddHHmmss)-$(Get-Random).tmp"
	    $stdLog = ($tmpLog + ".std")
	    $errLog = ($tmpLog + ".err")
	    $ProcessArguments += @("1> $stdLog","2> $errLog")
    }
    
    if (($ProcessArguments -ne $null) -and ($ProcessArguments.Count -gt 0)) {
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
        	
        if(!($LogToFile.isPresent)){
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
		if($LogToFile.isPresent){
	        if(Test-Path($stdLog)){
	        	$stdout = Get-Content $stdLog | Out-String
	            Remove-Item $stdLog -Force
	        }
	        
	        if(Test-Path($errLog)){
	        	$stderr = Get-Content $errLog | Out-String
	            Remove-Item $errLog -Force
	        }
		}
    }
    
    return [PSCustomObject] @{
        StdOut = $stdout
        StdErr = $stderr
        ExitCode = $exitcode
    }
}

##############################################################################################################
# Get-CredentialBaseName
#   Returns the username of a credential object.  If the credential object is a distringuished name the first
#   part of the user object is used
##############################################################################################################
Function Get-CredentialBaseName {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param ([parameter(Mandatory)][PSCredential] $UserCredential)
    
    [string] $credBaseName = Get-UserBaseName ($UserCredential.UserName)
    Return $credBaseName
}

##############################################################################################################
# Get-UserBaseName
#   Returns the base part of the username given a full username.  If its a distringuished name the first part
#   of the user object is used
##############################################################################################################
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

##############################################################################################################
# Set-NetUse
#   Mounts or Unmounts a file share via "net use" using the specified credentials 
##############################################################################################################
Function Set-NetUse {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (   
        [parameter(Mandatory = $true)]
        [string] $SharePath,
        
        [parameter(Mandatory = $false)]
        [PSCredential] $SharePathCredential,
        
        [string] $Ensure = "Present",
        
        [switch] $MapToDrive
    )
    
    [string] $randomDrive = $null

    Write-Verbose -Message "NetUse set share $SharePath ..."

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

##############################################################################################################
# Set-JavaProperties
#   Updates a java property file based on the provided hashtable.  It allows to either append new Properties
#   or only modify existing ones.
##############################################################################################################
Function Set-JavaProperties() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory=$true,position=0)]
        [String]
        $PropertyFilePath,

        [parameter(Mandatory=$true,position=1)]
        [Hashtable]
        $Properties,

        [switch]
        $DoNotAppend
    )

	[string] $finalFile = ""
    [string[]] $updatedProps = @()
	
	if (Test-Path $PropertyFilePath) {
		$file = gc $PropertyFilePath
		
		foreach($line in $file) {
			if ((!($line.StartsWith('#'))) -and
				(!($line.StartsWith(';'))) -and
				(!($line.StartsWith(";"))) -and
				(!($line.StartsWith('`'))) -and
				(($line.Contains('=')))) {
				$property=$line.split('=')[0]

                $Properties.Keys | % {
                    $propValue = $Properties.Item($_)
                    if ($_ -eq $property)
                    {
					    Write-Debug "Updated property: $_=$propValue"
					    $line = "$_=$propValue"
                        $updatedProps += $_
				    }
                }
			}
            if ([string]::IsNullOrEmpty($line)) {
                $finalFile += "$line"
            } else {
                $finalFile += "$line`n"
            }
		}
        if (!($DoNotAppend)) {
            # Properties that were not updated will be added to the end of the file
            $Properties.Keys | % {
                if (!($updatedProps.Contains($_))) {
                    $propValue = $Properties.Item($_)
                    Write-Debug "New property: $_=$propValue"
                    $line = "$_=$propValue"
                    $finalFile += "$line`n"
                }
            }
        }
		$finalFile | out-file "$PropertyFilePath" -encoding "ASCII"
	} else {
		Write-Error "Java Property file: $PropertyFilePath not found"
	}
}

##############################################################################################################
# Get-JavaProperties
#   Reads a Java-style Properties file and returns a hashtable of its content (excludes comments) 
##############################################################################################################
Function Get-JavaProperties() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory=$true,position=0)]
        [string]
        $PropertyFilePath,

        [parameter(Mandatory=$false,position=1)]
        [string[]]
        $PropertyList
    )

    [hashtable] $props = @{}
	
	if (Test-Path $PropertyFilePath) {
		$file = gc $PropertyFilePath
		
		foreach($line in $file) {
			if ((!($line.StartsWith('#'))) -and
				(!($line.StartsWith(';'))) -and
				(!($line.StartsWith(";"))) -and
				(!($line.StartsWith('`'))) -and
				(($line.Contains('=')))) {
				$propName=$line.split('=', 2)[0]
                $propValue=$line.split('=', 2)[1]

                if ($PropertyList) {
                    $PropertyList | % {
                        if ($_ -eq $propName){
                            $props.Add($propName, $propValue)
				        }
                    }
                } else {
                    $props.Add($propName, $propValue)
                }
			}
		}
	} else {
		Write-Error "Java Property file: $PropertyFilePath not found"
	}

    Return $props
}

##############################################################################################################
# Invoke-Batch
#   Process utility method that provides error handling, output buffering, etc
##############################################################################################################
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

##############################################################################################################
# Enable-BlueShellPSDscSequenceDebug
#   Switch for Debuging BlueShell DSC module sequence, when enabled, all the BlueShell DSC tests returns true
##############################################################################################################
function Enable-BlueShellPSDscSequenceDebug([Bool] $Enable){
    if ($Enable) {
        Write-Warning "Enable BlueShell PowerShell Dsc Sequence Debugging, skip all BlueShell DSC config."
    } else {
        Write-Warning "Disable BlueShell PowerShell Dsc Sequence Debugging, All BlueShell DSC config will be effected."
    }
    
    [Environment]::SetEnvironmentVariable($BS_PSDSC_SEQ_DEBUG, $Enable, "Machine");
}

##############################################################################################################
# Test-BlueShellPSDscSequenceDebug
#   Return $True if current BlueShell DSC sequence is in debug mode 
##############################################################################################################
function Test-BlueShellPSDscSequenceDebug(){
    $isDebug = $false
    $debugFlag = [Environment]::GetEnvironmentVariable($BS_PSDSC_SEQ_DEBUG)
    if ($debugFlag -and ($debugFlag -eq "true")) {
        $isDebug = $True
    }
    return $isDebug
}

##############################################################################################################
# Copy-RemoteItemLocal
#   Copy file/folder from local path or networkshared path  
##############################################################################################################
function Copy-RemoteItemLocal(){
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
	    Set-NetUse -SharePath $sourceDir -SharePathCredential $SourceCredential -Ensure "Present" | Out-Null
    }
    
    try {
    	if( !$Directory ){
			Write-Verbose ("Copy File $Source $Destination")
			if(!(Test-Path($destinationDir))){
				New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
			}
        	Copy-Item $Source $Destination -Force | Out-Null
        } else {
        	Write-Verbose ("Copy Directory $Source $Destination")
        	if(!(Test-Path($destinationDir))){
				New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
			}
    		Get-ChildItem $sourceDir | % {Copy-Item -Path $_.FullName -Destination  $destinationDir -Force -Container -Recurse | Out-Null}
    	}
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Error "An error occurred while copying files: $Source to $Destination \n Error Message: $ErrorMessage"
    } finally {
    	if($networkShare){
	        try {
	            Set-NetUse -SharePath $sourceDir -SharePathCredential $SourceCredential -Ensure "Absent" | Out-Null
	        } catch {
	            Write-Warning "Unable to disconnect share: $Source"
	        }
    	}
    }
    
    return $Destination
}