module iedit_menu_col_whbal;
define iedit_whitebal;
define iedit_menu_col_whbal;
%include 'image_edit.ins.pas';
{
********************************************************************************
*
*   Subroutine IEDIT_WHITEBAL (COLOR)
*
*   Explicitly set the white balance.  COLOR indicates the relative weighting of
*   red, green, and blue that is to result in a shade of gray.  These are
*   intended to be in the 0.0 to 1.0 range, but must not be negative.
}
procedure iedit_whitebal (             {set explicit white balance}
  in    color: color_t);               {relative values for a shade of gray}
  val_param;

var
  r, g, b: real;                       {sanitized input values}
  maxin: real;                         {maximum input value}

begin
  r := max(0.0, color.red);            {clip to eliminate negative values}
  g := max(0.0, color.grn);
  b := max(0.0, color.blu);

  maxin := max(r, b, g);               {make brightest component value}
  if maxin < 0.00001 then begin        {all black ?}
    r := 1.0;
    g := 1.0;
    b := 1.0;
    maxin := 1.0;
    end;

  whtbal.red := max(0.00001, r / maxin);
  whtbal.grn := max(0.00001, g / maxin);
  whtbal.blu := max(0.00001, b / maxin);

  col_usewhb := true;                  {use the white balance reference}
  iedit_white_update;                  {update the white in point to white balance}
  end;
{
********************************************************************************
*
*   Function IEDIT_MENU_COL_WHBAL (ULX, ULY, EVHAN)
*
*   Process events for the COLORS > WHITE BALANCE menu.  This routine is called
*   from COLORS menu events handler when the WHITE BALANCE entry is selected.
}
function iedit_menu_col_whbal (        {handle events for COLORS > WHITE BALLANCE}
  in      ulx, uly: real;              {preferred UL corner of subordinate menu}
  in out  evhan: gui_evhan_k_t)        {updated events handled status}
  :gui_selres_k_t;                     {overall user selection result}
  val_param;

var
  tp: rend_text_parms_t;               {local copy of text control parameters}
  menu: gui_menu_t;                    {our sub-menu}
  men2: gui_menu_t;                    {next layer down sub-menu}
  id: sys_int_machine_t;               {ID of selected menu entry}
  sel_p: gui_menent_p_t;               {points to selected menu entry}
  resp: string_var8192_t;              {user response string}
  tk, tk2: string_treename_t;          {scratch token}
  err: string_var1024_t;               {error string}
  p: string_index_t;                   {parse index}
  conn: file_conn_t;                   {scratch connection to directory or file}
  finfo: file_info_t;                  {info about a directory entry}
  selres: gui_selres_k_t;              {returned user selection result}
  ment_p: gui_menent_p_t;              {pointer to menu entry}
  ent: gui_enter_t;                    {string entry object}
  col: color_t;                        {scratch color}
  stat: sys_err_t;

label
  retry, abort_select, leave;

