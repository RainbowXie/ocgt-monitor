@echo off
setlocal

:: Enable CGO (needed for WebView2 sidebar)
set CGO_ENABLED=1

:: Set GCC path (MSYS2 MinGW64)
set "PATH=C:\msys64\mingw64\bin;%PATH%"

:: --- CLI version (double-click opens terminal) ---
:: go build -ldflags="-s -w" -o ocgt-monitor.exe .

:: --- GUI version (double-click starts sidebar, no terminal window) ---
go build -ldflags="-s -w -H windowsgui" -o ocgt-monitor.exe .

echo Build complete: ocgt-monitor.exe (GUI mode)
