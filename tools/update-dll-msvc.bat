@echo off
rem Update the DLL using MSVC.
rem current support version of Visual C compiler is 2008 and upper version
rem
rem usage: update-dll-msvc
rem
rem
rem Sample .vimrc:
rem
rem NeoBundle 'Shougo/vimproc.vim', {
rem \ 'build' : {
rem \     'windows' : 'tools\\update-dll-msvc',
rem \     'cygwin' : 'make -f make_cygwin.mak',
rem \     'mac' : 'make -f make_mac.mak',
rem \     'linux' : 'make',
rem \     'unix' : 'gmake',
rem \    },
rem \ }

REM --------------------------------------------------------------------------------------------
REM Set the default value for vimproc_arch and msvc_arch based on processor architecture.
REM --------------------------------------------------------------------------------------------
set vimproc_arch=32
set msvc_arch=x86
if /i "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "vimproc_arch=64" & set "msvc_arch=x86_amd64" & goto Search_VC_Location
if /i "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "vimproc_arch=64" & set "msvc_arch=x86_amd64" & goto Search_VC_Location
if /i "%PROCESSOR_ARCHITECTURE%"=="x64"   set "vimproc_arch=64" & set "msvc_arch=x86_amd64" & goto Search_VC_Location
if /i "%PROCESSOR_ARCHITECTURE%"=="IA64"  set "vimproc_arch=64" & set "msvc_arch=x86_amd64" & goto Search_VC_Location
if /i "%PROCESSOR_ARCHITEW6432%"=="IA64"  set "vimproc_arch=64" & set "msvc_arch=x86_amd64"

set vimproc_dllname=vimproc_win%vimproc_arch%.dll

:Search_VC_Location

REM --------------------------------------------------------------------------------------------
REM Determine which registry keys to look at based on architecture type.
REM --------------------------------------------------------------------------------------------
if "%vimproc_arch%"=="64" (
    set VCRegKeyPath=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\SxS\VC7
    set VSRegKeyPath=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\SxS\VS7
)    else (
    set VCRegKeyPath=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\SxS\VC7
    set VSRegKeyPath=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\SxS\VS7
)

if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
    REM --------------------------------------------------------------------------------------------
    REM  found the lasted version of Visual C compiler, which start from 2017
    REM --------------------------------------------------------------------------------------------
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        set InstallDir=%%i
        if exist "%%i\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt" (
            set /p msvc_ver=<"%%i\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt"
        )
    )
) else (
    REM --------------------------------------------------------------------------------------------
    REM found the version of Visual C compiler which version is lower than 2017
    REM --------------------------------------------------------------------------------------------

    REM --------------------------------------------------------------------------------------------
    REM Read the value for VCRoot and VSRoot from the registry.
    REM Note: The second call to reg will fail if VS is not installed.  These calls to reg are
    REM checking to see if VS is installed in a custom location.  This behavior is expected in
    REM this scenario.
    REM --------------------------------------------------------------------------------------------

    REM --------------------------------------------------------------------------------------------
    REM Visual Studio 14.0
    REM --------------------------------------------------------------------------------------------
    for /f "tokens=2*" %%a in ('reg query "%VCRegKeyPath%" /v 14.0 /reg:32 2^>nul') do (
        set VCRoot=%%~b
        set msvc_ver=14
        goto Start_Build
    )

    for /f "tokens=2*" %%a in ('reg query "%VSRegKeyPath%" /v 14.0 /reg:32 2^>nul') do (
        set VSRoot=%%~b
        set msvc_ver=14
        goto Start_Build
    )

    REM --------------------------------------------------------------------------------------------
    REM Visual Studio 12.0
    REM --------------------------------------------------------------------------------------------
    for /f "tokens=2*" %%a in ('reg query "%VCRegKeyPath%" /v 12.0 /reg:32 2^>nul') do (
        set VCRoot=%%~b
        set msvc_ver=12
        goto Start_Build
    )

    for /f "tokens=2*" %%a in ('reg query "%VSRegKeyPath%" /v 12.0 /reg:32 2^>nul') do (
        set VSRoot=%%~b
        set msvc_ver=12
        goto Start_Build
    )

    REM --------------------------------------------------------------------------------------------
    REM Visual Studio 11.0
    REM --------------------------------------------------------------------------------------------
    for /f "tokens=2*" %%a in ('reg query "%VCRegKeyPath%" /v 11.0 /reg:32 2^>nul') do (
        set VCRoot=%%~b
        set msvc_ver=11
        goto Start_Build
    )

    for /f "tokens=2*" %%a in ('reg query "%VSRegKeyPath%" /v 11.0 /reg:32 2^>nul') do (
        set VSRoot=%%~b
        set msvc_ver=11
        goto Start_Build
    )

    REM --------------------------------------------------------------------------------------------
    REM Visual Studio 10.0
    REM --------------------------------------------------------------------------------------------
    for /f "tokens=2*" %%a in ('reg query "%VCRegKeyPath%" /v 10.0 /reg:32 2^>nul') do (
        set VCRoot=%%~b
        set msvc_ver=10
        goto Start_Build
    )

    for /f "tokens=2*" %%a in ('reg query "%VSRegKeyPath%" /v 10.0 /reg:32 2^>nul') do (
        set VSRoot=%%~b
        set msvc_ver=10
        goto Start_Build
    )

    REM --------------------------------------------------------------------------------------------
    REM Visual Studio 9.0
    REM --------------------------------------------------------------------------------------------
    for /f "tokens=2*" %%a in ('reg query "%VCRegKeyPath%" /v 9.0 /reg:32 2^>nul') do (
        set VCRoot=%%~b
        set msvc_ver=9
        goto Start_Build
    )

    for /f "tokens=2*" %%a in ('reg query "%VSRegKeyPath%" /v 9.0 /reg:32 2^>nul') do (
        set VSRoot=%%~b
        set msvc_ver=9
        goto Start_Build
    )
)

:Start_Build

if exist "%InstallDir%\VC\Auxiliary\Build\vcvarsall.bat" (
    call "%InstallDir%"\VC\Auxiliary\Build\vcvarsall.bat %msvc_arch%
) else if exist "%VSRoot%vcvarsall.bat" (
    call "%VSRoot%vcvarsall.bat %msvc_arch%"
) else if exist "%VCRoot%vcvarsall.bat" (
    call "%VCRoot%vcvarsall.bat %msvc_arch%"
) else if exist "%VSRoot%bin\vcvars%vimproc_arch%.bat" (
    call "%VSRoot%bin\vcvars%vimproc_arch%.bat"
) else if exist "%VCRoot%bin\vcvars%vimproc_arch%.bat" (
    call "%VCRoot%bin\vcvars%vimproc_arch%.bat"
) else (
    echo "Could not find the lower verison or the installation path of Visual C compiler!"
)

where nmake >nul 2>&1
if errorlevel 1 (
    echo nmake not found.
    goto :EOF
)

if %msvc_ver% geq 11 (
    nmake -f make_msvc.mak nodebug=1 CPU=%PROCESSOR_ARCHITECTURE% "SDK_INCLUDE_DIR=%ProgramFiles(x86)%\Microsoft SDKs\Windows\v7.1A\Include"
) else (
    nmake -f make_msvc.mak nodebug=1 CPU=%PROCESSOR_ARCHITECTURE%
)

if errorlevel 1 (
    rem Build failed, then clean the generated files.
    nmake -f make_msvc.mak clean
)

