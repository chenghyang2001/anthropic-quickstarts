# VPS remote log monitor - append mode (no screen clear)
# Each refresh appends only NEW filtered lines; keeps full history visible.
# Usage: .\watch_vps_log.ps1 [-LogFile <path>] [-Interval <sec>]

param(
    [string]$LogFile  = "/tmp/vps_run2.log",
    [int]   $Interval = 3
)

$VPS_HOST    = "claude@187.127.109.145"
$shownCount  = 0

Write-Host "=== VPS log monitor (append mode) ===" -ForegroundColor Cyan
Write-Host "Host: $VPS_HOST   Log: $LogFile   Refresh: ${Interval}s   Ctrl+C to stop" -ForegroundColor DarkCyan
Write-Host ""

try {
    while ($true) {
        # Fetch full log; sentinel when file not yet created
        $rawLines = ssh -o BatchMode=yes $VPS_HOST `
            "cat '$LogFile' 2>/dev/null || echo '__FILE_NOT_FOUND__'" 2>&1

        if ($LASTEXITCODE -ne 0) {
            $ts = Get-Date -Format "HH:mm:ss"
            Write-Host "[$ts] SSH error (exit $LASTEXITCODE), retrying..." -ForegroundColor Red
        } elseif ($rawLines -contains '__FILE_NOT_FOUND__') {
            # Log file not yet created - silent wait
        } else {
            # Filter: tool calls / results / AI text / session markers / feature refs
            $filtered = $rawLines | Where-Object {
                $_ -match '\[Tool:'                              -or
                $_ -match '^\s+\[(OK|ERR)\]'                   -or
                $_ -match '^  >'                               -or
                $_ -match '={4,}'                              -or
                $_ -match '(DONE|cost:|[Ff]eature|Session \d)'
            }

            $newLines = @($filtered | Select-Object -Skip $shownCount)

            if ($newLines.Count -gt 0) {
                foreach ($line in $newLines) {
                    if      ($line -match '\[Tool:')         { Write-Host $line -ForegroundColor Cyan    }
                    elseif  ($line -match '^\s+\[OK\]')      {
                        $s = if ($line.Length -gt 120) { $line.Substring(0,120) + ' ...' } else { $line }
                        Write-Host $s -ForegroundColor Green
                    }
                    elseif  ($line -match '^\s+\[ERR\]')     { Write-Host $line -ForegroundColor Red     }
                    elseif  ($line -match '^  >')            { Write-Host $line -ForegroundColor White   }
                    elseif  ($line -match '={4,}')           { Write-Host $line -ForegroundColor Magenta }
                    else                                     { Write-Host $line -ForegroundColor Gray    }
                }
                $shownCount = $filtered.Count
            }
        }

        Start-Sleep -Seconds $Interval
    }
}
finally {
    Write-Host ""
    Write-Host "Monitor stopped." -ForegroundColor Cyan
}
