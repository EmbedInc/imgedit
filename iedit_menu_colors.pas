module iedit_menu_colors;
define iedit_op_colors;
define iedit_get_color;
define iedit_white_update;
define iedit_menu_colors;
%include 'iedit.ins.pas';
{
********************************************************************************
*
*   Subroutine IEDIT_OP_COLORS
*
*   Find the colors of the OP window.  If these are already computed and still
*   valid, then nothing is done.
*
*   The minimum and maximum intensity (darkest black and lightest white) and
*   average color are found in the OP region.  The min and max colors are the
*   min and max found in any rectangle of pixels that is COL_AVSIZE pixels on a
*   side.  COL_AVSIZE is defined in the main include file.  If the OP region is
*   smaller than COL_AVSIZE, the averaging target size is reduced in that
*   dimension accordingly.
}
procedure iedit_op_colors;             {make sure OP window computed colors up to date}
  val_param;

var
  tdx, tdy: sys_int_machine_t;         {averaging target size in pixels, X and Y}
  tpix: sys_int_machine_t;             {total number of pixels in averaging target}
  opx, opy: sys_int_machine_t;         {pixel coordinate index into OP region}
  atx, aty: sys_int_machine_t;         {pixel coordinate into averaging target}
  ix, iy: sys_int_machine_t;           {source image pixel coord of curr OP pixel}
  ax, ay: sys_int_machine_t;           {source img pixel coor in averaging window}
  tmaxx, tmaxy: sys_int_machine_t;     {max offset into OP window to fit ave target}
  opred, opgrn, opblu: double;         {averaging accumulators for whole OP region}
  atred, atgrn, atblu: double;         {averaging accumulators for averaging target}
  iten: real;                          {intensity}
  atmax, atmin: real;                  {best max/min intensities found so far}

