//*****************************************************
//  GaleFuncs Add-In for LibreOffice Calc
//  Version 0.2.2
//  Rev. 4.09.2026

//  Author: Alexander Torubarov
//  Contact: runfla@yandex.com

//  Filename: galefuncs.lpr
//  Source Code: Object Pascal / FPC
//  Compatible: Lazarus 4.2 x64 win10 linux

//  Copyright (C) 2026 Alexander Torubarov
//  Licensed under the MIT License.
//  See the LICENSE file in the project root
//  or a copy available at https://opensource.org
//  for full license information.
//*****************************************************

// TODO -oGale -cRev.2026.00.00:

library galefuncs;

{$mode objfpc}{$H+}

uses cmem,                // must be first
  SysUtils, Variants,
  RunFormula in 'RunFormula/runformula.pas';

{$B-}                           // do not complete boolean evaluation
{$POINTERMATH ON}               // allow use of pointer math
{$R-}                           // switch off range checking
{$Q-}                           // switch off overflow checking
{$T-}                           // untyped address operator
{$Z4}                           // Minimum enumeration type size
{$inline on}

type
  TAnsiRec = packed record                         // from astrings.inc
    CodePage : TSystemCodePage;                    // but packed just in case
    ElementSize : word;
{$ifdef CPU64}
    { align fields  }
    Dummy : DWord;
{$endif CPU64}
    Ref : SizeInt;
    Len : SizeInt;
  end;

  PAnsiRec = ^TAnsiRec;

  TDataRec = packed record
    DataType  : (None = 0, Int = 1, Float = 2, Str = 3);  // 4 bytes ctypes.c_int
    AlignPad  : integer;          // 4 bytes pad
    AsSizeInt : Int64;            // 8 bytes ctypes.c_int64
    AsDouble  : Double;           // 8 bytes ctypes.c_double
    AsPChar   : PSizeInt;         // 8 bytes ctypes.c_char_p  point to 0-terminated string
  end;

  PDataRec = ^TDataRec;

const
  SAnsiRec = SizeOf(TAnsiRec);
  QStr = #7;
  ArgSpr = #$1C;
  GaleErr = 'GaleFuncs ERROR';
  OddMsg = ': Number of parameters must be odd';

procedure Pos2Row(P:PByte; Pos:integer; out Row, Col:SizeInt);
begin                                                     //DONE -oGale -cRev.2026.08.20: Proc Pos2Row
  Row:=1;
  Col:=1;
  if P=nil then exit;
  repeat
    if Pos=0 then exit;
    case P^ of
      0 : exit;
      $A, $D : begin
                  case PWord(P)^ of
                    $0A0D, $0D0A : if abs(Pos)>1 then begin
                                     inc(P);
                                     dec(Pos);
                                   end;
                  end;
                  inc(Row);
                  Col:=0;
                end;
    end;
    inc(P);
    dec(Pos);
    inc(Col);
  until false;
end;

procedure StrResult(constref S:string; PRec:PDataRec);          //DONE -oGale -cRev.2026.08.02: Proc StrResult
var ansi : PSizeInt;
begin
  ansi:=PSizeInt(S);
  if ansi=nil then exit;
  if ansi[-2]>0 then InterlockedIncrement64(ansi[-2]);
  with PRec^ do begin
    AsPChar:=ansi;
    DataType:=Str;
  end;
end;

function ArgConv(Arg:PChar; out Count, Offs:SizeInt):string;    //DONE -oGale -cRev.2026.08.21: Func ArgConv
var L : SizeInt;
    larg, p : PChar;
    d : PByte;
    c : char;
begin
  Count:=0;
  p:=Arg;
  L:=StrLen(p);
  if L<=0 then exit;
  d:=GetMem(L+(SAnsiRec+1));
  with PAnsiRec(d)^ do begin
    CodePage:=CP_UTF8;
    ElementSize:=1;
    Ref:=1;
    Len:=L;
  end;
  inc(d, SAnsiRec);
  PByte(Result):=d;
  larg:=p-1;
  Count:=1;
  repeat
    c:=p^;
    case c of
      #0     : break;
      QStr   : if (Count and 1)<>0 then c:=#$20;
      ArgSpr : begin
                 c:='=';
                 if (Count and 1)=0 then c:=',';
                 larg:=p;
                 inc(Count);
               end;
    end;
    d^:=byte(c);
    inc(d);
    inc(p);
  until false;
  d^:=0;
  Offs:=larg-Arg+2;
end;

function MakeErrMsg(var Err:TRunFlaError; Arg:PChar; Offs:SizeInt):string;
var r, c : SizeInt;                                         //DONE -oGale -cRev.2026.08.21: Func MakeErrMsg
    p : PChar;
begin
  with Err do begin
    if Position>=Offs then begin
      Pos2Row(PByte(Arg), Position, r, c);
      if r=1 then dec(c, Offs);
      Result:=' in script (row '+IntToStr(r)+', pos '+IntToStr(c)+')';
    end else begin
      p:=GetMem(Position+1);
      for c:=0 to Position-1 do begin
        p[c]:=Arg[c];
        if p[c]=#0 then break;
      end;
      p[Position]:=#0;
      ArgConv(p, r, Offs);
      FreeMem(p);
      if r=0 then r:=1;
      Result:=' in parameter '+IntToStr(r);
    end;
    Result:=GaleErr+Result+': '+RunFlaErrorMsg[Code].ErrMsg;
    if PByte(Value)<>nil then Result:=Result+' (diag: "'+Value+'")';
  end;
