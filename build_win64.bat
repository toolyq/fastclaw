@echo off
setlocal enabledelayedexpansion

:: Check for Go
where go >nul 2>nul
if !ERRORLEVEL! neq 0 (
    echo Error: Go is not installed or not in PATH.
    exit /b 1
)

:: Set default version/commit/date
set VERSION=dev
set COMMIT=unknown
set DATE=unknown

:: Try to update them using git
where git >nul 2>nul
if !ERRORLEVEL! equ 0 (
    for /f "tokens=*" %%i in ('git describe --tags --always --dirty') do set VERSION=%%i
    for /f "tokens=*" %%i in ('git rev-parse --short HEAD') do set COMMIT=%%i
    for /f "tokens=*" %%i in ('powershell -Command "Get-Date -UFormat '%%Y-%%m-%%dT%%H:%%M:%%SZ'"') do set DATE=%%i
)

echo.
echo ========================================
echo Building FastClaw for Win64
echo   Version: %VERSION%
echo   Commit:  %COMMIT%
echo   Date:    %DATE%
echo ========================================
echo.

:: Build web frontend if needed
echo [1/3] Building web frontend...

:: If web/out exists, skip frontend build
if exist "web\out" (
    echo   (Web output already exists, skipping frontend build)
    goto :PREPARE_FILES
)

:: 1. 进入 web 目录
cd web
:: 2. 安装依赖（如果没安装过）
npm install
:: 3. 运行编译
npm run build

cd ..

:PREPARE_FILES
:: Prepare embedded files
echo [2/3] Preparing embedded files...
if not exist "web\out" (
    echo Error: web\out not found.
    exit /b 1
)

:: Use a temporary directory to avoid xcopy issues with existing dirs
if exist "internal\setup\web" rd /s /q "internal\setup\web"
mkdir "internal\setup\web"
xcopy /e /i /y "web\out" "internal\setup\web" >nul


:: Compile the binary
echo [3/3] Compiling Go binary (win64)...
if not exist "bin" mkdir "bin"

set LDFLAGS=-s -w -X main.version=%VERSION% -X main.commit=%COMMIT% -X main.date=%DATE%
set CGO_ENABLED=0
set GOOS=windows
set GOARCH=amd64

go build -ldflags "%LDFLAGS%" -o bin\fastclaw.exe ./cmd/fastclaw

if !ERRORLEVEL! equ 0 (
    echo.
    echo ========================================
    echo Success! Binary is located at bin\fastclaw.exe
    echo ========================================
) else (
    echo.
    echo Build failed.
    exit /b 1
)

endlocal
