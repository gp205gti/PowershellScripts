<#
.SYNOPSIS
Writes a log message to a specified log file.

.DESCRIPTION
The Write-SfLog function writes a log message to a specified log file. It includes the message, timestamp,
and log level.

.PARAMETER Message
The log message to be written.

.PARAMETER Level
The log level of the message. Valid values are 'INFO', 'WARNING', and 'ERROR'. The default value is 'INFO'.

.PARAMETER Path
The path of the log file. If not specified, the default log file path will be used.

.EXAMPLE
Write-SfLog -Message "This is an informational message" -Level "INFO" -Path "C:\Logs\log.txt"
Writes an informational message to the specified log file with the log level set to 'INFO'.

.EXAMPLE
Write-SfLog -Message "This is a warning message" -Level "WARNING"
Writes a warning message to the default log file with the log level set to 'WARNING'.

#>
function Write-SfLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('INFO' , 'WARNING' , 'ERROR')]
        [string] $Level = 'INFO',
        [string] $LogFile
    )

    $message = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level]: $Message"
    Write-Verbose $Message
    $Message | Out-File -FilePath $LogFile -Append
}


<#
.SYNOPSIS
    Removes an item with retry logic.

.DESCRIPTION
    The Remove-SfItemWithRetry function removes an item specified by the ItemToRemove parameter. It provides
    retry logic in case of failures, allowing multiple attempts to remove the item. It also supports logging
    and throwing exceptions on failure.

.PARAMETER ItemToRemove
    Specifies the path of the item to be removed.

.PARAMETER Retries
    Specifies the number of retry attempts. The default value is 3.

.PARAMETER ThrowOnFailure
    Specifies whether to throw an exception on failure. The default value is $true.

.PARAMETER LogFile
    Specifies the path of the log file for logging messages.

.EXAMPLE
    Remove-SfItemWithRetry -ItemToRemove "C:\Temp\File.txt" -Retries 5 -ThrowOnFailure $false -LogFile "C:\Temp\Logs\RemoveItem.log"
    This example removes the file "C:\Temp\File.txt" with 5 retry attempts. It does not throw
    an exception on failure and logs messages to the file "C:\Temp\Logs\RemoveItem.log".

.NOTES
    Author: Your Name
    Date:   Current Date
#>
function Remove-SfItemWithRetry {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string] $ItemToRemove,
        [int]$Retries = 3,
        [bool] $ThrowOnFailure = $true,
        [string]$LogFile
    )

    if (-not(Test-Path $ItemToRemove)) {
        $message = "Path `"$ItemToRemove`" does not exist."
        Write-SfLog -Message $message -LogFile $LogFile
        return
    }

    $counter = 1
    do {
        try {
            $item = Get-Item -Path $ItemToRemove -ErrorAction SilentlyContinue
            if (-not $item) {
                break
            }
            else {
                if ($PSCmdlet.ShouldProcess($ItemToRemove, "Remove item")) {
                    Remove-Item -Path $ItemToRemove -Force -ErrorAction Stop | Out-Null
                }
            }
            break
        }
        catch [Exception] {
            if ($counter -ge $Retries) {
                if ($ThrowOnFailure) {
                    Write-SfLog -Message "$ItemToRemove cannot be removed Error: $_" -Level 'Error' `
                        -LogFile $LogFile
                    throw $_.Exception.Message
                }
                Write-SfLog -Message "$ItemToRemove cannot be removed, exception is suppressed." -Level 'Error' `
                    -LogFile $LogFile
                return 1
            }
            Start-Sleep -Seconds 1
            Write-SfLog " Could not remove `"$($ItemToRemove)`" folder. Error: $($_.Exception.Message)" `
                -LogFile $LogFile
            Write-SfLog " Beginning retry attempt $counter of $Retries" -LogFile $LogFile
        }
        $counter++
    } while ($counter -le $Retries)

    return 0
}
