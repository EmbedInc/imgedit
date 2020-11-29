module iedit_drag;
define iedit_drag_line;
define iedit_drag_box;
%include 'iedit.ins.pas';
{
********************************************************************************
*
*   Function IEDIT_DRAG_LINE (STARTX, STARTY, ENDX, ENDY)
*
*   Perform a rubber band drag operation.  STARTX,STARTY are the RENDlib
*   coordinates for the drag starting location.  ENDX,ENDY will be set
*   to the RENDlib coordinates of the drag end location confirmed by the
*   user.  The function returns TRUE if the user confirmed the drag end,
*   and FALSE if the drag operation was cancelled for whatever reason.
*   ENDX and ENDY are undefined if the function returns FALSE.
*
*   It is assumed that the drag operation was initiated by a press of the
*   left mouse button, and that this mouse button is still pressed.  The
*   drag will be ended and confirmed when this mouse button is released.
*   Any event not related to a normal drag cancells the drag, in which case
*   the unexpected event is pushed back onto the event queue.
}
function iedit_drag_line (             {perform a pointer rubber band drag operation}
  in      startx, starty: real;        {RENDlib coordinates of drag start}
  out     endx, endy: real)            {final RENDlib end of drag coordinates}
  :boolean;                            {TRUE if drag confirmed, not cancelled}
  val_param;

var
  sx, sy: sys_int_machine_t;           {2DIMI pixel coordinate of drag start}
  ix, iy: sys_int_machine_t;           {2DIMI pixel coordinate of current drag end}
  ev: rend_event_t;                    {one RENDlib event}
  modk: rend_key_mod_t;                {set of modifier keys}

label
  loop_event, cancel;
{
********************
*
*   Internal subroutine LINE
*
*   Draw the rubber band line once from SX,SY to IX,IY.  It is assumed that
*   XOR mode is in effect, so drawing the line a second time will erase it.
}
procedure line;
  val_param; internal;

begin
  rend_set.cpnt_2dim^ (sx + 0.5, sy + 0.5);
  rend_prim.vect_2dim^ (ix + 0.5, iy + 0.5);
  end;
{
********************
*
*   Internal subroutine NEWLINE (X, Y)
*
*   Update the rubber band line to the new end point X,Y.
}
procedure newline (
  in      x, y: sys_int_machine_t);
  val_param;

begin
  line;                                {erase old line by drawing again in XOR mode}
  ix := x;                             {update drag end point}
  iy := y;
  line;                                {draw line in new position}
  end;
{
********************
*
*   Internal subroutine UNDRAG
*
*   Erase the drag line and restore the drawing state.
}
procedure undrag;
  val_param; internal;

begin
  line;                                {erase old line by drawing again in XOR mode}
  rend_set.iterp_pixfun^ (rend_iterp_red_k, rend_pixfun_insert_k);
  rend_set.iterp_pixfun^ (rend_iterp_grn_k, rend_pixfun_insert_k);
  rend_set.iterp_pixfun^ (rend_iterp_blu_k, rend_pixfun_insert_k);
  end;
{
********************
*
*   Start of main routine.
}
begin
  sx := trunc(startx);                 {save 2DIMI coordinate of drag start}
  sy := trunc(starty);
  discard( rend_get.pointer^ (ix, iy) ); {init current end of drag}
  rend_set.iterp_pixfun^ (rend_iterp_red_k, rend_pixfun_xor_k);
  rend_set.iterp_pixfun^ (rend_iterp_grn_k, rend_pixfun_xor_k);
  rend_set.iterp_pixfun^ (rend_iterp_blu_k, rend_pixfun_xor_k);
  rend_set.rgb^ (0.5, 0.5, 0.5);       {set value to XOR against existing pixels}
  line;                                {draw initial rubber band line}

