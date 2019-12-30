module iedit_menu_crop;
define iedit_menu_crop;
%include 'iedit.ins.pas';
{
********************************************************************************
*
*   Function IEDIT_MENU_CROP (ULX, ULY)
*
*   Process events for the CROP top level menu.  This routine is called from the
*   top level menu events handler when the FILE entry is selected.  The top
*   level menu event handler will return with whatever this routine returns
*   with.
}
function iedit_menu_crop (             {handle events for CROP selected}
  in    ulx, uly: real)                {preferred UL corner of subordinate menu}
  :gui_evhan_k_t;                      {returned event handling status}

var
  tp: rend_text_parms_t;               {local copy of text control parameters}
  menu: gui_menu_t;                    {our sub-menu}
  id: sys_int_machine_t;               {ID of selected menu entry}
  sel_p: gui_menent_p_t;               {points to selected menu entry}
  ent: gui_enter_t;                    {string entry object}
  resp: string_var8192_t;              {user response string}
  tk: string_var32_t;                  {scratch token}
  err: string_var1024_t;               {error string}
  p: string_index_t;                   {response string parse index}
  ii, jj: sys_int_machine_t;           {scratch integers}
  ix, iy: sys_int_machine_t;           {scratch coordinate}
  idx, idy: sys_int_machine_t;         {scratch integer width/height}
  x, y: real;                          {scratch FP coordinate}
  stat: sys_err_t;

label
  done_select, leave;

