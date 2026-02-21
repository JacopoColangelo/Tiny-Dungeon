@echo off
setlocal

:: --- Configuration ---
set GAME_NAME=TinyDungeon
set LOVE_PATH=D:\Giochi\LOVE
set DIST_DIR=dist

echo === Building %GAME_NAME% Executable ===

:: 1. Create dist directory
if not exist %DIST_DIR% mkdir %DIST_DIR%

:: 2. Create the .love file (a renamed zip of your project files)
:: We use powershell to create the zip to avoid external dependencies
echo Creating %GAME_NAME%.love...
powershell -Command "Compress-Archive -Path *.lua, *.glsl, *.ttf -DestinationPath %DIST_DIR%\%GAME_NAME%.zip -Force"
move %DIST_DIR%\%GAME_NAME%.zip %DIST_DIR%\%GAME_NAME%.love

:: 3. Create the .exe by fusing love.exe and our .love file
echo Fusing executable...
copy /b "%LOVE_PATH%\love.exe"+%DIST_DIR%\%GAME_NAME%.love %DIST_DIR%\%GAME_NAME%.exe

:: 4. Copy required DLLs from LOVE directory
echo Copying dependencies...
copy "%LOVE_PATH%\*.dll" %DIST_DIR%\ > nul
copy "%LOVE_PATH%\license.txt" %DIST_DIR%\ > nul

:: Clean up temp love file
del %DIST_DIR%\%GAME_NAME%.love

echo.
echo === DONE! ===
echo Your game is ready in the '%DIST_DIR%' folder.
echo To share with friends, simply zip the entire '%DIST_DIR%' folder and send it to them.
echo.
pause
