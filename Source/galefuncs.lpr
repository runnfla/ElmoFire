//*****************************************************
//  GaleFuncs Add-In for LibreOffice Calc
//  Version 0.2.1
//  Rev. 2.08.2026

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
{$inline on}

const
  QStr = #7;
  ArgSpr = #$1C;
  GaleErr = 'GaleFuncs ERROR';
  OddMsg = ': Number of parameters must be odd';

type
  TDataRec = packed record
    DataType  : integer;          // 4 bytes ctypes.c_int
    AlignPad  : integer;          // 4 bytes
    AsSizeInt : Int64;            // 8 bytes ctypes.c_int64
    AsDouble  : Double;           // 8 bytes ctypes.c_double
    AsPChar   : PSizeInt;         // 8 bytes ctypes.c_char_p  point to 0-terminated string
  end;

  PDataRec = ^TDataRec;

procedure StrResult(constref S:string; P:PDataRec);       //DONE -oGale -cRev.2026.08.02: Proc StrResult
var ansi : PSizeInt;
begin
  ansi:=PSizeInt(S);
  if ansi=nil then exit;
  if ansi[-2]>0 then InterlockedIncrement64(ansi[-2]);
  with P^ do begin
    AsPChar:=ansi;
    DataType:=3;
  end;
end;

function ConvArg(Arg:PChar; out Count, Offs:integer):string;    //DONE -oGale -cRev.2026.08.02: Func ConvArg
var L : SizeInt;
    larg, p, d : PChar;
    c : char;
begin
  Count:=0;
  p:=Arg;
  L:=StrLen(p);
  if L=0 then exit;
  SetLength(Result, L);
  d:=PChar(Result);
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
    d^:=c;
    inc(d);
    inc(p);
  until false;
  Offs:=larg-Arg+1;
end;

function MakeErrMsg(var Err:TRunFlaError; Ptr:PChar; Offs:integer):string;
var s : string;                                           //DONE -oGale -cRev.2026.08.02: Func MakeErrMsg
    L : integer;
begin
  with Err do begin
    L:=Position-Offs;
    if L<0 then begin
      Ptr[Position]:=#0;
      ConvArg(Ptr, L, Offs);
      if L=0 then L:=1;
      s:=' at parameter ';
    end else s:=' at script position ';
    Result:=GaleErr+s+IntToStr(L)+': '+RunFlaErrorMsg[Code].ErrMsg;
    if length(Value)>0 then Result:=Result+' (diag: "'+Value+'")';
  end;
end;

function gale_str_py(Ptr:PChar; RStruc:PDataRec):integer; cdecl; export;
var err : TRunFlaError;                               //DONE -oGale -cRev.2026.08.02: Func gale_str_py
    s : string;
    cnt, ofs : integer;
begin
  Result:=0;
  RStruc^.DataType:=0;
  s:=ConvArg(Ptr, cnt, ofs);
  if (cnt and 1)=0 then begin
    StrResult(GaleErr+OddMsg, RStruc);
    exit;
  end;
{$ifdef UNIX}
  HookSignal(RTL_SIGDEFAULT);
{$endif}
  s:=RunFlaExecStr(RunFlaParse(s, err), err);
{$ifdef UNIX}
  UnHookSignal(RTL_SIGDEFAULT);
{$endif}
  if err.Code<>OK then s:=MakeErrMsg(err, Ptr, ofs);
  StrResult(s, RStruc);
end;

function gale_val_py(Ptr:PChar; RStruc:PDataRec):integer; cdecl; export;
var err : TRunFlaError;                               //DONE -oGale -cRev.2026.08.02: Func gale_val_py
    s : string;
    v : Variant;
    cnt, ofs : integer;
begin
  Result:=0;
  RStruc^.DataType:=0;
  s:=ConvArg(Ptr, cnt, ofs);
  if (cnt and 1)=0 then begin
    StrResult(GaleErr+OddMsg, RStruc);
    exit;
  end;
{$ifdef UNIX}
  HookSignal(RTL_SIGDEFAULT);
{$endif}
  v:=RunFlaExecVrt(RunFlaParse(s, err), err);
{$ifdef UNIX}
  UnHookSignal(RTL_SIGDEFAULT);
{$endif}
  if err.Code=OK then with RStruc^ do case PVarData(@v)^.vtype of
    varDouble : begin
                  AsDouble:=PVarData(@v)^.vdouble;
                  DataType:=2;
                end;
    varByte   : begin
                  AsSizeInt:=PVarData(@v)^.vbyte;
                  DataType:=1;
                end;
    varInt64  : begin
                  AsSizeInt:=PVarData(@v)^.vint64;
                  DataType:=1;
                end;
    varString : StrResult(string(PVarData(@v)^.vstring), RStruc);
  end else StrResult(MakeErrMsg(err, Ptr, ofs), RStruc);
end;

function gale_free_py(Ptr:PSizeInt):integer; cdecl; export;   //DONE -oGale -cRev.2026.08.02: Func gale_free_py
begin
  Result:=0;
  if Ptr[-2]<0 then exit;
  if Ptr[-2]=1 then FreeMem(Ptr-3) else InterlockedDecrement64(Ptr[-2]);
end;

function gale_str_vba(Ptr:PChar; RStruc:PDataRec):integer; stdcall; export;
begin                                                          //DONE -oGale -cRev.2026.08.02: Func gale_str_vba
  Result:=gale_str_py(Ptr, RStruc);
end;

function gale_val_vba(Ptr:PChar; RStruc:PDataRec):integer; stdcall; export;
begin                                                          //DONE -oGale -cRev.2026.08.02: Func gale_val_vba
  Result:=gale_val_py(Ptr, RStruc);
end;

function gale_free_vba(Ptr:PSizeInt):integer; stdcall; export;    //DONE -oGale -cRev.2026.08.02: Func gale_free_vba
begin
  Result:=gale_free_py(Ptr);
end;

exports
  gale_str_py name 'gale_str_py',
  gale_val_py name 'gale_val_py',
  gale_free_py name 'gale_free_py',
  gale_str_vba name 'gale_str_vba',
  gale_val_vba name 'gale_val_vba',
  gale_free_vba name 'gale_free_vba';

begin
  ReturnNilIfGrowHeapFails:=true;
  IsMultiThread:=true;
end.

