{   Routines that deal with the output image.
}
module iedit_out;
define iedit_out_geo;
define iedit_out_op;
define iedit_out_write;
%include 'iedit.ins.pas';
{
********************************************************************************
*
*   Internal function NEWOP (LFT, DX, TOP, DY)
*
*   Update the op window to these coordinates without any checking or further
*   clipping.  The function returns TRUE if the OP window is actually changed
*   and FALSE on no change.
}
function newop (                       {set OP window to new location}
  in    lft, dx: sys_int_machine_t;    {left edge and width}
  in    top, dy: sys_int_machine_t)    {top edge and height}
  :boolean;                            {OP window was changed}
  val_param; internal;

begin
  if                                   {no change ?}
      (op_lft = lft) and (op_dx = dx) and
      (op_top = top) and (op_dy = dy)
      then begin
    newop := false;                    {indicate nothing was changed}
    return;
    end;

  op_lft := lft;                       {set the OP window to its new coordinates}
  op_dx := dx;
  op_top := top;
  op_dy := dy;
  col_op := false;                     {invalidate cached op color stats}
  newop := true;                       {indicate OP window was changed}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_OUT_OP (LFT, RIT, TOP, BOT)
*
*   Set the OP region to the desired limits.  The actual OP region may be
*   clipped or otherwise modified from the values passed in.
}
procedure iedit_out_op (               {set new op region, limit as required}
  in      lft, rit, top, bot: sys_int_machine_t); {edge pixels in op region}
  val_param;

var
  old_lft, old_dx: sys_int_machine_t;  {saved previous state}
  old_top, old_dy: sys_int_machine_t;
  old_col_op: boolean;

begin
  old_lft := op_lft;                   {save existing values}
  old_dx := op_dx;
  old_top := op_top;
  old_dy := op_dy;
  old_col_op := col_op;

  op_lft := lft;                       {set new OP region to the desired value}
  op_dx := rit - lft + 1;
  op_top := top;
  op_dy := bot - top + 1;

  iedit_out_geo;                       {update output geometry, clip OP region}

  if col_op then begin                 {cached colors assumed to be valid}
    col_op :=                          {invalidate cached data on OP region change}
      (op_lft = old_lft) and (op_dx = old_dx) and
      (op_top = old_top) and (op_dy = old_dy);
    end;
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_OUT_GEO
*
*   Update the output image geometry from the crop window and output image
*   preferences.  This routine may be called, for example, when the input image
*   crop window is changed.
}
procedure iedit_out_geo;               {update output image geometry from crop state}
  val_param;

var
  lft, rit, top, bot: sys_int_machine_t; {scratch pixel region limits}

begin
  case outsize of
{
*   OUTSIZE SCALE  -  Number of pixels scale governs.
}
outsize_scale_k: begin
  out_dx := max(1, round(crop_dx * out_scalex));
  out_dy := max(1, round(crop_dy * out_scaley));
  out_pasp := inpaspect * out_relasp;
  out_asp := out_pasp * out_dx / out_dy;
  end;
{
*   OUTSIZE FIT  -  Maximally fit while preserving aspect ratio.
}
outsize_fit_k: begin
  end;
{
*   OUTSIZE PIX  -  Explicit number of output pixels.
}
outsize_pix_k: begin
  end;

    end;                               {end of output size preference cases}
{
*   Update the operations region to not exceed the crop window.
}
  lft := op_lft;                       {get current op region extent}
  rit := op_lft + op_dx - 1;
  top := op_top;
  bot := op_top + op_dy - 1;

  lft := max(lft, crop_lft);           {clip to crop window}
  rit := min(rit, crop_lft + crop_dx - 1);
  top := max(top, crop_top);
  bot := min(bot, crop_top + crop_dy - 1);

  if (rit < lft) or (bot < top)
    then begin                         {operations window has been eliminated}
      discard( newop (crop_lft, crop_dx, crop_top, crop_dy) );
      end
    else begin                         {at least one pixel left in operations window}
      discard( newop (lft, rit - lft + 1, top, bot - top + 1) );
      end
    ;
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_OUT_WRITE
*
*   Write the output image to a image file as defined by the current state.
}
procedure iedit_out_write;             {write output image to image file}
  val_param;

