#Requires -Version 5.0 -RunAsAdministrator

<#
.SYNOPSIS
    This script synchronizes two directories by copying new and updated files from the source directory to the
     replica directory, and removing files from the replica directory that are not present in the source directory.

.DESCRIPTION
    The Sync-Folders.ps1 script takes the following parameters:
    - Source: The path to the source directory.
    - Replica: The path to the replica directory.
    - LogFile: The path to the log file.
    - ShowVerbose: Specifies whether to display verbose output. Default is $true.
    - RemovalRetries: The number of retries when removing files from the replica directory. Default is 3.
    - RemoveFailureThrow: Specifies whether to throw an error if removing a file from the replica directory fails.
        Default is $true.
    - WhatIfRemoval: Specifies whether to simulate the removal of files from the replica directory.
        Default is $false.

.PARAMETER Source
    Specifies the path to the source directory.

.PARAMETER Replica
    Specifies the path to the replica directory.

.PARAMETER LogFile
    Specifies the path to the log file.

.PARAMETER ShowVerbose
    Specifies whether to display verbose output. Default is $true.

.PARAMETER RemovalRetries
    Specifies the number of retries when removing files from the replica directory. Default is 3.

.PARAMETER RemoveFailureThrow
    Specifies whether to throw an error if removing a file from the replica directory fails. Default is $true.

.PARAMETER WhatIfRemoval
    Specifies whether to simulate the removal of files from the replica directory. Default is $false.

.EXAMPLE
    Sync-Folders -Source "C:\Source" -Replica "D:\Replica" -LogFile "C:\Logs\SyncLog.txt"

    This example synchronizes the "C:\Source" directory with the "D:\Replica" directory and logs the
    synchronization process to "C:\Logs\SyncLog.txt".

.NOTES
    - This script requires PowerShell version 3.0 or later.
    - The script uses the Support.Functions module to import supporting functions if needed.
    - The script ensures that the log file directory, source directory, and replica directory exist before
    proceeding with the synchronization process.
    - The script copies empty directories from the source directory to the replica directory.
    - The script copies new and updated files from the source directory to the replica directory.
    - The script removes files from the replica directory that are not present in the source directory.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [Parameter(Mandatory = $true)]
    [string]$Replica,
    [Parameter(Mandatory = $true)]
    [string]$LogFile,
    [bool]$ShowVerbose = $true,
    [int] $RemovalRetries = 3,
    [bool]$RemoveFailureThrow = $true,
    [bool]$WhatIfRemoval = $false
)

#region Initialization area

# Initialize counters for the number of items copied, removed, and failed
$sourceItemCopied = 0
$sourceFolderCopied = 0
$replicaItemRemoved = 0
$itemFailure = 0

# Import supporting functions if needed
$ModuleName = 'Support.Functions'
# if (-not(Get-Module -Name $ModuleName)){
$ModulePath = Join-Path $PSScriptRoot -ChildPath "$ModuleName\$ModuleName.psd1"
$ModulePath | Import-Module -Verbose:$ShowVerbose
# }

# Ensure the log file directory exists
if (-not(Test-Path -Path $LogFile)) {
    try {
        New-Item -ItemType File -Force -Path $LogFile -ErrorAction Stop | Out-Null
        $message = "Create file $LogFile"
        Write-SfLog -Message $message -LogFile $LogFile -Verbose:$ShowVerbose
    }
    catch {
        Write-Error "Failed to create log file directory $LogFile Error: $_"
        exit 1
    }
}

# Ensure the source directory exists
if (-not(Test-Path -Path $Source -PathType Container)) {
    $message = "Source directory $Source does not exist"
    Write-Error $message
    Write-SfLog -Message $message -Level 'ERROR' -LogFile $LogFile -Verbose:$ShowVerbose
    exit 1
}

# Ensure the replica directory exists
if (-not(Test-Path -Path $Replica -PathType Container)) {
    try {
        New-Item -ItemType Directory -Force -Path $Replica -ErrorAction Stop | Out-Null
        $message = "Create directory $Replica"
        Write-SfLog -Message $message -LogFile $LogFile -Verbose:$ShowVerbose
    }
    catch {
        $message = "Create directory $Replica failed ! Error: $_"
        Write-Error $message
        Write-SfLog -Message $message -Level 'ERROR' -LogFile $LogFile -Verbose:$ShowVerbose
        $itemFailure++
        exit 1
    }

}
#endregion

