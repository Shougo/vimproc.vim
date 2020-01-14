@echo off
rem Update the DLL using MSVC.
rem If the old DLL is in use, rename it to avoid compilation error.
rem
rem usage: update-dll-msvc [arch] [makeopts]
rem
rem   [arch] is 32 or 64. If omitted, it is automatically detected from the
rem   %PROCESSOR_ARCHITECTURE% environment.
rem   [makeopts] is option(s) for nmake.
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

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set vimproc_arch=64
    set cpu_arch=AMD64
    set msvc_arch=amd64
) else (
    set vimproc_arch=32
    set cpu_arch=x86
    set msvc_arch=x86
)

set vimproc_dllname=vimproc_win%vimproc_arch%.dll


call "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" %msvc_arch%
where nmake >nul 2>&1
if ERRORLEVEL 1 (
    echo nmake not found.
    goto :EOF
)

nmake -f make_msvc.mak nodebug=1 CPU=%cpu_arch% "SDK_INCLUDE_DIR=C:\Program Files (x86)\Microsoft SDKs\Windows\v7.1A\Include"

if ERRORLEVEL 1 (
    rem Build failed.

    rem Try to delete old DLLs.
    if exist lib\%vimproc_dllname%.old del lib\%vimproc_dllname%.old
    if exist lib\%vimproc_dllname%     del lib\%vimproc_dllname%
    rem If the DLL couldn't delete (may be it is in use), rename it.
    if exist lib\%vimproc_dllname%     ren lib\%vimproc_dllname% %vimproc_dllname%.old

    nmake -f make_msvc.mak nodebug=1 CPU=%cpu_arch% "SDK_INCLUDE_DIR=C:\Program Files (x86)\Microsoft SDKs\Windows\v7.1A\Include"
)

