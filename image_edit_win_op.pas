module iedit_win_op;
define iedit_win_op_create;
define iedit_win_op_update;
%include 'image_edit.ins.pas';
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_OP_DRAW (WIN, APP_P)
*
*   Drawing routine for this window.  This routine is called automatically from
*   the GUI library when appropriate.
}
procedure iedit_win_op_draw (          {drawing routine for root window}
  in out  win: gui_win_t;              {window to draw}
  in      app_p: univ_ptr);            {pointer to arbitrary application data}
  val_param; internal;

var
  tp: rend_text_parms_t;               {local copy of text control parameters}
  text: string_var132_t;               {scratch text string}
  tk: string_var32_t;                  {scratch token}
  x, y: real;                          {scratch coordinate}
  full: boolean;                       {text has full importance}

begin
  text.max := size_char(text.str);     {init local var strings}
  tk.max := size_char(tk.str);

  rend_set.rgb^ (0.10, 0.10, 0.10);    {init to background color}
  rend_prim.clear_cwind^;
  if not inputimg then return;         {no current input image ?}
  {
  *   Set up for drawing OP mode title.
  }
  tp := tparm;                         {make local copy of text control parameters}
  tp.size := tp.size * 1.5;            {size for title}
  tp.start_org := rend_torg_um_k;
  tp.end_org := rend_torg_lr_k;
  rend_set.cpnt_2d^ (
    win.rect.dx / 2.0,
    win.rect.dy - (tp.size * tp.height * 0.5));
  rend_set.text_parms^ (tp);
  iedit_text_color (true);
  {
  *   Set up for drawing content text.
  }
  tparm.start_org := rend_torg_ll_k;   {configure text string anchors}
  tparm.end_org := rend_torg_lr_k;
  text_left := tparm.size * tparm.width * 0.75; {set left margin}
  text_y := win.rect.dy -              {Y for lower left of first content text line}
    tparm.size * (tparm.height + tparm.lspace) * 3.0;

  case opmode of
{
****************************************
*
*   Operation mode: CROP
}
opmode_crop_k: begin
  iedit_texts ('Crop');                {draw title for this mode}
  rend_set.text_parms^ (tparm);        {switch to regular content text parameters}
  rend_set.cpnt_2d^ (text_left, text_y); {go to start of first line}
{
*   Original.
}
  iedit_texts ('Input image');

  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Size');
  iedit_text_tab (16);
  iedit_text_int_left (indx);
  iedit_texts (' x '(0));
  iedit_text_int (indy);

  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Pixel aspect '(0));
  iedit_text_tab (17);
  iedit_text_fp (inpaspect, 4);

  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Image aspect '(0));
  iedit_text_tab (17);
  iedit_text_fp (inaspect, 4);
{
*   Crop region.
}
  iedit_text_newline;
  iedit_text_newline;
  iedit_texts ('Crop region');

  iedit_text_newline;
  full := not crop_asplock; iedit_text_color (full);
  iedit_text_space (1.5);
  iedit_texts ('Size'(0));
  iedit_text_tab (16);
  iedit_text_int_left (crop_dx);
  iedit_texts (' x '(0));
  iedit_text_int (crop_dy);

  iedit_text_newline;
  iedit_text_color (true);
  iedit_text_space (1.5);
  iedit_texts ('Center'(0));
  iedit_text_tab (16);
  iedit_text_fp_left (crop_lft + (crop_dx / 2.0), 1);
  iedit_texts (' x '(0));
  iedit_text_fp (crop_top + (crop_dy / 2.0), 1);

  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Left');
  iedit_text_tab (16);
  iedit_text_int_left (crop_lft);

  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Right');
  iedit_text_tab (16);
  iedit_text_int_left (crop_lft + crop_dx - 1);

  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Top');
  iedit_text_tab (16);
  iedit_text_int_left (crop_top);

  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Bottom');
  iedit_text_tab (16);
  iedit_text_int_left (crop_top + crop_dy - 1);

  iedit_text_newline;
  iedit_text_color (crop_asplock);
  iedit_text_space (1.5);
  iedit_texts ('Target aspect '(0));
  iedit_text_tab (17);
  iedit_text_fp (crop_aspt, 4);

  iedit_text_newline;
  iedit_text_color (false);
  iedit_text_space (1.5);
  iedit_texts ('Actual spect '(0));
  iedit_text_tab (17);
  iedit_text_fp (crop_asp, 4);
{
*   Output image.
}
  iedit_text_color (true);
  iedit_text_newline;
  iedit_text_newline;
  iedit_texts ('Output image');

  full := outsize = outsize_pix_k; iedit_text_color (full);
  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Size');
  iedit_text_tab (16);
  iedit_text_int_left (out_dx);
  iedit_texts (' x '(0));
  iedit_text_int (out_dy);

  full := outsize = outsize_fit_k; iedit_text_color (full);
  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Fit in');
  iedit_text_tab (16);
  iedit_text_int_left (out_fitx);
  iedit_texts (' x '(0));
  iedit_text_int (out_fity);

  full := outsize = outsize_scale_k; iedit_text_color (full);
  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Scale');
  iedit_text_tab (16);
  iedit_text_fp_left (out_scalex, 3);
  iedit_texts (' x '(0));
  iedit_text_fp (out_scaley, 3);

  full := (outsize = outsize_fit_k) or (outsize = outsize_pix_k);
  iedit_text_color (full);
  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Pixel aspect '(0));
  iedit_text_tab (17);
  iedit_text_fp (out_pasp, 4);

  full := (outsize = outsize_scale_k) or (outsize = outsize_fit_k);
  iedit_text_color (full);
  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Rel aspect '(0));
  iedit_text_tab (17);
  iedit_text_fp (out_relasp, 4);

  iedit_text_color (false);
  iedit_text_newline;
  iedit_text_space (1.5);
  iedit_texts ('Aspect '(0));
  iedit_text_tab (17);
  iedit_text_fp (out_asp, 4);
  end;                                 {end of CROP mode case}
{
****************************************
*
*   Operation mode: COLORS
}
opmode_colors_k: begin
  iedit_color_upd;                     {make sure derived color state is up to date}

  iedit_texts ('Colors');              {draw title for this mode}
  rend_set.text_parms^ (tparm);        {switch to regular content text parameters}
  rend_set.cpnt_2d^ (text_left, text_y); {go to start of first line}

  iedit_texts ('Black in');
  iedit_text_tab (10);
  iedit_text_fp (blkin.red, 5);
  iedit_text_space (1.0);
  iedit_text_fp (blkin.grn, 5);
  iedit_text_space (1.0);
  iedit_text_fp (blkin.blu, 5);

  iedit_text_newline;
  iedit_texts ('Black out');
  iedit_text_tab (10);
  iedit_text_fp (blkout.red, 5);
  iedit_text_space (1.0);
  iedit_text_fp (blkout.grn, 5);
  iedit_text_space (1.0);
  iedit_text_fp (blkout.blu, 5);

  iedit_text_newline;
  iedit_text_newline;
  iedit_texts ('White in');
  iedit_text_tab (10);
  iedit_text_fp (whtin.red, 5);
  iedit_text_space (1.0);
  iedit_text_fp (whtin.grn, 5);
  iedit_text_space (1.0);
  iedit_text_fp (whtin.blu, 5);

  iedit_text_color(col_usewhb);
  iedit_text_newline;
  iedit_texts ('White ref');
  iedit_text_tab (10);
  iedit_text_fp (whtbal.red, 5);
  iedit_text_space (1.0);
  iedit_text_fp (whtbal.grn, 5);
  iedit_text_space (1.0);
  iedit_text_fp (whtbal.blu, 5);
  iedit_text_color (true);

  iedit_text_newline;
  iedit_texts ('White out');
  iedit_text_tab (10);
  iedit_text_fp (whtout.red, 5);
  iedit_text_space (1.0);
  iedit_text_fp (whtout.grn, 5);
  iedit_text_space (1.0);
  iedit_text_fp (whtout.blu, 5);

  iedit_text_newline;
  iedit_text_newline;
  iedit_texts ('Brighten');
  iedit_text_space (1.0);
  iedit_text_fp (brighten, 2);

  iedit_text_newline;
  full := col_logmode = logmode_ratio_k; iedit_text_color(full);
  iedit_texts ('Log ratio');
  iedit_text_space (1.0);
  iedit_text_fp (col_log_rat, 2);
  iedit_texts (' F-stops');

  if col_log_ofs <= 999999.0 then begin
    full := col_logmode = logmode_add_k; iedit_text_color(full);
    iedit_text_newline;
    iedit_texts ('Log offset');
    iedit_text_space (1.0);
    iedit_text_fp (col_log_ofs, 4);
    end;
  iedit_text_color (true);

  iedit_text_newline;
  iedit_texts ('Saturate');
  iedit_text_space (1.0);
  iedit_text_fp (saturate, 2);

  if col_op then begin                 {OP region data has been computed ?}
    iedit_text_newline;                {leave some vertical space}
    iedit_text_newline;
    rend_set.text_parms^ (tp);         {use text parameters for title}
    rend_set.cpnt_2d^ (win.rect.dx / 2.0, text_y);
    iedit_texts ('Selected Area');
    rend_get.cpnt_2d^ (x, y);          {get the resulting current point}
    text_y := y;                       {update Y after title}
    rend_set.cpnt_2d^ (text_left, text_y); {go to start of next line}
    rend_set.text_parms^ (tparm);      {back to normal text}
    iedit_text_newline;

    iedit_text_newline;
    iedit_texts ('Size');
    iedit_text_tab (10);
    iedit_text_int (op_dx);
    iedit_texts (' x '(0));
    iedit_text_int (op_dy);

    iedit_text_newline;
    iedit_texts ('X');
    iedit_text_tab (10);
    iedit_text_int (op_lft);
    iedit_texts (' - '(0));
    iedit_text_int (op_lft + op_dx - 1);

    iedit_text_newline;
    iedit_texts ('Y');
    iedit_text_tab (10);
    iedit_text_int (op_top);
    iedit_texts (' - '(0));
    iedit_text_int (op_top + op_dy - 1);

    iedit_text_newline;
    iedit_texts ('Black');
    iedit_text_tab (10);
    iedit_text_fp (col_min.red, 5);
    iedit_text_space (1.0);
    iedit_text_fp (col_min.grn, 5);
    iedit_text_space (1.0);
    iedit_text_fp (col_min.blu, 5);

    iedit_text_newline;
    iedit_texts ('White');
    iedit_text_tab (10);
    iedit_text_fp (col_max.red, 5);
    iedit_text_space (1.0);
    iedit_text_fp (col_max.grn, 5);
    iedit_text_space (1.0);
    iedit_text_fp (col_max.blu, 5);

    iedit_text_newline;
    iedit_texts ('Average');
    iedit_text_tab (10);
    iedit_text_fp (col_ave.red, 5);
    iedit_text_space (1.0);
    iedit_text_fp (col_ave.grn, 5);
    iedit_text_space (1.0);
    iedit_text_fp (col_ave.blu, 5);
    end;
  end;                                 {end of COLORS mode case}
{
****************************************
*
*   Operation mode: OUT
}
opmode_out_k: begin
  iedit_texts ('Output');              {draw title for this mode}
  rend_set.text_parms^ (tparm);        {switch to regular content text parameters}
  rend_set.cpnt_2d^ (text_left, text_y); {go to start of first line}

  iedit_text_newline;
  iedit_texts ('Image type');
  iedit_text_tab (15);
  if out_itype.len = 0
    then begin                         {image type comes from file name}
      iedit_texts ('- from filename -');
      end
    else begin                         {fixed type is specified}
      iedit_text (out_itype);
      end
    ;

  iedit_text_newline;
  iedit_texts ('Bits/color');
  iedit_text_tab (15);
  iedit_text_int (out_bits);

  iedit_text_newline;
  iedit_texts ('Quality');
  iedit_text_tab (15);
  iedit_text_fp (out_qual, 1);
  iedit_texts ('%');

  end;
{
****************************************
}
    end;                               {end of operation mode cases}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_OP_CREATE
}
procedure iedit_win_op_create;         {create and init operation window}

begin
  gui_win_child (                      {create this window}
    win_op,                            {returned window object}
    win_root,                          {parent window}
    x_op1, y_op1,                      {lower left corner in parent window}
    x_op2 - x_op1, y_op2 - y_op1);     {displacement to upper right corner}

  gui_win_set_draw (                   {install drawing routine for this window}
    win_op,
    univ_ptr(addr(iedit_win_op_draw)));
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_WIN_OP_UPDATE
*
*   Cause the image to be re-displayed with the current state and configuration.
}
procedure iedit_win_op_update;         {create and init image display window}
  val_param;

begin
  gui_win_draw_all (win_op);
  end;
