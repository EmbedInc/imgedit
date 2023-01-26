module iedit_open;
define iedit_open;
%include 'image_edit.ins.pas';
{
********************************************************************************
*
*   Subroutine IEDIT_OPEN (FNAM)
*
*   Open the indicate image as the input image.  If a input image is already
*   open, then it will first be closed and the input image state reset.
}
procedure iedit_open (                 {open new input image}
  in out  fnam: univ string_var_arg_t); {name of the image to open}
  val_param;

const
  max_msg_args = 1;                    {max arguments we can pass to a message}

var
  img: img_conn_t;                     {connection to the input image}
  sz: sys_int_adr_t;                   {memory size of the image}
  y: sys_int_machine_t;                {scan line coordinate}
  pix: sys_int_machine_t;              {pixel within image at start of scan line}
  pdx, pdy: sys_int_machine_t;         {pixel size of previous image}
  p: univ_ptr;
  newopen: boolean;                    {opening for first time, no previous state}
  msg_parm:                            {references arguments passed to a message}
    array[1..max_msg_args] of sys_parm_msg_t;
  stat: sys_err_t;

begin
  newopen := true;                     {init to this is first-time open}
  pdx := 0;
  pdy := 0;

  if inputimg then begin               {previous input image exists ?}
    newopen := false;                  {not first image opened this session}
    pdx := indx;                       {save pixel size of the previous image}
    pdy := indy;
    util_mem_ungrab (image_p, mem_p^); {deallocate previous image}
    util_mem_ungrab (inscan_p, mem_p^); {deallocate scan line pointers array}
    string_list_kill (out_comm);       {deallocate previous image comment lines}
    inputimg := false;
    end;

  sys_msg_parm_vstr (msg_parm[1], fnam); {show image being opened}
  iedit_msg_message ('img', 'iedit_img_open', msg_parm, 1);

  img_open_read_img (fnam, img, stat); {open the image}
  if sys_error(stat) then begin        {error opening image ?}
    if file_not_found(stat) then begin {requested image doesn't exist ?}
      sys_msg_parm_vstr (msg_parm[1], fnam);
      iedit_msg_message ('img', 'iedit_open_nfound', msg_parm, 1);
      return;
      end;
    sys_msg_parm_vstr (msg_parm[1], fnam);
    iedit_msg_message ('img', 'iedit_open_err', msg_parm, 1);
    return;
    end;
  indx := img.x_size;                  {save input image parameters}
  indy := img.y_size;
  inaspect := img.aspect;
  inpaspect := inaspect * indy / indx; {make pixel aspect ratio}
  string_copy (img.tnam, intnam);
  ingnam.max := size_char(ingnam.str);
  string_copy (img.gnam, ingnam);

  string_list_init (out_comm, mem_p^); {create new image comment lines}
  out_comm.deallocable := true;
  string_list_pos_abs (img.comm, 1);   {go to first source comment line}
  while img.comm.str_p <> nil do begin {once for each comment line}
    out_comm.size := img.comm.str_p^.len;
    string_list_line_add (out_comm);   {create new line in local list}
    string_copy (img.comm.str_p^, out_comm.str_p^); {copy this line}
    string_list_pos_rel (img.comm, 1);
    end;

  sz := sizeof(image_p^[0]);           {size of one pixel}
  sz := sz * img.x_size * img.y_size;  {size of all source image pixels}
  util_mem_grab (sz, mem_p^, true, image_p); {alloc memory for the pixels}
  sz := sizeof(inscan_p^[0]) * img.y_size; {size of pointers to all scans}
  util_mem_grab (sz, mem_p^, true, inscan_p); {alloc array of scan line pointers}

  pix := 0;                            {init pixel offset of first scan line}
  for y := 0 to img.y_size-1 do begin  {once for each scan line}
    p := addr(image_p^[pix]);          {get address of this scan start}
    inscan_p^[y] := p;                 {set this scan line pointer}
    img_read_scan2 (img, inscan_p^[y]^, stat); {read in and save this scan line}
    sys_error_abort (stat, '', '', nil, 0);
    pix := pix + img.x_size;
    end;

  string_copy (img.gnam, out_tnam);    {init output name to input generic leafname}
  if newopen then begin
    out_bits := min(img.bits_max, 8);  {init output precision}
    end;
  img_close (img, stat);               {close the input image}

  roti := 0;                           {init to use original orientation}
  idisp_focus.x := indx / 2.0;         {init to maximally scale and center whole image}
  idisp_focus.y := indy / 2.0;
  imgwin_focus.x := 0.5;
  imgwin_focus.y := 0.5;
  idisp_zoom := 1.0;

  if newopen or (indx <> pdx) or (indy <> pdy) then begin {default in-out mapping ?}
    crop_lft := 0;                     {init crop region to whole input image}
    crop_top := 0;
    crop_dx := indx;
    crop_dy := indy;
    crop_asp := inaspect;
    crop_aspt := inaspect;
    crop_asplock := false;

    outsize := outsize_scale_k;        {init to 1:1 input to output pixels}
    out_scalex := 1.0;
    out_scaley := 1.0;
    out_dx := indx;
    out_dy := indy;
    out_pasp := inpaspect;
    out_relasp := 1.0;
    out_asp := inaspect;
    string_vstring (out_itype, 'jpg'(0), -1);
    out_qual := 100.0;
    end;

  op_lft := 0;
  op_dx := indx;
  op_top := 0;
  op_dy := indy;

  if newopen then begin
    blkin.red := 0.0;
    blkin.grn := 0.0;
    blkin.blu := 0.0;
    blkout.red := 0.0;
    blkout.grn := 0.0;
    blkout.blu := 0.0;
    whtin.red := 1.0;
    whtin.grn := 1.0;
    whtin.blu := 1.0;
    whtout.red := 1.0;
    whtout.grn := 1.0;
    whtout.blu := 1.0;
    whtbal.red := 1.0;
    whtbal.grn := 1.0;
    whtbal.blu := 1.0;
    brighten := 0.0;
    col_eb := 1.0;
    saturate := 0.0;
    col_es := 1.0;
    col_logmode := logmode_ratio_k;
    col_log_rat := 0.0;
    col_log_ofs := 1.0e6;
    iedit_color_inv;
    end;

  col_op := false;                     {init to OP region colors not computed}
  iedit_win_img_ncache;                {make sure any cached display pixels are invalid}
  iedit_msg_vstr (intnam);             {show the full source pathname}
  inputimg := true;
  iedit_win_op_update;                 {update the operations window}
  iedit_win_img_update;                {update the image display}
  end;
