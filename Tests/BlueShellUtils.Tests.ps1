$PSVersion = $PSVersionTable.PSVersion.Major
$ModuleName = $ENV:BHProjectName
$ModulePath = Join-Path $ENV:BHProjectPath $ModuleName

# Verbose output for non-master builds on appveyor
# Handy for troubleshooting.
# Splat @Verbose against commands as needed (here or in pester tests)
$Verbose = @{}
if($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose") {
    $Verbose.add("Verbose", $True)
}

Import-Module $ModulePath -Force

Describe "BlueShellUtils Module PS$PSVersion" {
    Context 'Strict mode' {

        Set-StrictMode -Version latest

        It 'Should load' {
            $Module = Get-Module $ModuleName
            $Module.Name | Should be $ModuleName
            $Commands = $Module.ExportedCommands.Keys
            $Commands -contains 'Invoke-ProcessHelper' | Should Be $True
            $Commands -contains 'Copy-RemoteItemLocally' | Should Be $True
        }
    }
}

Describe "Invoke-ProcessHelper PS$PSVersion" {
    InModuleScope $ModuleName {
        It 'Should be able to capture the standard output of an executable' {
            $x = Invoke-ProcessHelper -ProcessFileName "$env:windir\System32\TRACERT.EXE" -ProcessArguments @("localhost") -Verbose
            $x.StdOut -like '*Trace complete*' | Should Be $True
        }
    }
}
