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

unit Oz.El.Parser;

interface

uses
  Classes, SysUtils, Rtti, Dialogs, Oz.El.Scanner, Oz.El.Ast;

{$Region 'TELParser: Expression parser'}

type
  TELParser = class
  private
    FScanner: TELScanner;
    FErrDist: integer;
    FErrorCount: integer;
    function GetSym: TSymbol; inline;
  private
    function CompositeExpression: TAstCompositeExpression;
    function BracedExpression: TNode;
    function LiteralExpression: TAstLiteralExpression;
    function Choice: TNode;
    function Expression: TNode;
    function SimpleExpression: TNode;
    function Term: TNode;
    function Factor: TNode;
    procedure Designator(X: TNode);
    procedure Parameters(X: TNode);
  protected
    procedure Error(ErrNo: integer; Typ: TErrorTypes);
    procedure SemError(errNo: integer);
    procedure SynError(errNo: integer);
    procedure Get; inline;
    property Sym: TSymbol read GetSym;
    procedure Expect(n: TSymbol);
    property Scanner: TELScanner read FScanner;
  public
    constructor Create(const Source: string);
    destructor Destroy; override;
    function Parse: TAstCompositeExpression;
    property ErrorCount: Integer read FErrorCount;
  end;

{$EndRegion}

implementation

const
  minErrDist = 2;

{$Region 'TELParser'}

constructor TELParser.Create(const Source: string);
begin
  inherited Create;
  FScanner := TELScanner.Create(Source);
  FScanner.ScannerError := Self.Error;
  FErrorCount := 0;
  Get;
end;

destructor TELParser.Destroy;
begin
  FScanner.Free;
  inherited;
end;

function TELParser.CompositeExpression: TAstCompositeExpression;
var
  X: TNode;
begin
  // A compound expression is a text,
  // within which there are expressions enclosed in brackets
  Result := TAstCompositeExpression.Create(Sym);
  X := nil;
  repeat
    if Sym = TextSym then
      X := LiteralExpression
    else if Sym in [HashLbraceSym, DollarLbraceSym] then
      X := BracedExpression
    else
      break;
    Result.Children.Add(X);
  until False;
end;

function TELParser.BracedExpression: TNode;
begin
  Result := TAstBracedExpression.Create(Sym);
  Get;
  Result.Children.Add(Choice);
  Scanner.SetTextMode;
  Expect(RbraceSym);
end;

function TELParser.LiteralExpression: TAstLiteralExpression;
begin
  Result := TAstLiteralExpression.Create(TextSym, Scanner.Token);
  Get;
end;

function TELParser.Choice: TNode;
var
  X: TNode;
begin
  X := Expression;
  if Sym = QuerySym then
  begin
    Get;
    X := TAstChoice.Create(QuerySym, X);
    X.Children.Add(Expression);
    Expect(ColonSym);
    X.Children.Add(Expression);
  end;
  Result := X;
end;

function TELParser.Expression: TNode;
var
  X: TNode;
  Op: TSymbol;
begin
  X := SimpleExpression;
  if Sym in [EqSym, GtSym, LtSym, GeSym, LeSym, EqSym, NeSym] then
  begin
    Op := Sym; Get;
    X := TAstRelation.Create(Op, X);
    X.Children.Add(SimpleExpression);
  end;
  Result := X;
end;

function TELParser.SimpleExpression: TNode;
var
  i: Integer;
  X: TNode;
  Op: TSymbol;
begin
  if Sym = PlusSym then
  begin
    Get;
    X := Term;
  end
  else if Sym in [MinusSym, EmptySym] then
  begin
    Op := Sym; Get;
    X := TAstUnaryOp.Create(Op, Term);
  end
  else
    X := Term;
  i := 0;
  while Sym in [PlusSym, MinusSym, OrSym] do
  begin
    Op := Sym; Get;
    if i = 0 then
      X := TAstBinaryOp.Create(Op, X);
    X.Children.Add(Term);
    Inc(i);
  end;
  Result := X;
end;

function TELParser.Term: TNode;
var
  i: Integer;
  X: TNode;
  Op: TSymbol;
begin
  X := Factor;
  i := 0;
  while Sym in [AndSym, StarSym, DivSym, ModSym] do
  begin
    Op := Sym; Get;
    if i = 0 then
      X := TAstBinaryOp.Create(Op, X);
    X.Children.Add(Factor);
    Inc(i);
  end;
  Result := X;
end;

function TELParser.Factor: TNode;
var
  X: TNode;
  NameSpace, Ident: string;
begin
  { sync }
  if Sym < LparenSym then
  begin
    SynError(1);
    repeat Get until Sym >= LParenSym;
  end;
  X := nil;
  case Sym of
    IdentSym:
      // Possible construction: [ Ident ':' ] Ident
      begin
        Ident := Scanner.Token;
        Get;
        if Sym = colonSym then
        begin
          NameSpace := Scanner.Token;
          Get;
          if Sym = IdentSym then
            Ident := Ident + ':' + Ident
          else
            Expect(IdentSym);
        end;
        X := TAstIdentifier.Create(IdentSym, Ident);
        Designator(X);
      end;
    IntSym, DoubleSym, StringSym, FalseSym, TrueSym, NullSym:
      begin
        X := TAstLiteralExpression.Create(Sym, FScanner.Val);
        Get;
      end;
    LparenSym:
      begin
        Get;
        X := TAstBracedExpression.Create(LparenSym);
        X.Children.Add(Expression);
        Expect(RparenSym);
      end;
    NotSym:
      begin
        Get;
        X := TAstUnaryOp.Create(NotSym);
        X.Children.Add(Factor);
      end;
    else
      SynError(3);
  end;
  Result := X;
end;

procedure TELParser.Designator(X: TNode);
var
  Y: TNode;
begin
  while (Sym = LbrackSym) or (Sym = PointSym) or (Sym = LparenSym) do
  begin
    if Sym = LbrackSym then
    begin
      Get;
      Y := TAstBracedExpression.Create(LbrackSym, Expression);
      X.Children.Add(Y);
      Expect(RbrackSym);
    end
    else if Sym = PointSym then
    begin
      Get;
      Expect(IdentSym);
      Y := TAstIdentifier.Create(PointSym, Scanner.Token);
      X.Children.Add(Y);
    end
    else
      Parameters(X);
  end;
end;

procedure TELParser.Parameters(X: TNode);
begin
  if Sym <> RparenSym then
  begin
    X.Children.Add(Expression);
    while Sym = CommaSym do
    begin
      X.Children.Add(Expression);
    end;
    Expect(RparenSym);
  end;
end;

function TELParser.Parse: TAstCompositeExpression;
begin
  Result := CompositeExpression;
end;

procedure TELParser.Get;
begin
  FScanner.Get;
end;

function TELParser.GetSym: TSymbol;
begin
  Result := FScanner.Sym;
end;

procedure TELParser.SemError(errNo: integer);
begin
  Inc(FErrorCount);
  if FErrDist >= minErrDist then
    FScanner.ScannerError(errNo, etSymantic);
  FErrDist := 0;
end;

procedure TELParser.SynError(errNo: integer);
begin
  Inc(FErrorCount);
  if FErrDist >= minErrDist then
    FScanner.ScannerError(errNo, etSyntax);
  FErrDist := 0;
end;

procedure TELParser.Error(ErrNo: integer; Typ: TErrorTypes);
begin
  // Stub. It is necessary to save the errors and
  // show them to the user at will.
end;

procedure TELParser.Expect(n: TSymbol);
begin
  if Sym = n then
    Get
  else
    SynError(Ord(n));
end;

{$EndRegion}

end.

