module iedit_win_img;
define iedit_win_img_create;
define iedit_win_img_init;
define iedit_win_img;
define iedit_win_img_update;
define iedit_win_img_ncache;
%include 'iedit.ins.pas';

const
  backg_red = 0.20;                    {default background color, 0-1 scale}
  backg_grn = 0.20;
  backg_blu = 0.20;

var
  dpaspect: real;                      {pixel dx/dy aspect ratio of draw area}
  winimg_p: img_scan1_arg_p_t;         {points to all scan lines of image in window}
  reimage: boolean;                    {cached window image must be recomputed}
  fw: xf2d_t;                          {forward (source image to window) transform}
  bk: xf2d_t;                          {backward (window to source image) transform}

function iedit_win_img_evhan (         {event handler for this window}
  in out  win: gui_win_t;              {this window}
  in      app_p: univ_ptr)             {pointer to arbitrary application data}
  :gui_evhan_k_t;                      {returned events handled status}
  val_param; internal; forward;

procedure iedit_win_img_draw (         {drawing routine for root window}
  in out  win: gui_win_t;              {window to draw}
  in      app_p: univ_ptr);            {pointer to arbitrary application data}
  val_param; internal; forward;
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_IMG_INIT
*
*   Initialize the local state of this module.  This routine is called only once
*   during program startup.
}
procedure iedit_win_img_init;
  val_param;

var
  ii: sys_int_machine_t;               {scratch integer}
  r: real;                             {scratch floating point}

begin
  for ii := 0 to 128 do begin          {set up anti-aliasing filter function}
    r := sqr(ii / 128);                {make squared 0-1 radius here}
    r := r * pi;                       {make cosine angle}
    r := cos(r);
    r := (r + 1.0) / 2.0;              {scale cosine to 0-1 range}
    ffunc[ii] := r;
    end;
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_IMG_CREATE
}
procedure iedit_win_img_create;
  val_param;

var
  ix, iy: sys_int_machine_t;           {draw pixel dimensions}
  r: real;                             {scratch floating point}

begin
  rend_set.enter_rend^;
  rend_get.image_size^ (ix, iy, r);    {get draw area properties}
  rend_set.exit_rend^;
  dpaspect := r * iy / ix;             {save aspect ratio of drawing pixels}

  gui_win_child (                      {create this window}
    win_img,                           {returned window object}
    win_root,                          {parent window}
    x_img1, y_img1,                    {lower left corner in parent window}
    x_img2 - x_img1, y_img2 - y_img1); {displacement to upper right corner}

  gui_win_alloc_static (               {allocate memory for one display scan line}
    win_img,                           {window the memory belongs to}
    win_img.rect.dx * win_img.rect.dy * sizeof(winimg_p^[0]), {amount of memory to allocate}
    winimg_p);                         {returned pointer to the new memory}
  reimage := true;                     {init cached window image to invalid}

  gui_win_set_draw (                   {install drawing routine for this window}
    win_img,
    univ_ptr(addr(iedit_win_img_draw)));

  gui_win_set_evhan (                  {install event handler for this window}
    win_img,
    univ_ptr(addr(iedit_win_img_evhan)));
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_IMG_UPDATE
*
*   Cause the image to be re-displayed with the current state and configuration.
}
procedure iedit_win_img_update;        {create and init image display window}
  val_param;

begin
  gui_win_draw_all (win_img);
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_IMG_NCACHE
*
*   Indicates the cached display image, if any, is no longer valid.  The cached
*   image will be recomputed before the next update of the image window.  This
*   routine is called by other parts of the system when any state, such as color
*   mapping, was changed outside this module.
}
procedure iedit_win_img_ncache;        {invalidate cached display image}
  val_param;

begin
  reimage := true;
  end;
{
********************************************************************************
*
*   Local function WINCOOR (RX, RY)
*
*   Returns the GUI window coordinate from the RENDlib device 2DIMI coordinate
*   RX, RY.
}
function wincoor (                     {convert RENDlib to window coordinates}
  in    rx, ry: sys_int_machine_t)     {RENDlib device 2DIMI coordinate}
  :gui_ixy_t;                          {returned GUI library coordinate within window}
  val_param; internal;

var
  ixy: gui_ixy_t;                      {returned coordinate}

