@echo off
rem Update the DLL using MSVC.
rem If the old DLL is in use, rename it to avoid compilation error.
rem current support version of Visual C compiler is from 2005 to 2019
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

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set vimproc_arch=64
) else (
    set vimproc_arch=32
)

set vimproc_dllname=vimproc_win%vimproc_arch%.dll

if exist "%~dp0vswhere.exe" (
    REM  found the lasted version of Visual C compiler
    for /f "usebackq tokens=*" %%i in (`"%~dp0vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do (
        set InstallDir=%%i

        if exist "%InstallDir%\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt" (
            set /p msvc_ver=<"%InstallDir%\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt"

            rem Trim
            set msvc_ver=!msvc_ver: =!
        )

        if exist "%InstallDir%\VC\Auxiliary\Build\vcvars%vimproc_arch%.bat" (
            call "%InstallDir%\VC\Auxiliary\Build\vcvars%vimproc_arch%.bat"
        )
    )
) else if defined VS140COMNTOOLS (
    REM  Microsoft Visual Studio 2015 installed
    set msvc_ver=14
    call "%VS140COMNTOOLS%\..\..\VC\bin\vcvars%vimproc_arch%.bat"
) else if defined VS120COMNTOOLS (
    REM  Microsoft Visual Studio 2013 installed
    set msvc_ver=12
    call "%VS120COMNTOOLS%\..\..\VC\bin\vcvars%vimproc_arch%.bat"
) else if defined VS110COMNTOOLS (
    REM  Microsoft Visual Studio 2012 installed
    set msvc_ver=11
    call "%VS110COMNTOOLS%\..\..\VC\bin\vcvars%vimproc_arch%.bat"
) else if defined VS100COMNTOOLS (
    REM  Microsoft Visual Studio 2010 installed
    set msvc_ver=10
    call "%VS100COMNTOOLS%\..\..\VC\bin\vcvars%vimproc_arch%.bat"
) else if defined VS90COMNTOOLS (
    REM  Microsoft Visual Studo 2008 installed
    set msvc_ver=9
    call "%VS90COMNTOOLS%\..\..\VC\bin\vcvars%vimproc_arch%.bat"
) else if defined VS80COMNTOOLS (
    REM  Microsoft Visual Studio 2005 installed
    set msvc_ver=8
    call "%VS80COMNTOOLS%\..\..\VC\bin\vcvars%vimproc_arch%.bat"
) else if defined VS71COMNTOOLS (
    REM  Microsoft Visual C++ .NET 2003 installed
    set msvc_ver=7
    call "%VS71COMNTOOLS%\..\..\VC\bin\vcvars%vimproc_arch%.bat"
) else if defined VS70COMNTOOLS (
    REM  Microsoft Visual C++ .NET 2002 installed
    set msvc_ver=7
    call "%VS70COMNTOOLS%\..\..\VC\bin\vcvars%vimproc_arch%.bat"
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio 14.0\VC\bin\vcvars%vimproc_arch%.bat" (
    REM  Microsoft Visual C++ 2015 Express installed
    set msvc_ver=14
    call "%ProgramFiles(x86)%\Microsoft Visual Studio 14.0\VC\bin\vcvars%vimproc_arch%.bat"
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio 12.0\VC\bin\vcvars%vimproc_arch%.bat" (
    REM  Microsoft Visual C++ 2013 Express installed
    set msvc_ver=12
    call "%ProgramFiles(x86)%\Microsoft Visual Studio 12.0\VC\bin\vcvars%vimproc_arch%.bat"
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio 11.0\VC\bin\vcvars%vimproc_arch%.bat" (
    REM  Microsoft Visual C++ 2012 Express installed
    set msvc_ver=11
    call "%ProgramFiles(x86)%\Microsoft Visual Studio 11.0\VC\bin\vcvars%vimproc_arch%.bat"
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio 10.0\VC\bin\vcvars%vimproc_arch%.bat" (
    REM  Microsoft Visual C++ 2010 Express installed
    set msvc_ver=10
    call "%ProgramFiles(x86)%\Microsoft Visual Studio 10.0\VC\bin\vcvars%vimproc_arch%.bat"
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio 9.0\VC\bin\vcvars%vimproc_arch%.bat" (
    REM  Microsoft Visual C++ 2008 Express installed
    set msvc_ver=9
    call "%ProgramFiles(x86)%\Microsoft Visual Studio 9.0\VC\bin\vcvars%vimproc_arch%.bat"
    nmake -f make_msvc.mak nodebug=1 CPU=%PROCESSOR_ARCHITECTURE% 
) else if exist "%ProgramFiles(x86)%\Microsoft Visual Studio 8\VC\bin\vcvars%vimproc_arch%.bat" (
    REM  Microsoft Visual C++ 2005 Express installed
    set msvc_ver=8
    call "%ProgramFiles(x86)%\Microsoft Visual Studio 8\VC\bin\vcvars%vimproc_arch%.bat"
) else (
    echo Warning: Could not find the lower version or environment variables for Visual Studio
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
    rem Build failed.

    rem Try to delete old DLLs.
    if exist lib\%vimproc_dllname%.old del lib\%vimproc_dllname%.old
    if exist lib\%vimproc_dllname%     del lib\%vimproc_dllname%
    rem If the DLL couldn't delete (may be it is in use), rename it.
    if exist lib\%vimproc_dllname%     ren lib\%vimproc_dllname% %vimproc_dllname%.old

    if %msvc_ver% geq 11 (
        nmake -f make_msvc.mak nodebug=1 CPU=%PROCESSOR_ARCHITECTURE% "SDK_INCLUDE_DIR=%ProgramFiles(x86)%\Microsoft SDKs\Windows\v7.1A\Include"
    ) else (
        nmake -f make_msvc.mak nodebug=1 CPU=%PROCESSOR_ARCHITECTURE% 
    )
)

