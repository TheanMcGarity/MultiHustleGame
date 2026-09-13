@echo off
echo Wait for game to completely close...
pause
cd %2

echo Replacing game package...
copy /Y "MH.pck" "%~1"

echo Launching updated game...

cd %3
echo test
pause
start YourOnlyMoveIsHUSTLE.exe

exit