begin
  ixy.x := rx - win_img.pos.x;
  ixy.y := (win_img.rect.dy - 1) - (ry - win_img.pos.y);
  wincoor := ixy;
  end;
{
********************************************************************************
*
*   Subroutine IMGWXF (FW, BK)
*
*   Returns the transform from input image pixel coordinates to window GUI
*   coordinates in FW, and the reverse in BK.
*
*   The transform is derived from the input image properties and the global
*   image display position/scale state IDISP_FOCUS, IMGWIN_FOCUS, and
*   IDISP_ZOOM.
}
procedure imgwxf (                     {get the image pixel to window GUI transform}
  out     fw: xf2d_t;                  {forward (image to window) transform}
  out     bk: xf2d_t);                 {reverse (window to image) transform}
  val_param; internal;

var
  x, y: real;                          {scratch coordinate}
  x2, y2: real;

begin
  x :=                                 {make image display area aspect ratio}
    dpaspect * (win_img.rect.dx - 4) / (win_img.rect.dy - 4);

  case roti of

0:  begin                              {not rotated}
      if inaspect >= x
        then begin                     {max fit fills left to right}
          fw.xb.x := idisp_zoom * (win_img.rect.dx - 4) / indx;
          fw.yb.y := -fw.xb.x * dpaspect / inpaspect;
          end
        else begin                     {max fit fills vertically}
          fw.yb.y := idisp_zoom * (win_img.rect.dy - 4) / indy;
          fw.xb.x := fw.yb.y * inpaspect / dpaspect;
          fw.yb.y := -fw.yb.y;
          end
        ;
      fw.xb.y := 0;
      fw.yb.x := 0;
      end;

1:  begin                              {rotated left}
      if (x * inaspect) <= 1
        then begin                     {max fit fills left to right}
          fw.yb.x := idisp_zoom * (win_img.rect.dx - 4) / indy;
          fw.xb.y := fw.yb.x * dpaspect * inpaspect;
          end
        else begin                     {max fit fills vertically}
          fw.xb.y := idisp_zoom * (win_img.rect.dy - 4) / indx;
          fw.yb.x := fw.xb.y / (dpaspect * inpaspect);
          end
        ;
      fw.xb.x := 0.0;
      fw.yb.y := 0.0;
      end;

2:  begin                              {upside down}
      if inaspect >= x
        then begin                     {max fit fills left to right}
          fw.xb.x := -idisp_zoom * (win_img.rect.dx - 4) / indx;
          fw.yb.y := -fw.xb.x * dpaspect / inpaspect;
          end
        else begin                     {max fit fills vertically}
          fw.yb.y := -idisp_zoom * (win_img.rect.dy - 4) / indy;
          fw.xb.x := -fw.yb.y * inpaspect / dpaspect;
          end
        ;
      fw.xb.y := 0;
      fw.yb.x := 0;
      end;

3:  begin                              {rotated right}
      if (x * inaspect) <= 1
        then begin                     {max fit fills left to right}
          fw.yb.x := -idisp_zoom * (win_img.rect.dx - 4) / indy;
          fw.xb.y := fw.yb.x * dpaspect * inpaspect;
          end
        else begin                     {max fit fills vertically}
          fw.xb.y := -idisp_zoom * (win_img.rect.dy - 4) / indx;
          fw.yb.x := fw.xb.y / (dpaspect * inpaspect);
          end
        ;
      fw.xb.x := 0.0;
      fw.yb.y := 0.0;
      end;

otherwise                              {unexpected value of ROTI}
    writeln ('Internal error: ROTI = ', roti);
    sys_bomb;
    end;                               {end of rotation cases}

  x := win_img.rect.dx * imgwin_focus.x; {make window coor of focus point}
  y := win_img.rect.dy * imgwin_focus.y;

  x2 := fw.xb.x*idisp_focus.x + fw.yb.x*idisp_focus.y; {transform focus point without offset}
  y2 := fw.xb.y*idisp_focus.x + fw.yb.y*idisp_focus.y;

  fw.ofs.x := x - x2;                  {set offset to make focus points match}
  fw.ofs.y := y - y2;

  xf2d_inv (fw, bk);                   {make the backwards transform from the forwards}
  end;
{
********************************************************************************
*
*   Local function WINIMG (WX, WY)
*
*   Converts the window GUI coordinate WX,WY to the input image pixel
*   coordinate.
}
function winimg (                      {convert window to image coordinates}
  in      wx, wy: real)                {window GUI coordinate}
  :vect_2d_t;                          {input image pixel coordinate}
  val_param; internal;

var
  xy: vect_2d_t;

