{   Private include file for the IMAGE_EDIT program.
}
%include 'sys.ins.pas';
%include 'util.ins.pas';
%include 'string.ins.pas';
%include 'file.ins.pas';
%include 'img.ins.pas';
%include 'math.ins.pas';
%include 'vect.ins.pas';
%include 'rend.ins.pas';
%include 'gui.ins.pas';

const
  col_avsize = 4;                      {pixels accross target for color averaging}
  col_arsize = 65536;                  {slots in color mapping array}
  pi = 3.14159265359;                  {what it sounds like, don't touch}
  {
  *   Derived constants.
  }
  col_arscale = col_arsize + 0.0;      {scale for 0-1 color to make color array index}

type
  image_p_t = ^image_t;
  image_t = array[0..0] of img_pixel2_t; {all the input image pixels}

  inscans_p_t = ^inscans_t;
  inscans_t = array[0..0] of img_scan2_arg_p_t; {pointer to input scan lines}

  opmode_k_t = (                       {list of main operation modes}
    opmode_crop_k,                     {crop, input image subset and output size}
    opmode_colors_k,                   {color and related transforms}
    opmode_out_k);                     {settings for writing output image}

  outsize_k_t = (                      {output image size governing mode}
    outsize_scale_k,                   {scale factors}
    outsize_fit_k,                     {maximum within fit region}
    outsize_pix_k);                    {explicit pixels size}

  color_t = record                     {one color in 0-1 full scale range}
    red: real;
    grn: real;
    blu: real;
    end;

  xf2d_t = record                      {2D transform}
    xb: vect_2d_t;                     {X basis vector}
    yb: vect_2d_t;                     {y basis vector}
    ofs: vect_2d_t;                    {offset vector}
    end;

  col_array_t =                        {array of color mapping information}
    array[0 .. col_arsize] of real;

  col_cache_t = record                 {cached color info derived from base data}
    mul_red, ofs_red: real;            {scale and offset, from 16 bit integer to 0-1}
    mul_grn, ofs_grn: real;
    mul_blu, ofs_blu: real;
    iten: col_array_t;                 {color intensity mapping lookup table}
    sat: col_array_t;                  {saturation ratio mapping lookup table}
    end;

  logmode_k_t = (                      {log brightness mapping mode}
    logmode_ratio_k,                   {governed by fixed white/black ratio}
    logmode_add_k);                    {add offset to log range}

var (iedit)
  rendev: rend_dev_id_t;               {RENDlib device ID}
  mem_p: util_mem_context_p_t;         {top dynamic memory context}
  tparm: rend_text_parms_t;            {our base text control parameters}
  thigh: real;                         {resulting char cell height from TPARM}
  twide: real;                         {resulting char cell width from TPARM}
  lspace: real;                        {resulting gap between lines from TPARM}
  pparm: rend_poly_parms_t;            {our base polygon control parameters}
  vparm: rend_vect_parms_t;            {our base vector control parameters}
  wind_bitmap: rend_bitmap_handle_t;   {handle to bitmap for main drawing window}
  wind_bitmap_alloc: boolean;          {TRUE if WIND_BITMAP has pixels allocated}
  windows: boolean;                    {TRUE if our base GUI window set exists}
  wind_dx, wind_dy: sys_int_machine_t; {main drawing window size in pixels}
  aspect: real;                        {drawing device width/height aspect ratio}
  win_root: gui_win_t;                 {our root GUI window}
  win_img: gui_win_t;                  {image display window}
  win_op: gui_win_t;                   {operations window}
{
*   Various locations within the windows in root window coordinates.
}
  y_men1, y_men2: real;                {bottom/top of main window menu}
  y_img1, y_img2: real;                {bot/top of image drawing area}
  x_img1, x_img2: real;                {lft/rit of image drawing area}
  y_msg1, y_msg2: real;                {bot/top of message line}

  x_op1, x_op2: real;                  {lft/rit of operations area}
  y_op1, y_op2: real;                  {bot/top of operations area}
{
*   Input image information.
}
  image_p: image_p_t;                  {points to source image pixels}
  inscan_p: inscans_p_t;               {points to scan line pointers}
  indx, indy: sys_int_machine_t;       {image size in pixels}
  inaspect: real;                      {width/height of properly displayed image}
  inpaspect: real;                     {width/height of each pixel}
  intnam: string_treename_t;           {full pathname of input image}
  ingnam: string_leafname_t;           {generic name of input image}
  inputimg: boolean;                   {the input image is open}
  ffunc: array[0..128] of real;        {anti-aliasing function of dist squared}
  roti: sys_int_machine_t;             {rotation 0,1,2,3 (increments of 90 deg CCW)}
{
*   Image display configuration.
}
  idisp_focus: vect_2d_t;              {input image focus point for zoom changes}
  imgwin_focus: vect_2d_t;             {relative 0-1 coordinate of focus in IMG window}
  idisp_zoom: real;                    {scale factor relative to full best fit}
{
*   Operations info.
}
  opmode: opmode_k_t;                  {current operations mode}
  op_lft, op_top: sys_int_machine_t;   {UL input pixel in operations region}
  op_dx, op_dy: sys_int_machine_t;     {pixel width and height of operations region}

  disp_aa: boolean;                    {anti-alias the main image}

  crop_lft, crop_top: sys_int_machine_t; {UL input pixel included in output}
  crop_dx, crop_dy: sys_int_machine_t; {pixel width and height of output region}
  crop_asp: real;                      {actual crop region aspect ratio}
  crop_aspt: real;                     {target aspect ratio when locked}
  crop_asplock: boolean;               {output aspect not allowed to implicitly change}

  outsize: outsize_k_t;                {output size governing mode}
  out_scalex, out_scaley: real;        {crop to output numbers of pixels}
  out_fitx, out_fity: sys_int_machine_t; {max allowed dimensions within aspect}
  out_dx, out_dy: sys_int_machine_t;   {output image dimension, pixels}
  out_pasp: real;                      {aspect ratio of output pixel}
  out_relasp: real;                    {relative input to output aspect ratio}
  out_asp: real;                       {output image aspect ratio}
  out_itype: string_var32_t;           {image output file type suffix, no leading "."}
  out_bits: sys_int_machine_t;         {minimum output bits/color to request}
  out_qual: real;                      {output image quality to request, percent}
  out_comm: string_list_t;             {output image comment lines}
  out_tnam: string_treename_t;         {output image file generic treename}

  blkin: color_t;                      {input image black level}
  blkout: color_t;                     {output color that BLKIN maps to}
  whtin: color_t;                      {input image white level}
  whtout: color_t;                     {output color that WHTIN maps to}
  whtbal: color_t;                     {input colors ratios for white, max at 1.0}
  brighten: real;                      {exponential brighten value, after blk/wht level}
  col_eb: real;                        {internal exponent derived from BRIGHTEN}
  saturate: real;                      {relative saturation, 0 = leave as is}
  col_es: real;                        {internal exponent derived from SATURATE}
  col_min, col_max: color_t;           {min/max color values in op region}
  col_ave: color_t;                    {average color in op region}
  col_usewhb: boolean;                 {use white ballance to adjust white level}
  col_op: boolean;                     {op region colors are up to date}
  col_logmode: logmode_k_t;            {log brightness warping mode}
  col_log_rat: real;                   {fixed number of f-stops from black to white}
  col_log_ofs: real;                   {add to color range before taking log}
  col: col_cache_t;                    {cached color mapping, derived from above}
{
*   State for layered text drawing routines.  This is assumed to be trashed by
*   any drawing routine.
}
  text_left: real;                     {left margin X}
  text_y: real;                        {Y coordinate of current text line}
{
*   Entry points.
}
procedure iedit_color_init;            {initialize color mapping module}
  val_param; extern;

procedure iedit_color_inv;             {cached color mapping is invalid}
  val_param; extern;

procedure iedit_color_upd;             {make sure cached color info is up to date}
  val_param; extern;

function iedit_drag_box (              {perform a pointer box drag operation}
  in      win: gui_win_t;              {window to confine drag within}
  in      startx, starty: sys_int_machine_t; {RENDlib drag start pixel}
  out     rect: gui_irect_t)           {returned final rectangle}
  :boolean;                            {TRUE if drag confirmed, not cancelled}
  val_param; extern;

function iedit_drag_line (             {perform a pointer rubber band drag operation}
  in      startx, starty: real;        {RENDlib coordinates of drag start}
  out     endx, endy: real)            {final RENDlib end of drag coordinates}
  :boolean;                            {TRUE if drag confirmed, not cancelled}
  val_param; extern;

function iedit_get_color (             {get color from user via user entry popup}
  in out  ent: gui_enter_t;            {user entry object, will be deleted}
  out     col: color_t)                {the returned RGB color}
  :boolean;                            {success, returning with color}
  val_param; extern;

procedure iedit_menu_add_msg (         {add menu entries from message}
  in out  menu: gui_menu_t;            {menu to add entries to}
  in      subsys: string;              {message file generic name}
  in      msg: string;                 {name of message within message file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameters for the message}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  val_param; extern;

function iedit_menu_colors (           {handle events for COLORS top menu entry}
  in    ulx, uly: real)                {preferred UL corner of subordinate menu}
  :gui_evhan_k_t;                      {returned event handling status}
  extern;

function iedit_menu_col_whbal (        {handle events for COLORS > WHITE BALLANCE}
  in      ulx, uly: real;              {preferred UL corner of subordinate menu}
  in out  evhan: gui_evhan_k_t)        {updated events handled status}
  :gui_selres_k_t;                     {overall user selection result}
  val_param; extern;

function iedit_menu_crop (             {handle events for CROP top menu entry}
  in    ulx, uly: real)                {preferred UL corner of subordinate menu}
  :gui_evhan_k_t;                      {returned event handling status}
  extern;

function iedit_menu_disp (             {handle events for DISPLAY top menu entry}
  in    ulx, uly: real)                {preferred UL corner of subordinate menu}
  :gui_evhan_k_t;                      {returned event handling status}
  extern;

function iedit_menu_file (             {handle events for FILE top menu entry}
  in    ulx, uly: real)                {preferred UL corner of subordinate menu}
  :gui_evhan_k_t;                      {returned event handling status}
  extern;

function iedit_menu_out (              {handle events for OUT top menu entry}
  in    ulx, uly: real)                {preferred UL corner of subordinate menu}
  :gui_evhan_k_t;                      {returned event handling status}
  extern;

procedure iedit_msg_message (          {set status line from message file message}
  in      subsys: string;              {name of subsystem, used to find message file}
  in      msg: string;                 {message name within subsystem file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameter descriptors}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  val_param; extern;

procedure iedit_msg_vstr (             {set status message string}
  in      str: univ string_var_arg_t); {the message to display}
  val_param; extern;

procedure iedit_op_colors;             {make sure OP window computed colors up to date}
  val_param; extern;

procedure iedit_open (                 {open new input image}
  in out  fnam: univ string_var_arg_t); {name of the image to open}
  val_param; extern;

procedure iedit_out_geo;               {update output image geometry from crop state}
  val_param; extern;

procedure iedit_out_op (               {set new op region, limit as required}
  in      lft, rit, top, bot: sys_int_machine_t); {edge pixels in op region}
  val_param; extern;

procedure iedit_out_write;             {write output image to image file}
  val_param; extern;

procedure iedit_resize;                {create or recreate windows to draw area size}
  val_param; extern;

procedure iedit_text (                 {draw text from var string}
  in      s: univ string_var_arg_t);   {text string to draw}
  val_param; extern;

procedure iedit_text_color (           {set text drawing color}
  in      full: boolean);              {text has regular full importance}
  val_param; extern;

procedure iedit_text_fp (              {draw floating point string}
  in      fp: real;                    {floating point value to draw}
  in      rit: sys_int_machine_t);     {number of digits right of point}
  val_param; extern;

procedure iedit_text_fp_left (         {draw floating point left from curr point}
  in      fp: real;                    {floating point value to draw}
  in      rit: sys_int_machine_t);     {number of digits right of point}
  val_param; extern;

procedure iedit_text_int (             {draw integer text string}
  in      ii: sys_int_machine_t);      {integer value to draw}
  val_param; extern;

procedure iedit_text_int_left (        {draw integer left from curr point}
  in      ii: sys_int_machine_t);      {integer value to draw}
  val_param; extern;

procedure iedit_text_newline;          {set up for text at start of next line down}
  val_param; extern;

procedure iedit_text_space (           {efficiently skip horizontal space in text}
  in      sp: real);                   {size to skip in character cell widths}
  val_param; extern;

procedure iedit_text_tab (             {tab to a specific character column}
  in      col: real);                  {column to tab to, 0 = left margin}
  val_param; extern;

procedure iedit_texts (                {draw text from Pascal string}
  in    str: string);                  {string to draw, blank pad or nul term}
  val_param; extern;

procedure iedit_whitebal (             {set explicit white balance}
  in    color: color_t);               {relative values for a shade of gray}
  val_param; extern;

procedure iedit_white_update;          {update in white point to white bal if enabled}
  val_param; extern;

procedure iedit_win_img_create;        {create and set up image display window}
  val_param; extern;

procedure iedit_win_img_init;          {init image display window module}
  val_param; extern;

procedure iedit_win_img_ncache;        {invalidate cached display image}
  val_param; extern;

procedure iedit_win_img_update;        {redraw image display window}
  val_param; extern;

procedure iedit_win_menu_init;         {create and init main menu window}
  val_param; extern;

procedure iedit_win_msg_init;          {create and init message line window}
  val_param; extern;

procedure iedit_win_op_create;         {create and init operation window}
  val_param; extern;

procedure iedit_win_op_update;         {redraw operations window}
  val_param; extern;

procedure iedit_win_root_init;         {create and init root GUI window}
  val_param; extern;

procedure xf2d_inv (                   {create inverse of 2D transform}
  in      fw: xf2d_t;                  {input forward transform}
  out     bk: xf2d_t);                 {returned reverse transform}
  val_param; extern;
