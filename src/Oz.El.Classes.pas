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

unit Oz.El.Classes;

interface

uses
  Classes, SysUtils, Rtti, TypInfo, Generics.Collections, Generics.Defaults;

type
  TELContext = class;

{$Region 'TValueReference: Encapsulation of the base model of an object and its properties'}

  TValueReference = class
  private
    FObj: TObject;
    FProp: Pointer;
  public
    // The object
    property Obj: TObject read FObj;
    // Pointer to the structure describing the field
    property Prop: Pointer read FProp;
  end;

{$EndRegion}

{$Region 'TMethodInfo: Encapsulation of the base model of an object and its method'}

  TMethodInfo = class
  private
    FObj: TObject;
    FMethod: Pointer;
  public
    // The object
    property Obj: TObject read FObj;
    // Pointer to the structure describing the method
    property Method: Pointer read FMethod;
  end;

{$EndRegion}

{$Region 'TExpression: Expression (method or variable)'}

  TExpression  = class
  private
    FExpr: string;
  public
    constructor Create(const aExpressionString: string);
    // Get a string representation of the expression
    function GetExpressionString: string;
  end;

{$EndRegion}

{$Region 'TValueExpression: Expression, the value of which can be obtained or set'}

  TValueExpression = class(TExpression)
  public
    function GetValue(Ctx: TElContext): TValue; virtual; abstract;
    procedure SetValue(Ctx: TElContext; Value: TValue); virtual;
    function GetType(Ctx: TElContext): PTypeInfo; virtual;
    function IsReadOnly(Ctx: TElContext): boolean; virtual;
  end;

{$EndRegion}

{$Region 'TMethodExpression: Function'}

  TMethodExpression  = class(TExpression)
  public
    // Get information about the method signature
    function GetMethodInfo(Ctx: TElContext): TMethodInfo; virtual; abstract;
    function GetValue(Ctx: TElContext): TValue; virtual; abstract;
    procedure SetValue(Ctx: TElContext; Value: TValue); virtual; abstract;
    function IsReadOnly(Ctx: TElContext; Obj: TObject): boolean; virtual; abstract;
  end;

{$EndRegion}

{$Region 'TVariableMapper: List of variables (used when parsing an expression)'}

  TVariableMapper = class
  private
    FMap: TDictionary<string, TValueExpression>;
  public
    constructor Create;
    destructor Destroy; override;
    // Find a variable
    function ResolveVariable(const Variable: string): TValueExpression;
    // Set the variable value
    procedure SetVariable(const Variable: string; Expression: TValueExpression);
    // Dictionary
    property Map: TDictionary<string, TValueExpression> read FMap;
  end;

{$EndRegion}

{$Region 'TFunctionMapper: List of functions (used when parsing an expression)'}

  TFunctionMapper = class
  private
    FMap: TDictionary<string, TMethodExpression>;
  public
    constructor Create;
    destructor Destroy; override;
    function ResolveFunction(const Prefix, LocalName: string): TMethodExpression;
    procedure AddFunction(const Prefix, LocalName: string; Method: TMethodExpression);
  end;

{$EndRegion}

{$Region 'TElResolver'}

  // Tries to get or set the property value
  // If the attempt was successful - sets the Ctx.PropertyResolved property  TElResolver = class
  TElResolver = class
  public
    // Get the value of the object property
    function GetValue(Ctx: TElContext; Obj: TObject; const Prop: TValue): TValue; virtual; abstract;
    // Set the object property
    procedure SetValue(Ctx: TElContext; Obj: TObject; const Prop: TValue; Value: TValue); virtual;
    // Can the setValue method be used
    function IsReadOnly(Ctx: TElContext; Obj: TObject): boolean; virtual;
    // Returns the type of the property
    function GetCommonPropertyType(Ctx: TElContext; Obj: TObject): PTypeInfo; virtual;
  end;

{$EndRegion}

{$Region 'TElContext: Context for calculating expressions'}

  TElContext = class(TSingletonImplementation)
  private
    FPropertyResolved: Boolean;
    FContextObjects: TDictionary<TCLass, TObject>;
  public
    constructor Create;
    destructor Destroy; override;
    // Get Expression Resolver
    function GetElResolver: TElResolver; virtual;
    // Get Variable Mapper
    function GetVariableMapper: TVariableMapper; virtual;
    // GetFunction Mapper; virtual; //GetFunction Mapper
    function GetFunctionMapper: TFunctionMapper; virtual;
    // Put into a context some object necessary for Expression Resolver to work
    procedure PutContext(Key: TCLass; ContextObject: TObject); virtual;
    // Put into a context an object necessary for Expression Resolver to work
    function GetContext(Key: TCLass): TObject; virtual;
    // Property or identifier was not found
    property PropertyResolved: Boolean read FPropertyResolved write FPropertyResolved;
  end;