begin
  xy.x := bk.xb.x*wx + bk.yb.x*wy + bk.ofs.x; {transform the point}
  xy.y := bk.xb.y*wx + bk.yb.y*wy + bk.ofs.y;
  winimg := xy;                        {pass back the result}
  end;
{
********************************************************************************
*
*   Subroutine IMGWIN (IMGX, IMGY, WINX, WINY)
*
*   Convert the image pixels coordinate IMGX,IMGY to the drawing window GUI
*   coordinate WINX,WINY.  The forward transform FW must be previously set up.
}
procedure imgwin (                     {transform image coordinate to window}
  in      imgx, imgy: real;            {input image pixel coordinate}
  out     winx, winy: real);           {returned window GUI coordinate}
  val_param; internal;

begin
  winx := fw.xb.x*imgx + fw.yb.x*imgy + fw.ofs.x;
  winy := fw.xb.y*imgx + fw.yb.y*imgy + fw.ofs.y;
  end;
{
********************************************************************************
*
*   Function IEDIT_WIN_IMG_EVHAN (WIN, APP_P)
*
*   Event handling routine for this window.  This function is called
*   automatically from the GUI library when appropriate.  The function must
*   return one of the following values:
*
*     GUI_EVHAN_NONE_K  -  No events were processed, queue not altered.
*
*     GUI_EVHAN_DID_K  -  At least one event was processed, all handled.
*
*     GUI_EVHAN_NOTME_K  -  The last event was not for this window.  The
*       unhandled event has been pushed back onto the event queue.
}
function iedit_win_img_evhan (         {event handler for this window}
  in out  win: gui_win_t;              {this window}
  in      app_p: univ_ptr)             {pointer to arbitrary application data}
  :gui_evhan_k_t;                      {returned events handled status}
  val_param; internal;

var
  ev: rend_event_t;                    {event from RENDlib queue}
  modk: rend_key_mod_t;                {set of modifier keys}
  ret: gui_evhan_k_t;                  {function return value}
  redraw: boolean;                     {window must be redrawn as result of events}
  r1, r2: real;                        {scratch floating point}
  ixy: gui_ixy_t;                      {scratch pixel coordinate}
  rect: gui_irect_t;                   {scratch GUI library rectangle}
  lft, rit, top, bot: sys_int_machine_t; {scratch rectangular pixel region}
  p1, p2: vect_2d_t;                   {scratch X,Y points}
  wx, wy: real;                        {scratch window coordinate}
  confirmed: boolean;                  {operation was confirmed by user}

label
  getev, reset_oprect, notus, evdone, done;

begin
  ret := gui_evhan_none_k;             {init to no event handled}
  redraw := false;                     {init to window redraw not required}
  goto getev;                          {go get the first event}

