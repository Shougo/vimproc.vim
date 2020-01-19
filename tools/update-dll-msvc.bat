@echo off
rem Update the DLL using MSVC.
rem If the old DLL is in use, rename it to avoid compilation error.
rem current support version of Visual C compiler is 2010 and upper version
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

setlocal enabledelayedexpansion

rem detect the cpu architecture is 32 bit or 64 bit processor
reg query "HKLM\Hardware\Description\System\CentralProcessor\0" /v "Identifier" | find /i "x86" > NUL && set cpu_arch=i386 || set cpu_arch=AMD64

rem --------------------------------------------------------------------------------------------
rem  See https://docs.microsoft.com/zh-cn/archive/blogs/david.wang/howto-detect-process-bitness
rem  In an ideal world, everything runs as native bitness (64bit program on 64bit OS, 
rem  32bit program on 32bit OS) and life goes on. However, sometimes you need to run 
rem  that legacy 32bit program on a 64bit OS and need to configure things a little 
rem  differently as a result. How can you detect this WOW64 case (32bit program on 64bit OS) 
rem  and act appropriately?
rem
rem  Detection Matrix
rem  The general idea is to check the following environment variables:
REM
rem  PROCESSOR_ARCHITECTURE - reports the native processor architecture EXCEPT for WOW64, where it reports x86.
rem  PROCESSOR_ARCHITEW6432 - not used EXCEPT for WOW64, where it reports the original native processor architecture.
rem
rem  Visually, it looks like:
REM
rem  Environment Variable\Program Bitness	32bit Native	64bit Native	WOW64
rem  PROCESSOR_ARCHITECTURE	                x86	            AMD64	        x86
rem  PROCESSOR_ARCHITEW6432	                undefined	    undefined	    AMD64
rem
rem  WOW64 = 32bit Program on 64bit OS
rem --------------------------------------------------------------------------------------------
set vimproc_arch=64
set msvc_arch=x86_amd64
if "%PROCESSOR_ARCHITECTURE%"=="x86" (if not defined PROCESSOR_ARCHITEW6432 set "vimproc_arch=32" & set "msvc_arch=x86")

set vimproc_dllname=vimproc_win%vimproc_arch%.dll

rem --------------------------------------------------------------------------------------------
rem Determine which registry keys to look at based on architecture type.
rem --------------------------------------------------------------------------------------------
if "%vimproc_arch%"=="64" (
    set VCRegKeyPath=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\SxS\VC7
    set VSRegKeyPath=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\SxS\VS7
    rem Visual Studio 2010 Express edition need to work with Windows SDK 7.1 if the msvc_arch is x86_amd64
    set WinSDKRegKeyPath=HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\Windows\v7.1
)    else (
    set VCRegKeyPath=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\SxS\VC7
    set VSRegKeyPath=HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\SxS\VS7
    rem Visual Studio 2010 Express edition need to work with Windows SDK 7.1 if the msvc_arch is x86_amd64
    set WinSDKRegKeyPath=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1
)