{$EndRegion}

implementation

{$Region 'TExpression'}

constructor TExpression.Create(const aExpressionString: string);
begin
  inherited Create;
  FExpr := aExpressionString;
end;

function TExpression.GetExpressionString: string;
begin
  Result := FExpr;
end;

{$EndRegion}

{$Region 'TValueExpression'}

function TValueExpression.GetType(Ctx: TElContext): PTypeInfo;
begin
  Result := GetValue(Ctx).TypeInfo;
end;

function TValueExpression.IsReadOnly(Ctx: TElContext): boolean;
begin
  Result := True;
end;

procedure TValueExpression.SetValue(Ctx: TElContext; Value: TValue);
begin
  raise Exception.Create('Unsupported method');
end;

{$EndRegion}

{$Region 'TVariableMapper'}

constructor TVariableMapper.Create;
begin
  inherited;
  FMap := TDictionary<string, TValueExpression>.Create;
end;

destructor TVariableMapper.Destroy;
var Item: TPair<string, TValueExpression>;
begin
  for Item in FMap do
    Item.Value.Free;
  FMap.Free;
  inherited;
end;

function TVariableMapper.ResolveVariable(const Variable: string): TValueExpression;
var R: TValueExpression;
begin
  if FMap.TryGetValue(Variable, R) then
    Result := R
  else
    Result := nil;
end;

procedure TVariableMapper.SetVariable(const Variable: string; Expression: TValueExpression);
begin
  if Expression = nil then
    raise Exception.Create('SetVariable: Expression = nil');
  FMap.AddOrSetValue(Variable, Expression);
end;

{$EndRegion}

{$Region 'TFunctionMapper'}

constructor TFunctionMapper.Create;
begin
  inherited;
  FMap := TDictionary<string, TMethodExpression>.Create;
end;

destructor TFunctionMapper.Destroy;
var Item: TPair<string, TMethodExpression>;
begin
  for Item in FMap do Item.Value.Free;
  FMap.Free;
  inherited;
end;

procedure TFunctionMapper.AddFunction(const Prefix, LocalName: string; Method: TMethodExpression);
begin
  FMap.Add(Prefix + ':' +  LocalName, Method);
end;

function TFunctionMapper.ResolveFunction(const Prefix, LocalName: string): TMethodExpression;
var
  R: TMethodExpression;
begin
  if FMap.TryGetValue(Prefix + ':' +  LocalName, R) then
    Result := R
  else
    Result := nil;
end;

{$EndRegion}

{$Region 'TElContext'}

constructor TElContext.Create;
begin
  inherited Create;
  FContextObjects := TDictionary<TCLass, TObject>.Create;
end;

destructor TElContext.Destroy;
begin
  FContextObjects.Free;
  inherited;
end;

function TElContext.GetElResolver: TElResolver;
begin
  Result := nil;
end;

function TElContext.GetFunctionMapper: TFunctionMapper;
begin
  Result := nil;
end;

function TElContext.GetVariableMapper: TVariableMapper;
begin
  Result := nil;
end;

function TElContext.GetContext(Key: TCLass): TObject;
begin
  if not FContextObjects.TryGetValue(Key, Result) then
    raise Exception.CreateFmt('GetContext: there is no object detected in the context %s', [Key.ClassName]);
end;

procedure TElContext.PutContext(Key: TCLass; ContextObject: TObject);
begin
  FContextObjects.AddOrSetValue(Key, ContextObject);
end;

{$EndRegion}

{$Region 'TElResolver'}

function TElResolver.GetCommonPropertyType(Ctx: TElContext; Obj: TObject): PTypeInfo;
begin
  Result := nil;
end;

function TElResolver.IsReadOnly(Ctx: TElContext; Obj: TObject): boolean;
begin
  Result := True;
end;

procedure TElResolver.SetValue(Ctx: TElContext; Obj: TObject; const Prop: TValue; Value: TValue);
begin
  raise Exception.Create('Unsupported method');
end;

{$EndRegion}

end.

