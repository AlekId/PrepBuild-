@echo off
rem Sourcen aus Repository updaten
rem Build durchfuehren
rem falls Fehler: Anhalten und Fehler anzeigen
rem revert der automatischen Buildnummer-Aenderung

svn update
if errorlevel 1 goto Error

set BatchBuild=1
call _BuildProject.cmd

if not exist src\*_version.ini goto :eof
svn revert src\*_version.ini
if errorlevel 1 goto error

goto :eof

:error
echo ***** ERROR *****
pause
