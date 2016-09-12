<# 
 .Synopsis
  Reads a Java-style Properties file and returns a hashtable of its content

 .Description
  Retrieves properties from a java property file and returns them as a hashtable.  It allows specific properties to be retrived, in the case the property file is too large

 .Parameter PropertyFilePath
  The path to the property file that will be parsed.

 .Parameter PropertyList
  If specified, only properties in this list will be retrieved

 .Example
   # Get java properties from a file
   Get-JavaProperties "C:\myprops.properties"
#>
Function Get-JavaProperties() {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding(SupportsShouldProcess=$False)]
    [OutputType([Hashtable])]
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
		$file = Get-Content $PropertyFilePath
		
		foreach($line in $file) {
			if ((!($line.StartsWith('#'))) -and
				(!($line.StartsWith(';'))) -and
				(!($line.StartsWith(";"))) -and
				(!($line.StartsWith('`'))) -and
				(($line.Contains('=')))) {
				$propName=$line.split('=', 2)[0]
                $propValue=$line.split('=', 2)[1]

                if ($PropertyList) {
                    $PropertyList | ForEach-Object {
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