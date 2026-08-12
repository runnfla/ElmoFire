//*****************************************************
//  GaleFuncs Add-In for LibreOffice Calc
//  Version 0.2.1
//  Rev. 11.08.2026

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

procedure Pos2Row(P:PChar; Pos:integer; out Row, Col:SizeInt);
begin                                                     //DONE -oGale -cRev.2026.08.11: Proc Pos2Row
  Row:=1;
  Col:=1;
  if P=nil then exit;
  repeat
    if Pos=0 then exit;
    case P^ of
      #0 : exit;
      #$D, #$A : begin
                   case PWord(P)^ of
                     $0D0A, $0A0D : if abs(Pos)>1 then begin
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

function ConvArg(Arg:PChar; out Count, Offs:SizeInt):string;    //DONE -oGale -cRev.2026.08.02: Func ConvArg
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
  Offs:=larg-Arg+2;
end;

function MakeErrMsg(var Err:TRunFlaError; Ptr:PChar; Offs:SizeInt):string;
var s : string;                                           //DONE -oGale -cRev.2026.08.11: Func MakeErrMsg
    r, c : SizeInt;
begin
  with Err do begin
    if Position>=Offs then begin
      Pos2Row(Ptr, Position, r, c);
      if r=1 then dec(c, Offs);
      s:=' in script (row '+IntToStr(r)+', pos '+IntToStr(c)+')';
    end else begin
      Ptr[Position]:=#0;
      ConvArg(Ptr, r, Offs);
      if r=0 then r:=1;
      s:=' in parameter '+IntToStr(r);
    end;
    Result:=GaleErr+s+': '+RunFlaErrorMsg[Code].ErrMsg;
    if length(Value)>0 then Result:=Result+' (diag: "'+Value+'")';
  end;
end;

function gale_str_py(Ptr:PChar; PRec:PDataRec):integer; cdecl; export;
var err : TRunFlaError;                               //DONE -oGale -cRev.2026.08.02: Func gale_str_py
    s : string;
    cnt, ofs : SizeInt;
begin
  Result:=0;
  PRec^.DataType:=0;
  s:=ConvArg(Ptr, cnt, ofs);
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
  if err.Code<>OK then s:=MakeErrMsg(err, Ptr, ofs);
  StrResult(s, PRec);
end;

function gale_val_py(Ptr:PChar; PRec:PDataRec):integer; cdecl; export;
var err : TRunFlaError;                               //DONE -oGale -cRev.2026.08.02: Func gale_val_py
    s : string;
    v : Variant;
    cnt, ofs : SizeInt;
begin
  Result:=0;
  PRec^.DataType:=0;
  s:=ConvArg(Ptr, cnt, ofs);
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
    varString : StrResult(string(PVarData(@v)^.vstring), PRec);
  end else StrResult(MakeErrMsg(err, Ptr, ofs), PRec);
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

