@echo off
setlocal
if not defined LOCALAPPDATA (
  echo Windows LOCALAPPDATA is unavailable. Run OrbitNote-Server.exe with a private data directory.
  pause
  exit /b 1
)
echo Orbit Note self-hosted server
echo Data and private owner key: %LOCALAPPDATA%\OrbitNote\Server
echo Same-machine address: http://127.0.0.1:47831
echo Other devices require HTTPS through a reverse proxy. Localhost refers to each device itself.
echo Keep this window open. Press Ctrl+C to stop the server.
"%~dp0OrbitNote-Server.exe" "%LOCALAPPDATA%\OrbitNote\Server"
if errorlevel 1 pause
