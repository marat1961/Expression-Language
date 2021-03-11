(* Oz Expression Language, for Delphi
 * Copyright (c) 2021 Tomsk, Marat Shaimardanov
 *
 * This file is part of Oz Expression Language, for Delphi
 * is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this file. If not, see <https://www.gnu.org/licenses/>.
*)

unit Oz.El.Scanner;

interface

uses
  Classes, SysUtils, Rtti, Character;

type
  TSymbol = (
    NoSym,            // error token code
    StarSym,          // *
    DivSym,           // / 'div'
    ModSym,           // % 'mod'
    AndSym,           // && 'and'
    PlusSym,          // +
    MinusSym,         // -
    NotSym,           // 'not'
    EmptySym,         // 'empty'
    OrSym,            // || 'or'
    EqSym,            // == 'eq'
    NeSym,            // != 'ne' <>
    LtSym,            // < 'lt'
    GeSym,            // >= 'ge'
    LeSym,            // <= 'le'
    GtSym,            // > 'gt'
    PointSym,         // .
    CommaSym,         // ,
    ColonSym,         // :
    RparenSym,        // )
    RbrackSym,        // ]
    LparenSym,        // (
    LbrackSym,        // [
    IntSym,           // Integer
    DoubleSym,        // A floating-precision number
    StringSym,        // String
    IdentSym,         // Identifier
    TrueSym,          // 'true'
    FalseSym,         // 'false'
    NullSym,          // 'null'
    QuerySym,         // ?
    InstanceofSym,    // 'instanceof'
    DollarLbraceSym,  // ${
    HashLbraceSym,    // #{
    RbraceSym,        // }
    TextSym,          // Text between expressions
    EofSym            // EOF
  );

  TErrorTypes = (etSyntax, etSymantic);
  TErrorProc = procedure(ErrNo: integer; Typ: TErrorTypes) of object;

  TELScanner = class
  strict private
    FKeyTab: TStringList;
    // Add a reserved word
    procedure Enter(Sym: TSymbol; const KeyWord: string);
    // Search in the table of reserved words
    function Find(const Id: string): TSymbol;
    // Fill in the table
    procedure FillKeyTab;
  strict private
    FSource: string;
    FPosition, FLastPosition: Integer;
    FLast, FCh: Char;
    FIsTextMode: Boolean;
    property Ch: Char read FCh;
    property Last: Char read FLast;
    function IsIdentChar(Ch: Char): Boolean;
    procedure GetCh;
    procedure GetIdent;
    procedure GetNumber;
    procedure GetString;
  strict private
    FToken: TStringBuilder;
    FSym: TSymbol;
    function GetToken: string;
    // Reading text - everything up to '${' or '#{'
    procedure GetExprMode;
    // Reading an expression
    procedure GetTextMode;
    function GetVal: TValue;
  strict private
    FScannerError: TErrorProc;
  public
    // Convert the message number to a content string
    function ErrorMessage(ErrNo: Integer): string;
    // Assignable procedure for handling parsing errors
    property ScannerError: TErrorProc read FScannerError write FScannerError;
  public
    constructor Create(const Source: string);
    destructor Destroy; override;
    // Read the lexeme
    procedure Get;
    // Set to read text mode
    procedure SetTextMode;
    // The lexeme
    property Sym: TSymbol read FSym;
    // The string value of the token
    property Token: string read GetToken;
    // Value for a number, string or boolean type
    property Val: TValue read GetVal;
  end;

implementation

{ TELScaner }

constructor TELScanner.Create(const Source: string);
begin
  inherited Create;
  FToken := TStringBuilder.Create;
  FKeyTab := TStringList.Create;
  FSource := Source;
  FIsTextMode := True;
  FPosition := Low(string);
  FLastPosition := Low(string) + Length(Source);
  FillKeyTab;
  GetCh;
end;

destructor TELScanner.Destroy;
begin
  FKeyTab.Free;
  FToken.Free;
  inherited;
end;

function TELScanner.Find(const Id: string): TSymbol;
var
  Idx: Integer;
begin
  if FKeyTab.Find(Id, Idx) then
    Result := TSymbol(FKeyTab.Objects[Idx])
  else
    Result := IdentSym;
end;

procedure TELScanner.Enter(Sym: TSymbol; const KeyWord: string);
begin
  FKeyTab.AddObject(KeyWord, TObject(Sym))
end;

procedure TELScanner.FillKeyTab;
begin
  Enter(AndSym, 'and');
  Enter(OrSym, 'or');
  Enter(NotSym, 'not');
  Enter(DivSym, 'div');
  Enter(ModSym, 'mod');
  Enter(EqSym, 'eq');
  Enter(GtSym, 'gt');
  Enter(NeSym, 'ne');
  Enter(LeSym, 'le');
  Enter(GeSym, 'ge');
  Enter(LtSym, 'lt');
  Enter(InstanceofSym, 'instanceof');
  Enter(EmptySym, 'empty');
  Enter(EmptySym, 'null');
  Enter(TrueSym, 'true');
  Enter(FalseSym, 'false');
  FKeyTab.Sorted := True;
end;

procedure TELScanner.GetCh;
begin
  FLast := FCh;
  if FPosition <= FLastPosition then
  begin
    FCh := FSource[FPosition];
    Inc(FPosition);
  end
  else
    FCh := #0;
end;