#region Main Script

# Get the files in the source and replica directories
$sourceFiles = Get-ChildItem -Path $Source -Recurse -File
$replicaFiles = Get-ChildItem -Path $Replica -Recurse -File

# Copy of empty directories in the source to the replica
$sourceDirs = Get-ChildItem -Path $Source -Recurse -Directory

foreach ($dir in $sourceDirs) {
    $replicaDir = $dir.FullName.Replace($Source, $Replica)
    if (-not(Test-Path -Path $replicaDir)) {
        try {
            # New-Item -ItemType Directory -Force -Path $replicaDir -ErrorAction Stop | Out-Null
            Copy-Item -Path "$($dir.Fullname)" -Destination "$replicaDir" -Force | Out-Null
            $message = "Copied directory $replicaDir"
            Write-SfLog -Message $message -LogFile $LogFile -Verbose:$ShowVerbose
            $sourceFolderCopied++
        }
        catch {
            $message = "Failed to create directory $replicaDir Error: $_"
            Write-Error $message
            Write-SfLog -Message $message -Level 'ERROR' -LogFile $LogFile -Verbose:$ShowVerbose
            $itemFailure++
            continue
        }
    }
}

# Copy new and updated files to the replica
foreach ($file in $sourceFiles) {
    $replicaFile = $file.FullName.Replace($source, $replica)
    $destinationDir = Split-Path -Path $replicaFile -Parent

    # Create the destination directory if it does not exist
    if (-not(Test-Path -Path $destinationDir)) {
        try {
            New-Item -ItemType Directory -Force -Path $destinationDir -ErrorAction Stop | Out-Null
            $message = "Created directory $destinationDir"
            Write-SfLog -Message $message -LogFile $LogFile -Verbose:$ShowVerbose
            $sourceItemCopied++
        }
        catch {
            $message = "Failed to create directory $destinationDir Error: $_"
            Write-Error $message
            Write-SfLog -Message $message -Level 'ERROR' -LogFile $LogFile -Verbose:$ShowVerbose
            $itemFailure++
            continue
        }

    }

    # Copy the file if it does not exist in the replica or if it is newer than the replica file
    if (-not(Test-Path -Path $replicaFile) -or ($file.LastWriteTime -gt
        (Get-Item -Path $replicaFile).LastWriteTime)) {
        try {
            Copy-Item -Path $file.FullName -Destination $replicaFile -Force
            $message = "Copied $($file.FullName) to $($replicaFile)"
            Write-SfLog -Message $message -LogFile $LogFile -Verbose:$ShowVerbose
            $sourceItemCopied++
        }
        catch {
            $message = "Failed to copy $($file.FullName) to $($replicaFile) Error: $_"
            Write-Error $message
            Write-SfLog -Message $message -Level 'ERROR' -Verbose:$ShowVerbose
            $itemFailure++
            continue
        }
    }
}

# Remove files from the replica that are not in the source
foreach ($file in $replicaFiles) {
    $sourceFile = $file.FullName.Replace($Replica, $Source)

    # Check if the file is not in the source directory
    if (-not (Test-Path -Path $sourceFile)) {

        try {
            $removalParams = @{
                ItemToRemove   = $file.FullName
                Retries        = $RemovalRetries
                ThrowOnFailure = $RemoveFailureThrow
                LogFile        = $LogFile
                WhatIf         = $WhatIfRemoval
            }
            $removal = Remove-SfItemWithRetry @removalParams
            $message = "Removed $($file.FullName) [WhatIf]: $WhatIfRemoval"
            Write-SfLog -Message $message -LogFile $LogFile -Verbose:$ShowVerbose

            if ($removal -eq 0 -and $WhatIfRemoval -eq $false) {
                $replicaItemRemoved++
            }
        }
        catch {
            $message = "Failed to remove $($file.FullName) Error: $_"
            Write-Error $message
            Write-SfLog -Message $message -Level 'ERROR' -LogFile $LogFile -Verbose:$ShowVerbose
            $itemFailure++
            continue
        }
    }
}

