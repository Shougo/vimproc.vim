@echo off
rem Update the DLL using MinGW.
rem If the old DLL is in use, rename it to avoid compilation error.
rem
rem usage: update-dll-mingw [arch] [makeopts]
rem
rem   [arch] is 32 or 64. If omitted, 32 is used.
rem   [makeopts] is option(s) for mingw32-make.
rem
rem
rem Sample .vimrc:
rem
rem let vimproc_updcmd = has('win64') ?
rem   \ 'tools\\update-dll-mingw 64' : 'tools\\update-dll-mingw 32'
rem execute "NeoBundle 'Shougo/vimproc.vim'," . string({
rem 	\ 'build' : {
rem 		\     'windows' : vimproc_updcmd,
rem 		\     'cygwin' : 'make -f make_cygwin.mak',
rem 		\     'mac' : 'make -f make_mac.mak',
rem 		\     'unix' : 'make -f make_unix.mak',
rem 		\    },
rem 		\ })

if "%1"=="32" (
  set vimproc_arch=%1
  shift
) else if "%1"=="64" (
  set vimproc_arch=%1
  shift
) else (
  set vimproc_arch=32
)
set vimproc_dllname=vimproc_win%vimproc_arch%.dll

mingw32-make -f make_mingw%vimproc_arch%.mak %1 %2 %3 %4 %5 %6 %7 %8 %9
if ERRORLEVEL 1 (
  rem Build failed.

  rem Try to delete old DLLs.
  if exist autoload\%vimproc_dllname%.old del autoload\%vimproc_dllname%.old
  if exist autoload\%vimproc_dllname%     del autoload\%vimproc_dllname%
  rem If the DLL couldn't delete (may be it is in use), rename it.
  if exist autoload\%vimproc_dllname%     ren autoload\%vimproc_dllname% %vimproc_dllname%.old

  mingw32-make -f make_mingw%vimproc_arch%.mak %1 %2 %3 %4 %5 %6 %7 %8 %9
)