procedure TELScanner.Get;
begin
  FToken.Clear;
  if not FIsTextMode then
    GetExprMode
  else
  begin
    GetTextMode;
    if (FToken.Length = 0) and (Ch = '{') then
      GetExprMode;
  end;
end;

procedure TELScanner.GetExprMode;

  procedure Check(DueCh: Char; DueSym, OtherSym: TSymbol);
  begin
    GetCh;
    if Ch <> DueCh then
      FSym := OtherSym
    else
    begin
      GetCh;
      FSym := DueSym;
    end;
  end;

begin
  while Ch.IsSeparator do
    GetCh;
  case Ch of
    'a'..'z', 'A'..'Z': GetIdent;
    '0'..'9':  GetNumber;
    '''', '"': GetString;
    '?': begin GetCh; FSym := QuerySym end;
    '.': begin GetCh; FSym := PointSym end;
    ',': begin GetCh; FSym := CommaSym end;
    '(': begin GetCh; FSym := LparenSym end;
    ')': begin GetCh; FSym := RparenSym end;
    '[': begin GetCh; FSym := LbrackSym end;
    ']': begin GetCh; FSym := RbrackSym end;
    ':': begin GetCh; FSym := ColonSym end;
    '+': begin GetCh; FSym := PlusSym end;
    '-': begin GetCh; FSym := MinusSym; end;
    '*': begin GetCh; FSym := StarSym end;
    '/': begin GetCh; FSym := DivSym end;
    '%': begin GetCh; FSym := ModSym end;
    '|': Check('|', OrSym, NoSym);
    '&': Check('&', AndSym, NoSym);
    '>': Check('=', GeSym, GtSym);
    '!': Check('=', NeSym, NotSym);
    '=': Check('=', EqSym, EqSym);
    '$': Check('{', DollarLbraceSym, NotSym);
    '#': Check('{', HashLbraceSym, NotSym);
    '<': begin
           Check('=', LeSym, NoSym);
           if FSym = NoSym then Check('>', NeSym, LtSym)
         end;
    '{': if Last = '$' then begin GetCh; FSym := DollarLbraceSym end
         else if Last = '#' then begin GetCh; FSym := HashLbraceSym end
         else GetTextMode;
    '}': begin GetCh; FSym := RbraceSym end;
    #0:  FSym := EofSym;
    else GetTextMode;
  end;
end;

procedure TELScanner.GetTextMode;
begin
  FIsTextMode := True;
  try
    // The text includes characters up to '${' or '${'
    FSym := TextSym;
    repeat
      while (Ch <> '$') and (Ch <> '#') do
      begin
        if Ch = '\' then
          GetCh;
        if Ch = #0 then
        begin
          if FToken.Length = 0 then FSym := EofSym;
          exit;
        end;
        FToken.Append(Ch);
        GetCh;
      end;
      GetCh;
    until Ch = '{';
  finally
    FIsTextMode := False;
  end;
end;

procedure TELScanner.GetIdent;
begin
  repeat
    FToken.Append(Ch);
    GetCh;
  until not IsIdentChar(Ch);
  FSym := Find(FToken.ToString);
end;

procedure TELScanner.GetNumber;

   procedure GetInt;
   begin
     while Ch.IsNumber do
     begin
       FToken.Append(Ch);
       GetCh;
     end;
   end;

begin
  FSym := IntSym;
  GetInt;
  if Ch = '.' then
  begin
    FSym := DoubleSym;
    FToken.Append('.');
    GetCh;
    GetInt;
    if (Ch = 'E') or (Ch = 'e') then
    begin
      FToken.Append('E');
      GetCh;
      GetInt;
    end;
  end;
end;

procedure TELScanner.GetString;
var
  Limiter: Char;
begin
  FSym := StringSym;
  Limiter := Ch;
  GetCh;
  // skip the string limiter ' | "
  while Ch <> Limiter do
  begin
    case Ch of
      #13, #10:
        begin
          if Ch = #13 then GetCh;
          break;
        end;
     '\':
      begin
        // if there is a combination with an escape character, replace it with
        GetCh;
        case Ch of
          'b': FCh := #8;
          't': FCh := #9;
          'n': FCh := #10;
          'f': FCh := #12;
          'r': FCh := #13;
        end;
      end;
    end;
    FToken.Append(Ch);
    GetCh;
  end;
  GetCh; // Skip one of the characters: ', ', #10
end;

function TELScanner.GetToken: string;
begin
  Result := FToken.ToString;
end;

function TELScanner.GetVal: TValue;
begin
  case Sym of
    IntSym:
      Result := StrToInt(Token);
    DoubleSym:
      Result := StrToFloat(Token);
    TrueSym:
      Result := True;
    FalseSym:
      Result := False;
    NullSym:
      Result := nil;
    else
      Result := Token;
  end;
end;

function TELScanner.IsIdentChar(Ch: Char): Boolean;
begin
  case Ch of
    'A'..'Z', 'a'..'z', '_':
      Result := True;
    else
      Result := False;
  end;
end;

procedure TELScanner.SetTextMode;
begin
  FIsTextMode := True;
end;

function TELScanner.ErrorMessage(ErrNo: Integer): string;
begin
  case ErrNo of
    1: Result := 'Expected identifier';
    2: Result := 'Redeclaration';
    3: Result := 'Multiplier expected';
    4: Result := 'Not an array';
    5: Result := 'Too many parameters';
    6: Result := 'Expected ${ or #{';
    else Result := 'Uregistered Error'
  end;
end;

end.

