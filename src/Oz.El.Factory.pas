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

unit Oz.El.Factory;

interface

uses
  SysUtils, TypInfo, Rtti, Generics.Defaults, Oz.El.Ast;

{$Region 'Subroutines'}

function GetElFactory: IExpressionFactory;
procedure CloseElFactory;

{$EndRegion}

implementation

uses
  Oz.El.Scanner, Oz.El.Classes, Oz.El.Parser, Oz.El.Utils;

{$Region 'TMyModel'}

type
  TMyModel = class
  private
    FCount: Integer;
  public
    // My function
    function GetMyFunc: Integer;
    // Return count
    function GetCount: Integer;
  end;

{$EndRegion}

{$Region 'TExpressionFactory'}

  TExpressionFactory = class(TSingletonImplementation, IExpressionFactory)
  private
    class var Factory: TExpressionFactory;
    class destructor Destroy;
  private
    FContext: TELContext;
  public
    constructor Create;
    destructor Destroy; override;
    function GetContext: TELContext;
    function CreateValueExpression(const Expr: string; Node: TNode; ExpectedType: PTypeInfo): TValueExpression;
    function CreateMethodExpression(const Expr: string; ExpectedType: PTypeInfo; ParamTypes: array of PTypeInfo): TMethodExpression;
  end;

{$EndRegion}

{$Region 'TMyResolver'}

  TMyResolver = class(TElResolver)
  public
    function GetValue(Ctx: TElContext; Obj: TObject; const Prop: TValue): TValue; override;
  end;

{$EndRegion}

{$Region 'TMyContext'}

  TMyContext = class(TELContext)
  private
    FVarMap: TVariableMapper;
    FResolver: TElResolver;
  public
    constructor Create;
    destructor Destroy; override;
    function GetElResolver: TElResolver; override;
    function GetVariableMapper: TVariableMapper; override;
    function GetFunctionMapper: TFunctionMapper; override;
    // My function
    function GetMyFunc: Integer;
    // Return count
    function GetCount: Integer;
  end;

{$EndRegion}

{$Region 'TValueExpressionImpl'}

  TValueExpressionImpl = class(TValueExpression)
  private
    FExpectedType: PTypeInfo;
    FNode: TNode;
  public
    constructor Create(const Expr: string; Node: TNode; ExpectedType: PTypeInfo);
    destructor Destroy; override;
    function GetValue(Ctx: TElContext): TValue; override;
    procedure SetValue(Ctx: TElContext; Value: TValue); override;
    function IsReadOnly(Ctx: TElContext): Boolean; override;
    property ExpectedType: PTypeInfo read FExpectedType;
  end;

{$EndRegion}

{$Region 'TExpressionFactory'}

class destructor TExpressionFactory.Destroy;
begin
  FreeAndNil(Factory);
end;

constructor TExpressionFactory.Create;
begin
  inherited Create;
  FContext := TMyContext.Create;
end;

destructor TExpressionFactory.Destroy;
begin
  FContext.Free;
  inherited;
end;

function TExpressionFactory.GetContext: TElContext;
begin
  Result := FContext;
end;

function TExpressionFactory.CreateValueExpression(const Expr: string; Node: TNode; ExpectedType: PTypeInfo): TValueExpression;
begin
  Result := TValueExpressionImpl.Create(Expr, Node, ExpectedType);
end;

function TExpressionFactory.CreateMethodExpression(const Expr: string; ExpectedType: PTypeInfo; ParamTypes: array of PTypeInfo): TMethodExpression;
begin
  Result := nil;
end;

{$EndRegion}

{$Region 'TMyContext'}

constructor TMyContext.Create;
begin
  inherited Create;
  FVarMap := TVariableMapper.Create;
  FResolver := TMyResolver.Create;
end;

destructor TMyContext.Destroy;
begin
  FResolver.Free;
  FVarMap.Free;
  inherited;
end;

function TMyContext.GetElResolver: TElResolver;
begin
  Result := FResolver;
end;

function TMyContext.GetFunctionMapper: TFunctionMapper;
begin
  Result := nil;
end;

function TMyContext.GetVariableMapper: TVariableMapper;
begin
  Result := FVarMap;
end;

function TMyContext.GetMyFunc: Integer;
begin
  Result := ;
end;

function TMyContext.GetCount: Integer;
var
  Model: TMyModel;
begin
  Model := GetContext(TMyModel) as TMyModel;
  if Model = nil then
    Result := -1
  else
    Result := Model.Count;
end;

{$EndRegion}

{$Region 'TValueExpression'}

constructor TValueExpressionImpl.Create(const Expr: string; Node: TNode; ExpectedType: PTypeInfo);
begin
  inherited Create(Expr);
  FNode := Node;
  FExpectedType := ExpectedType;
end;

destructor TValueExpressionImpl.Destroy;
begin
  FNode.Free;
  inherited;
end;

function TValueExpressionImpl.GetValue(Ctx: TElContext): TValue;
begin
  if FNode = nil then
    Result := ''
  else
  begin
    Result := FNode.GetValue(Ctx);
    if ExpectedType <> nil then
      Result := VM.CoerceToType(Result, ExpectedType);
  end;
end;

function TValueExpressionImpl.IsReadOnly(Ctx: TElContext): Boolean;
begin
  Result := FNode.IsReadOnly(Ctx);
end;

procedure TValueExpressionImpl.SetValue(Ctx: TElContext; Value: TValue);
begin
  FNode.SetValue(Ctx, Value);
end;

{$EndRegion}

{$Region 'TMyResolver'}

function TMyResolver.GetValue(Ctx: TElContext; Obj: TObject; const Prop: TValue): TValue;
var
  s: string;
begin
  Result := Prop;
  if Ctx is TMyContext then
  begin
    Ctx.PropertyResolved := True;
    s := LowerCase(Prop.AsString);
    if s = 'myfunc' then
      Result := TMyContext(Ctx).GetMyFunc
    else if s = 'count' then
      Result := TMyContext(Ctx).GetCount
    else
    begin
      Ctx.PropertyResolved := False;
      Result := Prop;
    end;
  end;
end;

{$EndRegion}

{$Region 'Subroutines'}

function GetELFactory: IExpressionFactory;
begin
  Result := TExpressionFactory.Factory;
end;

procedure CreateDrawingFactory(CacheTable: TCachedExpression);
begin
  FreeAndNil(TExpressionFactory.Factory);
  TExpressionFactory.Factory.FContext.PutContext(TCachedExpression, CacheTable);
end;

procedure CloseElFactory;
begin
  FreeAndNil(TExpressionFactory.Factory);
end;

{$EndRegion}

{$Region 'TMyModel'}

function TMyModel.GetCount: Integer;
begin
  Result := FCount;
end;

function TMyModel.GetMyFunc: Integer;
begin
  Inc(FCount);
  Result := FCount;
end;

{$EndRegion}

end.

