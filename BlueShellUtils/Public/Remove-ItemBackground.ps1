<# 
 .Synopsis
  Removes an item using a background job

 .Description
  Removes an item using a background job.  This help in the cases where an antivirus might have a lock on an item. 

 .Parameter Path
  The path to the item that will be deleted in the background

 .Example
   # Removes all the items in a temp directory
   Remove-ItemBackground "C:\TEMP\TempDir"
#>
Function Remove-ItemBackground() {
    [CmdletBinding(SupportsShouldProcess=$True,ConfirmImpact="Medium")]
    param (
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,position=0)]
        [string] $Path
    )

    PROCESS {
        if ($PSCmdLet.ShouldProcess($Path)) {
            # Clean up / Workaround for AntiVirus issue - hangs while deleting files
            Write-Verbose "Attempting to remove item, after 1 minute the job will timeout and you may need to delete $Path directory manually."
            $rmjob = Start-Job {
                param($tdir)
                Remove-Item $tdir -Recurse -Force -ErrorAction SilentlyContinue 
            } -ArgumentList $Path

            # Set background job options
            Wait-Job $rmjob -Timeout 60 | Out-Null
            Stop-Job $rmjob | Out-Null
            Receive-Job $rmjob | Out-Null
            Remove-Job $rmjob | Out-Null
        }
    }
}