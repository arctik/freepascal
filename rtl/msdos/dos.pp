{
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by the Free Pascal development team.

    Dos unit for BP7 compatible RTL

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{$inline on}

unit dos;

interface

Type
  searchrec = packed record
     fill : array[1..21] of byte;
     attr : byte;
     time : longint;
     { reserved : word; not in DJGPP V2 }
     size : longint;
     name : string[255]; { LFN Name, DJGPP uses only [12] but more can't hurt (PFV) }
  end;

{$DEFINE HAS_REGISTERS}
{$I registers.inc}

{$i dosh.inc}

{$IfDef SYSTEM_DEBUG_STARTUP}
  {$DEFINE FORCE_PROXY}
{$endif SYSTEM_DEBUG_STARTUP}
Const
  { This variable can be set to true
    to force use of !proxy command lines even for short
    strings, for debugging purposes mainly, as
    this might have negative impact if trying to
    call non-go32v2 programs }
  force_go32v2_proxy : boolean =
{$ifdef FORCE_PROXY}
  true;
{$DEFINE DEBUG_PROXY}
{$else not FORCE_PROXY}
  false;
{$endif not FORCE_PROXY}
  { This variable allows to use !proxy if command line is
    longer than 126 characters.
    This will only work if the called program knows how to handle
    those command lines.
    Luckily this is the case for Free Pascal compiled
    programs (even old versions)
    and go32v2 DJGPP programs.
    You can set this to false to get a warning to stderr
    if command line is too long. }
  Use_go32v2_proxy : boolean = true;

{ Added to interface so that there is no need to implement it
  both in dos and sysutils units }

procedure exec_ansistring(path : string;comline : ansistring);

procedure Intr(IntNo: Byte; var Regs: Registers); external name 'FPC_INTR';
procedure MsDos(var Regs: Registers); external name 'FPC_MSDOS';

implementation

uses
  strings;

{$DEFINE HAS_GETMSCOUNT}
{$DEFINE HAS_INTR}
{$DEFINE HAS_SETCBREAK}
{$DEFINE HAS_GETCBREAK}
{$DEFINE HAS_SETVERIFY}
{$DEFINE HAS_GETVERIFY}
{$DEFINE HAS_SWAPVECTORS}
{$DEFINE HAS_GETSHORTNAME}
{$DEFINE HAS_GETLONGNAME}

{$DEFINE FPC_FEXPAND_UNC} (* UNC paths are supported *)
{$DEFINE FPC_FEXPAND_DRIVES} (* Full paths begin with drive specification *)

{$I dos.inc}

{******************************************************************************
                           --- Dos Interrupt ---
******************************************************************************}

var
  dosregs : registers;

procedure LoadDosError;
var
  r : registers;
  SimpleDosError : word;
begin
  if (dosregs.flags and fcarry) <> 0 then
   begin
     { I got a extended error = 0
       while CarryFlag was set from Exec function }
     SimpleDosError:=dosregs.ax;
     r.ax:=$5900;
     r.bx:=$0;
     intr($21,r);
     { conversion from word to integer !!
       gave a Bound check error if ax is $FFFF !! PM }
     doserror:=integer(r.ax);
     case doserror of
      0  : DosError:=integer(SimpleDosError);
      19 : DosError:=150;
      21 : DosError:=152;
     end;
   end
  else
    doserror:=0;
end;


{******************************************************************************
                        --- Info / Date / Time ---
******************************************************************************}

function dosversion : word;
begin
  dosregs.ax:=$3000;
  msdos(dosregs);
  dosversion:=dosregs.ax;
end;


procedure getdate(var year,month,mday,wday : word);
begin
  dosregs.ax:=$2a00;
  msdos(dosregs);
  wday:=dosregs.al;
  year:=dosregs.cx;
  month:=dosregs.dh;
  mday:=dosregs.dl;
end;


procedure setdate(year,month,day : word);
begin
   dosregs.cx:=year;
   dosregs.dh:=month;
   dosregs.dl:=day;
   dosregs.ah:=$2b;
   msdos(dosregs);
end;


procedure gettime(var hour,minute,second,sec100 : word);
begin
  dosregs.ah:=$2c;
  msdos(dosregs);
  hour:=dosregs.ch;
  minute:=dosregs.cl;
  second:=dosregs.dh;
  sec100:=dosregs.dl;
end;


procedure settime(hour,minute,second,sec100 : word);
begin
  dosregs.ch:=hour;
  dosregs.cl:=minute;
  dosregs.dh:=second;
  dosregs.dl:=sec100;
  dosregs.ah:=$2d;
  msdos(dosregs);
end;


function GetMsCount: int64;
begin
  GetMsCount := int64 (MemL [$40:$6c]) * 55;
end;


{******************************************************************************
                               --- Exec ---
******************************************************************************}

const
  DOS_MAX_COMMAND_LINE_LENGTH = 126;

procedure exec_ansistring(path : string;comline : ansistring);
begin
  {TODO: implement}
  runerror(304);
end;

procedure exec(const path : pathstr;const comline : comstr);
begin
  exec_ansistring(path, comline);
end;


procedure getcbreak(var breakvalue : boolean);
begin
  dosregs.ax:=$3300;
  msdos(dosregs);
  breakvalue:=dosregs.dl<>0;
end;


procedure setcbreak(breakvalue : boolean);
begin
  dosregs.ax:=$3301;
  dosregs.dl:=ord(breakvalue);
  msdos(dosregs);
end;


procedure getverify(var verify : boolean);
begin
  dosregs.ah:=$54;
  msdos(dosregs);
  verify:=dosregs.al<>0;
end;


procedure setverify(verify : boolean);
begin
  dosregs.ah:=$2e;
  dosregs.al:=ord(verify);
  msdos(dosregs);
end;


{******************************************************************************
                               --- Disk ---
******************************************************************************}

type
  ExtendedFat32FreeSpaceRec = packed record
    RetSize           : word;      { $00 }
    Strucversion      : word;      { $02 }
    SecPerClus,                    { $04 }
    BytePerSec,                    { $08 }
    AvailClusters,                 { $0C }
    TotalClusters,                 { $10 }
    AvailPhysSect,                 { $14 }
    TotalPhysSect,                 { $18 }
    AvailAllocUnits,               { $1C }
    TotalAllocUnits   : longword;  { $20 }
    Dummy,                         { $24 }
    Dummy2            : longword;  { $28 }
  end;                             { $2C }

const
  IOCTL_INPUT = 3;       //For request header command field
  CDFUNC_SECTSIZE = 7;   //For cdrom control block func field
  CDFUNC_VOLSIZE  = 8;   //For cdrom control block func field

type
  TRequestHeader = packed record
    length     : byte;         { $00 }
    subunit    : byte;         { $01 }
    command    : byte;         { $02 }
    status     : word;         { $03 }
    reserved1  : longword;     { $05 }
    reserved2  : longword;     { $09 }
    media_desc : byte;         { $0D }
    transf_ofs : word;         { $0E }
    transf_seg : word;         { $10 }
    numbytes   : word;         { $12 }
  end;                         { $14 }

  TCDSectSizeReq = packed record
    func    : byte;            { $00 }
    mode    : byte;            { $01 }
    secsize : word;            { $02 }
  end;                         { $04 }

  TCDVolSizeReq = packed record
    func    : byte;            { $00 }
    size    : longword;        { $01 }
  end;                         { $05 }


function do_diskdata(drive : byte; Free : boolean) : Int64;
begin
  {TODO: implement}
  runerror(304);
end;

function diskfree(drive : byte) : int64;
begin
   diskfree:=Do_DiskData(drive,TRUE);
end;

function disksize(drive : byte) : int64;
begin
  disksize:=Do_DiskData(drive,false);
end;


{******************************************************************************
                      --- LFNFindfirst LFNFindNext ---
******************************************************************************}

type
  LFNSearchRec=packed record
    attr,
    crtime,
    crtimehi,
    actime,
    actimehi,
    lmtime,
    lmtimehi,
    sizehi,
    size      : longint;
    reserved  : array[0..7] of byte;
    name      : array[0..259] of byte;
    shortname : array[0..13] of byte;
  end;

procedure LFNSearchRec2Dos(const w:LFNSearchRec;hdl:longint;var d:Searchrec;from_findfirst : boolean);
var
  Len : longint;
begin
  With w do
   begin
     FillChar(d,sizeof(SearchRec),0);
     if DosError=0 then
      len:=StrLen(@Name)
     else
      len:=0;
     d.Name[0]:=chr(len);
     Move(Name[0],d.Name[1],Len);
     d.Time:=lmTime;
     d.Size:=Size;
     d.Attr:=Attr and $FF;
     if (DosError<>0) and from_findfirst then
       hdl:=-1;
     Move(hdl,d.Fill,4);
   end;
end;

{$ifdef DEBUG_LFN}
const
  LFNFileName : string = 'LFN.log';
  LFNOpenNb : longint = 0;
  LogLFN : boolean = false;
var
  lfnfile : text;
{$endif DEBUG_LFN}

procedure LFNFindFirst(path:pchar;attr:longint;var s:searchrec);
begin
  {TODO: implement}
  runerror(304);
end;


procedure LFNFindNext(var s:searchrec);
begin
  {TODO: implement}
  runerror(304);
end;


procedure LFNFindClose(var s:searchrec);
begin
  {TODO: implement}
  runerror(304);
end;


{******************************************************************************
                     --- DosFindfirst DosFindNext ---
******************************************************************************}

procedure dossearchrec2searchrec(var f : searchrec);
var
  len : longint;
begin
  { Check is necessary!! OS/2's VDM doesn't clear the name with #0 if the }
  { file doesn't exist! (JM)                                              }
  if dosError = 0 then
    len:=StrLen(@f.Name)
  else len := 0;
  Move(f.Name[0],f.Name[1],Len);
  f.Name[0]:=chr(len);
end;


procedure DosFindfirst(path : pchar;attr : word;var f : searchrec);
begin
  {TODO: implement}
  runerror(304);
end;


procedure Dosfindnext(var f : searchrec);
begin
  {TODO: implement}
  runerror(304);
end;


{******************************************************************************
                     --- Findfirst FindNext ---
******************************************************************************}

procedure findfirst(const path : pathstr;attr : word;var f : searchRec);
var
  path0 : array[0..255] of char;
begin
  doserror:=0;
  strpcopy(path0,path);
  if LFNSupport then
   LFNFindFirst(path0,attr,f)
  else
   Dosfindfirst(path0,attr,f);
end;


procedure findnext(var f : searchRec);
begin
  doserror:=0;
  if LFNSupport then
   LFNFindnext(f)
  else
   Dosfindnext(f);
end;


Procedure FindClose(Var f: SearchRec);
begin
  DosError:=0;
  if LFNSupport then
   LFNFindClose(f);
end;


type swap_proc = procedure;

var
  _swap_in  : swap_proc;external name '_swap_in';
  _swap_out : swap_proc;external name '_swap_out';
  _exception_exit : pointer;external name '_exception_exit';
  _v2prt0_exceptions_on : longbool;external name '_v2prt0_exceptions_on';

procedure swapvectors;
begin
  if _exception_exit<>nil then
    if _v2prt0_exceptions_on then
      _swap_out()
    else
      _swap_in();
end;


{******************************************************************************
                               --- File ---
******************************************************************************}


Function FSearch(path: pathstr; dirlist: string): pathstr;
var
  i,p1   : longint;
  s      : searchrec;
  newdir : pathstr;
begin
{ check if the file specified exists }
  findfirst(path,anyfile and not(directory),s);
  if doserror=0 then
   begin
     findclose(s);
     fsearch:=path;
     exit;
   end;
{ No wildcards allowed in these things }
  if (pos('?',path)<>0) or (pos('*',path)<>0) then
    fsearch:=''
  else
    begin
       { allow slash as backslash }
       DoDirSeparators(dirlist);
       repeat
         p1:=pos(';',dirlist);
         if p1<>0 then
          begin
            newdir:=copy(dirlist,1,p1-1);
            delete(dirlist,1,p1);
          end
         else
          begin
            newdir:=dirlist;
            dirlist:='';
          end;
         if (newdir<>'') and (not (newdir[length(newdir)] in ['\',':'])) then
          newdir:=newdir+'\';
         findfirst(newdir+path,anyfile and not(directory),s);
         if doserror=0 then
          newdir:=newdir+path
         else
          newdir:='';
       until (dirlist='') or (newdir<>'');
       fsearch:=newdir;
    end;
  findclose(s);
end;


{ change to short filename if successful DOS call PM }
function GetShortName(var p : String) : boolean;
begin
  {TODO: implement}
  runerror(304);
end;


{ change to long filename if successful DOS call PM }
function GetLongName(var p : String) : boolean;
begin
  {TODO: implement}
  runerror(304);
end;


{******************************************************************************
                       --- Get/Set File Time,Attr ---
******************************************************************************}

procedure getftime(var f;var time : longint);
begin
  dosregs.bx:=textrec(f).handle;
  dosregs.ax:=$5700;
  msdos(dosregs);
  loaddoserror;
  time:=(dosregs.dx shl 16)+dosregs.cx;
end;


procedure setftime(var f;time : longint);
begin
  dosregs.bx:=textrec(f).handle;
  dosregs.cx:=time and $ffff;
  dosregs.dx:=time shr 16;
  dosregs.ax:=$5701;
  msdos(dosregs);
  loaddoserror;
end;


procedure getfattr(var f;var attr : word);
begin
  {TODO: implement}
  runerror(304);
end;


procedure setfattr(var f;attr : word);
begin
  {TODO: implement}
  runerror(304);
end;


{******************************************************************************
                             --- Environment ---
******************************************************************************}

function envcount : longint;
var
  hp : ppchar;
begin
  hp:=envp;
  envcount:=0;
  while assigned(hp^) do
   begin
     inc(envcount);
     inc(hp);
   end;
end;


function envstr (Index: longint): string;
begin
  if (index<=0) or (index>envcount) then
    envstr:=''
  else
    envstr:=strpas(ppchar(pointer(envp)+SizeOf(PChar)*(index-1))^);
end;


Function  GetEnv(envvar: string): string;
var
  hp    : ppchar;
  hs    : string;
  eqpos : longint;
begin
  envvar:=upcase(envvar);
  hp:=envp;
  getenv:='';
  while assigned(hp^) do
   begin
     hs:=strpas(hp^);
     eqpos:=pos('=',hs);
     if upcase(copy(hs,1,eqpos-1))=envvar then
      begin
        getenv:=copy(hs,eqpos+1,length(hs)-eqpos);
        break;
      end;
     inc(hp);
   end;
end;

{$ifdef DEBUG_LFN}
begin
  LogLFN:=(GetEnv('LOGLFN')<>'');
  assign(lfnfile,LFNFileName);
{$I-}
  Reset(lfnfile);
  if IOResult<>0 then
    begin
      Rewrite(lfnfile);
      Writeln(lfnfile,'New lfn.log');
    end;
  close(lfnfile);
{$endif DEBUG_LFN}

end.
