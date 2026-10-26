@echo off
setlocal
cd /d "%~dp0"

if exist "build\web\index.html" goto serve

echo Building WorkinAI for the web...
where flutter >nul 2>nul
if not errorlevel 1 (
  flutter build web --release --no-web-resources-cdn
  goto built
)
if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
  call "%USERPROFILE%\flutter\bin\flutter.bat" build web --release --no-web-resources-cdn
  goto built
)
if exist "C:\flutter\bin\flutter.bat" (
  call "C:\flutter\bin\flutter.bat" build web --release --no-web-resources-cdn
  goto built
)

echo Flutter was not found on PATH.
echo Install Flutter, then run:
echo   flutter build web --release --no-web-resources-cdn
pause
exit /b 1

:built
if not exist "build\web\index.html" (
  echo The web build did not finish. See the messages above.
  pause
  exit /b 1
)

:serve
where python >nul 2>nul
if errorlevel 1 (
  echo Python 3 is required to serve the app.
  echo Install Python, then run: python serve_workinai.py
  pause
  exit /b 1
)

python serve_workinai.py
if errorlevel 1 pause
exit /b 0
