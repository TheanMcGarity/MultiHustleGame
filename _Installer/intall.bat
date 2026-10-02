@echo off
echo Wait for game to completely close...
pause
echo Replacing game package...
copy /Y "%~2" "%~1"
echo Replacing with debug exe... (if exists)
cd /D %3
copy /Y "%~4" YourOnlyMoveIsHUSTLE.exe
echo Launching updated game...

start YourOnlyMoveIsHUSTLE.exe
pause
exit