getev:                                 {back here to get next event}
  rend_event_get_nowait (ev);          {get the next event from the event queue}
  case ev.ev_type of                   {what kind of event is it ?}
{
****************************************
*
*   A key was pressed or released.
}
rend_ev_key_k: begin                   {a key was pressed or released}
  modk := ev.key.modk;                 {get set of modifier keys}
  modk := modk - [                     {remove modifiers that are OK or we use}
    rend_key_mod_shiftlock_k,
    rend_key_mod_shift_k];
  if modk <> [] then goto notus;       {punt on any other modifier keys}
  case gui_key_k_t(ev.key.key_p^.id_user) of {check for GUI library special key}
{
**********
*
*   Up arrow.  Zoom in.
}
gui_key_arrow_up_k: begin
  if rend_key_mod_shift_k in ev.key.modk then goto notus;

  if not ev.key.down then goto evdone; {key was released, not pressed ?}
  idisp_zoom := idisp_zoom * 1.414;    {zoom in}
  redraw := true;                      {redraw required}
  reimage := true;                     {cached window image must be recomputed}
  end;
{
**********
*
*   Down arrow.  Zoom out.
}
gui_key_arrow_down_k: begin
  if rend_key_mod_shift_k in ev.key.modk then goto notus;

  if not ev.key.down then goto evdone; {key was released, not pressed ?}
  idisp_zoom := idisp_zoom / 1.414;    {zoom out}
  redraw := true;                      {redraw required}
  reimage := true;                     {cached window image must be recomputed}
  end;
{
**********
*
*   Left mouse button.  Pan image in window.
}
gui_key_mouse_left_k: begin
  if rend_key_mod_shift_k in ev.key.modk then goto notus;
  if rend_key_mod_ctrl_k in ev.key.modk then goto notus;
  if rend_key_mod_alt_k in ev.key.modk then goto notus;
  ixy := wincoor(ev.key.x, ev.key.y);  {make GUI window coor of event}
  if                                   {event was not in this window ?}
      (ixy.x < 0) or (ixy.x >= win.rect.dx) or
      (ixy.y < 0) or (ixy.y >= win.rect.dy)
    then goto notus;

  if not ev.key.down then goto evdone; {key was released, not pressed ?}
  if iedit_drag_line (                 {drag confirmed ?}
      ev.key.x+0.5, ev.key.y+0.5, r1, r2) then begin
    idisp_focus := winimg (ixy.x+0.5, ixy.y+0.5); {set focus point in image}
    ixy := wincoor(trunc(r1), trunc(r2)); {window coor of drag end}
    imgwin_focus.x := (ixy.x+0.5) / win.rect.dx;
    imgwin_focus.y := (ixy.y+0.5) / win.rect.dy;
    reimage := true;                   {cached window image must be recomputed}
    redraw := true;                    {window contents must be redrawn}
    end;
  end;
{
**********
*
*   Right mouse button.  Defines rectangular region of the image.  The meaning
*   of this rectangle is context dependent.
}
gui_key_mouse_right_k: begin
  if rend_key_mod_shift_k in ev.key.modk then goto notus;
  if rend_key_mod_ctrl_k in ev.key.modk then goto notus;
  if rend_key_mod_alt_k in ev.key.modk then goto notus;
  ixy := wincoor(ev.key.x, ev.key.y);  {make GUI window coor of event}
  if                                   {event was not in this window ?}
      (ixy.x < 0) or (ixy.x >= win.rect.dx) or
      (ixy.y < 0) or (ixy.y >= win.rect.dy)
    then goto notus;

  if not ev.key.down then goto evdone; {key was released, not pressed ?}
  confirmed := iedit_drag_box (        {do box drag until cancelled or confirmed}
    win, ev.key.x, ev.key.y, rect);
  case opmode of
{
*   Opmode CROP.  Drag box is the new crop region.
}
opmode_crop_k: begin
  if not confirmed then goto evdone;

  wx := rect.x + 1.0;                  {make lower left window coor}
  wy := rect.y + 1.0;
  p1 := winimg (wx, wy);               {make one corner point in image}
  wx := rect.x + rect.dx;
  wy := rect.y + rect.dy;              {make upper right window coor}
  p2 := winimg (wx, wy);               {make other corner point in image}

  lft := trunc(min(p1.x, p2.x) + 0.5); {make integer pixel coor just inside box}
  rit := trunc(max(p1.x, p2.x) - 0.5);
  top := trunc(min(p1.y, p2.y) + 0.5);
  bot := trunc(max(p1.y, p2.y) - 0.5);

  lft := max(0, min(indx-1, lft));     {clip to image extent}
  rit := max(0, min(indx-1, rit));
  top := max(0, min(indy-1, top));
  bot := max(0, min(indy-1, bot));
  if (rit < lft) or (bot < top) then goto evdone; {ignore if no pixels left}

  crop_lft := lft;                     {set the new crop region}
  crop_dx := rit - lft + 1;
  crop_top := top;
  crop_dy := bot - top + 1;
  crop_asp := inpaspect * crop_dx / crop_dy; {update actual aspect ratio}
  crop_asplock := false;

  iedit_out_geo;                       {update output image geometry}
  iedit_win_op_update;                 {show new state}
  iedit_win_img_update;
  end;
{
*   Opmode COLORS.  Drag box is the new colors region.
}
opmode_colors_k: begin                 {box is new auto color region}
  if not confirmed then begin          {revert back to crop rectangle ?}