# Get the directories in and replica
$replicaDirs = Get-ChildItem -Path $replica -Recurse -Directory

# Sort the directories by depth in descending order
$replicaDirs = $replicaDirs | Sort-Object { $_.FullName.Split('\').Count } -Descending

# Remove empty directories not in source from the replica
foreach ($dir in $replicaDirs) {
    $sourceDir = $dir.FullName.Replace($replica, $source)
    if (-not(Test-Path -Path $sourceDir)) {
        # Check if the directory is empty, including hidden files and empty directories
        $items = Get-ChildItem -Path $dir.FullName -Force -Directory

        # If the directory is empty, remove it
        if ($items.Count -eq 0) {
            try {
                $removalParams = @{
                    ItemToRemove   = $dir.FullName
                    Retries        = $RemovalRetries
                    ThrowOnFailure = $RemoveFailureThrow
                    LogFile        = $LogFile
                    WhatIf         = $WhatIfRemoval
                }
                $removal = Remove-SfItemWithRetry @removalParams
                $message = "Removed directory $($dir.FullName) [WhatIf]: $WhatIfRemoval"
                Write-SfLog -Message $message -LogFile $LogFile -Verbose:$ShowVerbose

                if ($removal -eq 0 -and $WhatIfRemoval -eq $false) {
                    $replicaItemRemoved++
                }
            }
            catch {
                $message = "Failed to remove directory $($dir.FullName) Error: $_"
                Write-Error $message
                Write-SfLog -Message $message -Level 'ERROR' -LogFile $LogFile -Verbose:$ShowVerbose
                $actionItemFailure
                $itemFailure++
                continue
            }
        }
    }
}

# Check if replica and source have same number of files,folders and size
$sourceFiles = Get-ChildItem -Path $Source -Recurse -File
$replicaFiles = Get-ChildItem -Path $Replica -Recurse -File

$sourceFilesCount = $sourceFiles.Count
$replicaFilesCount = $replicaFiles.Count

$sourceFilesSize = ($sourceFiles | Measure-Object -Property Length -Sum).Sum
$replicaFilesSize = ($replicaFiles | Measure-Object -Property Length -Sum).Sum

$sourceDirsCount = (Get-ChildItem -Path $Source -Recurse -Directory).Count
$replicaDirsCount = (Get-ChildItem -Path $Replica -Recurse -Directory).Count

if ($sourceFilesCount -ne $replicaFilesCount -or $sourceFilesSize -ne $replicaFilesSize -or $sourceDirsCount -ne $replicaDirsCount) {
    $message = "Synchronization of $Source to $Replica failed. Source and Replica have different number of files,directories or size."
    Write-SfLog -Message $message -LogFile $LogFile -Verbose:$ShowVerbose -Level 'ERROR'
    $itemFailure++
}


# No changes detected
if ($sourceItemCopied -eq 0 -and $replicaItemRemoved -eq 0 -and $itemFailure -eq 0) {
    $message = "No changes detected between Source: [$Source] and Replica: [$Replica] Log: [$LogFile]"
    Write-SfLog -Message $message -LogFile $LogFile -Verbose:$ShowVerbose
}
else {
    $message = "Synchronization completed [$Source] <=> [$Replica] Log: [$LogFile]"
    Write-SfLog -Message $message -LogFile $LogFile -Verbose:$ShowVerbose
}
#endregion

# Return the results
return [PSCustomObject]@{
    FilesCopied        = $sourceItemCopied
    DirectoriesCopied  = $sourceFolderCopied
    SourceFiles        = $sourceFilesCount
    ReplicaFiles       = $replicaFilesCount
    SourceDirs         = $sourceDirsCount
    ReplicaDirs        = $replicaDirsCount
    ReplicaItemRemoved = $replicaItemRemoved
    SourceSizeBytes    = $sourceFilesSize
    ReplicaSizeBytes   = $replicaFilesSize
    ItemFailure        = $itemFailure
    ReturnCode         = if ($itemFailure) { 1 } else { 0 }
}