var
  img: img_conn_t;                     {connection to the output image}
  tk: string_var32_t;                  {scratch token}
  str: string_var8192_t;               {scratch string}

  sizex, sizey: sys_int_machine_t;     {pixel size of the output image}
  fw: xf2d_t;                          {forward transform, image to window GUI coor}
  bk: xf2d_t;                          {backard transform, window GUI coor to image}
  shx, shy: real;                      {input to output shrink factors}
  irx, iry: sys_int_machine_t;         {anti-aliasing "radius" in source image}
  r, g, b, r2: real;                   {scratch floating point}
  ox, oy: sys_int_machine_t;           {output X,Y pixel coordinate}
  wx, wy: real;                        {output image coor at center of current pixel}
  wsx, wsy: real;                      {output image coor of current input subpixel}
  ix, iy: sys_int_machine_t;           {image pixel coordinate}
  in_lft, in_rit, in_top, in_bot:      {input image coordinate limits to display}
    sys_int_machine_t;
  x, y: real;                          {output pixel center in source image}
  sx, sy: sys_int_machine_t;           {source subpixel coordinate}
  weight: double;                      {accumulated subpixel weights}
  red, grn, blu: double;               {0.0 to 1.0 color value}
  scan_p: img_scan2_arg_p_t;           {points to output image scan line}
  iten: real;                          {pixel intensity}
  itene: real;                         {intensity with brighten exponent applied}

  stat: sys_err_t;

begin
  tk.max := size_char(tk.str);         {init local var strings}
  str.max := size_char(str.str);

  if not inputimg then begin           {no input image is available ?}
    discard( gui_message_msg (         {pop up error message}
      win_op,                          {parent window}
      gui_msgtype_err_k,               {message type}
      'img', 'iedit_stat_noinput',     {message reference}
      nil, 0) );                       {message parameters}
    return;
    end;
{
*   Set up the coordinate mapping.  FW will be the forward transform from the
*   input image pixel coordinates to the output image pixel coordinates.  BK
*   will be the reverse transform.  SIZEX,SIZEY will be set to the actual size
*   to make the output image.
}
  case roti of                         {which way is the image rotated ?}

0:  begin                              {original orientation}
      sizex := out_dx;
      sizey := out_dy;
      fw.xb.x := sizex / crop_dx;
      fw.xb.y := 0.0;
      fw.yb.x := 0.0;
      fw.yb.y := sizey / crop_dy;
      end;

1:  begin                              {rotated left 90 degrees}
      sizex := out_dy;
      sizey := out_dx;
      fw.xb.x := 0.0;
      fw.xb.y := -sizey / crop_dx;
      fw.yb.x := sizex / crop_dy;
      fw.yb.y := 0.0;
      end;

2:  begin                              {upside down}
      sizex := out_dx;
      sizey := out_dy;
      fw.xb.x := -sizex / crop_dx;
      fw.xb.y := 0.0;
      fw.yb.x := 0.0;
      fw.yb.y := -sizey / crop_dy;
      end;

3:  begin                              {rotated right 90 degrees}
      sizex := out_dy;
      sizey := out_dx;
      fw.xb.x := 0.0;
      fw.xb.y := sizey / crop_dx;
      fw.yb.x := -sizex / crop_dy;
      fw.yb.y := 0.0;
      end;