begin
  if col_op then return;               {computed colors already up to date ?}

  tdx := min(col_avsize, op_dx);       {determine actual averaging target size}
  tdy := min(col_avsize, op_dy);
  tpix := tdx * tdy;                   {number of pixels in averaging target}
  if tpix < 1 then return;             {not enough pixels to do anyting (shouldn't happen)}

  opred := 0.0;                        {init OP region averaging accumulators}
  opgrn := 0.0;
  opblu := 0.0;
  atmax := -1.0;                       {init max/min intensities found so far}
  atmin := 4.0;

  tmaxx := op_dx - tdx;                {make max OP region offset to fit ave target}
  tmaxy := op_dy - tdy;

  for opy := 0 to op_dy-1 do begin     {down the OP window rows}
    iy := op_top + opy;                {make source image Y coordinate}
    for opx := 0 to op_dx-1 do begin   {accross this OP window row}
      ix := op_lft + opx;              {make source image X coordinate}
      opred := opred + inscan_p^[iy]^[ix].red; {update OP window overall average}
      opgrn := opgrn + inscan_p^[iy]^[ix].grn;
      opblu := opblu + inscan_p^[iy]^[ix].blu;

      if                               {room for averaging target starting here ?}
          (opx <= tmaxx) and (opy <= tmaxy)
          then begin
        atred := 0.0;                  {init averaging accumulators}
        atgrn := 0.0;
        atblu := 0.0;
        for aty := 0 to tdy-1 do begin {down the averaging target rows}
          ay := iy + aty;              {make source image Y coordinate here}
          for atx := 0 to tdx-1 do begin {accross this averaging target row}
            ax := ix + atx;            {make source image X coordinate here}
            atred := atred + inscan_p^[ay]^[ax].red; {accumulate this pixel contribution}
            atgrn := atgrn + inscan_p^[ay]^[ax].grn;
            atblu := atblu + inscan_p^[ay]^[ax].blu;
            end;                       {back for next averaging target pixel accross}
          end;                         {back for next averaging target row down}
        atred := (atred / 65535.0) / tpix; {make average color in this ave window}
        atgrn := (atgrn / 65535.0) / tpix;
        atblu := (atblu / 65535.0) / tpix;
        iten := atred + atgrn + atblu; {make intensity of average target}
        if iten < atmin then begin     {found better minimum ?}
          col_min.red := atred;        {save best min found so far}
          col_min.grn := atgrn;
          col_min.blu := atblu;
          atmin := iten;               {update best min}
          end;
        if iten > atmax then begin     {found better maximum ?}
          col_max.red := atred;        {save best max found so far}
          col_max.grn := atgrn;
          col_max.blu := atblu;
          atmax := iten;               {update best max}
          end;
        end;                           {done processing averaging target}

      end;                             {back for next pixel accross OP row}
    end;                               {back for next OP row down}

  ix := op_dx * op_dy;                 {number of pixels in OP window}
  col_ave.red := (opred / 65535.0) / ix; {make and save average over whole OP window}
  col_ave.grn := (opgrn / 65535.0) / ix;
  col_ave.blu := (opblu / 65535.0) / ix;

  col_op := true;                      {indicate computed colors now up to date}
  end;
{
********************************************************************************
*
*   Function IEDIT_GET_COLOR (ENT, COL)
*
*   Get a color value entered by the user.  They user can enter separate R, G,
*   and B values, or a single value that will then be used for all three color
*   components (will be interpreted as gray).
*
*   The function returns true if reading the user input was successful.  It
*   returns false if the user cancelled the operation.  In either case, ENT is
*   deleted.
}
function iedit_get_color (             {get color from user via user entry pop}
  in out  ent: gui_enter_t;            {user entry object, will be deleted}
  out     col: color_t)                {the returned RGB color}
  :boolean;                            {success, returning with color}
  val_param;

var
  err: string_var1024_t;               {error message string}
  resp: string_var1024_t;              {user response string}
  tk: string_var32_t;                  {token parsed from user string}
  p: string_index_t;                   {user string parse index}
  stat: sys_err_t;

begin
  err.max := size_char(err.str);       {init local var strings}
  resp.max := size_char(resp.str);
  tk.max := size_char(tk.str);
  iedit_get_color := false;            {init to the operation was cancelled}

  err.len := 0;
  while true do begin
    if not gui_enter_get (ent, err, resp) then return; {user cancelled ?}
    string_vstring (err, 'One or three numeric values required'(0), -1); {get err string ready}
    p := 1;                            {init parse index}
    string_token_fpm (resp, p, col.red, stat); {get red level}
    if sys_error(stat) then next;
    string_token_fpm (resp, p, col.grn, stat); {get green level}
    if string_eos(stat) then begin     {user only entered a single value ?}
      col.grn := col.red;
      col.blu := col.red;
      exit;
      end;
    if sys_error(stat) then next;
    string_token_fpm (resp, p, col.blu, stat); {get blue level}
    if sys_error(stat) then next;
    string_token (resp, p, tk, stat);  {try to get another token}
    if not string_eos(stat) then next; {extra token ?}
    exit;
    end;
  gui_enter_delete (ent);              {delete the user entry object}

  iedit_get_color := true;             {indicate returning with color value}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_WHITE_UPDATE
*
*   Update the white input level according to the white ballance if this is
*   enabled.
}
procedure iedit_white_update;          {update in white point to white bal if enabled}
  val_param;

var
  r: real;

begin
  if not col_usewhb then return;       {not using white ballance reference}

  r := max(                            {find multiplier to maximize range}
    whtin.red / whtbal.red,
    whtin.grn / whtbal.grn,
    whtin.blu / whtbal.blu);
  r := min(r, 1.0);                    {don't allow clipping the input range}

  whtin.red := whtbal.red * r;         {use scaled white reference as white input}
  whtin.grn := whtbal.grn * r;
  whtin.blu := whtbal.blu * r;
  end;
{
********************************************************************************
*
*   Function IEDIT_MENU_COLORS (ULX, ULY)
*
*   Process events for the COLORS top level menu.  This routine is called from
*   the top level menu events handler when the COLORS entry is selected.  The
*   top level menu event handler will return with whatever this routine returns
*   with.
}
function iedit_menu_colors (           {handle events for COLORS top menu entry}
  in    ulx, uly: real)                {preferred UL corner of subordinate menu}
  :gui_evhan_k_t;                      {returned event handling status}

var
  tp: rend_text_parms_t;               {local copy of text control parameters}
  menu: gui_menu_t;                    {our sub-menu}
  id: sys_int_machine_t;               {ID of selected menu entry}
  sel_p: gui_menent_p_t;               {points to selected menu entry}
  ent: gui_enter_t;                    {string entry object}
  resp: string_var8192_t;              {user response string}
  tk: string_treename_t;               {scratch token}
  err: string_var1024_t;               {error string}
  r1: real;                            {scratch floating point}
  evhan: gui_evhan_k_t;                {event handling status to return to caller}
  stat: sys_err_t;

label
  retry, update_bri_sat, abort_select, leave;

begin
  resp.max := size_char(resp.str);     {init local var strings}
  tk.max := size_char(tk.str);
  err.max := size_char(err.str);
  evhan := gui_evhan_did_k;            {init to events were processed and handled}

  if opmode <> opmode_colors_k then begin {changing op mode ?}
    opmode := opmode_colors_k;         {set the new op mode}
    iedit_win_op_update;               {draw the OP window with the new mode}
    iedit_win_img_ncache;              {update the image display}
    iedit_win_img_update;
    end;
  tp := tparm;                         {temp set text parameters for the menu}
  tp.lspace := 1.0;
  rend_set.text_parms^ (tp);
  gui_menu_create (menu, win_root);    {create this menu}
  iedit_menu_add_msg (menu, 'img', 'iedit_menu_colors', nil, 0);

  gui_menu_place (menu, ulx - 2, uly); {set menu location}
  rend_set.text_parms^ (tparm);        {restore default text parameters}

retry:
  if not gui_menu_select (menu, id, sel_p) then begin {menu cancelled ?}
    goto leave;
    end;
  case id of                           {which menu entry was selected ?}
{
****************************************
*
*   COLORS > AUTO WHT/BLK
}
9: begin
  gui_menu_delete (menu);              {delete the original menu}
  iedit_op_colors;                     {compute op region colors if not already}
  blkin := col_min;                    {set the new input black level}
  whtin := col_max;                    {set the new input white level}
  iedit_white_update;                  {adjust to reference white ballance if enabled}
  end;
{
****************************************
*
*   COLORS > AUTO BLACK
}
1: begin
  gui_menu_delete (menu);              {delete the original menu}
  iedit_op_colors;                     {compute op region colors if not already}
  blkin := col_min;                    {set the new input black level}
  end;
{
****************************************
*
*   COLORS > AUTO WHITE
}
2: begin
  gui_menu_delete (menu);              {delete the original menu}
  iedit_op_colors;                     {compute op region colors if not already}
  whtin := col_max;                    {set new input white level}
  iedit_white_update;                  {adjust to reference white ballance if enabled}
  end;
{
****************************************
*
*   COLORS > BRIGHTEN
}
3: begin
  gui_menu_delete (menu);              {delete the original menu}
  string_f_fp_fixed (resp, brighten, 2); {make seed string with current value}

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_colors_brighten', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  if not gui_enter_get_fp (ent, err, r1) then goto abort_select;
  gui_enter_delete (ent);              {delete the user entry object}

  brighten := r1;                      {set the new brighten value}

update_bri_sat:                        {update to new brighten and saturate values}
  col_eb := 2.0 ** (-brighten);        {precompute exponents}
  col_es := 2.0 ** (saturate - brighten * 0.4);
  end;
{
****************************************
*
*   COLORS > BLACK IN
}
4: begin
  gui_menu_delete (menu);              {delete the original menu}
  string_f_fp_fixed (resp, blkin.red, 5);
  string_append1 (resp, ' ');
  string_f_fp_fixed (tk, blkin.grn, 5);
  string_append (resp, tk);
  string_append1 (resp, ' ');
  string_f_fp_fixed (tk, blkin.blu, 5);
  string_append (resp, tk);

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_colors_black', nil, 0); {prompt message info}
  if not iedit_get_color (ent, blkin) then goto abort_select;
  end;
{
****************************************
*
*   COLORS > BLACK OUT
}
7: begin
  gui_menu_delete (menu);              {delete the original menu}
  string_f_fp_fixed (resp, blkout.red, 5);
  string_append1 (resp, ' ');
  string_f_fp_fixed (tk, blkout.grn, 5);
  string_append (resp, tk);
  string_append1 (resp, ' ');
  string_f_fp_fixed (tk, blkout.blu, 5);
  string_append (resp, tk);

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_colors_black', nil, 0); {prompt message info}
  if not iedit_get_color (ent, blkout) then goto abort_select;
  end;
{
****************************************
*
*   COLORS > WHITE IN
}
5: begin
  gui_menu_delete (menu);              {delete the original menu}
  string_f_fp_fixed (resp, whtin.red, 5);
  string_append1 (resp, ' ');
  string_f_fp_fixed (tk, whtin.grn, 5);
  string_append (resp, tk);
  string_append1 (resp, ' ');
  string_f_fp_fixed (tk, whtin.blu, 5);
  string_append (resp, tk);

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_colors_black', nil, 0); {prompt message info}
  if not iedit_get_color (ent, whtin) then goto abort_select;

  col_usewhb := false;                 {use this white value explicitly}
  end;
{
****************************************
*
*   COLORS > WHITE OUT
}
8: begin
  gui_menu_delete (menu);              {delete the original menu}
  string_f_fp_fixed (resp, whtout.red, 5);
  string_append1 (resp, ' ');
  string_f_fp_fixed (tk, whtout.grn, 5);
  string_append (resp, tk);
  string_append1 (resp, ' ');
  string_f_fp_fixed (tk, whtout.blu, 5);
  string_append (resp, tk);

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_colors_black', nil, 0); {prompt message info}
  if not iedit_get_color (ent, whtout) then goto abort_select;
  end;
{
****************************************
*
*   COLORS > SATURATE
}
6: begin
  gui_menu_delete (menu);              {delete the original menu}
  string_f_fp_fixed (resp, saturate, 2); {make seed string with current value}

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_colors_saturate', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  if not gui_enter_get_fp (ent, err, r1) then goto abort_select;
  gui_enter_delete (ent);              {delete the user entry object}

  saturate := r1;
  goto update_bri_sat;                 {update to new brighten or saturate}
  end;
{
****************************************
*
*   COLORS > LOG RATIO
}
10: begin
  gui_menu_delete (menu);              {delete the original menu}
  string_f_fp_fixed (resp, col_log_rat, 2); {make seed string with current value}
  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_log_ratio', nil, 0); {prompt message info}
  err.len := 0;                        {init to no error message}
  if not gui_enter_get_fp (ent, err, r1) then goto abort_select;
  gui_enter_delete (ent);              {delete the user entry object}
  col_log_rat := r1;                   {update the parameter}
  col_logmode := logmode_ratio_k;
  end;
{
****************************************
*
*   COLORS > LOG OFFSET
}
11: begin
  gui_menu_delete (menu);              {delete the original menu}
  resp.len := 0;                       {init seed string to empty}
  if col_log_ofs <= 999999.0 then begin
    string_f_fp_fixed (resp, col_log_ofs, 4); {make seed string with current value}
    end;
  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_log_offset', nil, 0); {prompt message info}
  err.len := 0;                        {init to no error message}
  if not gui_enter_get_fp (ent, err, r1) then goto abort_select;
  gui_enter_delete (ent);              {delete the user entry object}
  col_log_ofs := r1;                   {update the parameter}
  col_logmode := logmode_add_k;
  end;
{
****************************************
*
*   COLORS > WHITE BALANCE
}
12: begin
  case iedit_menu_col_whbal (          {run WHITE BALANCE sub-menu}
      sel_p^.xr + menu.win.rect.x,
      sel_p^.yt + menu.win.rect.y,
      evhan)
      of
gui_selres_prev_k: begin               {user canceled to go to previous level}
      goto retry;
      end;
    end;

  gui_menu_delete (menu);              {delete the original menu}
  end;
{
****************************************
}
    end;                               {end of menu entry ID cases}

  iedit_color_inv;                     {indicate derived color state is now invalid}
  iedit_win_op_update;                 {update numeric diplay}
  iedit_win_img_update;                {update displayed image}
  goto leave;

abort_select:                          {done processing this selection}
  if sys_error(stat) then begin
    discard( gui_message_msg_stat (    {show error status to user}
      win_img,                         {parent window to show error popup within}
      gui_msgtype_err_k,               {message type}
      stat,                            {error status}
      '', '', nil, 0) );               {additional message parameters}
    end;

leave:                                 {common exit point}
  iedit_menu_colors := evhan;          {return events handled status}
  end;
