module iedit_resize;
define iedit_resize;
%include 'image_edit.ins.pas';
{
********************************************************************************
*
*   Subroutine IEDIT_RESIZE
*
*   Create or re-create our windows according to the current drawing area size.
*   All placements within the windows and other state that depends on drawing
*   area size is determined in this routine.
}
procedure iedit_resize;

const
  mmenu_high_pix_k = 20;               {max main menu height in pixels}
  mmenu_high_frac_k = 0.059;           {max main menu height as fraction of dim}
  op_wide_k = 400;                     {max op window width in pixels}
  op_wide_frac_k = 0.250;              {max op width as fraction of window}

var
  xb, yb, di: vect_2d_t;               {2D transform}
  f: real;                             {scratch floating point value}
  ii: sys_int_machine_t;               {scratch integer}

begin
  if windows then begin                {GUI windows currently exist ?}
    gui_win_delete (win_root);         {delete all our GUI windows}
    windows := false;                  {indicate windows don't currently exist}
    end;

  rend_set.enter_rend^;                {make sure we are in graphics mode}

  rend_set.dev_reconfig^;              {look at device parameters and reconfigure}

  rend_get.image_size^ (wind_dx, wind_dy, aspect); {get window size and aspect ratio}

  if wind_bitmap_alloc then begin      {pixel memory allocated in bitmap ?}
    rend_set.dealloc_bitmap^ (wind_bitmap); {deallocate bitmap pixel memory}
    end;
  rend_set.alloc_bitmap^ (             {allocate pixel memory for new window size}
    wind_bitmap,                       {bitmap handle}
    wind_dx, wind_dy,                  {bitmap size in pixels}
    3,                                 {bytes per pixel}
    rend_scope_dev_k);                 {deallocate on device close}
  wind_bitmap_alloc := true;           {indicate that bitmap has pixel memory}
{
*   Set up the 2D transform so that 0,0 is the lower left corner, X is to the
*   right, Y up, and both are in units of pixels.
}
  xb.y := 0.0;                         {fill in static part of 2D transform}
  yb.x := 0.0;

  if aspect >= 1.0
    then begin                         {window is wider than tall}
      xb.x := 2.0 * aspect / wind_dx;
      yb.y := 2.0 / wind_dy;
      di.x := -aspect;
      di.y := -1.0;
      end
    else begin                         {window is taller than wide}
      xb.x := 2.0 / wind_dx;
      yb.y := (2.0 / aspect) / wind_dy;
      di.x := -1.0;
      di.y := -1.0 / aspect;
      end
    ;
  rend_set.xform_2d^ (xb, yb, di);     {set new 2D transform}
{
*   Find sizes and locations of various features.
}
  f := min(                            {main menu height}
    mmenu_high_pix_k,                  {preferred main menu height}
    mmenu_high_frac_k * wind_dy,       {max allowed due to window height}
    mmenu_high_frac_k * wind_dx);      {max allowed due to window width}
  f := round(f);                       {round to nearest whole pixels}
  y_men2 := wind_dy;                   {top of main menu is top of window}
  y_men1 := y_men2 - f;                {set bottom of main menu}

  y_msg1 := 0.0;                       {message line at bottom and same height as menu}
  y_msg2 := y_msg1 + (y_men2 - y_men1);

  y_img1 := y_msg2;                    {image window between message line and menu}
  y_img2 := y_men1;

  f := min(                            {operations area width}
    op_wide_k,                         {preferred width}
    op_wide_frac_k * wind_dx);         {max allowed fraction of whole window}
  f := round(f);                       {round to nearest whole pixel}
  x_op2 := wind_dx;                    {OP area is at right edge}
  x_op1 := x_op2 - f;
  x_img1 := 0.0;                       {image window is at left edge}
  x_img2 := x_op1;                     {to right up to OP area}
  y_op1 := y_img1;                     {op area same vertical placement as image}
  y_op2 := y_img2;
{
*   Set text size, which is derived from main menu height.
}
  tparm.size := max(0.5, (y_men2 - y_men1) * 0.5);
  ii := trunc(tparm.size * 0.11);      {whole pixels text vector width}
  ii := max(ii, 1);                    {always at least one pixel wide}
  tparm.vect_width := ii / tparm.size; {make text vects integer pixels wide}
  rend_set.text_parms^ (tparm);
  thigh := tparm.size * tparm.height;  {save char cell height}
  twide := tparm.size * tparm.width;   {save char cell width}
  lspace := tparm.size * tparm.lspace; {save space between text lines}

  rend_set.exit_rend^;                 {pop back to caller's enter level}

  iedit_win_root_init;                 {init root window and everything below it}
  end;
