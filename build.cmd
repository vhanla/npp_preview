@Echo off

pushd %~dp0

:: prepare to build the DLLs
call rsvars.bat

MSBuild /v:q /p:Config=Debug;Platform=Win32 /t:build src\prj\PreviewHTML.dproj > out\PreviewHTML_Win32_Debug.txt
if errorlevel 1 echo Compilation errors, aborting... && start "" out\PreviewHTML_Win32_Debug.txt && goto TheEnd

MSBuild /v:q /p:Config=Debug;Platform=Win64 /t:build src\prj\PreviewHTML.dproj > out\PreviewHTML_Win64_Debug.txt
if errorlevel 1 echo Compilation errors, aborting... && start "" out\PreviewHTML_Win64_Debug.txt && goto TheEnd

MSBuild /v:q /p:Config=Release;Platform=Win32 /t:build src\prj\PreviewHTML.dproj > out\PreviewHTML_Win32.txt
if errorlevel 1 echo Compilation errors, aborting... && start "" out\PreviewHTML_Win32.txt && goto TheEnd

MSBuild /v:q /p:Config=Release;Platform=Win64 /t:build src\prj\PreviewHTML.dproj > out\PreviewHTML_Win64.txt
if errorlevel 1 echo Compilation errors, aborting... && start "" out\PreviewHTML_Win64.txt && goto TheEnd

:TheEnd
popd