reset_oprect:
    iedit_out_op (                     {update op region}
      crop_lft, crop_lft + crop_dx - 1,
      crop_top, crop_top + crop_dy - 1);
    iedit_win_op_update;               {udpate OP window to show no OP region}
    redraw := true;
    goto evdone;
    end;

  wx := rect.x + 1.0;                  {make lower left window coor}
  wy := rect.y + 1.0;
  p1 := winimg (wx, wy);               {make one corner point in image}
  wx := rect.x + rect.dx;
  wy := rect.y + rect.dy;              {make upper right window coor}
  p2 := winimg (wx, wy);               {make other corner point in image}

  lft := trunc(min(p1.x, p2.x) + 0.5); {make integer pixel coor just inside box}
  rit := trunc(max(p1.x, p2.x) - 0.5);
  top := trunc(min(p1.y, p2.y) + 0.5);
  bot := trunc(max(p1.y, p2.y) - 0.5);
  if (rit < lft) or (bot < top) then goto reset_oprect; {no pixels left ?}

  iedit_out_op (lft, rit, top, bot);   {update op region as appropriate}
  iedit_op_colors;                     {compute data for new OP region}
  iedit_win_op_update;                 {udpate OP window with the new data}
  redraw := true;
  end;                                 {end of COLORS op mode case}

    end;                               {end of op modes cases}
  end;                                 {end of right mouse button event}
{
**********
*
*   This is not one of the special keys of the GUI library.  Check for other
*   RENDlib keys we handle.
}
otherwise
  if ev.key.key_p^.spkey.key = rend_key_sp_func_k then begin {special function key}
    case ev.key.key_p^.spkey.detail of {which function key is it ?}
{
**********
*
*         F1: Reset to full image best fit.
*   Shift F1: Set up for 1:1 pixel mapping.
}
1: begin
  if not ev.key.down then goto evdone; {key was released, not pressed ?}

  if rend_key_mod_shift_k in ev.key.modk
    then begin                         {shift HOME}
      r1 := dpaspect * (win.rect.dx-2) / (win.rect.dy-2); {make image area aspect}
      if inaspect >= r1
        then begin                     {image fills area left to right}
          idisp_zoom := indx / (win.rect.dx - 2);
          end
        else begin                     {image fills area top to bottom}
          idisp_zoom := indy / (win.rect.dy - 2);
          end
        ;
      end
    else begin                         {HOME}
      idisp_focus.x := indx / 2.0;     {reset zoom pivot to image center}
      idisp_focus.y := indy / 2.0;
      imgwin_focus.x := 0.5;           {anchor to center of window}
      imgwin_focus.y := 0.5;
      idisp_zoom := 1.0;               {reset to maximum size to fit whole image}
      end
    ;
  redraw := true;                      {redraw is required}
  reimage := true;                     {cached window image must be recomputed}
  end;                                 {end of F1 key case}
{
**********
*
*   Not a F key we handle.
}
otherwise                              {not a function key we handle}
        goto notus;
        end;                           {end of function key cases}
      goto evdone;                     {this function key was handled}
      end;                             {end of function key case}

    goto notus;
    end;                               {end of GUI key event cases}
  end;                                 {end of RENDlib key event type}
{
****************************************
*
*   Unrecognized event.
}
otherwise
notus:                                 {this event is not for us}
    if ev.ev_type <> rend_ev_none_k then begin {real event left unhandled ?}
      rend_event_push (ev);            {put event back onto queue}
      end;
    if ret = gui_evhan_none_k then begin {no previous event handled ?}
      ret := gui_evhan_notme_k;        {indicate event found that was not for us}
      end;
    goto done;
    end;                               {end of RENDlib event type cases}
{
*   This event was handled.
}
evdone:
  ret := gui_evhan_did_k;              {indicate at least one event was processed}
  if redraw then goto getev;           {process as many events as possible before redraw}
{
*   Done handling events.
}
done:
  if redraw then begin                 {window needs to be redrawn ?}
    gui_win_draw_all (win);            {redraw the window}
    end;
  iedit_win_img_evhan := ret;          {pass back status}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_IMG_DRAW (WIN, APP_P)
*
*   Drawing routine for this window.  This routine is called automatically from
*   the GUI library when appropriate.
}
procedure iedit_win_img_draw (         {drawing routine for root window}
  in out  win: gui_win_t;              {window to draw}
  in      app_p: univ_ptr);            {pointer to arbitrary application data}
  val_param; internal;

var
  shx, shy: real;                      {real image to display shrink factor}
  irx, iry: sys_int_machine_t;         {anti-aliasing "radius" in source image}
  r, g, b, r2: real;                   {scratch floating point}
  ox, oy: sys_int_machine_t;           {integer window current pixel coordinate}
  wx, wy: real;                        {window coor at center of current pixel}
  wsx, wsy: real;                      {window coor of current input subpixel}
  ix, iy: sys_int_machine_t;           {image pixel coordinate}
  in_lft, in_rit, in_top, in_bot:      {input image coordinate limits to display}
    sys_int_machine_t;
  x, y: real;                          {scratch X,Y coordinate}
  sx, sy: sys_int_machine_t;           {source subpixel coordinate}
  weight: real;                        {accumulated subpixel weights}
  red, grn, blu: real;                 {0.0 to 1.0 color value}
  sz: sys_int_adr_t;                   {memory size}
  scan_p: img_scan1_arg_p_t;           {points to current scan line in window image}
  iten: real;                          {pixel intensity}
  itene: real;                         {intensity with brighten exponent applied}

