# Load required assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the XAML string for the GUI
$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Modern Codebase Processor" Height="400" Width="600" WindowStartupLocation="CenterScreen" Background="#2E3440">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Header Section -->
        <TextBlock Grid.Row="0" Text="Codebase Extraction Tool" FontSize="20" Foreground="#A3BE8C" Margin="0,0,0,15" HorizontalAlignment="Center"/>

        <!-- Folder Selection Section -->
        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,10">
            <TextBlock Text="Codebase Folder:" Foreground="#D8DEE9" VerticalAlignment="Center" Width="120"/>
            <TextBox x:Name="CodebaseFolderPath" Width="350" Margin="10,0,10,0"/>
            <Button Content="Browse" Width="80" x:Name="BrowseCodebaseFolderButton" Background="#5E81AC" Foreground="#ECEFF4"/>
        </StackPanel>

        <!-- Output File Section -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,10">
            <TextBlock Text="Output File:" Foreground="#D8DEE9" VerticalAlignment="Center" Width="120"/>
            <TextBox x:Name="OutputFilePath" Width="350" Margin="10,0,10,0"/>
            <Button Content="Browse" Width="80" x:Name="BrowseOutputFileButton" Background="#5E81AC" Foreground="#ECEFF4"/>
        </StackPanel>

        <!-- File Extensions Section -->
        <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,0,0,10">
            <TextBlock Text="File Extensions:" Foreground="#D8DEE9" VerticalAlignment="Center" Width="120"/>
            <TextBox x:Name="FileExtensions" Width="440" Margin="10,0,0,0" Text=".js,.py,.tsx,.ts,.html"/>
        </StackPanel>
        <TextBlock Grid.Row="4" Text="Enter extensions separated by commas (e.g., .js,.py,.tsx)" FontSize="11" Foreground="#81A1C1" Margin="130,0,0,10"/>

        <!-- Action Buttons -->
        <StackPanel Grid.Row="5" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,15,0,0">
            <Button Content="Process Codebase" x:Name="ProcessCodebaseButton" Width="150" Height="35" Background="#88C0D0" Foreground="#2E3440" Margin="0,0,20,0"/>
            <Button Content="Exit" x:Name="ExitButton" Width="100" Height="35" Background="#BF616A" Foreground="#ECEFF4"/>
        </StackPanel>
        
        <!-- Status Section -->
        <TextBlock Grid.Row="6" x:Name="StatusText" Foreground="#A3BE8C" Margin="0,15,0,0" TextWrapping="Wrap"/>
    </Grid>
</Window>
"@

# Parse the XAML
[xml]$XAMLReader = $XAML
$Reader = New-Object System.Xml.XmlNodeReader $XAMLReader
$Window = [Windows.Markup.XamlReader]::Load($Reader)

# Find elements by name
$CodebaseFolderPath = $Window.FindName("CodebaseFolderPath")
$OutputFilePath = $Window.FindName("OutputFilePath")
$FileExtensions = $Window.FindName("FileExtensions")
$BrowseCodebaseFolderButton = $Window.FindName("BrowseCodebaseFolderButton")
$BrowseOutputFileButton = $Window.FindName("BrowseOutputFileButton")
$ProcessCodebaseButton = $Window.FindName("ProcessCodebaseButton")
$ExitButton = $Window.FindName("ExitButton")
$StatusText = $Window.FindName("StatusText")

# Function to update status
function Update-Status {
    param (
        [string]$message,
        [string]$color = "#A3BE8C"
    )
    
    $StatusText.Dispatcher.Invoke({
        $StatusText.Text = $message
        $StatusText.Foreground = $color
    }, "Normal")
}