if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
    rem --------------------------------------------------------------------------------------------
    rem  found the lasted version of Visual C compiler, which start from 2017
    rem --------------------------------------------------------------------------------------------
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        set InstallDir=%%i
        if exist "!InstallDir!\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt" (
            set /p msvc_ver=<"!InstallDir!\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt"

            rem Trim
            set msvc_ver=!msvc_ver: =!
        )
        call "!InstallDir!\VC\Auxiliary\Build\vcvarsall.bat" %msvc_arch%
        goto Start_Build
    )
) else (
    rem --------------------------------------------------------------------------------------------
    rem found the version of Visual C compiler which version is lower than 2017
    rem --------------------------------------------------------------------------------------------

    rem --------------------------------------------------------------------------------------------
    rem Read the value for VCRoot and VSRoot from the registry.
    rem Note: These calls to reg are checking to see if VS or VC is installed in a custom location. 
    rem --------------------------------------------------------------------------------------------

    rem --------------------------------------------------------------------------------------------
    rem Visual Studio 14.0
    rem --------------------------------------------------------------------------------------------
    for /f "tokens=2*" %%a in ('reg query "%VCRegKeyPath%" /v 14.0 /reg:32 2^>nul') do (
        set VCRoot=%%~b
        set msvc_ver=14
        call "!VCRoot!vcvarsall.bat" %msvc_arch%
        goto Start_Build
    )
    rem --------------------------------------------------------------------------------------------
    rem Visual Studio 12.0
    rem --------------------------------------------------------------------------------------------
    for /f "tokens=2*" %%a in ('reg query "%VCRegKeyPath%" /v 12.0 /reg:32 2^>nul') do (
        set VCRoot=%%~b
        set msvc_ver=12
        call "!VCRoot!vcvarsall.bat" %msvc_arch%
        goto Start_Build
    )

    rem --------------------------------------------------------------------------------------------
    rem Visual Studio 11.0
    rem --------------------------------------------------------------------------------------------
    for /f "tokens=2*" %%a in ('reg query "%VCRegKeyPath%" /v 11.0 /reg:32 2^>nul') do (
        set VCRoot=%%~b
        set msvc_ver=11
        call "!VCRoot!vcvarsall.bat" %msvc_arch%
        goto Start_Build
    )

    rem --------------------------------------------------------------------------------------------
    rem Visual Studio 10.0
    rem --------------------------------------------------------------------------------------------
    for /f "tokens=2*" %%a in ('reg query "%VSRegKeyPath%" /v 10.0 /reg:32 2^>nul') do (
        set VSRoot=%%~b
        set msvc_ver=10
        call "!VSRoot!VC\vcvarsall.bat" %msvc_arch%
        goto Start_Build
    )

    for /f "tokens=2*" %%a in ('reg query "%VCRegKeyPath%" /v 10.0 /reg:32 2^>nul') do (
        set VCRoot=%%~b
        set msvc_ver=10
        rem Don't use VS100COMNTOOLS to check whether is Visual Studio 2010 Express edition,
        rem because the environment variable VS100COMNTOOLS will also be defined if only install
        rem Express edition.
        if "x!VSRoot!"=="x" (
            rem Visual Studio 2010 Express Edition
            if %msvc_arch%=="x86" (
                call "!VCRoot!vcvarsall.bat" %msvc_arch%
                goto Start_Build
            ) else (
                rem vcvarsx86_amd64.bat is missing from VC++ 2010 Express / Windows SDK 7.1
                for /f "tokens=2*" %%a in ('reg query "%WinSDKRegKeyPath%" /v InstallationFolder /reg:32 2^>nul') do (
                    set WindowsSDKDir=%%~b
                )
                if exist "!WindowsSDKDir!bin\SetEnv.cmd" (
                    call "!WindowsSDKDir!bin\SetEnv.cmd" /Release /x64
                ) else (
                    rem no Windows SDK 7.1 installed but also request to build with x86_amd64 architecture option
                    echo "vcvarsx86_amd64.bat is missing from VC++ 2010 Express / Windows SDK 7.1" 
                )
                goto Start_Build
            )
        ) else (
            rem Visual Studio 2010 IDE Edition
            call "!VCRoot!vcvarsall.bat" %msvc_arch%
            goto Start_Build
        )
    )
)

:Start_Build
where nmake >nul 2>&1
if errorlevel 1 (
    echo nmake not found.
    goto :eof
)

if %msvc_ver% geq 11 (
    nmake -f make_msvc.mak nodebug=1 CPU=%cpu_arch% "SDK_INCLUDE_DIR=%ProgramFiles(x86)%\Microsoft SDKs\Windows\v7.1A\Include"
) else (
    nmake -f make_msvc.mak nodebug=1 CPU=%cpu_arch% 
)

if errorlevel 1 (
    rem Build failed.

    rem Try to delete old DLLs.
    if exist lib\%vimproc_dllname%.old del lib\%vimproc_dllname%.old
    if exist lib\%vimproc_dllname%     del lib\%vimproc_dllname%
    rem If the DLL couldn't delete (may be it is in use), rename it.
    if exist lib\%vimproc_dllname%     ren lib\%vimproc_dllname% %vimproc_dllname%.old

    if %msvc_ver% geq 11 (
        nmake -f make_msvc.mak nodebug=1 CPU=%cpu_arch% "SDK_INCLUDE_DIR=%ProgramFiles(x86)%\Microsoft SDKs\Windows\v7.1A\Include"
    ) else (
        nmake -f make_msvc.mak nodebug=1 CPU=%cpu_arch% 
    )
)

