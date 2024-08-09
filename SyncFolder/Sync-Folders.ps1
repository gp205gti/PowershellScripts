#Requires -Version 3.0

<#
.SYNOPSIS
    Synchronizes files and directories between a source and replica directory.

.DESCRIPTION
    This script synchronizes files and directories between a source directory and a replica directory. It copies
    new and updated files from the source to the replica, and removes files from the replica that are not present
    in the source. It also removes empty directories from the replica.

.PARAMETER Source
    Specifies the path of the source directory.

.PARAMETER Replica
    Specifies the path of the replica directory.

.PARAMETER LogFile
    Specifies the path of the log file to record synchronization actions.

.PARAMETER ShowVerbose
    Specifies whether to show verbose messages. Default is $true.

.NOTES
    - This script requires PowerShell version 3.0 or later.
    - The log file directory will be created if it does not exist.
    - If the source directory does not exist, an error will be logged and the script will exit with a failure code.
    - If the replica directory does not exist, it will be created. If the creation fails, an error will be logged
        and the script will exit with a failure code.
    - Files in the source directory that are newer than their corresponding files in the replica directory
        will be copied to the replica.
    - Files in the replica directory that are not present in the source directory will be removed.
    - Empty directories in the replica directory will be removed.

    Author: Peter Gondola
    Version: 1.0
    Date: 08/08/2024

.EXAMPLE
    Sync-Folders -Source "C:\Source" -Replica "D:\Replica" -LogFile "C:\Logs\SyncLog.txt"

    This example synchronizes the files and directories between the
    "C:\Source" directory and the "D:\Replica" directory.
    The synchronization actions will be logged to the "C:\Logs\SyncLog.txt" file. And the script will
    output verbose messages.

#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [Parameter(Mandatory = $true)]
    [string]$Replica,
    [Parameter(Mandatory = $true)]
    [string]$LogFile,
    [bool]$ShowVerbose = $true
)

#region Initialization area

# Set the VerbosePreference based on the ShowVerbose parameter
if ($ShowVerbose) {
    $VerbosePreference = 'Continue'
} else {
    $VerbosePreference = 'SilentlyContinue'
}

# Initialize counters for the number of items copied, removed, and failed
$sourceItemCopied = 0
$replicaItemRemoved = 0
$itemFailure = 0

<#
.SYNOPSIS
Writes a log message to a specified log file.

.DESCRIPTION
The Write-Log function is used to write log messages to a log file. It accepts a message, log level,
and log file path as parameters.

.PARAMETER Message
The log message to be written.

.PARAMETER Level
The log level of the message. Valid values are 'INFO', 'WARNING', and 'ERROR'. The default value is 'INFO'.

.PARAMETER Path
The path of the log file.

.EXAMPLE
Write-Log -Message "This is an informational message" -Level INFO

This example writes an informational message to the default log file.

.EXAMPLE
Write-Log -Message "This is a warning message" -Level WARNING -Path "C:\Logs\log.txt"

This example writes a warning message to a specific log file.

#>
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('INFO' ,'WARNING' ,'ERROR')]
        [string] $Level = 'INFO',
        [string] $Path = $LogFile
    )

    $message = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level]: $Message"
    Write-Verbose $Message
    $Message | Out-File -FilePath $Path -Append
}

# Ensure the log file directory exists
if (-not(Test-Path -Path $LogFile)) {
    try {
        New-Item -ItemType File -Force -Path $LogFile -ErrorAction Stop | Out-Null
        $message = "Create file $LogFile"
        Write-Log -Message $message -Level 'INFO'
    } catch {
        Write-Error "Failed to create log file directory $LogFile Error: $_"
        exit 1
    }
}

# Ensure the source directory exists
if (!(Test-Path -Path $Source -PathType Container)) {
    $message = "Source directory $Source does not exist"
    Write-Error $message
    Write-Log -Message $message -Level 'ERROR'
    exit 1
}

