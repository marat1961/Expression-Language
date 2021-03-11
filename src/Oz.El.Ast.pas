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

unit Oz.El.Ast;

interface

uses
  SysUtils, Classes, Generics.Collections, Rtti, TypInfo,
  Oz.El.Classes, Oz.El.Scanner, Oz.El.Utils;

type
  TNode = class;

{$Region 'TNodeVisitor'}

  TNodeVisitor = class
  public
    procedure Visit(Node: TNode); virtual; abstract;
  end;

{$EndRegion}

{$Region 'TNode: The basic type of all nodes included in the abstract syntax tree.'}

  TNode = class
  private
    FOp: TSymbol;
    FParent: TNode;
    FChildren: TObjectList<TNode>;
    FImage: string;
  public
    constructor Create(Op: TSymbol); overload;
    constructor Create(Op: TSymbol; Child: TNode); overload;
    destructor Destroy; override;
    // Returns the type of expression
    function GetType(Ctx: TELContext): PTypeInfo; virtual;
    // Get the value of expression
    function GetValue(Ctx: TELContext): TValue; virtual;
    // Set the value of expression
    procedure SetValue(Ctx: TELContext; Value: TValue); virtual;
    // Get the pointer to the object property
    function GetValueReference(Ctx: TELContext): TValueReference; virtual;
    // It is possible to use the setValue method
    function IsReadOnly(Ctx: TELContext): Boolean; virtual;
    // Support of the "Visitor" template
    procedure Accept(Visitor: TNodeVisitor); virtual;
    // Invoke method
    function Invoke(Ctx: TELContext; ParamTypes: array of TClass; ParamValues: array of TValue): TValue; virtual;
    // Get information about a method
    function GetMethodInfo(Ctx: TELContext; ParamTypes: array of TClass): TMethodInfo; virtual;
    // if there are parameters
    function IsParametersProvided: boolean; virtual;
    // Operation
    property Op: TSymbol read FOp;
    // Parent node
    property Parent: TNode read FParent;
    // Nested nodes
    property Children: TObjectList<TNode> read FChildren;
    // Visible representation
    property Image: string read FImage;
  end;

{$EndRegion}

{$Region 'TAstLiteralExpression: Constant - string, number or Boolean'}

  TAstLiteralExpression = class(TNode)
  private
    FValue: TValue;
  public
    constructor Create(Op: TSymbol; const V: TValue);
    function GetType(Ctx: TELContext): PTypeInfo; override;
    function GetValue(Ctx: TELContext): TValue; override;
    // Set visible representation
    procedure SetImage(const Image: string); virtual;
  end;

{$EndRegion}

{$Region 'TAstLiteralExpression: Variable or function identifier'}

  TAstIdentifier = class(TNode)
  public
    constructor Create(Op: TSymbol; const Ident: string);
    function GetType(Ctx: TELContext): PTypeInfo; override;
    function GetValue(Ctx: TELContext): TValue; override;
    procedure SetValue(Ctx: TELContext; Value: TValue); override;
    function IsReadOnly(Ctx: TELContext): Boolean; override;
  end;

{$EndRegion}

{$Region 'TAstBracedExpression: The expression in parentheses ident'}

  // ( '[' Expr ']' | '(' Expr, [',' Expr] ')' ) )
  TAstBracedExpression = class(TNode)
  public
    function GetType(Ctx: TELContext): PTypeInfo; override;
    function GetValue(Ctx: TELContext): TValue; override;
    procedure SetValue(Ctx: TELContext; Value: TValue); override;
    function IsReadOnly(Ctx: TELContext): Boolean; override;
  end;

{$EndRegion}

{$Region 'TAstChoice: Conditional operator - BoolExpr ? Expr1 : Expr2'}

  TAstChoice = class(TNode)
  public
    function GetType(Ctx: TELContext): PTypeInfo; override;
    function GetValue(Ctx: TELContext): TValue; override;
  end;

{$EndRegion}

{$Region 'TAstRelation: Comparison operation - Expr1 RelOp Expr2'}

  TAstRelation = class(TNode)
  public
    function GetType(Ctx: TELContext): PTypeInfo; override;
    function GetValue(Ctx: TELContext): TValue; override;
  end;

{$EndRegion}

{$Region 'TAstUnaryOp: Unary operation - [ '+' | '-' | 'empty' | 'not' ] Expr'}

  TAstUnaryOp = class(TNode)
  public
    function GetType(Ctx: TELContext): PTypeInfo; override;
    function GetValue(Ctx: TELContext): TValue; override;
  end;

{$EndRegion}

