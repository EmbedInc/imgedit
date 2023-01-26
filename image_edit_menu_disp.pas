module iedit_menu_disp;
define iedit_menu_disp;
%include 'image_edit.ins.pas';
{
********************************************************************************
*
*   Function IEDIT_MENU_DISP (ULX, ULY)
*
*   Process events for the DISPLAY top level menu.  This routine is called from
*   the top level menu events handler when the DISPLAY entry is selected.  The
*   top level menu event handler will return with whatever this routine returns
*   with.
}
function iedit_menu_disp (             {handle events for DISPLAY selected}
  in    ulx, uly: real)                {preferred UL corner of subordinate menu}
  :gui_evhan_k_t;                      {returned event handling status}

var
  tp: rend_text_parms_t;               {local copy of text control parameters}
  menu: gui_menu_t;                    {DISPLAY menu}
  id: sys_int_machine_t;               {ID of selected menu entry}
  sel_p: gui_menent_p_t;               {points to selected menu entry}
  tk: string_var32_t;                  {scratch token}
  str: string_var32_t;

label
  loop_select, leave;

begin
  tk.max := size_char(tk.str);         {init local var strings}
  str.max := size_char(str.str);
  iedit_menu_disp := gui_evhan_did_k;  {init to events were processed}

  tp := tparm;                         {temp set text parameters for the menu}
  tp.lspace := 1.0;
  rend_set.text_parms^ (tp);

  gui_menu_create (menu, win_root);    {create this menu}
  iedit_menu_add_msg (menu, 'img', 'iedit_menu_display', nil, 0);
  gui_menu_place (menu, ulx - 2, uly); {set menu location}

  rend_set.text_parms^ (tparm);        {restore default text parameters}

loop_select:                           {back here each new menu entry selection}
  if not gui_menu_select (menu, id, sel_p) then begin {menu cancelled ?}
    goto leave;
    end;
  gui_menu_delete (menu);              {delete the menu}
  case id of                           {which menu entry was selected ?}
{
****************************************
*
*   DISPLAY > FAST
}
1: begin
  if disp_aa then begin
    disp_aa := false;                  {display nearest pixel}
    iedit_win_img_ncache;
    iedit_win_img_update;
    end;
  end;
{
****************************************
*
*   DISPLAY > SMOOTH
}
2: begin
  if not disp_aa then begin
    disp_aa := true;                   {display nearest pixel}
    iedit_win_img_ncache;
    iedit_win_img_update;
    end;
  end;
{
****************************************
*
*   DISPLAY > ROT RIGHT
}
3: begin
  roti := roti - 1;
  if roti < 0 then roti := 3;

  string_vstring (str, 'ROTI = '(0), -1);
  string_f_int (tk, roti);
  string_append (str, tk);
  iedit_msg_vstr (str);

  iedit_win_img_ncache;
  iedit_win_img_update;
  end;
{
****************************************
*
*   DISPLAY > ROT LEFT
}
4: begin
  roti := roti + 1;
  if roti > 3 then roti := 0;

  string_vstring (str, 'ROTI = '(0), -1);
  string_f_int (tk, roti);
  string_append (str, tk);
  iedit_msg_vstr (str);

  iedit_win_img_ncache;
  iedit_win_img_update;
  end;
{
****************************************
}
    end;                               {end of menu entry ID cases}

leave:                                 {common exit point}
  end;