loop_event:                            {back here to get each new event}
  rend_event_get (ev);                 {get the next event from the event queue}
  case ev.ev_type of                   {what kind of event is it ?}
{
*   A key was pressed or released.
}
rend_ev_key_k: begin                   {a key was pressed or released}
      if ev.key.down then goto cancel; {a key was pressed, not released ?}
      modk := ev.key.modk;             {get set of modifier keys}
      modk := modk - [                 {remove modifiers that are OK}
        rend_key_mod_shiftlock_k];
      if modk <> [] then goto cancel;  {punt on any other modifier keys}
      if gui_key_k_t(ev.key.key_p^.id_user) <> gui_key_mouse_left_k
        then goto cancel;              {not left mouse button ?}

      undrag;                          {exit drag mode}
      endx := ix + 0.5;                {return final drag end coordinates}
      endy := iy + 0.5;
      iedit_drag_line := true;         {indicate drag confirmed}
      return;
      end;
{
*   The pointer moved.
}
rend_ev_pnt_move_k: begin
      newline (ev.pnt_move.x, ev.pnt_move.y);
      end;
{
*   The pointer entered the drawing area.
}
rend_ev_pnt_enter_k: ;                 {ignore this}
{
*   The pointer left the drawing area.
}
rend_ev_pnt_exit_k: ;                  {ignore this}
{
*   Event that is not part of the drag operation.  This cancels the drag.
}
otherwise
    goto cancel;
    end;
  goto loop_event;                     {back to get and process the next event}
{
*   Cancel the drag operation.  The event in EV will be pushed back onto
*   the event queue.
}
cancel:
  undrag;                              {exit drag mode}
  rend_event_push (ev);                {push unexpected event back onto the queue}
  iedit_drag_line := false;            {indicate the drag operation was canceled}
  end;
{
********************************************************************************
*
*   Function IEDIT_DRAG_BOX (WIN, STARTX, STARTY, RECT)
*
*   Perform a rectangular box drag operation.  STARTX,STARTY are the RENDlib
*   coordinates for the drag starting location.  RECT is returned indicating the
*   final rectangle, which is guaranteed to be within the window WIN.  RECT is
*   in GUI window coordinates, with the DX and DY files guaranteed to be zero or
*   positive.
*
*   It is assumed that the drag operation was initiated by a press of the right
*   mouse button, and that this mouse button is still pressed.  The drag will be
*   ended and confirmed when this mouse button is released.  Any event not
*   related to a normal drag cancells the drag, in which case the unexpected
*   event is pushed back onto the event queue.
*
*   RECT is not defined if the operation is cancelled (function returns FALSE).
}
function iedit_drag_box (              {perform a pointer box drag operation}
  in      win: gui_win_t;              {window to confine drag within}
  in      startx, starty: sys_int_machine_t; {RENDlib drag start pixel}
  out     rect: gui_irect_t)           {returned final rectangle, GUI coordinates}
  :boolean;                            {TRUE if drag confirmed, not cancelled}
  val_param;

var
  stx, sty: sys_int_machine_t;         {saved copy of STARTX,STARTY}
  xl, xr: sys_int_machine_t;           {left and right X of box interior}
  yt, yb: sys_int_machine_t;           {top and bottom Y of box interior}
  xliml, xlimr, ylimt, ylimb:          {allowed rectangle limits, RENDlib coor}
    sys_int_machine_t;
  ix, iy: sys_int_machine_t;           {scratch coordinate}
  ev: rend_event_t;                    {one RENDlib event}
  modk: rend_key_mod_t;                {set of modifier keys}

label
  loop_event, cancel;
{
********************
*
*   Internal subroutine DRAW
*
*   Draw the box.  It is assumed that XOR mode is in effect, so drawing the box
*   a second time will erase it.
}
procedure draw;
  val_param; internal;

begin
  rend_set.cpnt_2dimi^ (xl, yt);
  rend_prim.vect_2dimi^ (xl, yb-1);

  rend_set.cpnt_2dimi^ (xl, yb);
  rend_prim.vect_2dimi^ (xr-1, yb);

  rend_set.cpnt_2dimi^ (xr, yb);
  rend_prim.vect_2dimi^ (xr, yt+1);

  rend_set.cpnt_2dimi^ (xr, yt);
  rend_prim.vect_2dimi^ (xl+1, yt);
  end;
{
********************
*
*   Internal subroutine NEWCOOR (X, Y)
*
*   Update the box coordinates to the new pointer coordinate X,Y.
}
procedure newcoor (
  in      x, y: sys_int_machine_t);
  val_param; internal;

