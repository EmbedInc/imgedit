{   Routines that handle the mapping of colors from the input image to the
*   output image.
}
module iedit_color;
define iedit_color_init;
define iedit_color_inv;
define iedit_color_upd;
%include 'iedit.ins.pas';

var
  cvalid: boolean;                     {all cached color information is valid}
{
********************************************************************************
*
*   Subroutine IEDIT_COLOR_INIT
*
*   Initialize the state managed by this module.
}
procedure iedit_color_init;            {initialize color mapping module}
  val_param;

begin
  cvalid := false;                     {cached information is not valid}
  col_logmode := logmode_add_k;
  col_log_rat := 0.0;
  col_log_ofs := 1.0e6;
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_COLOR_INV
*
*   Indicate that the cached input to output image color mapping state is not
*   up to date and must be recomputed from the original parameters.
}
procedure iedit_color_inv;             {cached color mapping is invalid}
  val_param;

begin
  cvalid := false;                     {indicate cached information is invalid}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_COLOR_UPD
*
*   Make sure all cached color mapping information is correct.  If it is not,
*   then it will be recomputed from the original user data.  If all information
*   is already up to date, then this routing returns quickly.
}
procedure iedit_color_upd;             {make sure cached color info is up to date}
  val_param;

var
  ii: sys_int_machine_t;               {scratch integer and loop counter}
  r: double;                           {scratch floating point}
  b, w: double;                        {scratch black and white levels}
  logm, logb: double;                  {linear mapping from log to 0-1 brightness}
  log_on: boolean;                     {log brightness warping is enabled}

label
  log_off;

begin
  if cvalid then return;               {cached information is already correct ?}
  cvalid := true;                      {no, but it will be}
  iedit_win_img_ncache;                {cached display image will be out of date}
{
*   Resolve all the LOG parameters based on the mode and the relevant input
*   parameters for that mode.  The non-linear brightness mapping in COL.ITEN is
*   applied after the linear min to max scaling for each color.  The COL.ITEN
*   data is therefore always relative to the full black to white range.
}
  log_on := false;                     {init to not do log brightness mapping}
  case col_logmode of                  {what is the log mapping mode ?}

logmode_ratio_k: begin                 {fixed white/black ratio}
      r := 2.0 ** col_log_rat;         {make acutal ratio from f-stops}
      if abs(r - 1.0) < 0.00001 then goto log_off; {ratio too low for log mapping ?}
      col_log_ofs :=                   {compute offset equivalent to ratio}
        1.0 / (r - 1.0);
      end;

logmode_add_k: begin                   {add fixed value to intensity before log}
      if col_log_ofs > 999999.0 then goto log_off; {infinite offset, no log mapping ?}
      if abs(col_log_ofs) < 0.00001 then begin {infinitely black ?}
        col_log_ofs := 1.0 / 65536.0;  {make tiny bit above infinite black}
        end;
      r := (1.0 + col_log_ofs) / col_log_ofs; {white/black ratio after offset}
      col_log_rat := math_log2(r);     {save ratio in f-stops}
      end;

otherwise                              {unexpected log mapping type ?}
    goto log_off;                      {don't use log brightness mapping}
    end;                               {end of log mode cases}

  log_on := true;                      {enable log brightness mapping}
  b := ln(col_log_ofs);                {make log of black and white}
  w := ln(1.0 + col_log_ofs);
  logm := 1.0 / (w - b);               {scale from log to 0-1 brightness}
  logb := -b * logm;                   {offset to preserve black}

log_off:                               {skip here to not turn on log mapping}
  if not log_on then begin
    col_log_rat := 0.0;
    col_log_ofs := 1.0e6;
    end;
{
*   Compute the initial linear mapping from the 16 bit unsigned pixel values to
*   the 0-1 floating point color component values.
}
  r := whtin.red - blkin.red;          {compute red linear mapping}
  if abs(r) < 0.00001 then r := 0.00001;
  col.mul_red := (whtout.red - blkout.red) / r;
  col.ofs_red := blkout.red - (blkin.red * col.mul_red);
  col.mul_red := col.mul_red / 65535.0;

  r := whtin.grn - blkin.grn;          {compute green linear mapping}
  if abs(r) < 0.00001 then r := 0.00001;
  col.mul_grn := (whtout.grn - blkout.grn) / r;
  col.ofs_grn := blkout.grn - (blkin.grn * col.mul_grn);
  col.mul_grn := col.mul_grn / 65535.0;

  r := whtin.blu - blkin.blu;          {compute blue linear mapping}
  if abs(r) < 0.00001 then r := 0.00001;
  col.mul_blu := (whtout.blu - blkout.blu) / r;
  col.ofs_blu := blkout.blu - (blkin.blu * col.mul_blu);
  col.mul_blu := col.mul_blu / 65535.0;
{
*   Compute the input to output brightness mapping.  A linear 0-1 ramp would
*   leave the brightness unchanged.
}
  for ii := 0 to col_arsize do begin   {once for each array entry}
    r := min(1.0, (ii + 0.5) / col_arscale); {0-1 input value at this slot}

    r := r ** col_eb;                  {apply BRIGHTEN mapping}
    if log_on then begin               {apply log mapping ?}
      r := ln(r + col_log_ofs) * logm + logb;
      end;

    col.iten[ii] := r;                 {save final output brightness this slot}
    end;                               {back to fill in next array slot}
{
*   Compute the relative saturation mapping.  To adjust saturation of a color
*   component, the component value is divided by the maximum component of that
*   color, then the resulting 0-1 mapping adjusted by this table.  A linear 0-1
*   ramp would therefore leave the saturation unchanged.  Values below the ramp
*   increase saturation and values above the ramp decrease it.
}
  for ii := 0 to col_arsize do begin   {once for each array entry}
    r := min(1.0, (ii + 0.5) / col_arscale); {0-1 input value at this slot}

    r := r ** col_es;                  {apply saturation exponent}

    col.sat[ii] := r;                  {save final saturation adjust}
    end;                               {back to fill in next array slot}
  end;
