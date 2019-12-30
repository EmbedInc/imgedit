module iedit_menu_file;
define iedit_menu_file;
%include 'iedit.ins.pas';
{
********************************************************************************
*
*   Function IEDIT_MENU_FILE (ULX, ULY)
*
*   Process events for the FILE top level menu.  This routine is called from the
*   top level menu events handler when the FILE entry is selected.  The top
*   level menu event handler will return with whatever this routine returns
*   with.
}
function iedit_menu_file (             {handle events for FILE selected}
  in    ulx, uly: real)                {preferred UL corner of subordinate menu}
  :gui_evhan_k_t;                      {returned event handling status}

var
  tp: rend_text_parms_t;               {local copy of text control parameters}
  menu: gui_menu_t;                    {FILE menu}
  id: sys_int_machine_t;               {ID of selected menu entry}
  sel_p: gui_menent_p_t;               {points to selected menu entry}
  ent: gui_enter_t;                    {string entry object}
  resp: string_var8192_t;              {user response string}
  err: string_var1024_t;               {error string}
  ev: rend_event_t;                    {RENDlib event}

label
  loop_select, leave;

begin
  resp.max := size_char(resp.str);     {init local var strings}
  err.max := size_char(err.str);
  iedit_menu_file := gui_evhan_did_k;  {init to events were processed}

  tp := tparm;                         {temp set text parameters for the menu}
  tp.lspace := 1.0;
  rend_set.text_parms^ (tp);

  gui_menu_create (menu, win_root);    {create this menu}
  iedit_menu_add_msg (menu, 'img', 'iedit_menu_file', nil, 0);
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
*   FILE > OPEN
}
2: begin
  gui_enter_create_msg (               {create file name entry object}
    ent,                               {user entry object to create}
    win_img,                           {parent window}
    intnam,                            {seed string}
    'img', 'iedit_open_fnam', nil, 0); {prompt message}
  err.len := 0;                        {no error to show user}
  if not gui_enter_get(ent, err, resp) then begin {user cancelled ?}
    goto leave;
    end;
  gui_enter_delete (ent);              {done with the user entry object}

  string_copy (resp, intnam);          {make this response default for next}
  iedit_open (resp);                   {open the new input image}
  end;
{
****************************************
*
*   FILE > EXIT
}
1: begin
  ev.ev_type := rend_ev_close_user_k;  {create user close request event}
  ev.dev := rendev;
  rend_event_push (ev);                {add the event to the head of the queue}
  end;
{
****************************************
}
    end;                               {end of menu entry ID cases}

leave:                                 {common exit point}
  end;
