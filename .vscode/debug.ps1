$RequestedScript = (Resolve-Path $args[0]).Path

if ($RequestedScript -ieq $MyInvocation.MyCommand.Definition) {
    Write-Error "Cannot execute debug script directly"
    exit 1
} elseif (-not $RequestedScript.EndsWith(".ps1")) {
    Write-Error "'$RequestedScript' is not a PowerShell script"
    exit 1
}

& $RequestedScript
