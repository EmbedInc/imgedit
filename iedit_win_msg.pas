module iedit_win_msg;
define iedit_win_msg_init;
define iedit_msg_vstr;
define iedit_msg_message;
define iedit_win_msg;
%include 'iedit.ins.pas';

var
  win: gui_win_t;                      {window handled by this module}
  tp: rend_text_parms_t;               {local copy of text drawing parameters}

var (iedit_win_msg)                    {statically initialized state}
  msg:                                 {message string}
    %include '(cog)lib/string132.ins.pas';
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_MSG_DRAW (WIN, APP_P)
*
*   Drawing routine for the root window.  This routine is called automatically
*   from the GUI library when appropriate.
}
procedure iedit_win_msg_draw (         {drawing routine for root window}
  in out  win: gui_win_t;              {window to draw}
  in      app_p: univ_ptr);            {pointer to arbitrary application data}
  val_param; internal;

begin
  rend_set.text_parms^ (tp);

  rend_set.rgb^ (0.80, 0.80, 0.30);    {clear to background color}
  rend_prim.clear_cwind^;

  rend_set.rgb^ (0.0, 0.0, 0.0);       {draw the message string}
  rend_set.cpnt_2d^ (twide * 0.70, win.rect.dy / 2.0);
  rend_prim.text^ (msg.str, msg.len);
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_MSG_INIT
}
procedure iedit_win_msg_init;
  val_param;

begin
  tp := tparm;                         {make local copy of text drawing parms}
  tp.start_org := rend_torg_ml_k;

  gui_win_child (                      {create this window}
    win,                               {returned window object}
    win_root,                          {parent window}
    0.0, y_msg1,                       {lower left corner in parent window}
    win_root.rect.dx, y_msg2 - y_msg1); {displacement to upper right corner}

  gui_win_set_draw (                   {install drawing routine for this window}
    win,
    univ_ptr(addr(iedit_win_msg_draw)));
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_MSG_VSTR (STR)
*
*   Set the status message to the var string STR.
}
procedure iedit_msg_vstr (             {set status message string}
  in      str: univ string_var_arg_t); {the message to display}
  val_param;

begin
  string_copy (str, msg);              {save the new message string}
  gui_win_draw_all (win);              {redraw the message window}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_MSG_MESSAGE (SUBSYS, MSG, PARMS, N_PARMS)
*
*   Set the status line text from a message file message.
}
procedure iedit_msg_message (          {set status line from message file message}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name withing subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  val_param;

var
  str: string_var256_t;

begin
  str.max := size_char(str.str);       {init local var string}

  string_f_message (str, subsys, msg, parms, n_parms); {get message string}
  iedit_msg_vstr (str);                {set it as new status text}
  end;