{$Region 'TAstBinaryOp: Binary operation - '+' | '-' | '*' | '/' | 'div' | 'mod' ...'}

  TAstBinaryOp = class(TNode)
  public
    function GetType(Ctx: TELContext): PTypeInfo; override;
    function GetValue(Ctx: TELContext): TValue; override;
  end;

{$EndRegion}

{$Region 'TAstCompositeExpression: Composite expression'}

  // (any combination of text and bracketed expressions ${expr})
  TAstCompositeExpression = class(TNode)
  public
    function GetType(Ctx: TELContext): PTypeInfo; override;
    function GetValue(Ctx: TELContext): TValue; override;
  end;

{$EndRegion}

{$Region 'IExpressionFactory'}

  IExpressionFactory = interface
    function GetContext: TELContext;
    function CreateValueExpression(const Expr: string; Node: TNode; ExpectedType: PTypeInfo): TValueExpression;
    function CreateMethodExpression(const Expr: string; ExpectedType: PTypeInfo; ParamTypes: array of PTypeInfo): TMethodExpression;
  end;

{$EndRegion}

{$Region 'TUserVarExpression: User variable'}

  TUserVarExpression = class(TValueExpression)
  private
    FValue: TValue;
  public
    function GetValue(Ctx: TElContext): TValue; override;
    procedure SetValue(Ctx: TElContext; Value: TValue); override;
  end;

{$EndRegion}

{$Region 'TCachedExpression: Hash table for parsed expressions'}

  TCachedExpression = class(TNodeVisitor)
  private
    FTable: TDictionary<string, TNode>;
    FIdent: record
      Name: string;
      RefCount: Integer;
    end;
  public
    constructor Create;
    destructor Destroy; override;
    // Search expression in hash table
    function FindCachedExpression(const Expr: string): TNode;
    // Put the expression into the hash table
    procedure CacheExpression(const Expr: string; Node: TNode);
    // Consistently bypass all expressions and
    // count the number of references to the identifier
    function GetRefCount(const Name: string): Integer;
    // Used by GetRefCount
    procedure Visit(Node: TNode); override;
  end;

{$EndRegion}

implementation

uses
  Oz.El.Factory;

{$Region 'TNode'}

constructor TNode.Create(Op: TSymbol);
begin
  inherited Create;
  FChildren := TObjectList<TNode>.Create(True);
  FOp := Op;
end;

constructor TNode.Create(Op: TSymbol; Child: TNode);
begin
  Create(Op);
  Children.Add(Child);
end;

destructor TNode.Destroy;
begin
  FChildren.Free;
  inherited;
end;

function TNode.GetType(Ctx: TELContext): PTypeInfo;
begin
  raise Exception.Create('Unsupported operation');
end;

function TNode.GetValue(Ctx: TELContext): TValue;
begin
  raise Exception.Create('Unsupported Operation');
end;

procedure TNode.SetValue(Ctx: TELContext; Value: TValue);
begin
  raise Exception.Create('Property not writable');
end;

function TNode.GetValueReference(Ctx: TELContext): TValueReference;
begin
  Result := nil;
end;

function TNode.IsReadOnly(Ctx: TELContext): Boolean;
begin
  Result := True;
end;

procedure TNode.Accept(Visitor: TNodeVisitor);
var
  i: Integer;
begin
  Visitor.Visit(Self);
  if Children <> nil then
    for i := 0 to Children.Count - 1 do
      Children[i].Accept(Visitor);
end;

function TNode.GetMethodInfo(Ctx: TELContext; ParamTypes: array of TClass): TMethodInfo;
begin
  raise Exception.Create('Unsupported Operation');
end;

function TNode.Invoke(Ctx: TELContext; ParamTypes: array of TClass; ParamValues: array of TValue): TValue;
begin
  raise Exception.Create('Unsupported Operation');
end;

function TNode.IsParametersProvided: boolean;
begin
  Result := False;
end;

{$EndRegion}

{$Region 'TAstCompositeExpression'}

function TAstCompositeExpression.GetType(Ctx: TELContext): PTypeInfo;
begin
  Result := TypeInfo(string);
end;

function TAstCompositeExpression.GetValue(Ctx: TELContext): TValue;
var
  Sb: TStringBuilder;
  V: TValue;
  i: Integer;
begin
  Sb := TStringBuilder.Create;
  try
    if Children <> nil then
      for i := 0 to Children.Count - 1 do
      begin
        V := Children[i].GetValue(Ctx);
        Sb.Append(VM.CoerceToString(V));
      end;
    Result := Sb.ToString;
  finally
    Sb.Free;
  end;
end;

{$EndRegion}

{$Region 'TAstLiteralExpression'}

constructor TAstLiteralExpression.Create(Op: TSymbol; const V: TValue);
var
  s: string;
