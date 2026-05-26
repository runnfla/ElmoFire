library elmofire;

{$mode objfpc}{$H+}

uses cmem, // СТРОГО ПЕРВЫМ!
  SysUtils, Classes,
  RunFormula in 'RunFormula/runformula.pas';

{$B-}                           // do not complete boolean evaluation
{$POINTERMATH ON}               // allow use of pointer math
{$R-}                           // switch off range checking
{$Q-}                           // switch off overflow checking
{$T-}                           // untyped address operator
{$inline on}

type
  TDataRec = packed record
    DataType: Integer;         // 4 bytes ctypes.c_int
    AsSizeInt: Int64;          // 8 bytes ctypes.c_int64
    AsDouble: Double;          // 8 bytes ctypes.c_double
    AsPChar: PAnsiChar;        // 8 bytes ctypes.c_char_p
  end;

  PDataRec = ^TDataRec;

function elmo_str_py(Arg:PChar; ResStruct:PDataRec):integer; cdecl; export;
var s : string;

   ArgsString: UTF8String;
  ResultString: UTF8String;
  StrLen: Integer;


begin
  Result := 0;
  ResStruct^.DataType:=0;
  if Arg=nil then exit;
  s:=SysUtils.StrPas(Arg); // s может оказаться пустой      Result^.Value.AsPChar := StrNew(PChar(s));

  ResultString := 'Lazarus получил: ' + s;
  StrLen := Length(ResultString) + 1;
  ResStruct^.AsPChar := AllocMem(StrLen);

  Move(PByte(ResultString), ResStruct^.AsPChar, StrLen);
  ResStruct^.DataType := 3;


end;

function elmo_val_py(Arg:PChar):PDataRec; cdecl; export;
var s : string;
begin
  Result:=nil;
  if Arg=nil then exit;
  s:=SysUtils.StrPas(Arg); // s может оказаться пустой      Result^.Value.AsPChar := StrNew(PChar(s));
  new(Result);
  with Result^ do begin
    DataType:=3;
    AsPChar:=StrNew(@s[1]);
  end;
end;

procedure elmo_free_str(Ptr:PChar); cdecl; export;
begin
  FreeMem(Ptr);
end;

exports
  elmo_str_py,
  elmo_val_py,
  elmo_free_str;

begin
  IsMultiThread:=true;
end.
