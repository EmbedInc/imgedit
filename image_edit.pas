program "gui" image_edit;
%include 'iedit.ins.pas';
define iedit;                          {define the common block private to this program}

const
  max_msg_args = 2;                    {max arguments we can pass to a message}

var
  fnam_in:                             {input file name}
    %include '(cog)lib/string_treename.ins.pas';
  fnam_out:                            {output file name}
    %include '(cog)lib/string_treename.ins.pas';
  rend_name:                           {RENDlib device name}
    %include '(cog)lib/string_treename.ins.pas';
  keys_p: rend_key_ar_p_t;             {pointer to array of key descriptors}
  nk: sys_int_machine_t;               {number of keys in array}
  ii: sys_int_machine_t;               {scratch integer and loop counter}
  r: real;                             {scratch floating point}
  iname_set: boolean;                  {TRUE if the input file name already set}
  oname_set: boolean;                  {TRUE if the output file name already set}
  ev: rend_event_t;                    {one RENDlib event}

  opt:                                 {upcased command line option}
    %include '(cog)lib/string_treename.ins.pas';
  parm:                                {command line option parameter}
    %include '(cog)lib/string_treename.ins.pas';
  pick: sys_int_machine_t;             {number of token picked from list}
  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;                     {completion status code}

label
  next_opt, err_parm, parm_bad, done_opts, opened,
  loop_event, leave;
{
********************************************************************************
*
*   Start of main routine.
}
begin
{
*   Initialize before reading the command line.
}
  string_cmline_init;                  {init for reading the command line}
  iname_set := false;                  {no input file name specified}
  oname_set := false;                  {no output file name specified}
  disp_aa := false;                    {init to not anti-alias the main display}
  intnam.max := size_char(intnam.str);
  intnam.len := 0;
{
*   Back here each new command line option.
}
next_opt:
  string_cmline_token (opt, stat);     {get next command line option name}
  if string_eos(stat) then goto done_opts; {exhausted command line ?}
  sys_error_abort (stat, 'string', 'cmline_opt_err', nil, 0);
  if (opt.len >= 1) and (opt.str[1] <> '-') then begin {implicit pathname token ?}
    if not iname_set then begin        {input file name not set yet ?}
      string_treename(opt, fnam_in);   {set input file name}
      iname_set := true;               {input file name is now set}
      goto next_opt;
      end;
    if not oname_set then begin        {output file name not set yet ?}
      string_treename (opt, fnam_out); {set output file name}
      oname_set := true;               {output file name is now set}
      goto next_opt;
      end;
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_upcase (opt);                 {make upper case for matching list}
  string_tkpick80 (opt,                {pick command line option name from list}
    '-IN -OUT -DEV',
    pick);                             {number of keyword picked from list}
  case pick of                         {do routine for specific option}
{
*   -IN filename
}
1: begin
  if iname_set then begin              {input file name already set ?}
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_cmline_token (opt, stat);
  string_treename (opt, fnam_in);
  iname_set := true;
  end;
{
*   -OUT filename
}
2: begin
  if oname_set then begin              {output file name already set ?}
    sys_msg_parm_vstr (msg_parm[1], opt);
    sys_message_bomb ('string', 'cmline_opt_conflict', msg_parm, 1);
    end;
  string_cmline_token (opt, stat);
  string_treename (opt, fnam_out);
  oname_set := true;
  end;
{
*   -DEV <RENDlib device name>
}
3: begin
  string_cmline_token (rend_name, stat);
  end;
{
*   Unrecognized command line option.
}
otherwise
    string_cmline_opt_bad;             {unrecognized command line option}
    end;                               {end of command line option case statement}

err_parm:                              {jump here on error with parameter}
  string_cmline_parm_check (stat, opt); {check for bad command line option parameter}
  goto next_opt;                       {back for next command line option}

parm_bad:                              {jump here on got illegal parameter}
  string_cmline_reuse;                 {re-read last command line token next time}
  string_cmline_token (parm, stat);    {re-read the token for the bad parameter}
  sys_msg_parm_vstr (msg_parm[1], parm);
  sys_msg_parm_vstr (msg_parm[2], opt);
  sys_message_bomb ('string', 'cmline_parm_bad', msg_parm, 2);

done_opts:                             {done with all the command line options}
  inputimg := false;                   {init to input image is not open}
  wind_bitmap_alloc := false;          {init to pixels not allocated to bitmap}
  windows := false;                    {indicate GUI windows not currently exist}
  opmode := opmode_crop_k;             {init main operating mode}
  out_fitx := 1920;
  out_fity := 1200;
  out_itype.max := size_char(out_itype.str);
  out_tnam.max := size_char(out_tnam.str);

  for ii := 0 to 128 do begin          {set up anti-aliasing filter function}
    r := sqrt((ii + 0.5) / 128.0);     {make radius here}
    r := r * pi;                       {make cosine angle}
    r := cos(r);
    r := (r + 1.0) / 2.0;              {scale cosine to 0-1 range}
    ffunc[ii] := max(0.0, r);          {final weighting factor at this dist squared}
    end;

  iedit_color_init;                    {init color mapping module}
{
*   Initialize the graphics system and the windows.
}
  rend_start;                          {initialize RENDlib}
  if rend_name.len <= 0 then begin     {no explicit graphics device name given ?}
    rend_open (string_v('image_edit'), rendev, stat); {try with program name}
    if not sys_error(stat) then goto opened; {successfully opened ?}
    rend_open (string_v('*screen*'), rendev, stat); {try full screen}
    if not sys_error(stat) then goto opened; {successfully opened ?}
    end;
  rend_open (rend_name, rendev, stat); {open the RENDlib device}
  sys_error_abort (stat, '', '', nil, 0);