begin
  inherited Create(Op);
  FValue := V;
  case Op of
    IntSym:
      s := IntToStr(V.AsOrdinal);
    DoubleSym:
      s := FloatToStr(V.AsExtended);
    OrSym, AndSym:
      if V.AsBoolean then s := 'True' else s := 'False';
     EmptySym:
      s := 'empty';
     NullSym:
      s := 'null';
    else
      s := V.AsString;
  end;
  SetImage(s);
end;

function TAstLiteralExpression.GetType(Ctx: TELContext): PTypeInfo;
begin
  Result := FValue.TypeInfo;
end;

function TAstLiteralExpression.GetValue(Ctx: TELContext): TValue;
begin
  if Op in [IntSym, DoubleSym, OrSym, AndSym] then
    Result := FValue
  else
    Result := FImage;
end;

procedure TAstLiteralExpression.SetImage(const Image: string);
var
  i, Size: Integer;
  Sb: TStringBuilder;
  C, C1, C2: Char;
begin
  if Pos('\', Image) = 0 then
    FImage := Image
  else
  begin
    Size := Length(Image);
    Sb := TStringBuilder.Create(Size);
    try
      i := 0;
      while I < Size do
      begin
        C := Image.Chars[i];
        if (C = '\') and (i + 2 < Size) then
        begin
          C1 := Image.Chars[i + 1];
          C2 := Image.Chars[i + 2];
          if ((C1 = '#') or (C1 = '$')) and (C2 = '{') then
          begin
            C := C1;
            Inc(i);
          end;
        end;
        Sb.Append(c);
        Inc(i);
      end;
      FImage := Sb.ToString;
    finally
      Sb.Free;
    end;
  end;
end;

{$EndRegion}

{$Region 'TAstBracedExpression'}

function TAstBracedExpression.GetType(Ctx: TELContext): PTypeInfo;
begin
  Result := Children[0].GetType(Ctx);
end;

function TAstBracedExpression.GetValue(Ctx: TELContext): TValue;
begin
  Result := Children[0].GetValue(Ctx);
end;

function TAstBracedExpression.IsReadOnly(Ctx: TELContext): Boolean;
begin
  Result := Children[0].IsReadOnly(Ctx);
end;

procedure TAstBracedExpression.SetValue(Ctx: TELContext; Value: TValue);
begin
  Children[0].SetValue(Ctx, Value);
end;

{$EndRegion}

{$Region 'TAstChoice'}

function TAstChoice.GetType(Ctx: TELContext): PTypeInfo;
var
  V: TValue;
begin
  V := GetValue(Ctx);
  if V.IsEmpty then
    Result := nil
  else
    Result := V.TypeInfo;
end;

function TAstChoice.GetValue(Ctx: TELContext): TValue;
var Obj: TValue; BoolExpr: Boolean;
begin
  Obj := Children[0].GetValue(Ctx);
  BoolExpr := VM.CoerceToBoolean(Obj);
  if BoolExpr then
    Result := Children[1].GetValue(Ctx)
  else
    Result := Children[2].GetValue(Ctx);
end;

{$EndRegion}

{$Region 'TAstRelation'}

function TAstRelation.GetType(Ctx: TELContext): PTypeInfo;
begin
  Result := GetValue(Ctx).TypeInfo;
end;

function TAstRelation.GetValue(Ctx: TELContext): TValue;
var
  X, Y: TValue;
begin
  X := Children[0].GetValue(Ctx);
  Y := Children[1].GetValue(Ctx);
  if X.IsEmpty or Y.IsEmpty then
    Result := False
  else
    case Op of
      GtSym:
        Result := VM.Compare(X, Y) > 0;
      LtSym:
        Result := VM.Compare(X, Y) < 0;
      GeSym:
        Result := VM.Compare(X, Y) >= 0;
      LeSym:
        Result := VM.Compare(X, Y) <= 0;
      EqSym:
        Result := VM.Compare(X, Y) = 0;
      NeSym:
        Result := VM.Compare(X, Y) <> 0;
    end;
end;

{$EndRegion}

{$Region 'TAstUnaryOp'}

function TAstUnaryOp.GetType(Ctx: TELContext): PTypeInfo;
var
  V: TValue;
begin
  V := GetValue(Ctx);
  if V.IsEmpty then
    Result := nil
  else
    Result := V.TypeInfo;
end;

function TAstUnaryOp.GetValue(Ctx: TELContext): TValue;
var
  V: TValue;
begin
  V := Children[0].GetValue(Ctx);
  if Op = EmptySym then
    Result := VM.Empty(V)
  else if op = MinusSym then
    Result := VM.Negate(V)
end;

{$EndRegion}

{$Region 'TAstBinaryOp'}

function TAstBinaryOp.GetType(Ctx: TELContext): PTypeInfo;
begin
  Result := GetValue(Ctx).TypeInfo;
end;

function TAstBinaryOp.GetValue(Ctx: TELContext): TValue;
var
  X, Y: TValue;
begin
  X := Children[0].GetValue(Ctx);
  Y := Children[1].GetValue(Ctx);
  case Op of
    StarSym:
      Result := VM.Multiply(X, Y);
    DivSym:
      Result := VM.Divide(X, Y);
    ModSym:
      Result := VM.Modulo(X, Y);
    PlusSym:
      Result := VM.Add(X, Y);
    MinusSym:
      Result := VM.Subtract(X, Y);
    AndSym:
      Result := VM.Conjunction(X, Y);
    OrSym:
      Result := VM.Disjunction(X, Y);
  end;
end;

{$EndRegion}

{$Region 'TAstIdentifier'}

constructor TAstIdentifier.Create(Op: TSymbol; const Ident: string);
begin
  inherited Create(Op);
  FImage := Ident;
end;

function TAstIdentifier.GetType(Ctx: TELContext): PTypeInfo;
begin
  Result := GetValue(Ctx).TypeInfo;
end;

function TAstIdentifier.GetValue(Ctx: TELContext): TValue;
var
  Map: TVariableMapper;
  Expr: TValueExpression;
begin
  Map := Ctx.GetVariableMapper;
  if Map <> nil then
  begin
    Expr := Map.ResolveVariable(Image);
    if Expr <> nil then
    begin
      Result := Expr.GetValue(Ctx);
      exit;
    end;
  end;
  Ctx.PropertyResolved := False;
  Result := Ctx.GetElResolver.GetValue(Ctx, nil, Image);
  if not Ctx.PropertyResolved then
  begin
    // If no identifier is found - add a user variable
    Expr := TUserVarExpression.Create(Image);
    Map.SetVariable(Image, Expr);
    Result := '';
  end;
end;

function TAstIdentifier.IsReadOnly(Ctx: TELContext): Boolean;
var
  VarMapper: TVariableMapper;
  Expr: TValueExpression;
begin
  VarMapper := Ctx.GetVariableMapper;
  if VarMapper <> nil then
  begin
    Expr := VarMapper.ResolveVariable(Image);
    if Expr <> nil then
    begin
      Result := Expr.IsReadOnly(Ctx);
      exit;
    end;
  end;
  Ctx.PropertyResolved := False;
  Result := Ctx.GetElResolver.isReadOnly(Ctx, nil) and Ctx.PropertyResolved;
end;

procedure TAstIdentifier.SetValue(Ctx: TELContext; Value: TValue);
var
  VarMapper: TVariableMapper;
  Expr: TValueExpression;
begin
  VarMapper := Ctx.GetVariableMapper;
  if VarMapper <> nil then
  begin
    Expr := VarMapper.ResolveVariable(Image);
    if Expr <> nil then
      Expr.SetValue(Ctx, Value);
  end;
  Ctx.GetElResolver.SetValue(Ctx, nil, Image, Value);
end;

{$EndRegion}

{$Region 'TCachedExpression'}

constructor TCachedExpression.Create;
begin
  inherited;
  FTable := TDictionary<string, TNode>.Create;
end;

destructor TCachedExpression.Destroy;
var
  Item: TPair<string, TNode>;
begin
  for Item in FTable do
    Item.Value.Free;
  FTable.Free;
  inherited;
end;

procedure TCachedExpression.CacheExpression(const Expr: string; Node: TNode);
begin
  FTable.AddOrSetValue(Expr, Node);
end;

function TCachedExpression.FindCachedExpression(const Expr: string): TNode;
begin
  if not FTable.TryGetValue(Expr, Result) then
    Result := nil;
end;

function TCachedExpression.GetRefCount(const Name: string): Integer;
var
  Item: TPair<string, TNode>;
  ExprRoot: TNode;
  Expr: string;
begin
  FIdent.RefCount := 0;
  FIdent.Name := Name;
  for Item in FTable do
  begin
    Expr := Item.Key;
    ExprRoot := Item.Value;
    ExprRoot.Accept(Self);
  end;
  Result := FIdent.RefCount;
end;

procedure TCachedExpression.Visit(Node: TNode);
begin
  if (Node is TAstIdentifier) and (Node.Image = FIdent.Name) then
    Inc(FIdent.RefCount);
end;

{$EndRegion}

{$Region 'TUserVarExpression'}

function TUserVarExpression.GetValue(Ctx: TElContext): TValue;
begin
  Result := FValue;
end;

procedure TUserVarExpression.SetValue(Ctx: TElContext; Value: TValue);
begin
  FValue := Value;
end;

{$EndRegion}

end.

