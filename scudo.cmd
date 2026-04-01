@echo off
setlocal
set "script_dir=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%script_dir%scudo.ps1" %*