begin
  xl := max(xliml, min(xlimr, stx, x)); {compute new box coordinates}
  xr := min(xlimr, max(xliml, stx, x));
  yt := max(ylimt, min(ylimb, sty, y));
  yb := min(ylimb, max(ylimt, sty, y));
  end;
{
********************
*
*   Internal subroutine NEWDRAW (X, Y)
*
*   Update the internal state and the display to the new pointer coordinate X,Y.
}
procedure newdraw (
  in      x, y: sys_int_machine_t);
  val_param; internal;

begin
  draw;                                {redraw old display to erase it}
  newcoor (x, y);                      {update box coordinate to new point}
  draw;                                {draw the display in the new location}
  end;
{
********************
*
*   Internal subroutine UNDRAG
*
*   Erase the display and restore the drawing state.
}
procedure undrag;
  val_param; internal;

begin
  draw;                                {redraw old display to erase it}
  rend_set.iterp_pixfun^ (rend_iterp_red_k, rend_pixfun_insert_k);
  rend_set.iterp_pixfun^ (rend_iterp_grn_k, rend_pixfun_insert_k);
  rend_set.iterp_pixfun^ (rend_iterp_blu_k, rend_pixfun_insert_k);
  end;
{
********************
*
*   Start of main routine.
}
begin
  stx := startx;                       {make local copy of start coordinate}
  sty := starty;

  xliml := win.pos.x;                  {make rectangle interior limits}
  xlimr := win.pos.x + win.rect.dx - 1;
  ylimt := win.pos.y;
  ylimb := win.pos.y + win.rect.dy - 1;

  rend_set.iterp_pixfun^ (rend_iterp_red_k, rend_pixfun_xor_k);
  rend_set.iterp_pixfun^ (rend_iterp_grn_k, rend_pixfun_xor_k);
  rend_set.iterp_pixfun^ (rend_iterp_blu_k, rend_pixfun_xor_k);
  rend_set.rgb^ (0.5, 0.5, 0.5);       {set value to XOR against existing pixels}
  discard( rend_get.pointer^ (ix, iy) ); {get current pointer coordinate}
  newcoor (ix, iy);                    {compute starting box coordinates}
  draw;                                {draw starting box}

loop_event:                            {back here to get each new event}
  rend_event_get (ev);                 {get the next event from the event queue}
  case ev.ev_type of                   {what kind of event is it ?}
{
*   A key was pressed or released.
}
rend_ev_key_k: begin                   {a key was pressed or released}
      if ev.key.down then goto cancel; {a key was pressed, not released ?}
      modk := ev.key.modk;             {get set of modifier keys}
      modk := modk - [                 {remove modifiers that are OK}
        rend_key_mod_shiftlock_k];
      if modk <> [] then goto cancel;  {punt on any other modifier keys}
      if gui_key_k_t(ev.key.key_p^.id_user) <> gui_key_mouse_right_k
        then goto cancel;              {not right mouse button ?}

      undrag;                          {exit drag mode}
      {
      *   The final RENDlib coordinates of the box are in XL, XR, YT, YB.
      }
      rect.x := xl - win.pos.x;        {return rectangle in window GUI coor}
      rect.dx := xr - xl + 1;
      rect.y := win.rect.dy - yb + win.pos.y - 1;
      rect.dy := yb - yt + 1;
      iedit_drag_box := true;          {indicate drag confirmed}

(*
      writeln ('Box point ', rect.x, ',', rect.y, ' size ', rect.dx, ',', rect.dy);
*)

      return;
      end;
{
*   The pointer moved.
}
rend_ev_pnt_move_k: begin
      newdraw (ev.pnt_move.x, ev.pnt_move.y);
      end;
{
*   The pointer entered the drawing area.
}
rend_ev_pnt_enter_k: ;                 {ignore this}
{
*   The pointer left the drawing area.
}
rend_ev_pnt_exit_k: ;                  {ignore this}
{
*   Event that is not part of the drag operation.  This cancels the drag.
}
otherwise
    goto cancel;
    end;
  goto loop_event;                     {back to get and process the next event}
{
*   Cancel the drag operation.  The event in EV will be pushed back onto
*   the event queue.
}
cancel:
  undrag;                              {exit drag mode}
  rend_event_push (ev);                {push unexpected event back onto the queue}
  iedit_drag_box := false;             {indicate the drag operation was canceled}

(*
  rend_event_show (ev);
*)

  end;
