echo Wait for game to completely close...
pause
cd %2

echo Replacing game package...
copy /Y "MH.pck" "%~1"

echo Launch updated game?
pause

cd %3
start YourOnlyMoveIsHUSTLE.exe

exit