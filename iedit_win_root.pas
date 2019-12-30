module iedit_win_root;
define iedit_win_root_init;
%include 'iedit.ins.pas';
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_ROOT_DRAW (WIN, APP_P)
*
*   Drawing routine for the root window.  This routine is called automatically
*   from the GUI library when appropriate.
}
procedure iedit_win_root_draw (        {drawing routine for root window}
  in out  win: gui_win_t;              {window to draw}
  in      app_p: univ_ptr);            {pointer to arbitrary application data}
  val_param; internal;

begin
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_ROOT_INIT
*
*   Create the root window and everything subortinate to it.  Since this is the
*   root window, all drawing is subordinate to it.
}
procedure iedit_win_root_init;

begin
  gui_win_root (win_root);             {create the root GUI window}

  gui_win_set_draw (                   {set drawing routine for root window}
    win_root, univ_ptr(addr(iedit_win_root_draw)));

  iedit_win_menu_init;                 {create main menu window}
  iedit_win_msg_init;                  {create message line window}
  iedit_win_op_create;                 {create operations window}
  iedit_win_img_create;                {create image display window}
  windows := true;                     {GUI windows now exist}
  end;