opened:

  util_mem_context_get (               {get mem context for any permanent mem}
    util_top_mem_context,              {parent memory context}
    mem_p);                            {returned pointer to new mem context}

  rend_set.enter_rend^;                {push one level into graphics mode}

  rend_get.text_parms^ (tparm);        {get default text control parameters}
  tparm.width := 0.72;
  tparm.height := 1.0;
  tparm.slant := 0.0;
  tparm.rot := 0.0;
  tparm.lspace := 0.7;
  tparm.coor_level := rend_space_2d_k;
  tparm.poly := false;
  rend_set.text_parms^ (tparm);        {set our new "base" text control parameters}

  rend_get.poly_parms^ (pparm);        {get default polygon control parameters}
  pparm.subpixel := true;
  rend_set.poly_parms^ (pparm);        {set our new "base" polygon control parms}

  rend_get.vect_parms^ (vparm);        {get default vector control parameters}
  vparm.width := 2.0;
  vparm.poly_level := rend_space_none_k;
  vparm.subpixel := false;
  rend_set.vect_parms^ (vparm);        {set our new "base" vector control parameters}

  rend_set.alloc_bitmap_handle^ (      {create handle for our software bitmap}
    rend_scope_dev_k,                  {deallocate handle when device closed}
    wind_bitmap);                      {returned bitmap handle}

  rend_set.iterp_bitmap^ (rend_iterp_red_k, wind_bitmap, 0); {connect iterps to bitmap}
  rend_set.iterp_bitmap^ (rend_iterp_grn_k, wind_bitmap, 1);
  rend_set.iterp_bitmap^ (rend_iterp_blu_k, wind_bitmap, 2);

  rend_set.iterp_on^ (rend_iterp_red_k, true); {enable the interpolants}
  rend_set.iterp_on^ (rend_iterp_grn_k, true);
  rend_set.iterp_on^ (rend_iterp_blu_k, true);

  rend_set.min_bits_vis^ (24.0);       {try for high color resolution}

  rend_set.update_mode^ (rend_updmode_buffall_k); {buffer SW updates for speed sake}

  rend_set.event_req_close^ (true);    {enable CLOSE, CLOSE_USER}
  rend_set.event_req_wiped_resize^ (true); {redraw due to size change}
  rend_set.event_req_wiped_rect^ (true); {redraw due to got corrupted}
  rend_set.event_req_pnt^ (true);      {request pointer motion events}
  gui_events_init_key;                 {enable keys required by GUI library}

  rend_set.enter_level^ (0);           {make sure we are out of graphics mode}

  iedit_win_img_init;                  {one-time initialization}

  gui_events_init_key;                 {set up RENDlib key events}
  rend_get.keys^ (keys_p, nk);         {get key descriptors array info}
  for ii := 1 to nk do begin           {once for each key}
    with keys_p^[ii]:key do begin
    if key.spkey.key = rend_key_sp_func_k then begin {F key ?}
      rend_set.event_req_key_on^ (key.id, 0);
      end;
    end;                               {done with KEY abbreviation}
    end;                               {back to examine next key descriptor}

  iedit_resize;                        {make initial set of windows}
  gui_win_draw_all (win_root);         {draw initial blank state}
{
*   Initialize input image state.
}
  if fnam_in.len > 1 then begin        {input image name was provided on command line ?}
    iedit_open (fnam_in);              {try to open the input image}
    end;
{
*   Handle top level events.
}
loop_event:                            {back here to get each new RENDlib event}
  rend_event_get (ev);                 {wait for the next event}
  rend_event_push (ev);                {put the event back}
  case gui_win_evhan (win_root, false) of {handle event in windows if possible}
gui_evhan_notme_k: ;                   {found event that no window handled ?}
otherwise
    goto loop_event;
    end;
  rend_event_get (ev);                 {get the unhandled event}
  case ev.ev_type of                   {what kind of event is this ?}
{
**********
*
*   The drawing device has been closed.
}
rend_ev_close_k: begin                 {drawing device has been closed}
  goto leave;
  end;
{
**********
*
*   The user has requested that the drawing device be closed.
}
rend_ev_close_user_k: begin            {user wants to close device}
  goto leave;
  end;
{
**********
*
*   A rectangle of pixels was wiped out and can now be re-drawn.
}
rend_ev_wiped_rect_k: begin            {rectangular region needs redraw}
  gui_win_draw (                       {redraw a region}
    win_root,                          {window to draw}
    ev.wiped_rect.x,                   {left X}
    ev.wiped_rect.x + ev.wiped_rect.dx, {right X}
    win_root.rect.dy - ev.wiped_rect.y - ev.wiped_rect.dy, {bottom Y}
    win_root.rect.dy - ev.wiped_rect.y); {top Y}
  end;
{
**********
*
*   The size of the drawing device has changed.
}
rend_ev_wiped_resize_k: begin          {drawing device size changed}
  iedit_resize;                        {adjust to new drawing area size}
  gui_win_draw_all (win_root);         {redraw everything}
  end;
{
**********
*
*   Not a event we handle at this level, ignore it.
}
    end;                               {end of event type cases}
  goto loop_event;                     {back to get next event}

leave:                                 {exit the program}
  gui_win_delete (win_root);           {delete all the windows}
  rend_end;                            {shut down the graphics system}
  end.
