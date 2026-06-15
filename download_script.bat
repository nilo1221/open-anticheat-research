@echo off
echo Downloading capture_battleye_logs.ps1...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/nilo1221/open-anticheat-research/main/capture_battleye_logs.ps1' -OutFile 'C:\Users\%USERNAME%\Desktop\capture_battleye_logs.ps1'"
echo Download complete!
echo Script saved to: C:\Users\%USERNAME%\Desktop\capture_battleye_logs.ps1
pause