otherwise
    writeln ('Internal error: ROTI = ', roti);
    sys_bomb;
    end;                               {end of rotation cases}

  x := crop_lft + (crop_dx / 2.0);     {input point in center of crop window}
  y := crop_top + (crop_dy / 2.0);
  wx := fw.xb.x*x + fw.yb.x*y;         {transform crop center to output without offset}
  wy := fw.xb.y*x + fw.yb.y*y;
  x := sizex / 2.0;                    {output point in center of crop window}
  y := sizey / 2.0;
  fw.ofs.x := x - wx;                  {set offset so crop center comes out right}
  fw.ofs.y := y - wy;
  xf2d_inv (fw, bk);                   {make backwards transform from forwards}

  in_lft := crop_lft;                  {integer pixel coor limits from source image}
  in_rit := crop_lft + crop_dx - 1;
  in_top := crop_top;
  in_bot := crop_top + crop_dy - 1;

  shx :=                               {shrink factor along X in input image}
    1.0 / sqrt(sqr(fw.xb.x) + sqr(fw.xb.y));
  shy :=                               {shrink factor along Y in input image}
    1.0 / sqrt(sqr(fw.yb.x) + sqr(fw.yb.y));
  irx := trunc(abs(shx)) + 1;          {distance around source pixel for anti-aliasing}
  iry := trunc(abs(shy)) + 1;
{
*   Open the output image file.
}
  string_terminate_null (out_itype);

  str.len := 0;                        {build the format string}
  string_vstring (tk, '-QUAL'(0), -1); {-QUAL}
  string_append_token (str, tk);
  string_f_fp_fixed (tk, out_qual, 1);
  string_append_token (str, tk);
  string_vstring (tk, '-RED'(0), -1);  {-RED}
  string_append_token (str, tk);
  string_f_int (tk, out_bits);
  string_append_token (str, tk);
  string_vstring (tk, '-GREEN'(0), -1); {-GREEN}
  string_append_token (str, tk);
  string_f_int (tk, out_bits);
  string_append_token (str, tk);
  string_vstring (tk, '-BLUE'(0), -1); {-BLUE}
  string_append_token (str, tk);
  string_f_int (tk, out_bits);
  string_append_token (str, tk);

  img_open_write_img (                 {open the output image file}
    out_tnam,                          {file name}
    out_pasp * sizex / sizey,          {image aspect ratio}
    sizex, sizey,                      {number of pixels each dimension}
    out_itype.str,                     {image file type suffix}
    str,                               {format string}
    out_comm,                          {list of comment lines}
    img,                               {returned connection to the image}
    stat);
  if sys_error(stat) then begin        {open image file failed ?}
    discard( gui_message_msg_stat (
      win_op,                          {parent window}
      gui_msgtype_err_k,               {message type}
      stat,                            {error status}
      'img', 'iedit_stat_err_out_open', {message reference}
      nil, 0) );                       {message parameters}
    return;
    end;

  img_mem_alloc (                      {allocate temp output scan line buffer}
    img, sizeof(scan_p^[0]) * sizex, scan_p);
  for ix := 0 to sizex-1 do begin      {init output scan to fully opaque}
    scan_p^[ix].alpha := 65535;
    end;

  string_vstring (str, 'Writing '(0), -1); {show full treename of output file}
  string_append (str, img.tnam);
  iedit_msg_vstr (str);
{
*   Write the scan lines to the output image file.
}
  iedit_color_upd;                     {make sure cached color mappings are up to date}

  for oy := 0 to sizey-1 do begin      {down the output image scan lines}
    wy := oy + 0.5;                    {output Y at center of this scan line}
    for ox := 0 to sizex-1 do begin    {accross this output scan line}
      wx := ox + 0.5;                  {output X at center of this pixel}
      x := bk.xb.x*wx + bk.yb.x*wy + bk.ofs.x; {input point at center of output pixel}
      y := bk.xb.y*wx + bk.yb.y*wy + bk.ofs.y;
      ix := trunc(x);                  {input pixel containing output pixel center}
      iy := trunc(y);
      {
      *   IX,IY is the source image pixel that the center of the output pixel
      *   falls within.  IX,IY may be outside the source image or the region
      *   of it to display.
      }
      red := 0.0;                      {init accumulated colors for this output pixel}
      grn := 0.0;
      blu := 0.0;
      weight := 0.0;                   {init accumulated subpixel weights}
      for sy := iy-iry to iy+iry do begin {down the subpixel pattern}
        for sx := ix-irx to ix+irx do begin {accross this subpixel row}
          x := sx + 0.5;               {make input coor at center of this subpixel}
          y := sy + 0.5;
          wsx := fw.xb.x*x + fw.yb.x*y + fw.ofs.x; {output coor at subpixel center}
          wsy := fw.xb.y*x + fw.yb.y*y + fw.ofs.y;
          r := sqr(wsx - wx) + sqr(wsy - wy); {square of output dist to this subpixel}

          if r < 1.0 then begin        {within the anti-aliasing filter distance ?}
            r2 := ffunc[trunc(r * 128.0)]; {get weight of this subpixel}
            weight := weight + r2;     {add this weight contribution into accumulator}
            if
                (sx >= in_lft) and (sx <= in_rit) and
                (sy >= in_top) and (sy <= in_bot)
                then begin             {this subpixel is within the source area ?}
              r := max(0.0, min(1.0,   {convert pixel to 0-1 output scale}
                inscan_p^[sy]^[sx].red * col.mul_red + col.ofs_red));
              g := max(0.0, min(1.0,
                inscan_p^[sy]^[sx].grn * col.mul_grn + col.ofs_grn));
              b := max(0.0, min(1.0,
                inscan_p^[sy]^[sx].blu * col.mul_blu + col.ofs_blu));
              iten := max(r, g, b);    {make pixel intensity}
              if iten > 10.0e-6 then begin {intensity is above 0, perform computation ?}
                itene :=               {get output intensity for this input intensity}
                  col.iten[trunc(col_arscale * iten)];
                r :=                   {apply saturation mapping}
                  itene * col.sat[trunc(col_arscale * r / iten)];
                g :=
                  itene * col.sat[trunc(col_arscale * g / iten)];
                b :=
                  itene * col.sat[trunc(col_arscale * b / iten)];
                red := red + r * r2;   {add contribution from this subpixel}
                grn := grn + g * r2;
                blu := blu + b * r2;
                end;
              end;                     {end of subpixel is within source area}
            end;                       {end of subpixel is within anti-aliasing radius}
          end;                         {back for next subpixel accross}
        end;                           {back for next row of subpixels down}
      {
      *   Done accumulating all contributions for this output pixel.
      }
      if weight < 0.0001
        then begin                     {no subpixel contributions, use nearest}
          if
              (ix >= in_lft) and (ix <= in_rit) and
              (iy >= in_top) and (iy <= in_bot)
              then begin               {source pixel is within the source area}
            r := max(0.0, min(1.0,     {convert pixel to 0-1 output scale}
              inscan_p^[iy]^[ix].red * col.mul_red + col.ofs_red));
            g := max(0.0, min(1.0,
              inscan_p^[iy]^[ix].grn * col.mul_grn + col.ofs_grn));
            b := max(0.0, min(1.0,
              inscan_p^[iy]^[ix].blu * col.mul_blu + col.ofs_blu));
            iten := max(r, g, b);      {make pixel intensity}
            if iten > 10.0e-6 then begin {intensity is above 0, perform computation ?}
              itene :=                 {get output intensity for this input intensity}
                col.iten[trunc(col_arscale * iten)];
              red :=                   {apply saturation mapping}
                itene * col.sat[trunc(col_arscale * r / iten)];
              grn :=
                itene * col.sat[trunc(col_arscale * g / iten)];
              blu :=
                itene * col.sat[trunc(col_arscale * b / iten)];
              end;
            end;
          end
        else begin                     {enough subpixel contributions to use}
          red := red / weight;         {make blended color from subpixel contributions}
          grn := grn / weight;
          blu := blu / weight;
          end
        ;

      red := max(0.0, min(0.99999, red)); {clip pixel values to min/max range}
      grn := max(0.0, min(0.99999, grn));
      blu := max(0.0, min(0.99999, blu));
      scan_p^[ox].red := trunc(red * 65536.0); {convert to integer and write to output pixel}
      scan_p^[ox].grn := trunc(grn * 65536.0);
      scan_p^[ox].blu := trunc(blu * 65536.0);
      end;                             {back for next output pixel in this scan line}

    img_write_scan2 (img, scan_p^, stat); {write this scan line to output image}
    if sys_error(stat) then begin      {open image file failed ?}
      discard( gui_message_msg_stat (
        win_op,                        {parent window}
        gui_msgtype_err_k,             {message type}
        stat,                          {error status}
        'img', 'iedit_stat_err_out_close', {message reference}
        nil, 0) );                     {message parameters}
      exit;                            {abort writing scan lines}
      end;
    end;                               {back for next output scan line down}

  img_close (img, stat);               {close the output image file}
  if sys_error(stat) then begin        {open image file failed ?}
    discard( gui_message_msg_stat (
      win_op,                          {parent window}
      gui_msgtype_err_k,               {message type}
      stat,                            {error status}
      'img', 'iedit_stat_err_out_close', {message reference}
      nil, 0) );                       {message parameters}
    end;
  end;
