# AnaplanDailyAction.ps1
# This script runs an Anaplan action and logs the outcome
# ------ Configuration ------
# Anaplan credentials - keeping as-is since you're not worried about security for now
$ANAPLAN_USER = "jaiselvash.segar@relanto.ai"
$ANAPLAN_PASSWORD = 'AP_#@Jai._14'

# Anaplan workspace, model, and action details
$WORKSPACE_ID = "8a868cdc7bd6c9ae017be5b938c83112"
$MODEL_ID = "6E767AD07F1345D9B3E3AF6925799C8A"
$ACTION_NAME = "Import current date"

# Anaplan Connect directory - Updated for GitHub Actions
$ANAPLAN_CONNECT_DIR = ".\anaplan-connect-4.3.1"

# Log file location - Updated for GitHub Actions
$LOG_DIR = ".\logs"
$LOG_FILE = "$LOG_DIR\anaplan_daily_$(Get-Date -Format 'yyyy-MM-dd').log"

# ------ Functions ------
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Create log directory if it doesn't exist
    if (!(Test-Path -Path $LOG_DIR)) {
        New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null
    }
    
    # Write to log file
    Add-Content -Path $LOG_FILE -Value $logEntry
    
    # Also write to console
    Write-Host $logEntry
}

# ------ Main Script ------
try {
    Write-Log "Starting Anaplan daily action automation"
    
    # Navigate to Anaplan Connect directory
    Set-Location -Path $ANAPLAN_CONNECT_DIR
    Write-Log "Changed directory to Anaplan Connect folder: $ANAPLAN_CONNECT_DIR"
    
    # Find Java executable
    Write-Log "Finding Java path..."
    $java_path = $null
    if ($env:JAVA_HOME -and (Test-Path "$env:JAVA_HOME\bin\java.exe")) {
        $java_path = "$env:JAVA_HOME\bin\java.exe"
        Write-Log "Using JAVA_HOME: $java_path"
    }
    elseif (Get-Command java -ErrorAction SilentlyContinue) {
        $java_path = (Get-Command java).Source
        Write-Log "Using system Java: $java_path"
    }
    else {
        throw "Java runtime not found!"
    }
    
    # Verify Java version
    $java_version = & $java_path -version 2>&1 | Select-String "version" | ForEach-Object { $_ -match '"(\d+\.\d+)' ; $matches[1] }
    if ($java_version -match "^(1\.8|11\.0|17\.0|21\.0|22\.0)$") {
        Write-Log "Java version $java_version is supported."
    }
    else {
        throw "Unsupported Java version: $java_version. Use Java 8, 11, 17, or 21."
    }
    
    # Find Anaplan Connect JAR file
    $classpathFile = Get-ChildItem "$ANAPLAN_CONNECT_DIR\anaplan-connect-*-jar-with-dependencies.jar" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1
    
    if (-not $classpathFile) {
        throw "Cannot locate anaplan-connect JAR file."
    }
    
    $classpath = $classpathFile.FullName
    Write-Log "Using Anaplan Connect JAR: $classpath"
    
    # Execute Anaplan action
    Write-Log "Executing Anaplan action: $ACTION_NAME"
    $startTime = Get-Date
    
    $result = & $java_path -classpath "$classpath" `
        com.anaplan.client.Program `
        -s "https://api.anaplan.com" `
        -auth "https://auth.anaplan.com" `
        -w $WORKSPACE_ID `
        -m $MODEL_ID `
        -u "$($ANAPLAN_USER):$($ANAPLAN_PASSWORD)" `
        -i $ACTION_NAME `
        -x
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    # Log result
    Write-Log "Action completed in $($duration.TotalSeconds) seconds" 
    Write-Log "Action result: $result"
    Write-Log "Anaplan action execution completed successfully"
    
    exit 0
}
catch {
    Write-Log "Error occurred: $_" -Level "ERROR"
    exit 1
}
