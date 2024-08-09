# Pester test for the Sync-Folders.ps1 script (Install-Module -Name Pester -Force -SkipPublisherCheck).

Describe "Testing Sync-Folders.ps1" {

    BeforeAll {
        # Set up the test environment
        $sourceDir = "C:\Test\Source"
        $replicaDir = "C:\Test\Replica"
        $logFile = "C:\Test\SyncLog.txt"
        $showVerbose = $false

        # Create the source directory
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

        # Create some files in the source directory
        $file1 = New-Item -ItemType File -Path "$sourceDir\File1.txt" -Force
        $file2 = New-Item -ItemType File -Path "$sourceDir\File2.txt" -Force
        #Suppress PSUseDeclaredVarsMoreThanAssignments
        if ($false) { "$file1, $file2 " | Out-Null }

        # Create the replica directory
        New-Item -ItemType Directory -Path $replicaDir -Force | Out-Null

        # Import the Sync-Folders.ps1 script
        . $PSScriptRoot\Sync-Folders.ps1 -Source $replicaDir  -Replica $replicaDir -LogFile $logFile `
            -ShowVerbose $showVerbose
    }

    AfterAll {
        # Clean up the test environment
        Remove-Item -Path $sourceDir -Recurse -Force
        Remove-Item -Path $replicaDir -Recurse -Force
        Remove-Item -Path $logFile -Force
    }

    Context "Synchronization tests" {
        BeforeAll {
            $showVerbose = $false
            #Suppress PSUseDeclaredVarsMoreThanAssignments
            if ($false) { "$showVerbose" | Out-Null }
        }

        It "Should copy new and updated files from source to replica" {
            # Arrange
            $replicaFile1 = "$replicaDir\File1.txt"

            # Act
            . $PSScriptRoot\Sync-Folders.ps1 -Source $sourceDir -Replica $replicaDir -LogFile $logFile `
                -ShowVerbose $showVerbose

            # Assert
            (Test-Path -Path $replicaFile1) | Should -Be $true
        }

        It "Should remove files from replica that are not present in source" {
            # Arrange
            Remove-Item "$sourceDir\File2.txt" -Force
            $replicaFile2 = "$replicaDir\File2.txt"

            # Act
            . $PSScriptRoot\Sync-Folders.ps1 -Source $sourceDir -Replica $replicaDir -LogFile $logFile `
                -ShowVerbose $showVerbose

            # Assert
            (Test-Path -Path $replicaFile2) | Should -Be $false
        }

        It "Should remove empty directories from replica" {
            # Arrange
            $emptyDir = "$replicaDir\EmptyDir"
            New-Item -ItemType Directory -Path $emptyDir | Out-Null

            # Act
            . $PSScriptRoot\Sync-Folders.ps1 -Source $sourceDir -Replica $replicaDir -LogFile $logFile `
                -ShowVerbose $showVerbose

            # Assert
            (Test-Path -Path $emptyDir) | Should -Be $false
        }
    }

    Context "Error handling tests" {
        BeforeAll {
            $showVerbose = $false
            #Suppress PSUseDeclaredVarsMoreThanAssignments
            if ($false) { "$showVerbose" | Out-Null }
        }

        It "Should log an error if source directory does not exist" {
            # Arrange
            $nonExistentDir = "C:\Test\NonExistentDir"

            # Act
            . $PSScriptRoot\Sync-Folders.ps1 -Source $nonExistentDir -Replica $replicaDir -LogFile $logFile `
                -ShowVerbose $showVerbose -ErrorAction SilentlyContinue
            $exitCode = $LASTEXITCODE

            # Assert
            $exitCode | Should -Be 1
        }

        It "Should log an error if replica directory creation fails" {
            # Arrange
            # Get all available disk letters
            $currentDisks = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' } |
                Select-Object -ExpandProperty Name | ForEach-Object { $_[0] }

            # Create a range of all possible disk letters
            $allDiskLetters = 65..90 | ForEach-Object { [char]$_ }

            # Select the first disk letter not in use
            $unusedDiskLetter = $allDiskLetters | Where-Object { $_ -notin $currentDisks } |
                Select-Object -First 1

            $invalidPath = "$unusedDiskLetter`:\Invalid\Path"

            # Act
            . $PSScriptRoot\Sync-Folders.ps1 -Source $sourceDir -Replica $invalidPath -LogFile $logFile `
                -ShowVerbose $showVerbose -ErrorAction SilentlyContinue

            # Assert
            (Test-Path -Path $logFile) | Should -Be $true
            $logContent = Get-Content -Path $logFile
            $logRecord = $logContent -Match "Error: Cannot find drive. A drive with the name '$($unusedDiskLetter)' does not exist\."
            $logRecord | Should -Be $true
        }
    }
}
