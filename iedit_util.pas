module iedit_util;
define iedit_menu_add_msg;
define xf2d_inv;
%include 'iedit.ins.pas';
{
********************************************************************************
*
*   Subroutine IEDIT_MENU_ADD_MSG (MENU, SUBSYS, MSG, PARMS, N_PARMS)
*
*   Add entries to the menu MENU according to the menus entry message in the
*   message file SUBSYS of name MSG.  PARMS and N_PARMS provide the parameters
*   to the message, if any.
}
procedure iedit_menu_add_msg (         {add menu entried from message}
  in out  menu: gui_menu_t;            {menu to add entries to}
  in      subsys: string;              {message file generic name}
  in      msg: string;                 {name of message within message file}
  in      parms: univ sys_parm_msg_ar_t; {array of parameters for the message}
  in      n_parms: sys_int_machine_t); {number of parameters in PARMS}
  val_param;

var
  mmsg: gui_mmsg_t;                    {menu entries message state}
  name: string_treename_t;             {scratch name string}
  shcut: string_index_t;               {index of shortcut key within entry name}
  id: sys_int_machine_t;               {menu entry ID}

begin
  name.max := size_char(name.str);     {init local var string}

  gui_mmsg_init (                      {open the menu entries message}
    mmsg, subsys, msg, parms, n_parms);

  while gui_mmsg_next (mmsg, name, shcut, id) do begin {get next entry from message}
    gui_menu_ent_add (menu, name, shcut, id); {add this entry to the menu}
    end;                               {back to read next menu entry from message}

  gui_mmsg_close (mmsg);               {close the menu entries message}
  end;
{
********************************************************************************
*
*   Subroutine XF2D_INV (FW, BK)
*
*   Create the reverse 2D transform of FW in BK.
}
procedure xf2d_inv (                   {create inverse of 2D transform}
  in      fw: xf2d_t;                  {input forward transform}
  out     bk: xf2d_t);                 {returned reverse transform}
  val_param;

var
  r: real;                             {scratch floating point}

begin
  r := (fw.xb.x * fw.yb.y) - (fw.yb.x * fw.xb.y); {determinant}
  if abs(r) < 1.0e-12 then r := 1.0;   {return arbitrary scale when determinant 0}
  r := 1.0 / r;                        {make mult factor for each component}

  bk.xb.x := fw.yb.y * r;              {make backwards 2x2 part}
  bk.xb.y := -fw.xb.y * r;
  bk.yb.x := -fw.yb.x * r;
  bk.yb.y := fw.xb.x * r;
{
*   Find the offset vector of the reverse transform.  We know that (0,0) thru
*   the forward transform yields the forward offset vector.  We therefore
*   transform the forward offset vector thru the backwards transform and adjust
*   its offset to yield (0,0).
}
  bk.ofs.x := -(bk.xb.x*fw.ofs.x + bk.yb.x*fw.ofs.y);
  bk.ofs.y := -(bk.xb.y*fw.ofs.x + bk.yb.y*fw.ofs.y);
  end;
