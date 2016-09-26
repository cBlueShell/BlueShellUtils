# Adding Enums directly on PSM1 file, Dot Sourcing, Nesting Modules, Importing hasn't worked.  Maybe try in later PS version.

# Ensure Enum - Used by most DSC Resources
enum Ensure {
    Absent
    Present
}

# Startup Type - Startup Options for Windows Services
enum StartupType {
    Automatic
    Manual
    Disabled
}

#Get public and private function definition files.
$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
Foreach($import in @($Public + $Private)) {
    Try {
        . $import.fullname
    } Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

#Export public functions
Export-ModuleMember -Function $Public.Basename