# Function to process the codebase files
function Process-Codebase {
    param(
        [string]$folderPath,
        [string]$outputFile,
        [string[]]$extensions
    )

    try {
        Update-Status "Processing codebase..."
        
        # Change the current directory to the selected folder
        Push-Location $folderPath

        # Create file patterns by adding "*" to each extension
        $patterns = $extensions | ForEach-Object { "*" + $_ }

        # Get all files with the specified extensions
        $files = @(Get-ChildItem -Recurse -Include $patterns)

        Update-Status "Found $($files.Count) files to process..."

        # Create a StreamWriter to write to the output file
        $writer = New-Object System.IO.StreamWriter $outputFile

        # Write the header for the tree structure
        $writer.WriteLine("The structure of the codebase is:")

        # Function to build and write the directory tree
        function Write-DirectoryTree {
            param (
                [string]$path,
                [string]$prefix = ""
            )
            # Get all items in the current path
            $items = Get-ChildItem -Path $path
            $itemCount = $items.Count
            $index = 0

            foreach ($item in $items) {
                $index++
                $isLast = $index -eq $itemCount
                $relativePath = (Resolve-Path -Path $item.FullName -Relative).Replace('\', '/')
                
                # Write the current item with appropriate prefix
                if ($isLast) {
                    $writer.WriteLine("$prefix--- $relativePath")
                    $newPrefix = "$prefix    "
                } else {
                    $writer.WriteLine("$prefix+-- $relativePath")
                    $newPrefix = "$prefix|   "
                }
                
                # If the item is a directory, recursively process its contents
                if ($item.PSIsContainer) {
                    Write-DirectoryTree -path $item.FullName -prefix $newPrefix
                }
            }
        }

        Update-Status "Generating directory tree..."
        
        # Write the root folder and its full tree structure
        $rootRelativePath = (Resolve-Path -Path $folderPath -Relative).Replace('\', '/')
        $writer.WriteLine($rootRelativePath)
        Write-DirectoryTree -path $folderPath

        # Add a blank line before file contents
        $writer.WriteLine("")

        Update-Status "Writing file contents..."
        
        # Process each file for content
        $fileCounter = 0
        $totalFiles = $files.Count
        
        foreach ($file in $files) {
            $fileCounter++
            if ($fileCounter % 10 -eq 0) {
                Update-Status "Processing file $fileCounter of $totalFiles..."
            }
            
            # Get the relative path
            $relativePath = (Resolve-Path -Path $file.FullName -Relative).Replace('\', '/')
            
            # Write a header with the relative path
            $writer.WriteLine("--- File: $relativePath ---")
            
            try {
                # Read the file content
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
                
                # Write the content
                $writer.Write($content)
                $writer.WriteLine("")
            }
            catch {
                $writer.WriteLine("ERROR: Could not read file content: $_")
            }
        }

        # Close the StreamWriter
        $writer.Close()

        # Restore the original directory
        Pop-Location

        Update-Status "Processing complete! Output written to: $outputFile"
        return $true
    }
    catch {
        Update-Status "Error: $_" "#BF616A"
        return $false
    }
}

# Browse folder button event handler
$BrowseCodebaseFolderButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select Codebase Folder"
    $folderBrowser.ShowNewFolderButton = $true
    
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $CodebaseFolderPath.Text = $folderBrowser.SelectedPath
        
        # Suggest default output file if not already specified
        if ([string]::IsNullOrEmpty($OutputFilePath.Text)) {
            $OutputFilePath.Text = [System.IO.Path]::Combine($folderBrowser.SelectedPath, "CodebaseOutput.txt")
        }
    }
})

# Browse output file button event handler
$BrowseOutputFileButton.Add_Click({
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
    $saveFileDialog.DefaultExt = "txt"
    $saveFileDialog.Title = "Save Output File"
    
    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $OutputFilePath.Text = $saveFileDialog.FileName
    }
})

