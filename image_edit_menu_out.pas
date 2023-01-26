module iedit_menu_out;
define iedit_menu_out;
%include 'image_edit.ins.pas';
{
********************************************************************************
*
*   Function IEDIT_MENU_OUT (ULX, ULY)
*
*   Process events for the OUT top level menu.  This routine is called from the
*   top level menu events handler when the OUT entry is selected.  The top level
*   menu event handler will return with whatever this routine returns with.
}
function iedit_menu_out (              {handle events for OUT top menu entry}
  in    ulx, uly: real)                {preferred UL corner of subordinate menu}
  :gui_evhan_k_t;                      {returned event handling status}

var
  tp: rend_text_parms_t;               {local copy of text control parameters}
  menu: gui_menu_t;                    {our sub-menu}
  men2: gui_menu_t;                    {next layer down sub-menu}
  id: sys_int_machine_t;               {ID of selected menu entry}
  sel_p: gui_menent_p_t;               {points to selected menu entry}
  ent: gui_enter_t;                    {string entry object}
  resp: string_var8192_t;              {user response string}
  i1: sys_int_machine_t;               {integer user entry value}
  r1: real;                            {floating point user entry value}
  tk: string_var32_t;                  {scratch token}
  err: string_var1024_t;               {error string}
  p: string_index_t;                   {parse index}
  conf: boolean;                       {action was confirmed, not cancelled}
  stat: sys_err_t;

label
  done_select, leave;

begin
  resp.max := size_char(resp.str);     {init local var strings}
  tk.max := size_char(tk.str);
  err.max := size_char(err.str);
  iedit_menu_out := gui_evhan_did_k;   {init to events were processed}

  if opmode <> opmode_out_k then begin
    opmode := opmode_out_k;            {switch to OUT operation mode}
    iedit_win_op_update;               {refresh the OP window}
    end;

  tp := tparm;                         {temp set text parameters for the menu}
  tp.lspace := 1.0;
  rend_set.text_parms^ (tp);
  gui_menu_create (menu, win_root);    {create this menu}
  iedit_menu_add_msg (menu, 'img', 'iedit_menu_out', nil, 0);
  sel_p := menu.first_p;
  while sel_p <> nil do begin
    if sel_p^.id = 1 then begin
      sel_p^.flags :=                  {indicate this entry brings up another level}
        sel_p^.flags + [gui_entflag_nlevel_k];
      end;
    sel_p := sel_p^.next_p;
    end;

  gui_menu_place (menu, ulx - 2, uly); {set menu location}
  rend_set.text_parms^ (tparm);        {restore default text parameters}
  if not gui_menu_select (menu, id, sel_p) then begin {menu cancelled ?}
    goto leave;
    end;
  case id of                           {which menu entry was selected ?}
{
****************************************
*
*   OUT > IMAGE TYPE
}
1: begin
  gui_menu_create (men2, win_root);    {create the image types submenu}
  men2.flags := men2.flags + [gui_menflag_selsel_k]; {init to first selected entry}

  gui_menu_ent_add_str (               {add menu entry for getting suffix from file name}
    men2,                              {menu to add entry to}
    '- from filename -'(0),            {menu entry string to display}
    0,                                 {no shortcut key}
    0);                                {ID to return when this entry selected}
  if out_itype.len = 0 then begin      {this selection is the current setting ?}
    men2.last_p^.flags :=              {init this entry to selected}
      men2.last_p^.flags + [gui_entflag_selected_k];
    end;

  img_list_types ([file_rw_write_k], resp); {get list of image file suffix names}
  p := 1;                              {init suffixes parse index}
  id := 1;                             {init ID of next suffix to add to menu}
  while true do begin                  {back here each new image file suffix}
    string_token (resp, p, tk, stat);  {get next image file suffix}
    if sys_error(stat) then exit;
    gui_menu_ent_add (men2, tk, 0, id); {add this suffix as menu choice}
    if string_equal (tk, out_itype) then begin {this is the current setting ?}
      men2.last_p^.flags :=            {init this entry to selected}
        men2.last_p^.flags + [gui_entflag_selected_k];
      end;
    id := id + 1;                      {make ID for next time}
    end;                               {back to get next image output file suffix}

  gui_menu_place (                     {set submenu location}
    men2,                              {the menu to place}
    sel_p^.xr + menu.win.rect.x,       {X within parent window}
    sel_p^.yt + menu.win.rect.y + 2);  {Y within parent window}
  conf := gui_menu_select (men2, id, sel_p); {get submenu selection from the user}
  if conf then begin
    string_copy (sel_p^.name_p^, out_itype); {save menu entry string selected by user}
    if id = 0 then out_itype.len := 0; {get type from filename was selected ?}
    gui_menu_delete (men2);            {delete the submenu}
    iedit_win_op_update;
    end;
  gui_menu_delete (menu);              {delete the original menu}
  end;
{
****************************************
*
*   OUT > BITS/COLOR
}
2: begin
  gui_menu_delete (menu);              {delete the menu}

  string_f_int (resp, out_bits);       {make seed string with current value}
  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_out_bits', nil, 0); {prompt message info}
  err.len := 0;                        {init to no error message}
  if not gui_enter_get_int (ent, err, i1) then goto done_select;
  gui_enter_delete (ent);              {delete the user entry object}
  out_bits := i1;                      {set the new bits/color/pixel}

  iedit_win_op_update;
  end;
{
****************************************
*
*   OUT > QUALITY
}
3: begin
  gui_menu_delete (menu);              {delete the menu}

  string_f_fp_fixed (resp, out_qual, 0); {make seed string with current value}
  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_out_qual', nil, 0); {prompt message info}
  err.len := 0;                        {init to no error message}
  if not gui_enter_get_fp (ent, err, r1) then goto done_select;
  gui_enter_delete (ent);              {delete the user entry object}
  out_qual := r1;                      {set new output quality percent}

  iedit_win_op_update;
  end;
{
****************************************
*
*   OUT > SAVE
}
4: begin
  gui_menu_delete (menu);              {delete the menu}

  gui_enter_create_msg (               {create file name entry object}
    ent,                               {user entry object to create}
    win_img,                           {parent window}
    out_tnam,                          {seed string}
    'img', 'iedit_out_fnam', nil, 0);  {prompt message}
  err.len := 0;                        {no error to show user}
  if not gui_enter_get(ent, err, resp) then begin {user cancelled ?}
    goto done_select;
    end;

  gui_enter_delete (ent);              {done with the user entry object}
  string_copy (resp, out_tnam);        {update image output file name}
  iedit_out_write;                     {write the output image}
  end;
{
****************************************
}
otherwise
    gui_menu_delete (menu);            {delete the menu}
    end;                               {end of menu entry ID cases}
done_select:                           {done processing this selection}

leave:                                 {common exit point}
  end;