begin
  resp.max := size_char(resp.str);     {init local var strings}
  tk.max := size_char(tk.str);
  err.max := size_char(err.str);
  iedit_menu_crop := gui_evhan_did_k;  {init to events were processed}

  if opmode <> opmode_crop_k then begin {chaning op mode ?}
    opmode := opmode_crop_k;           {set the new op mode}
    iedit_win_op_update;               {draw the OP window with the new mode}
    iedit_win_img_ncache;              {update the image display}
    iedit_win_img_update;
    end;
  tp := tparm;                         {temp set text parameters for the menu}
  tp.lspace := 1.0;
  rend_set.text_parms^ (tp);
  gui_menu_create (menu, win_root);    {create this menu}
  iedit_menu_add_msg (menu, 'img', 'iedit_menu_crop', nil, 0);

  gui_menu_place (menu, ulx - 2, uly); {set menu location}
  rend_set.text_parms^ (tparm);        {restore default text parameters}
  if not gui_menu_select (menu, id, sel_p) then begin {menu cancelled ?}
    goto leave;
    end;
  gui_menu_delete (menu);              {delete the menu}
  case id of                           {which menu entry was selected ?}
{
****************************************
*
*   CROP > SIZE
}
1: begin
  string_f_int (resp, crop_dx);        {make seed string with current value}
  string_append1 (resp, ' ');
  string_f_int (tk, crop_dy);
  string_append (resp, tk);

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_crop_size', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  while true do begin
    if not gui_enter_get (ent, err, resp) then goto done_select;
    string_vstring (err, 'Two integers required'(0), -1); {get err string ready}
    p := 1;                            {init parse index}
    string_token (resp, p, tk, stat);  {get width token}
    if sys_error(stat) then next;
    string_t_int (tk, ii, stat);       {convert to integer}
    if sys_error(stat) then next;
    string_token (resp, p, tk, stat);  {get height token}
    if sys_error(stat) then next;
    string_t_int (tk, jj, stat);       {convert to integer}
    if sys_error(stat) then next;
    string_token (resp, p, tk, stat);  {try to get another token}
    if not string_eos(stat) then next; {extra token ?}
    exit;
    end;
  gui_enter_delete (ent);              {delete the user entry object}
  {
  *   II is width, JJ is height.  The entry object has been deleted.
  }
  ix := crop_lft + (crop_dx div 2);    {get existing center point}
  iy := crop_top + (crop_dy div 2);
  crop_dx := max(1, min(indx, ii));    {clip to valid range and set new size}
  crop_dy := max(1, min(indy, jj));
  idx := crop_dx div 2;                {radius of new crop window}
  idy := crop_dy div 2;
  crop_lft := max(0, min(indx - crop_dx, ix - idx)); {keep crop within image}
  crop_top := max(0, min(indy - crop_dy, iy - idy));
  crop_asp := inpaspect * crop_dx / crop_dy; {update crop window aspect ratio}
  crop_asplock := false;               {crop aspect ratio not locked}

  iedit_out_geo;                       {update output image geometry}

  iedit_win_op_update;                 {show new crop state}
  iedit_win_img_update;
  end;
{
****************************************
*
*   CROP > WIDTH
}
2: begin
  string_f_int (resp, crop_dx);        {make seed string with current value}

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_crop_width', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  while true do begin
    if not gui_enter_get (ent, err, resp) then goto done_select;
    string_t_int (resp, ii, stat);     {convert to integer}
    if sys_error(stat) then begin
      string_vstring (err, 'Invalid integer'(0), -1);
      next;
      end;
    exit;
    end;
  gui_enter_delete (ent);              {delete the user entry object}
  {
  *   II is width.
  }
  ix := crop_lft + (crop_dx div 2);    {get existing center point}
  iy := crop_top + (crop_dy div 2);

  ii := max(1, min(indx, ii));         {clip to valid range}
  if crop_asplock
    then begin                         {preserve aspect ratio}
      jj := max(1, round(ii * inpaspect / crop_asp)); {other dim from aspect}
      if jj > indy then begin          {need to shrink ?}
        jj := indy;
        ii := max(1, round(jj * crop_asp / inpaspect));
        end;
      end
    else begin                         {preserve other dimension}
      jj := crop_dy;
      end
    ;
  crop_dx := max(1, min(indx, ii));    {clip to valid range and set new size}
  crop_dy := max(1, min(indy, jj));
  idx := crop_dx div 2;                {radius of new crop window}
  idy := crop_dy div 2;
  crop_lft := max(0, min(indx - crop_dx, ix - idx)); {keep crop within image}
  crop_top := max(0, min(indy - crop_dy, iy - idy));
  crop_asp := inpaspect * crop_dx / crop_dy; {update actual aspect ratio}

  iedit_out_geo;                       {update output image geometry}

  iedit_win_op_update;                 {show new crop state}
  iedit_win_img_update;
  end;
{
****************************************
*
*   CROP > HEIGHT
}
3: begin
  string_f_int (resp, crop_dy);        {make seed string with current value}

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_crop_height', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  while true do begin
    if not gui_enter_get (ent, err, resp) then goto done_select;
    string_t_int (resp, jj, stat);     {convert to integer}
    if sys_error(stat) then begin
      string_vstring (err, 'Invalid integer'(0), -1);
      next;
      end;
    exit;
    end;
  gui_enter_delete (ent);              {delete the user entry object}
  {
  *   JJ is height.
  }
  ix := crop_lft + (crop_dx div 2);    {save existing center point}
  iy := crop_top + (crop_dy div 2);

  jj := max(1, min(indy, jj));         {clip desired height to valid range}
  if crop_asplock
    then begin                         {preserve aspect ratio}
      ii := max(1, round(jj * crop_asp / inpaspect)); {new raw width}
      if ii > indx then begin          {too wide, need to shrink ?}
        ii := indx;                    {set width to maximum}
        jj := max(1, round(ii * inpaspect / crop_asp)); {make resulting height}
        end;
      end
    else begin                         {preserve other dimension}
      ii := crop_dx;
      end
    ;
  crop_dx := max(1, min(indx, ii));    {clip to valid range and set new size}
  crop_dy := max(1, min(indy, jj));
  idx := crop_dx div 2;                {radius of new crop window}
  idy := crop_dy div 2;
  crop_lft := max(0, min(indx - crop_dx, ix - idx)); {keep crop within image}
  crop_top := max(0, min(indy - crop_dy, iy - idy));
  if not crop_asplock then begin
    crop_asp := inpaspect * crop_dx / crop_dy; {update crop window aspect ratio}
    end;

  iedit_out_geo;                       {update output image geometry}

  iedit_win_op_update;                 {show new crop state}
  iedit_win_img_update;
  end;
{
****************************************
*
*   CROP > LEFT
}
4: begin
  string_f_int (resp, crop_lft);       {make seed string with current value}

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_crop_left', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  while true do begin
    if not gui_enter_get (ent, err, resp) then goto done_select;
    string_t_int (resp, ii, stat);     {convert to integer}
    if sys_error(stat) then begin
      string_vstring (err, 'Invalid integer'(0), -1);
      next;
      end;
    exit;
    end;
  gui_enter_delete (ent);              {delete the user entry object}
{
*   II contains new left edge.
}
  ix := crop_lft + crop_dx - 1;        {save existing right edge}
  crop_lft := max(0, min(indx - 1, ii)); {clip to range and set new value}
  ii := max(crop_lft, min(indx - 1, ix)); {clip right to new limit}
  crop_dx := ii - crop_lft + 1;

  if crop_asplock then begin           {preserve aspect ratio ?}
    idy := max(1, round(crop_dx * inpaspect / crop_aspt)); {make new height}
    if idy > indy then begin           {too high ?}
      idy := indy;                     {set to maximum height}
      idx := max(1, round(idy * crop_aspt / inpaspect)); {make adjusted width}
      crop_lft := crop_lft + crop_dx - idx; {update horizontal state accordingly}
      crop_dx := idx;
      end;
    iy := crop_top + ((crop_dy - idy) div 2);
    crop_dy := idy;
    crop_top := max(1, min(indy - crop_dy + 1, iy));
    end;
  crop_asp := inpaspect * crop_dx / crop_dy; {update aspect ratio}

  iedit_out_geo;                       {update output image geometry}

  iedit_win_op_update;                 {show new crop state}
  iedit_win_img_update;
  end;
{
****************************************
*
*   CROP > RIGHT
}
5: begin
  string_f_int (resp, crop_lft + crop_dx - 1); {make seed string with current value}

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_crop_right', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  while true do begin
    if not gui_enter_get (ent, err, resp) then goto done_select;
    string_t_int (resp, ii, stat);     {convert to integer}
    if sys_error(stat) then begin
      string_vstring (err, 'Invalid integer'(0), -1);
      next;
      end;
    exit;
    end;
  gui_enter_delete (ent);              {delete the user entry object}
{
*   II contains new right edge X.
}
  ii := max(crop_lft, min(indx - 1, ii)); {clip right edge to valid range}
  crop_dx := ii - crop_lft + 1;        {update state to new right edge}

  if crop_asplock then begin           {preserve aspect ratio ?}
    idy := max(1, round(crop_dx * inpaspect / crop_aspt)); {make new height}
    if idy > indy then begin           {too high ?}
      idy := indy;                     {set to maximum height}
      crop_dx := max(1, round(idy * crop_aspt / inpaspect)); {make adjusted width}
      end;
    iy := crop_top + ((crop_dy - idy) div 2); {make new top}
    crop_dy := idy;
    crop_top := max(1, min(indy - crop_dy + 1, iy));
    end;
  crop_asp := inpaspect * crop_dx / crop_dy; {update aspect ratio}

  iedit_out_geo;                       {update output image geometry}

  iedit_win_op_update;                 {show new crop state}
  iedit_win_img_update;
  end;
{
****************************************
*
*   CROP > TOP
}
6: begin
  string_f_int (resp, crop_top);       {make seed string with current value}

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_crop_top', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  while true do begin
    if not gui_enter_get (ent, err, resp) then goto done_select;
    string_t_int (resp, ii, stat);     {convert to integer}
    if sys_error(stat) then begin
      string_vstring (err, 'Invalid integer'(0), -1);
      next;
      end;
    exit;
    end;
  gui_enter_delete (ent);              {delete the user entry object}
{
*   II contains new top edge Y.
}
  iy := crop_top + crop_dy - 1;        {save existing bottom edge}
  crop_top := max(0, min(indy - 1, ii)); {clip top to range and set new value}
  ii := max(crop_top, min(indy - 1, iy)); {clip bottom to new limit}
  crop_dy := ii - crop_top + 1;

  if crop_asplock then begin           {preserve aspect ratio ?}
    idx := max(1, round(crop_dy * crop_aspt / inpaspect)); {make new width}
    if idx > indx then begin           {too wide ?}
      idx := indx;                     {set to maximum width}
      idy := max(1, round(idx * inpaspect / crop_aspt)); {make adjusted height}
      crop_top := crop_top + crop_dy - idx; {update vertical state accordingly}
      crop_dy := idy;
      end;
    ix := crop_lft + ((crop_dx - idx) div 2); {make updated left edge}
    crop_dx := idx;                    {set new width}
    crop_lft := max(1, min(indx - crop_dx + 1, ix)); {set new left edge}
    end;

  crop_asp := inpaspect * crop_dx / crop_dy; {update actual aspect ratio}
  iedit_out_geo;                       {update output image geometry}
  iedit_win_op_update;                 {show new crop state}
  iedit_win_img_update;
  end;
{
****************************************
*
*   CROP > BOTTOM
}
7: begin
  string_f_int (resp, crop_top + crop_dy - 1); {make seed string with current value}

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_crop_bottom', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  while true do begin
    if not gui_enter_get (ent, err, resp) then goto done_select;
    string_t_int (resp, ii, stat);     {convert to integer}
    if sys_error(stat) then begin
      string_vstring (err, 'Invalid integer'(0), -1);
      next;
      end;
    exit;
    end;
  gui_enter_delete (ent);              {delete the user entry object}
{
*   II contains new bottom edge Y.
}
  ii := max(crop_top, min(indy - 1, ii)); {clip bottom edge to valid range}
  crop_dy := ii - crop_top + 1;        {update state to new bottom edge}

  if crop_asplock then begin           {preserve aspect ratio ?}
    idx := max(1, round(crop_dy * crop_aspt / inpaspect)); {make new width}
    if idx > indx then begin           {too wide ?}
      idx := indx;                     {set to maximum width}
      crop_dy := max(1, round(idx * inpaspect / crop_aspt)); {make adjusted height}
      end;
    ix := crop_lft + ((crop_dx - idx) div 2); {make updated left edge}
    crop_dx := idx;                    {set new width}
    crop_lft := max(1, min(indx - crop_dx + 1, ix)); {set new left edge}
    end;

  crop_asp := inpaspect * crop_dx / crop_dy; {update actual aspect ratio}
  iedit_out_geo;                       {update output image geometry}
  iedit_win_op_update;                 {show new crop state}
  iedit_win_img_update;
  end;
{
****************************************
*
*   CROP > ASPECT
}
8: begin
  string_f_fp_fixed (resp, crop_aspt, 4); {make seed string with current value}

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_crop_aspect', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  while true do begin
    if not gui_enter_get (ent, err, resp) then goto done_select;
    string_vstring (err, 'Not one or two floating point values'(0), -1); {init err string}
    p := 1;                            {init parse index}

    string_token (resp, p, tk, stat);
    if sys_error(stat) then next;
    string_t_fpm (tk, x, stat);        {get single or first value}
    if sys_error(stat) then next;
    if (x < 1.0e-6) or (x > 1.0e6) then begin
      string_vstring (err, 'Invalid', -1);
      next;
      end;

    string_token (resp, p, tk, stat);  {try to get another token}
    if string_eos(stat) then exit;     {no additional tokens, first is aspect}
    string_t_fpm (tk, y, stat);        {get second value}
    if sys_error(stat) then next;
    if (y < 1.0e-6) or (y > 1.0e6) then begin
      string_vstring (err, 'Invalid', -1);
      next;
      end;
    x := x / y;                        {make aspect ratio from the two value}

    string_token (resp, p, tk, stat);  {try to get another token}
    if not string_eos(stat) then next; {extra token ?}
    exit;
    end;
  gui_enter_delete (ent);              {delete the user entry object}
{
*   X contains the new aspect ratio.
}
  ix := crop_lft + (crop_dx div 2);    {get existing center point}
  iy := crop_top + (crop_dy div 2);

  crop_aspt := x;                      {save the new aspect ratio}
  crop_asplock := true;                {aspect ratio is now locked}
  x := crop_dx * inpaspect / crop_dy;  {make old aspect ratio}
  if crop_aspt >= x
    then begin                         {making more wide}
      y := sqrt(crop_aspt / x);        {relative amount to grow X}
      ii := max(1, min(indx, round(crop_dx * y))); {new width}
      jj := max(1, round(ii * inpaspect / crop_aspt)); {height from aspect}
      if jj > indy then begin          {need to shrink ?}
        jj := indy;
        ii := max(1, round(jj * crop_aspt / inpaspect)); {width from aspect}
        end;
      end
    else begin                         {making more tall}
      y := sqrt(x / crop_aspt);        {relative amount to grow Y}
      jj := max(1, min(indy, round(crop_dy * y))); {new height}
      ii := max(1, round(jj * crop_aspt / inpaspect)); {width from aspect}
      if ii > indx then begin          {need to shrink ?}
        ii := indx;
        jj := max(1, round(ii * inpaspect / crop_aspt)); {height from aspect}
        end;
      end
    ;

  crop_dx := max(1, min(indx, ii));    {clip to valid range and set new size}
  crop_dy := max(1, min(indy, jj));
  idx := crop_dx div 2;                {radius of new crop window}
  idy := crop_dy div 2;
  crop_lft := max(0, min(indx - crop_dx, ix - idx)); {keep crop within image}
  crop_top := max(0, min(indy - crop_dy, iy - idy));
  crop_asp := inpaspect * crop_dx / crop_dy; {update actual aspect ratio}

  iedit_out_geo;                       {update output image geometry}

  iedit_win_op_update;                 {show new crop state}
  iedit_win_img_update;
  end;
{
****************************************
*
*   CROP > CENTER
}
9: begin
  string_f_fp_fixed (resp, crop_lft + (crop_dx / 2.0), 1); {make seed string}
  string_append1 (resp, ' ');
  string_f_fp_fixed (tk, crop_top + (crop_dy / 2.0), 1);
  string_append (resp, tk);

  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_crop_center', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  while true do begin
    if not gui_enter_get (ent, err, resp) then goto done_select;
    string_vstring (err, 'Not two floating point values'(0), -1); {get err string ready}
    p := 1;                            {init parse index}
    string_token (resp, p, tk, stat);  {get X token}
    if sys_error(stat) then next;
    string_t_fpm (tk, x, stat);        {convert to floating point}
    if sys_error(stat) then next;
    string_token (resp, p, tk, stat);  {get Y token}
    if sys_error(stat) then next;
    string_t_fpm (tk, y, stat);        {convert to floating point}
    if sys_error(stat) then next;
    string_token (resp, p, tk, stat);  {try to get another token}
    if not string_eos(stat) then next; {extra token ?}
    exit;
    end;
  gui_enter_delete (ent);              {delete the user entry object}
{
*   X,Y contains the new desired center point.
}
  crop_lft := max(1, min(indx - crop_dx + 1,
    trunc(x - (crop_dx / 2.0) + 0.5) ));
  crop_top := max(1, min(indy - crop_dy + 1,
    trunc(y - (crop_dy / 2.0) + 0.5) ));

  iedit_out_geo;                       {update output image geometry}
  iedit_win_op_update;                 {show new crop state}
  iedit_win_img_update;
  end;
{
****************************************
*
*   CROP > MOVE
}
10: begin
  resp.len := 0;                       {init seed string to empty}
  gui_enter_create_msg (               {create user entry popup from message}
    ent,                               {returned user entry object}
    win_op,                            {parent window}
    resp,                              {seed string}
    'img', 'iedit_ent_crop_move', nil, 0); {prompt message info}

  err.len := 0;                        {init to no error message}
  while true do begin
    if not gui_enter_get (ent, err, resp) then goto done_select;
    string_vstring (err, 'Not 0, 1, or 2 numeric values'(0), -1); {get err string ready}
    x := 0.0;                          {init to default move amount (none)}
    y := 0.0;
    p := 1;                            {init parse index}

    string_token (resp, p, tk, stat);  {get X token}
    if string_eos(stat) then exit;
    if sys_error(stat) then next;
    string_t_fpm (tk, x, stat);        {convert to floating point}
    if sys_error(stat) then next;

    string_token (resp, p, tk, stat);  {get Y token}
    if string_eos(stat) then exit;
    if sys_error(stat) then next;
    string_t_fpm (tk, y, stat);        {convert to floating point}
    if sys_error(stat) then next;

    string_token (resp, p, tk, stat);  {try to get another token}
    if not string_eos(stat) then next; {extra token ?}
    exit;
    end;
  gui_enter_delete (ent);              {delete the user entry object}
{
*   X,Y contains the amount to move the crop region.
}
  x := crop_lft + (crop_dx / 2.0) + x; {make new desired center point}
  y := crop_top + (crop_dy / 2.0) + y;

  crop_lft := max(1, min(indx - crop_dx + 1,
    trunc(x - (crop_dx / 2.0) + 0.5) ));
  crop_top := max(1, min(indy - crop_dy + 1,
    trunc(y - (crop_dy / 2.0) + 0.5) ));

  iedit_out_geo;                       {update output image geometry}
  iedit_win_op_update;                 {show new crop state}
  iedit_win_img_update;
  end;
{
****************************************
}
    end;                               {end of menu entry ID cases}
done_select:                           {done processing this selection}

leave:                                 {common exit point}
  end;