# Ensure the replica directory exists
if (-not(Test-Path -Path $Replica -PathType Container)) {
    try{
        New-Item -ItemType Directory -Force -Path $Replica -ErrorAction Stop | Out-Null
        $message = "Create directory $Replica"
        Write-Log -Message $message -Level 'INFO'
    } catch {
        $message = "Create directory $Replica failed ! Error: $_"
        Write-Error $message
        Write-Log -Message $message -Level 'ERROR'
        $itemFailure++
        exit 1
    }

}
#endregion


#region Main Script

# Get the files in the source and replica directories
$sourceFiles = Get-ChildItem -Path $Source -Recurse -File
$replicaFiles = Get-ChildItem -Path $Replica -Recurse -File

# Copy new and updated files to the replica
foreach ($file in $sourceFiles) {
    $replicaFile = $file.FullName.Replace($source, $replica)
    $destinationDir = Split-Path -Path $replicaFile -Parent
    if (!(Test-Path -Path $destinationDir)) {
        try {
            New-Item -ItemType Directory -Force -Path $destinationDir -ErrorAction Stop | Out-Null
            $message = "Created directory $destinationDir"
            Write-Log -Message $message -Level 'INFO'
            $sourceItemCopied++
        }
        catch {
            $message = "Failed to create directory $destinationDir Error: $_"
            Write-Error $message
            Write-Log -Message $message -Level 'ERROR'
            $itemFailure++
            continue
        }

    }
    if (!(Test-Path -Path $replicaFile) -or ($file.LastWriteTime -gt (Get-Item -Path $replicaFile).LastWriteTime)) {
        try {
            Copy-Item -Path $file.FullName -Destination $replicaFile -Force
            $message = "Copied $($file.FullName) to $($replicaFile)"
            Write-Log -Message $message -Level 'INFO'
            $sourceItemCopied++
        }
        catch {
            $message = "Failed to copy $($file.FullName) to $($replicaFile) Error: $_"
            Write-Error $message
            Write-Log -Message $message -Level 'ERROR'
            $itemFailure++
            continue
        }
    }
}

# Remove files from the replica that are not in the source
foreach ($file in $replicaFiles) {
    $sourceFile = $file.FullName.Replace($Replica, $Source)
    if (-not (Test-Path -Path $sourceFile)) {

        try {
            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            $message = "Removed $($file.FullName)"
            Write-Log -Message $message -Level 'INFO'
            $replicaItemRemoved++
        }
        catch {
            $message = "Failed to remove $($file.FullName) Error: $_"
            Write-Error $message
            Write-Log -Message $message -Level 'ERROR'
            $itemFailure++
            continue
        }
    }
}

# Get the directories in and replica
$replicaDirs = Get-ChildItem -Path $replica -Recurse -Directory

# Sort the directories by depth in descending order
$replicaDirs = $replicaDirs | Sort-Object { $_.FullName.Split('\').Count } -Descending

# Remove empty directories from the replica
foreach ($dir in $replicaDirs) {
    $sourceDir = $dir.FullName.Replace($replica, $source)
    if (-not(Test-Path -Path $sourceDir)) {
        # Check if the directory is empty, including hidden files and empty directories
        $items = Get-ChildItem -Path $dir.FullName -Force -Directory
        if ($items.Count -eq 0) {
            try {
                Remove-Item -Path $dir.FullName -Force -Recurse -ErrorAction Stop
                $message = "Removed directory $($dir.FullName)"
                Write-Log -Message $message -Level 'INFO'
                $replicaItemRemoved++
            }
            catch {
                $message = "Failed to remove directory $($dir.FullName) Error: $_"
                Write-Error $message
                Write-Log -Message $message -Level 'ERROR'
                $actionItemFailure
                $itemFailure++
                continue
            }
        }
    }
}

if ($sourceItemCopied -eq 0 -and $replicaItemRemoved -eq 0 -and $itemFailure -eq 0) {
    $message = "No changes detected between $Source and $Replica"
    Write-Log -Message $message -Level 'INFO'
}
#endregion

# Return the results
return [PSCustomObject]@{
    SourceItemCopied = $sourceItemCopied
    ReplicaItemRemoved = $replicaItemRemoved
    ItemFailure = $itemFailure
    ReturnCode = if($itemFailure) {1} else {0}
}
