module iedit_win_menu;
define iedit_win_menu_init;
%include 'image_edit.ins.pas';

type
  id_k_t = sys_int_machine_t (         {IDs for the menu entries}
    id_file_k = 0,
    id_crop_k = 1,
    id_colors_k = 2,
    id_out_k = 3,
    id_disp_k = 4);

var
  win_menu: gui_win_t;                 {GUI window for the main menu}
  menu: gui_menu_t;                    {main menu object}
{
*************************************************************************
*
*   Function IEDIT_WIN_MENU_EVHAN (WIN, APP_P)
*
*   Event handler for parent window of main menu.
}
function iedit_win_menu_evhan (        {main menu parent window event handler}
  in out  win: gui_win_t;              {window to handle events for}
  in      app_p: univ_ptr)             {application pointer, unused}
  :gui_evhan_k_t;                      {completion status}
  val_param; internal;

var
  iid: sys_int_machine_t;              {integer menu entry ID}
  sel_p: gui_menent_p_t;               {pointer to selected menu entry}
  ulx, uly: real;                      {UL corner of subordinate menus in main win}

begin
  if not gui_menu_select (menu, iid, sel_p) then begin {no selection made ?}
    iedit_win_menu_evhan := menu.evhan; {pass back event handling status}
    return;
    end;
  iedit_win_menu_evhan := gui_evhan_did_k; {events were processed and handled}

  ulx := trunc(sel_p^.xl);             {set UL in main win for any subordinate menus}
  uly := y_men1;
{
*   The user selected a menu entry.  IID is the integer ID of the menu
*   entry, and SEL_P is pointing to the selected menu entry descriptor.
}
  case id_k_t(iid) of                  {which entry was selected ?}

id_file_k: begin                       {FILE}
      iedit_win_menu_evhan := iedit_menu_file (ulx, uly);
      end;

id_disp_k: begin                       {DISPLAY}
      iedit_win_menu_evhan := iedit_menu_disp (ulx, uly);
      end;

id_crop_k: begin                       {CROP}
      iedit_win_menu_evhan := iedit_menu_crop (ulx, uly);
      end;

id_colors_k: begin                     {COLORS}
      iedit_win_menu_evhan := iedit_menu_colors (ulx, uly);
      end;

id_out_k: begin                        {OUT}
      iedit_win_menu_evhan := iedit_menu_out (ulx, uly);
      end;

    end;                               {end of selected menu entry cases}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_MENU_INIT
}
procedure iedit_win_menu_init;
  val_param;

var
  tp: rend_text_parms_t;               {local copy of text control parameters}

begin
  gui_win_child (                      {create the window managed by this module}
    win_menu,                          {returned window}
    win_root,                          {parent window}
    0.0, y_men1,                       {lower left in parent window}
    win_root.rect.dx, y_men2 - y_men1); {displacement from corner}
  gui_win_set_evhan (win_menu,         {install event handler for this window}
    univ_ptr(addr(iedit_win_menu_evhan)));

  tp := tparm;                         {temp set text parameters for the menu}
  tp.lspace := 1.0;
  rend_set.text_parms^ (tp);

  gui_menu_create (menu, win_menu);    {create the main menu object}
  gui_menu_setup_top (menu);           {configure it as permanent top level menu}
  menu.flags :=                        {set menu to fill parent window}
    menu.flags + [gui_menflag_fill_k];
  iedit_menu_add_msg (                 {fill in menu entries from message}
    menu, 'img', 'iedit_menu', nil, 0);
  gui_menu_drawable (menu);            {add menu to redraw list}

  rend_set.text_parms^ (tparm);        {restore official text control parameters}
  end;
