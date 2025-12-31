@echo off
REM Quick deployment script for Windows
REM This batch file calls the PowerShell script

echo ========================================
echo  Microservices Logging Demo
echo  Quick Deployment for Windows
echo ========================================
echo.

REM Check if PowerShell is available
where powershell >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is not found in PATH
    echo Please install PowerShell or run the commands manually
    pause
    exit /b 1
)

REM Change to script directory
cd /d "%~dp0"

REM Run PowerShell script
echo Starting deployment...
echo.
powershell -ExecutionPolicy Bypass -File ".\scripts\deploy.ps1"

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Deployment failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo  Deployment Complete!
echo ========================================
echo.
echo Next steps:
echo   1. Run: kubectl port-forward -n logging svc/kibana 5601:5601
echo   2. Run: kubectl port-forward -n microservices svc/order-service 8080:80
echo   3. Open: http://localhost:5601
echo   4. Open: http://localhost:8080/swagger
echo.
pause