begin
  resp.max := size_char(resp.str);     {init local var strings}
  tk.max := size_char(tk.str);
  tk2.max := size_char(tk2.str);
  err.max := size_char(err.str);
{
*   Build the menu.
}
  tp := tparm;                         {temp set text parameters for the menu}
  tp.lspace := 1.0;
  rend_set.text_parms^ (tp);
  gui_menu_create (menu, win_root);    {create this menu}
  iedit_menu_add_msg (menu, 'img', 'iedit_menu_col_whbal', nil, 0);
  {
  *   Make the SAVE option (ID = 5) unselectable if there is no current white
  *   balance to save.
  }
  if not col_usewhb then begin         {no current white bal, gray out SAVE ?}
    ment_p := menu.first_p;            {init pointer to first menu entry}
    while ment_p <> nil do begin       {check this entry}
      if ment_p^.id = 5 then begin     {this is SAVE entry ?}
        ment_p^.flags :=               {don't allow SAVE to be selected}
          ment_p^.flags - [gui_entflag_selectable_k];
        exit;                          {stop scanning menu entries}
        end;
      ment_p := ment_p^.next_p;        {advance to next menu entry}
      end;                             {back to process this new entry}
    end;
{
*   Display the menu and get the user's selection.
}
  gui_menu_place (menu, ulx, uly+2);   {set menu location}
  rend_set.text_parms^ (tparm);        {restore default text parameters}

  selres := gui_selres_perf_k;         {init to user selected valid action}
retry:
  if not gui_menu_select (menu, id, sel_p) then begin {menu cancelled ?}
    if id = -2
      then selres := gui_selres_prev_k {user wants back to previous menu}
      else selres := gui_selres_canc_k; {user canceled}
    goto leave;
    end;
  case id of                           {which menu entry was selected ?}
{
****************************************
*
*   AVERAGE
}
1: begin
  gui_menu_delete (menu);              {delete the original menu}
  iedit_op_colors;                     {make sure min/ave/max colors up to date}
  iedit_whitebal (col_ave);
  end;
{
****************************************
*
*   DARKEST
}
2: begin
  gui_menu_delete (menu);              {delete the original menu}
  iedit_op_colors;                     {make sure min/ave/max colors up to date}
  iedit_whitebal (col_min);
  end;
{
****************************************
*
*   BRIGHTEST
}
3: begin
  gui_menu_delete (menu);              {delete the original menu}
  iedit_op_colors;                     {make sure min/ave/max colors up to date}
  iedit_whitebal (col_max);
  end;
{
****************************************
*
*   FROM FILE
}
4: begin
  file_open_read_dir (                 {open directory with white balance files}
    string_v('(cog)progs/image_edit'), conn, stat);
  if sys_error(stat) then goto abort_select;

  gui_menu_create (men2, win_root);    {create the submenu}

  while true do begin                  {loop over the directory contents}
    file_read_dir (                    {read next directory entry}
      conn,                            {connection to the directory}
      [],                              {no additional info needed}
      tk,                              {returned directory entry name}
      finfo,                           {returned info about the directory entry}
      stat);
    if sys_error(stat) then begin
      file_close (conn);               {close directory on any abnormal status}
      end;
    if file_eof(stat) then exit;       {hit end of directory ?}
    if sys_error(stat) then begin      {hard error ?}
      gui_menu_delete (men2);
      gui_menu_delete (menu);          {delete the original menu}
      goto abort_select;
      end;
    string_fnam_unextend (tk, '.wht'(0), tk2); {remove required suffix, if present}
    if tk2.len <> (tk.len - 4) then next; {not the required suffix, ignore this file ?}
    gui_menu_ent_add (                 {add this file name as menu option}
      men2,                            {menu to add entry to}
      tk2,                             {generic file name is menu entry text}
      0,                               {no shortcut key}
      0);                              {menu entry ID, not used}
    end;                               {back to get next menu entry}
  if men2.first_p = nil then begin     {no choices available at all ?}
    gui_menu_delete (men2);
    gui_menu_delete (menu);            {delete the original menu}
    goto abort_select;
    end;
  gui_menu_place (                     {set submenu location}
    men2,                              {the menu to place}
    sel_p^.xr + menu.win.rect.x,       {X within parent window}
    sel_p^.yt + menu.win.rect.y + 2);  {Y within parent window}

  if not gui_menu_select (men2, id, sel_p) then begin {menu cancelled ?}
    if id = -2 then goto retry;        {user wants back to this menu ?}
    gui_menu_delete (menu);            {delete the original menu}
    goto abort_select;                 {nothing was selected}
    end;

  string_copy (sel_p^.name_p^, tk);    {save name of file selected by user}
  gui_menu_delete (men2);              {delete the submenu}
  gui_menu_delete (menu);              {delete the original menu}
{
*   The generic leafname of the white ballance file is in TK.
}
  string_vstring (tk2, '(cog)progs/image_edit/'(0), -1); {make pathname in TK2}
  string_append (tk2, tk);
  file_open_read_text (tk2, '.wht', conn, stat); {open the white ballance file}
  if sys_error(stat) then goto abort_select;
  file_read_text (conn, resp, stat);   {read the first line from the file}
  file_close (conn);                   {done with the white ballance file}
  if sys_error(stat) then goto abort_select;
  p := 1;                              {init parse index}

  string_token_fpm (resp, p, col.red, stat); {get the three color component values}
  if sys_error(stat) then goto abort_select;
  string_token_fpm (resp, p, col.grn, stat);
  if sys_error(stat) then goto abort_select;
  string_token_fpm (resp, p, col.blu, stat);
  if sys_error(stat) then goto abort_select;

  iedit_whitebal (col);                {set the new white balance}
  end;
{
****************************************
*
*   SAVE
}
5: begin
  gui_menu_delete (menu);              {delete the original menu}

  resp.len := 0;                       {no seed string}
  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_whbal_save', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  while true do begin                  {retry until valid entry or cancelled}
    if not gui_enter_get (ent, err, resp) then goto leave; {user cancelled ?}
    if resp.len > 0 then exit;         {got a name string ?}
    string_f_message (err,             {get error string}
      'img', 'iedit_err_whbal_save', nil, 0);
    end;
  gui_enter_delete (ent);              {delete user string entry object}

  string_vstring (tk, '(cog)/progs/image_edit/'(0), -1); {fixed part of file name}
  string_append (tk, resp);            {add file leafname}
  file_open_write_text (               {open the white balance file}
    tk, '.wht',                        {file name}
    conn,                              {returned connection to the file}
    stat);
  if sys_error(stat) then goto abort_select;

  resp.len := 0;                       {build the string to write to the file}
  string_f_fp_fixed (tk, whtbal.red, 5);
  string_append (resp, tk);
  string_append1 (resp, ' ');
  string_f_fp_fixed (tk, whtbal.grn, 5);
  string_append (resp, tk);
  string_append1 (resp, ' ');
  string_f_fp_fixed (tk, whtbal.blu, 5);
  string_append (resp, tk);
  file_write_text (resp, conn, stat);  {write it}
  file_close (conn);                   {close the file}
  if sys_error(stat) then goto abort_select;
  end;
{
****************************************
*
*   RESET
}
6: begin
  gui_menu_delete (menu);              {delete the original menu}
  col_usewhb := false;
  whtin.red := 1.0;
  whtin.grn := 1.0;
  whtin.blu := 1.0;
  end;
{
****************************************
*
*   ENTER
}
7: begin
  gui_menu_delete (menu);              {delete the original menu}

  resp.len := 0;                       {init see string to empty}
  if col_usewhb then begin             {we have a existing white balance ?}
    string_f_fp_fixed (tk, whtbal.red, 5);
    string_append (resp, tk);
    string_append1 (resp, ' ');
    string_f_fp_fixed (tk, whtbal.grn, 5);
    string_append (resp, tk);
    string_append1 (resp, ' ');
    string_f_fp_fixed (tk, whtbal.blu, 5);
    string_append (resp, tk);
    end;

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_colors_whbal', nil, 0); {prompt message info}
  if iedit_get_color (ent, col) then begin {got a valid entry ?}
    iedit_whitebal (col);
    end;
  end;
{
****************************************
}
    end;                               {end of menu entry ID cases}
  goto leave;

abort_select:                          {done processing this selection}
  if sys_error(stat) then begin
    discard( gui_message_msg_stat (    {show error status to user}
      win_img,                         {parent window to show error popup within}
      gui_msgtype_err_k,               {message type}
      stat,                            {error status}
      '', '', nil, 0) );               {additional message parameters}
    end;
  selres := gui_selres_canc_k;         {indicate operation cancelled}

leave:                                 {common exit point}
  iedit_menu_col_whbal := selres;      {return user overall selection result}
  end;
