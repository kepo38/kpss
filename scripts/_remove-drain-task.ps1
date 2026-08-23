schtasks /Delete /TN "HEDEFKamu-TelegramDrain" /F
if ($LASTEXITCODE -eq 0) { "OK deleted" } else { "FAIL $LASTEXITCODE" }