begin
  if not inputimg then begin           {no input image is available ?}
    fw.xb.x := 1.0;                    {set transforms to benign values, shouldn't be used}
    fw.xb.y := 0.0;
    fw.yb.x := 0.0;
    fw.yb.y := 1.0;
    fw.ofs.x := 0.0;
    fw.ofs.y := 0.0;
    bk.xb.x := 1.0;
    bk.xb.y := 0.0;
    bk.yb.x := 0.0;
    bk.yb.y := 1.0;
    bk.ofs.x := 0.0;
    bk.ofs.y := 0.0;
    rend_set.rgb^ (0.30, 0.30, 0.30);  {clear window to gray}
    rend_prim.clear_cwind^;
    reimage := true;                   {make sure cached image is flagged as inavlid}
    return;
    end;

  iedit_color_upd;                     {make sure derived color data is up to date}
{
*   Set up the geometric mapping from window pixels to the original source image
*   pixels.
}
  imgwxf (                             {get the image/window coordiate mappings}
    fw,                                {image to window GUI coordinates transform}
    bk);                               {window GUI coordinates to image transform}

  case opmode of
opmode_crop_k: begin
      in_lft := 0;                     {display the full image}
      in_rit := indx - 1;
      in_top := 0;
      in_bot := indy - 1;
      end;
otherwise
    in_lft := crop_lft;                {display only the crop region}
    in_rit := crop_lft + crop_dx - 1;
    in_top := crop_top;
    in_bot := crop_top + crop_dy - 1;
    end;

  shx :=                               {shrink factor along X in input image}
    1.0 / sqrt(sqr(fw.xb.x) + sqr(fw.xb.y));
  shy :=                               {shrink factor along Y in input image}
    1.0 / sqrt(sqr(fw.yb.x) + sqr(fw.yb.y));
  irx := trunc(abs(shx)) + 1;          {distance around source pixel for anti-aliasing}
  iry := trunc(abs(shy)) + 1;
  if not disp_aa then begin            {don't anti-alias ?}
    irx := 0;
    iry := 0;
    end;
{
*   Set up the drawing state for drawing the image in the IMG window.
}
  rend_set.iterp_span_on^ (rend_iterp_red_k, true); {enable RGB for SPAN primitive}
  rend_set.iterp_span_on^ (rend_iterp_grn_k, true);
  rend_set.iterp_span_on^ (rend_iterp_blu_k, true);

  rend_set.iterp_span_ofs^ (rend_iterp_red_k, ord(img_col_red_k)); {configure span pixels}
  rend_set.iterp_span_ofs^ (rend_iterp_grn_k, ord(img_col_grn_k));
  rend_set.iterp_span_ofs^ (rend_iterp_blu_k, ord(img_col_blu_k));

  sz := sizeof(scan_p^[0]);
  rend_set.span_config^ (sz);          {mem offset of pixels in span}

  rend_set.cpnt_2dimi^ (win.pos.x, win.pos.y); {to top left corner of draw window}
  rend_prim.rect_px_2dimcl^ (win.rect.dx, win.rect.dy); {declare draw region for spans}
{
*   Draw the image as mapped to the window.
}
  iedit_color_upd;                     {make sure cached color mappings are up to date}

  for oy := win.rect.dy-1 downto 0 do begin {down the window scan lines}
    scan_p := univ_ptr(addr(winimg_p^[oy * win.rect.dx])); {point to this window image scan line}
    if reimage then begin              {cached image out of date, recompute this scan line ?}
      wy := oy + 0.5;                  {window Y at center of this scan line}
      for ox := 0 to win.rect.dx-1 do begin {accross this scan line to draw}
        wx := ox + 0.5;                {window X at center of this pixel}
        x := bk.xb.x*wx + bk.yb.x*wy + bk.ofs.x; {image point at center of output pixel}
        y := bk.xb.y*wx + bk.yb.y*wy + bk.ofs.y;
        if x >= 0.0                    {make IX,IY image pixel win pix is in}
          then ix := trunc(x)
          else ix := trunc(x) - 1;
        if y >= 0.0
          then iy := trunc(y)
          else iy := trunc(y) - 1;
        {
        *   IX,IY is the source image pixel that the center of the output pixel
        *   falls within.  IX,IY may be outside the source image or the region
        *   of it to display.
        }
        red := 0.0;                    {init accumulated color contributions}
        grn := 0.0;
        blu := 0.0;
        weight := 0.0;                 {init accumulated subpixel weights}
        for sy := iy-iry to iy+iry do begin {down the subpixel pattern}
          for sx := ix-irx to ix+irx do begin {accross this subpixel row}
            x := sx + 0.5;             {make image coor at center of this subpixel}
            y := sy + 0.5;
            wsx := fw.xb.x*x + fw.yb.x*y + fw.ofs.x; {window coor at subpixel center}
            wsy := fw.xb.y*x + fw.yb.y*y + fw.ofs.y;
            r := sqr(wsx - wx) + sqr(wsy - wy); {square of distance to this subpixel}
            if r < 1.0 then begin      {within the anti-aliasing filter distance ?}
              r2 := ffunc[trunc(r * 128.0)]; {get weight of this subpixel}
              weight := weight + r2;   {add this weight contribution into accumulator}
              if
                  (sx >= in_lft) and (sx <= in_rit) and
                  (sy >= in_top) and (sy <= in_bot)
                then begin             {this subpixel is within the source area}
                  r := max(0.0, min(1.0, {convert pixel to 0-1 output scale}
                    inscan_p^[sy]^[sx].red * col.mul_red + col.ofs_red));
                  g := max(0.0, min(1.0,
                    inscan_p^[sy]^[sx].grn * col.mul_grn + col.ofs_grn));
                  b := max(0.0, min(1.0,
                    inscan_p^[sy]^[sx].blu * col.mul_blu + col.ofs_blu));
                  iten := max(r, g, b); {make pixel intensity}
                  {
                  *   Perform non-linear intensity mapping.  The non-linear
                  *   intensity mapping results from BRIGHTEN and LOG scaling, for
                  *   example.  The input color range has already been applied.
                  *   The COL.ITEN array is therefore in the full black to white
                  *   space after input black and white level adjustments.
                  }
                  if iten > 10.0e-6 then begin {intensity is above 0, perform computation ?}
                    itene :=           {get output intensity for this input intensity}
                      col.iten[trunc(col_arscale * iten)];
                    r :=               {apply saturation mapping}
                      itene * col.sat[trunc(col_arscale * r / iten)];
                    g :=
                      itene * col.sat[trunc(col_arscale * g / iten)];
                    b :=
                      itene * col.sat[trunc(col_arscale * b / iten)];
                    end;
                  end
                else begin             {this subpixel is outside the source area}
                  r := backg_red;
                  g := backg_grn;
                  b := backg_blu;
                  end
                ;
              red := red + r * r2;     {add contribution from this subpixel}
              grn := grn + g * r2;
              blu := blu + b * r2;
              end;
            end;
          end;

        if weight < 0.0001
          then begin                   {no subpixel contributions, use nearest}
            if
                (ix >= in_lft) and (ix <= in_rit) and
                (iy >= in_top) and (iy <= in_bot)
              then begin               {source pixel is within the source area}
                r := max(0.0, min(1.0, {convert pixel to 0-1 output scale}
                  inscan_p^[iy]^[ix].red * col.mul_red + col.ofs_red));
                g := max(0.0, min(1.0,
                  inscan_p^[iy]^[ix].grn * col.mul_grn + col.ofs_grn));
                b := max(0.0, min(1.0,
                  inscan_p^[iy]^[ix].blu * col.mul_blu + col.ofs_blu));
                iten := max(r, g, b);  {make pixel intensity}
                if iten > 10.0e-6 then begin {intensity is above 0, perform computation ?}
                  itene :=             {get output intensity for this input intensity}
                    col.iten[trunc(col_arscale * iten)];
                  red :=               {apply saturation mapping}
                    itene * col.sat[trunc(col_arscale * r / iten)];
                  grn :=
                    itene * col.sat[trunc(col_arscale * g / iten)];
                  blu :=
                    itene * col.sat[trunc(col_arscale * b / iten)];
                  end;
                end
              else begin               {source pixel is outside the source area}
                red := backg_red;
                grn := backg_grn;
                blu := backg_blu;
                end
              ;
            end
          else begin                   {enough subpixel contributions to use}
            red := red / weight;       {make blended color from subpixel contributions}
            grn := grn / weight;
            blu := blu / weight;
            end
          ;

        red := max(0.0, min(0.998, red)); {clip pixel values to min/max range}
        grn := max(0.0, min(0.998, grn));
        blu := max(0.0, min(0.998, blu));
        scan_p^[ox].red := trunc(red * 256.0); {convert to integer and write to output pixel}
        scan_p^[ox].grn := trunc(grn * 256.0);
        scan_p^[ox].blu := trunc(blu * 256.0);
        end;                           {back to do next pixel accross}
      end;                             {done recomputing this window image scan line}
    rend_prim.span_2dimcl^ (win.rect.dx, scan_p^); {draw this window image scan line}
    end;
  reimage := false;                    {cached window image is now valid}
{
*   Show the crop border if appropriate.
}
  if opmode = opmode_crop_k then begin
    {   Make pixel coordinates of inner box to draw, IX to OX, IY to OY.
    }
    imgwin (crop_lft, crop_top, x, y);
    imgwin (crop_lft + crop_dx, crop_top + crop_dy, wx, wy);
    ix := trunc(min(x, wx) - 0.5);     {left of region}
    ox := trunc(max(x, wx) + 0.5);     {right of region}
    iy := trunc(min(y, wy) - 0.5);     {just below region}
    oy := trunc(max(y, wy) + 0.5);     {just above region}

    rend_set.rgb^ (0.30, 0.30, 0.30);  {inner box color}
    rend_set.cpnt_2d^ (ix + 0.5, iy + 0.5);
    rend_prim.vect_2d^ (ox + 0.5, iy + 0.5);
    rend_prim.vect_2d^ (ox + 0.5, oy + 0.5);
    rend_prim.vect_2d^ (ix + 0.5, oy + 0.5);
    rend_prim.vect_2d^ (ix + 0.5, iy + 0.5);

    rend_set.rgb^ (0.0, 0.0, 0.0);     {outer box color}
    ix := ix - 1;
    ox := ox + 1;
    iy := iy - 1;
    oy := oy + 1;
    rend_set.cpnt_2d^ (ix + 0.5, iy + 0.5);
    rend_prim.vect_2d^ (ox + 0.5, iy + 0.5);
    rend_prim.vect_2d^ (ox + 0.5, oy + 0.5);
    rend_prim.vect_2d^ (ix + 0.5, oy + 0.5);
    rend_prim.vect_2d^ (ix + 0.5, iy + 0.5);
    end;
{
*   Show the operation region if appropriate.
}
  case opmode of

opmode_colors_k: begin
  if col_op then begin                 {OP region in use ?}
    {   Make pixel coordinates of inner box to draw, IX to OX, IY to OY.
    }
    imgwin (op_lft, op_top, x, y);
    imgwin (op_lft + op_dx, op_top + op_dy, wx, wy);
    ix := trunc(min(x, wx) - 0.5);     {left of region}
    ox := trunc(max(x, wx) + 0.5);     {right of region}
    iy := trunc(min(y, wy) - 0.5);     {just below region}
    oy := trunc(max(y, wy) + 0.5);     {just above region}

    rend_set.rgb^ (0.30, 0.30, 0.30);  {inner box color}
    rend_set.cpnt_2d^ (ix + 0.5, iy + 0.5);
    rend_prim.vect_2d^ (ox + 0.5, iy + 0.5);
    rend_prim.vect_2d^ (ox + 0.5, oy + 0.5);
    rend_prim.vect_2d^ (ix + 0.5, oy + 0.5);
    rend_prim.vect_2d^ (ix + 0.5, iy + 0.5);

    rend_set.rgb^ (0.0, 0.0, 0.0);     {outer box color}
    ix := ix - 1;
    ox := ox + 1;
    iy := iy - 1;
    oy := oy + 1;
    rend_set.cpnt_2d^ (ix + 0.5, iy + 0.5);
    rend_prim.vect_2d^ (ox + 0.5, iy + 0.5);
    rend_prim.vect_2d^ (ox + 0.5, oy + 0.5);
    rend_prim.vect_2d^ (ix + 0.5, oy + 0.5);
    rend_prim.vect_2d^ (ix + 0.5, iy + 0.5);
    end;
  end;                                 {end of opmode case to show operations region}

    end;                               {end of opmode cases}

  end;
