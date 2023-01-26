module iedit_text;
define iedit_text;
define iedit_texts;
define iedit_text_newline;
define iedit_text_space;
define iedit_text_tab;
define iedit_text_int;
define iedit_text_int_left;
define iedit_text_fp;
define iedit_text_fp_left;
define iedit_text_color;
%include 'image_edit.ins.pas';
{
********************************************************************************
*
*   Subroutine IEDIT_TEXT (S)
*
*   Draw the text string S.
}
procedure iedit_text (                 {draw text from var string}
  in      s: univ string_var_arg_t);   {text string to draw}
  val_param;

begin
  rend_prim.text^ (s.str, s.len);
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_TEXTS (STR)
*
*   Draw the text from Pascal string.
}
procedure iedit_texts (                {draw text from Pascal string}
  in    str: string);                  {string to draw, blank pad or nul term}
  val_param;

var
  vstr: string_var8192_t;

begin
  vstr.max := size_char(vstr.str);     {init local var string}
  string_vstring (vstr, str, size_char(str)); {make var string}
  iedit_text (vstr);
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_TEXT_NEWLINE
*
*   Move the current point and update the local text drawing state for writing
*   subsequent text starting at the left margin of the next line down.
}
procedure iedit_text_newline;          {set up for text at start of next line down}
  val_param;

var
  dy: real;

begin
  dy := tparm.size * (tparm.height + tparm.lspace); {Y stride per text line}
  text_y := text_y - dy;               {make Y of this new line}
  rend_set.cpnt_2d^ (text_left, text_y); {go to start of the new line}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_TEXT_SPACE (SP)
*
*   Efficiently moves the current point horizontally SP number of character cell
*   widths.
}
procedure iedit_text_space (           {efficiently skip horizontal space in text}
  in      sp: real);                   {size to skip in character cell widths}
  val_param;

var
  x, y: real;

begin
  rend_get.cpnt_2d^ (x, y);            {get the current point}
  x := x + tparm.size * tparm.width * sp; {make the new X}
  rend_set.cpnt_2d^ (x, y);            {go there}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_TEXT_TAB (COL)
*
*   Tab to the indicated character column.  This only moves the current point to
*   the right.  The current point is moved to the right at least one character
*   cell width, even if that moves it past the tab point.  COL is relative to
*   the left margin.
}
procedure iedit_text_tab (             {tab to a specific character column}
  in      col: real);                  {column to tab to, 0 = left margin}
  val_param;

var
  x, y: real;
  w: real;                             {one character cell width}

begin
  rend_get.cpnt_2d^ (x, y);            {get the current point}
  w := tparm.size * tparm.width;       {make width of one character cell}
  x := max(text_left + col * w, x + w); {make new X}
  rend_set.cpnt_2d^ (x, y);            {go there}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_TEXT_INT (II)
*
*   Draw the decimal representation of the integer value as a text string.  Free
*   format is used.
}
procedure iedit_text_int (             {draw integer text string}
  in      ii: sys_int_machine_t);      {integer value to draw}
  val_param;

var
  tk: string_var32_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_int (tk, ii);               {make the character string}
  iedit_text (tk);                     {draw it}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_TEXT_INT_LEFT (II)
*
*   Draw the decimal representation of the integer value as a text string.  The
*   string is drawn left from the current point.  The current point is not
*   altered.
}
procedure iedit_text_int_left (        {draw integer left from curr point}
  in      ii: sys_int_machine_t);      {integer value to draw}
  val_param;

var
  tp: rend_text_parms_t;               {temporary text control parameters}
  x, y: real;                          {saved current point}
  tk: string_var32_t;                  {scratch text string}

begin
  tk.max := size_char(tk.str);         {init local var string}

  rend_get.cpnt_2d^ (x, y);            {save the current point}
  tp := tparm;                         {make local copy of text control parameters}
  tp.start_org := rend_torg_lr_k;      {set anchor point to lower right}
  rend_set.text_parms^ (tp);           {set the temporary text control parameters}
  string_f_int (tk, ii);               {make the character string}
  iedit_text (tk);                     {draw the number}
  rend_set.text_parms^ (tparm);        {restore the original text control parameters}
  rend_set.cpnt_2d^ (x, y);            {restore the original current point}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_TEXT_FP (FP, RIT)
*
*   Draw the floating point value FP with RIT digits right of the decimal point.
}
procedure iedit_text_fp (              {draw floating point string}
  in      fp: real;                    {floating point value to draw}
  in      rit: sys_int_machine_t);     {number of digits right of point}
  val_param;

var
  tk: string_var32_t;

begin
  tk.max := size_char(tk.str);         {init local var string}

  string_f_fp_fixed (tk, fp, rit);     {make the text string}
  iedit_text (tk);                     {draw it}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_TEXT_FP_LEFT (FP, RIT)
*
*   Draw the floating point value FP with RIT digits right of the decimal point.
*   The string is drawn left from the current point.  The current point is not
*   altered.
}
procedure iedit_text_fp_left (         {draw integer left from curr point}
  in      fp: real;                    {floating point value to draw}
  in      rit: sys_int_machine_t);     {number of digits right of point}
  val_param;

var
  tp: rend_text_parms_t;               {temporary text control parameters}
  x, y: real;                          {saved current point}
  tk: string_var32_t;                  {scratch text string}

begin
  tk.max := size_char(tk.str);         {init local var string}

  rend_get.cpnt_2d^ (x, y);            {save the current point}
  tp := tparm;                         {make local copy of text control parameters}
  tp.start_org := rend_torg_lr_k;      {set anchor point to lower right}
  rend_set.text_parms^ (tp);           {set the temporary text control parameters}
  string_f_fp_fixed (tk, fp, rit);     {make the text string}
  iedit_text (tk);                     {draw the number}
  rend_set.text_parms^ (tparm);        {restore the original text control parameters}
  rend_set.cpnt_2d^ (x, y);            {restore the original current point}
  end;
{
********************************************************************************
*
*   Subroutine IEDIT_TEXT_COLOR (FULL)
*
*   Set the color for drawing text.  FULL TRUE indicates the text should be
*   drawn at regular brightness.  FULL FALSE cause the color to be set for text
*   to be drawn indicating less importance.
}
procedure iedit_text_color (           {set text drawing color}
  in      full: boolean);              {text has regular full importance}
  val_param;

begin
  if full
    then begin
      rend_set.rgb^ (1.0, 1.0, 1.0);
      end
    else begin
      rend_set.rgb^ (0.50, 0.50, 0.50);
      end
    ;
  end;
