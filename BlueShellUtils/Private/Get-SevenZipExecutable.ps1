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