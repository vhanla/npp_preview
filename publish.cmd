<!-- :: Begin batch script
@Echo off

:: set code page to UTF-8
chcp 65001 >NUL

pushd "%~dp0"

:: call the WSF script to extract the current version number from the .dproj file
CScript //nologo "%~f0?.wsf" > set_version.bat
call set_version.bat
del set_version.bat

echo Preparing to build and release of version "%RELEASE_VERSION%" from branch:
fossil tag list --raw current
echo Press Ctrl-C to abort publication;
pause

:: copy all files from the 32-bits output folder to the 64-bits output folder
copy /y /b /v out\Win32\Release\* out\Win64\Release
del "out\Win64\Release\This is the 32-bits plugin.txt"

:: prepare to build the DLLs
call rsvars.bat

MSBuild /v:q /p:Config=Release;Platform=Win32 /t:build src\prj\PreviewHTML.dproj > out\PreviewHTML_Win32.txt
if errorlevel 1 echo Compilation errors, aborting... && start "" out\PreviewHTML_Win32.txt && goto TheEnd

MSBuild /v:q /p:Config=Release;Platform=Win64 /t:build src\prj\PreviewHTML.dproj > out\PreviewHTML_Win64.txt
if errorlevel 1 echo Compilation errors, aborting... && start "" out\PreviewHTML_Win64.txt && goto TheEnd

pushd %~dp0\out\Win32\Release
if not exist _FOSSIL_ echo goto NoPublicationRepo
start /wait "Release notes" ReleaseNotes.txt
fossil commit --comment "v%RELEASE_VERSION%" --tag v%RELEASE_VERSION%-32 --tag v%RELEASE_VERSION%
popd

pushd %~dp0\out\Win64\Release
if not exist _FOSSIL_ goto NoPublicationRepo
copy /y /b /v ..\..\Win32\Release\ReleaseNotes.txt .
fossil commit --comment "v%RELEASE_VERSION%" --tag v%RELEASE_VERSION%-64 --tag v%RELEASE_VERSION%
popd

:: Commit the source code
fossil commit --tag src-%RELEASE_VERSION% --tag release-src
fossil tag add src-%RELEASE_VERSION% current
fossil tag add release-src current

goto TheEnd

:NoPublicationRepo
echo There is no publication repository rooted in "%CD%"!
popd

:TheEnd
popd
exit /b


-- begin of wsf script -->
<package>
	<job>
		<script language="JScript">
			var xmlDoc = new ActiveXObject("MSXML2.DOMDocument.6.0");
			xmlDoc.load("src\\prj\\PreviewHTML.dproj");
			xmlDoc.setProperty("SelectionNamespaces", "xmlns:b='http://schemas.microsoft.com/developer/msbuild/2003'");
			var xmlKeys = xmlDoc.selectSingleNode("/b:Project/b:PropertyGroup/b:VerInfo_Keys");
			if (xmlKeys) {
				var keys = xmlKeys.text;
				var match = keys.match(/FileVersion=((\d+\.)+\d+)/);
				if (match) {
					WScript.Echo("set RELEASE_VERSION=" + match[1]);
				}
			}
		</script>
	</job>
</package>