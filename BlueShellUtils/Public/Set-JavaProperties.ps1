<# 
 .Synopsis
  Updates a java property file based on the provided hashtable

 .Description
  Updates a java property file based on the provided hashtable.  It allows to either append new Properties or only modify existing ones.

 .Parameter PropertyFilePath
  The path to the property file that will be modified.

 .Parameter Properties
  Hashtable containing the properties to set

 .Parameter DoNotAppend
  Specifies if new properties should be appended

 .Example
   # Add new properties to a file
   Set-JavaProperties "C:\myprops.properties" @{"newProp1":"newValue1"}
#>
Function Set-JavaProperties() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
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
		$file = Get-Content $PropertyFilePath
		
		foreach($line in $file) {
			if ((!($line.StartsWith('#'))) -and
				(!($line.StartsWith(';'))) -and
				(!($line.StartsWith(";"))) -and
				(!($line.StartsWith('`'))) -and
				(($line.Contains('=')))) {
				$property=$line.split('=')[0]

                $Properties.Keys | ForEach-Object {
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
            $Properties.Keys | ForEach-Object {
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