end;

function gale_str_py(Arg:PChar; PRec:PDataRec):integer; cdecl; export;
var err : TRunFlaError;                               //DONE -oGale -cRev.2026.08.02: Func gale_str_py
    s : string;
    cnt, ofs : SizeInt;
begin
  Result:=0;
  PRec^.DataType:=None;
  s:=ArgConv(Arg, cnt, ofs);
  if (cnt and 1)=0 then begin
    StrResult(GaleErr+OddMsg, PRec);
    exit;
  end;
{$ifdef UNIX}
  HookSignal(RTL_SIGDEFAULT);
{$endif}
  s:=RunFlaExecStr(RunFlaParse(s, err), err);
{$ifdef UNIX}
  UnHookSignal(RTL_SIGDEFAULT);
{$endif}
  if err.Code<>OK then s:=MakeErrMsg(err, Arg, ofs);
  StrResult(s, PRec);
end;

function gale_val_py(Arg:PChar; PRec:PDataRec):integer; cdecl; export;
var err : TRunFlaError;                               //DONE -oGale -cRev.2026.08.02: Func gale_val_py
    s : string;
    v : Variant;
    cnt, ofs : SizeInt;
begin
  Result:=0;
  PRec^.DataType:=None;
  s:=ArgConv(Arg, cnt, ofs);
  if (cnt and 1)=0 then begin
    StrResult(GaleErr+OddMsg, PRec);
    exit;
  end;
{$ifdef UNIX}
  HookSignal(RTL_SIGDEFAULT);
{$endif}
  v:=RunFlaExecVrt(RunFlaParse(s, err), err);
{$ifdef UNIX}
  UnHookSignal(RTL_SIGDEFAULT);
{$endif}
  if err.Code=OK then with PRec^ do case PVarData(@v)^.vtype of
    varDouble : begin
                  AsDouble:=PVarData(@v)^.vdouble;
                  DataType:=Float;
                end;
    varByte   : begin
                  AsSizeInt:=PVarData(@v)^.vbyte;
                  DataType:=Int;
                end;
    varInt64  : begin
                  AsSizeInt:=PVarData(@v)^.vint64;
                  DataType:=Int;
                end;
    varString : StrResult(string(PVarData(@v)^.vstring), PRec);
  end else StrResult(MakeErrMsg(err, Arg, ofs), PRec);
end;

function gale_free_py(Ptr:PSizeInt):integer; cdecl; export;   //DONE -oGale -cRev.2026.08.02: Func gale_free_py
begin
  Result:=0;
  if Ptr[-2]<0 then exit;
  if Ptr[-2]=1 then FreeMem(Ptr-3) else InterlockedDecrement64(Ptr[-2]);
end;

exports
  gale_str_py name 'gale_str_py',
  gale_val_py name 'gale_val_py',
  gale_free_py name 'gale_free_py';

{$ifdef WIN64}

function VBAtoUTF8(PU:PUnicodeChar):PChar;                      //DONE -oGale -cRev.2026.08.22: Func VBAtoUTF8
var L, sz : SizeUInt;
begin
  L:=length(PU);
  sz:=(L shl 2)+1;
  Result:=GetMem(sz);
  UnicodeToUtf8(Result, sz, PU, L);
end;

procedure UTF8toVBA(PRec:PDataRec);                             //DONE -oGale -cRev.2026.08.19: Proc UTF8toVBA
var PU : PByte;
    L : SizeUInt;
begin
  with PRec^ do begin
    if DataType<>Str then exit;
    L:=AsPChar[-1]+1;
    PU:=GetMem((L shl 1)+SAnsiRec)+SAnsiRec;          // simulating string
    PSizeInt(PU)[-2]:=1;
    Utf8ToUnicode(PUnicodeChar(PU), L, PChar(AsPChar), L);
    gale_free_py(AsPChar);
    AsPChar:=PSizeInt(PU);
  end;
end;

function gale_str_vba(Ptr:PUnicodeChar; PRec:PDataRec):integer; stdcall; export;
var arg : PChar;                                               //DONE -oGale -cRev.2026.08.19: Func gale_str_vba
begin
  arg:=VBAtoUTF8(Ptr);
  Result:=gale_str_py(arg, PRec);
  if arg<>nil then FreeMem(arg);
  UTF8toVBA(PRec);
end;

function gale_val_vba(Ptr:PUnicodeChar; PRec:PDataRec):integer; stdcall; export;
var arg : PChar;                                               //DONE -oGale -cRev.2026.08.19: Func gale_val_vba
begin
  arg:=VBAtoUTF8(Ptr);
  Result:=gale_val_py(arg, PRec);
  if arg<>nil then FreeMem(arg);
  UTF8toVBA(PRec);
end;

function gale_free_vba(Ptr:PSizeInt):integer; stdcall; export;    //DONE -oGale -cRev.2026.08.02: Func gale_free_vba
begin
  Result:=gale_free_py(Ptr);
end;

exports
  gale_str_vba name 'gale_str_vba',
  gale_val_vba name 'gale_val_vba',
  gale_free_vba name 'gale_free_vba';

{$endif}

begin
  ReturnNilIfGrowHeapFails:=true;
  IsMultiThread:=true;
end.

