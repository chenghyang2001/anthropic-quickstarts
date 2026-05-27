param(
    [string]$VPS = "claude@187.127.109.145",
    [string]$LogFile = "/tmp/podcastbrain_run1.log"
)

# param() must come first — encoding setup after
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$shownLines = 0
Write-Host "=== PodcastBrain Monitor ===" -ForegroundColor Cyan
Write-Host "VPS: $VPS  Log: $LogFile  Ctrl+C to stop" -ForegroundColor DarkGray
Write-Host ""

while ($true) {
    try {
        $raw = ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $VPS `
            "wc -l < '$LogFile' 2>/dev/null; tail -n +$(($shownLines + 1)) '$LogFile' 2>/dev/null"

        if ($raw) {
            $lines = $raw -split "`n"
            $totalLines = 0
            if ([int]::TryParse($lines[0].Trim(), [ref]$totalLines)) {
                if ($totalLines -gt $shownLines) {
                    for ($i = 1; $i -lt $lines.Count; $i++) {
                        $line = $lines[$i]
                        if ($line.Trim() -eq "") { continue }

                        if     ($line -match "^\[Tool:")                    { Write-Host $line -ForegroundColor Cyan    }
                        elseif ($line -match "^\s+\[OK\]")                  { Write-Host $line -ForegroundColor Green   }
                        elseif ($line -match "ERROR|FAIL|error:|Exception") { Write-Host $line -ForegroundColor Red     }
                        elseif ($line -match "^---.*---$|^={10}")           { Write-Host $line -ForegroundColor Magenta }
                        elseif ($line -match "WARNING|warning")             { Write-Host $line -ForegroundColor Yellow  }
                        elseif ($line -match "passes.*true|feature.*PASS")  { Write-Host $line -ForegroundColor Green   }
                        elseif ($line -match "^\s+>")                       { Write-Host $line -ForegroundColor White   }
                        else                                                 { Write-Host $line -ForegroundColor DarkGray}
                    }
                    $shownLines = $totalLines
                }
            }
        }
    } catch {
        Write-Host "[SSH failed, retrying...]" -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 3
}