# Process codebase button click handler
$ProcessCodebaseButton.Add_Click({
    # Validate input
    if ([string]::IsNullOrEmpty($CodebaseFolderPath.Text)) {
        [System.Windows.MessageBox]::Show("Please select a codebase folder.", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }
    
    # If no output file is specified, create a default one in the same folder
    if ([string]::IsNullOrEmpty($OutputFilePath.Text)) {
        $OutputFilePath.Text = [System.IO.Path]::Combine($CodebaseFolderPath.Text, "CodebaseOutput.txt")
    }
    
    # Parse extensions from the text box
    $extensions = $FileExtensions.Text -split ',' | ForEach-Object { $_.Trim() }
    
    # Disable the Process button while processing
    $ProcessCodebaseButton.IsEnabled = $false
    
    # Using RunspacePool to run in background without Task.Run ambiguity issues
    $InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, 1, $InitialSessionState, $Host)
    $RunspacePool.Open()
    
    # Create PowerShell instance for background processing
    $PowerShell = [System.Management.Automation.PowerShell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
    
    # Add the script and parameters
    [void]$PowerShell.AddScript({
        param($folderPath, $outputFile, $extensions, $syncHash)
        
        try {
            # Change the current directory to the selected folder
            Push-Location $folderPath
    
            # Create file patterns by adding "*" to each extension
            $patterns = $extensions | ForEach-Object { "*" + $_ }
    
            # Get all files with the specified extensions
            $files = @(Get-ChildItem -Recurse -Include $patterns)
            $syncHash.StatusText.Dispatcher.Invoke({ $syncHash.StatusText.Text = "Found $($files.Count) files to process..." })
    
            # Create a StreamWriter to write to the output file
            $writer = New-Object System.IO.StreamWriter $outputFile
    
            # Write the header for the tree structure
            $writer.WriteLine("The structure of the codebase is:")
    
            # Function to build and write the directory tree
            function Write-DirectoryTree {
                param (
                    [string]$path,
                    [string]$prefix = ""
                )
                # Get all items in the current path
                $items = Get-ChildItem -Path $path
                $itemCount = $items.Count
                $index = 0
    
                foreach ($item in $items) {
                    $index++
                    $isLast = $index -eq $itemCount
                    $relativePath = (Resolve-Path -Path $item.FullName -Relative).Replace('\', '/')
                    
                    # Write the current item with appropriate prefix
                    if ($isLast) {
                        $writer.WriteLine("$prefix--- $relativePath")
                        $newPrefix = "$prefix    "
                    } else {
                        $writer.WriteLine("$prefix+-- $relativePath")
                        $newPrefix = "$prefix|   "
                    }
                    
                    # If the item is a directory, recursively process its contents
                    if ($item.PSIsContainer) {
                        Write-DirectoryTree -path $item.FullName -prefix $newPrefix
                    }
                }
            }
    
            $syncHash.StatusText.Dispatcher.Invoke({ $syncHash.StatusText.Text = "Generating directory tree..." })
            
            # Write the root folder and its full tree structure
            $rootRelativePath = (Resolve-Path -Path $folderPath -Relative).Replace('\', '/')
            $writer.WriteLine($rootRelativePath)
            Write-DirectoryTree -path $folderPath
    
            # Add a blank line before file contents
            $writer.WriteLine("")
    
            $syncHash.StatusText.Dispatcher.Invoke({ $syncHash.StatusText.Text = "Writing file contents..." })
            
            # Process each file for content
            $fileCounter = 0
            $totalFiles = $files.Count
            
            foreach ($file in $files) {
                $fileCounter++
                if ($fileCounter % 10 -eq 0) {
                    $syncHash.StatusText.Dispatcher.Invoke({ 
                        $syncHash.StatusText.Text = "Processing file $fileCounter of $totalFiles..."
                    })
                }
                
                # Get the relative path
                $relativePath = (Resolve-Path -Path $file.FullName -Relative).Replace('\', '/')
                
                # Write a header with the relative path
                $writer.WriteLine("--- File: $relativePath ---")
                
                try {
                    # Read the file content
                    $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
                    
                    # Write the content
                    $writer.Write($content)
                    $writer.WriteLine("")
                }
                catch {
                    $writer.WriteLine("ERROR: Could not read file content: $_")
                }
            }
    
            # Close the StreamWriter
            $writer.Close()
    
            # Restore the original directory
            Pop-Location
    
            $syncHash.StatusText.Dispatcher.Invoke({ 
                $syncHash.StatusText.Text = "Processing complete! Output written to: $outputFile"
                $syncHash.StatusText.Foreground = "#A3BE8C" 
            })
            
            # Re-enable the Process button
            $syncHash.ProcessCodebaseButton.Dispatcher.Invoke({ $syncHash.ProcessCodebaseButton.IsEnabled = $true })
            
            # Show success message
            $syncHash.Window.Dispatcher.Invoke({
                [System.Windows.MessageBox]::Show("Codebase processed successfully. Output written to: $outputFile", 
                    "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            })
            
            return $true
        }
        catch {
            $syncHash.StatusText.Dispatcher.Invoke({ 
                $syncHash.StatusText.Text = "Error: $_"
                $syncHash.StatusText.Foreground = "#BF616A" 
            })
            
            # Re-enable the Process button
            $syncHash.ProcessCodebaseButton.Dispatcher.Invoke({ $syncHash.ProcessCodebaseButton.IsEnabled = $true })
            
            return $false
        }
    })
    
    # Create synchronized hashtable for cross-thread access to UI elements
    $syncHash = [hashtable]::Synchronized(@{})
    $syncHash.Window = $Window
    $syncHash.StatusText = $StatusText
    $syncHash.ProcessCodebaseButton = $ProcessCodebaseButton
    
    # Add parameters
    [void]$PowerShell.AddParameter("folderPath", $CodebaseFolderPath.Text)
    [void]$PowerShell.AddParameter("outputFile", $OutputFilePath.Text)
    [void]$PowerShell.AddParameter("extensions", $extensions)
    [void]$PowerShell.AddParameter("syncHash", $syncHash)
    
    # Begin async invocation
    $Handle = $PowerShell.BeginInvoke()
    
    # This will keep the UI responsive while the background job runs
    Update-Status "Starting processing... Please wait."
})

# Exit button click handler
$ExitButton.Add_Click({
    $Window.Close()
})

# Show the window
[void]$Window.ShowDialog()
