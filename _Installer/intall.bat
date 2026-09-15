@echo off
echo Wait for game to completely close...
pause

echo Replacing game package...
copy /Y "%~2" "%~1"

echo Launching updated game...

cd %3
pause
start YourOnlyMoveIsHUSTLE.exe

exit