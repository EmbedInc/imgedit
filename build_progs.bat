@echo off
rem
rem   BUILD_PROGS
rem
rem   Build the executable programs from this source directory.
rem
setlocal
call build_pasinit

call src_pas %srcdir% image_edit
call src_link image_edit image_edit iedit.lib
call src_exeput image_edit

