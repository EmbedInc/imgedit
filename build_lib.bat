@echo off
rem
rem   BUILD_LIB
rem
rem   Build the IMGEDIT library.
rem
setlocal
call build_pasinit

call src_pas %srcdir% %libname%_color
call src_pas %srcdir% %libname%_drag
call src_pas %srcdir% %libname%_menu_colors
call src_pas %srcdir% %libname%_menu_col_whbal
call src_pas %srcdir% %libname%_menu_crop
call src_pas %srcdir% %libname%_menu_disp
call src_pas %srcdir% %libname%_menu_file
call src_pas %srcdir% %libname%_menu_out
call src_pas %srcdir% %libname%_open
call src_pas %srcdir% %libname%_out
call src_pas %srcdir% %libname%_resize
call src_pas %srcdir% %libname%_text
call src_pas %srcdir% %libname%_util
call src_pas %srcdir% %libname%_win_img
call src_pas %srcdir% %libname%_win_menu
call src_pas %srcdir% %libname%_win_msg
call src_pas %srcdir% %libname%_win_op
call src_pas %srcdir% %libname%_win_root

call src_lib %srcdir% %libname% private
