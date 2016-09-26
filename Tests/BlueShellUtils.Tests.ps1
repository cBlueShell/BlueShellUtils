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
            $Commands -contains 'Invoke-Batch' | Should Be $True
            $Commands -contains 'Copy-RemoteItemLocally' | Should Be $True
            $Commands -contains 'Get-CredentialBaseName' | Should Be $True
            $Commands -contains 'Get-UserBaseName' | Should Be $True
            $Commands -contains 'Get-JavaProperties' | Should Be $True
            $Commands -contains 'Set-JavaProperties' | Should Be $True
            $Commands -contains 'Expand-ZipFile' | Should Be $True
            $Commands -contains 'Remove-ItemBackground' | Should Be $True
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

Describe "Expand-ZipFile PS$PSVersion" {
    InModuleScope $ModuleName {
        It 'Should extract the content of the zipfile to a target location' {
            $x = Expand-ZipFile -Path "$PSScriptRoot\TestData\testfile.zip" -DestinationPath $env:TEMP -Force -Verbose
            Test-Path("$x\testfile.txt") | Should Be $True
            Remove-Item "$x\testfile.txt" -Force -Confirm:$False
        }

        It 'Should extract the content of the zipfile and clean its target location' {
            $targetDir = Join-Path $env:TEMP "TargetDirTest"
            New-Item $targetDir -ItemType Directory -Force
            Copy-Item "$PSScriptRoot\TestData\testfile.zip" "$targetDir\testfile.zip" -Force -Verbose
            $x = Expand-ZipFile -Path "$PSScriptRoot\TestData\testfile.zip" -DestinationPath $targetDir -Force -Clean -Verbose
            Test-Path("$x\testfile.zip") | Should Be $False
            Test-Path("$x\testfile.txt") | Should Be $True
            Remove-Item "$x\testfile.txt" -Force -Confirm:$False
        }

        It 'Should extract the content of the zipfile to a random temporary location' {
            $x = Expand-ZipFile -Path "$PSScriptRoot\TestData\testfile.zip" -Verbose
            Test-Path("$x\testfile.txt") | Should Be $True
            Remove-Item "$x\testfile.txt" -Force -Confirm:$False
        }

        Mock Get-SevenZipExecutable

        It 'Should be able to extract the content of a zipfile without sevenzip' {
            $x = Expand-ZipFile "$PSScriptRoot\TestData\testfile.zip" -Verbose
            Test-Path("$x\testfile.txt") | Should Be $True
            Remove-Item "$x\testfile.txt" -Force -Confirm:$False
        }
    }
}

Describe "Remove-ItemBackground PS$PSVersion" {
    InModuleScope $ModuleName {
        It 'Should remove a directory and its content in the background' {
            $newDir = Join-Path $env:TEMP "newDir"
            New-Item $newDir -ItemType Directory -Force
            Copy-Item "$PSScriptRoot\TestData\testfile.zip" "$newDir\testfile.zip" -Force -Verbose
            Test-Path("$newDir\testfile.zip") | Should Be $True
            Remove-ItemBackground $newDir
            Test-Path("$newDir\testfile.zip") | Should Be $False
            Test-Path($newDir) | Should Be $False
        }
    }
}