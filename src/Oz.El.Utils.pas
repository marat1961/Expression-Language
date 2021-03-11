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

unit Oz.El.Utils;

interface

uses
  SysUtils, Rtti, TypInfo;

{$Region 'VM: Virtual machine'}

type

  VM = class sealed
  public type
    TValueType = (vtNull, vtString, vtBoolean, vtInteger, vtDouble, vtOther);
  public
    // Get the type of the value
    class function GetTValueType(const V: TValue): TValueType;
    // Is the value is a boolean type
    class function IsBoolean(const V: TValue): Boolean;
    // Is the value an enumerated type
    class function IsEnum(const V: TValue): Boolean;
    // Cast to Boolean
    class function CoerceToBoolean(const V: TValue): Boolean;
    // Cast to an integer
    class function CoerceToInteger(const V: TValue): Int64;
    // Cast to floating number
    class function CoerceToDouble(const V: TValue): Extended;
    // Cast to Enum
    class function CoerceToEnum(const V: TValue): Integer;
    // Cast to a string
    class function CoerceToString(const V: TValue): string;
    // Ñast to a number (integer or floating point)
    class function CoerceToNumber(const V: TValue): TValue;
    // Ñreation to the specified type
    class function CoerceToType(const V: TValue; const ExpectedType: PTypeInfo): TValue;
    // Comparison
    class function Equals(const A, B: TValue): Boolean; reintroduce;
    class function Compare(const A, B: TValue): Integer; overload;
    class function Compare(A, B: Int64): Integer; overload;
    class function Compare(A, B: Extended): Integer; overload;
    // Operand type definition
    class function IsBooleanOp(const A, B: TValue): Boolean;
    class function IsIntegerOp(const A, B: TValue): Boolean;
    class function IsExtendedOp(const A, B: TValue): Boolean;
    class function IsStringOp(const A, B: TValue): Boolean;
    class function IsEnumOp(const A, B: TValue): Boolean;
  public
    // Result := A + B
    class function Add(const A, B: TValue): TValue;
    // Result := A - B
    class function Subtract(const A, B: TValue): TValue;
    // Result := A * B
    class function Multiply(const A, B: TValue): TValue;
    // Result := A / B
    class function Divide(const A, B: TValue): TValue;
    // Result := A mod B
    class function Modulo(const A, B: TValue): TValue;
    // Result := A and B
    class function Conjunction(const A, B: TValue): TValue;
    // Result := A or B
    class function Disjunction(const A, B: TValue): TValue;
    // Result := Empty V
    class function Empty(const V: TValue): TValue;
    // Result := - V
    class function Negate(const V: TValue): TValue;
  end;

implementation

class function VM.GetTValueType(const V: TValue): TValueType;
begin
  if V.IsEmpty then exit(vtNull);
  Result := vtOther;
  case V.Kind of
    tkInteger, tkInt64, tkChar, tkWChar:
      Result := vtInteger;
    tkLString, tkWString, tkUString, tkString:
      Result := vtString;
    tkFloat:
      Result := vtDouble;
    tkEnumeration:
      if V.TypeInfo = TypeInfo(Boolean) then
        Result := vtBoolean;
  end;
end;

class function VM.IsBoolean(const V: TValue): Boolean;
begin
  Result := (not V.IsEmpty) and (V.TypeInfo = System.TypeInfo(Boolean));
end;

class function VM.isEnum(const V: TValue): Boolean;
begin
  Result := not V.IsEmpty and (V.Kind = tkEnumeration);
end;

class function VM.CoerceToBoolean(const V: TValue): Boolean;
begin
  case GetTValueType(V) of
    vtBoolean:
      Result := V.AsBoolean;
    vtString:
      Result := LowerCase(V.AsString) = 'true';
    else
      Result := False
  end;
end;

class function VM.CoerceToEnum(const V: TValue): Integer;
begin
  case GetTValueType(V) of
    vtString:
      Result := StrToIntDef(V.AsString, 0);
    vtBoolean:
      Result := Ord(V.AsBoolean);
    vtInteger:
      Result := V.AsInt64;
    vtDouble:
      Result := Round(V.AsExtended);
    else
      Result := 0;
  end;
end;

class function VM.CoerceToInteger(const V: TValue): Int64;
begin
  case GetTValueType(V) of
    vtString:
      Result := StrToIntDef(V.AsString, 0);
    vtBoolean, vtInteger:
      Result := V.AsInt64;
    vtDouble:
      Result := Round(V.AsExtended);
    else
      Result := 0;
  end;
end;

class function VM.CoerceToDouble(const V: TValue): Extended;
begin
  case GetTValueType(V) of
    vtString:
      Result := StrToFloatDef(V.AsString, 0);
    vtBoolean, vtInteger:
      Result := V.AsInt64;
    vtDouble:
      Result := V.AsExtended;
    else
      Result := 0;
  end;
end;

class function VM.CoerceToNumber(const V: TValue): TValue;
var
  s: string;
begin
  case GetTValueType(V) of
    vtNull:
      Result := 0;
    vtInteger:
      Result := V.AsInt64;
    vtDouble:
      Result := V.AsExtended;
    vtString:
      begin
        s := V.AsString;
        if Pos('.', s) = 0 then
          Result := StrToInt64Def(s, 0)
        else
          Result := StrToFloatDef(s, 0);
      end;
    else
      raise Exception.Create('error.CoerceToNumber');
  end;
end;

class function VM.CoerceToString(const V: TValue): string;
begin
  if V.IsEmpty then
    Result := ''
  else
    case V.Kind of
      tkInteger, tkInt64, tkChar, tkWChar:
        Result := IntToStr(V.AsInt64);
      tkLString, tkWString, tkUString, tkString:
        Result := V.AsString;
      tkFloat:
        Result := FloatToStr(V.AsExtended);
      tkEnumeration:
        if V.TypeInfo <> TypeInfo(Boolean) then
          Result := Format('%s(%d)', [V.TypeInfo.Name, V.AsInt64])
        else if V.AsBoolean then
          Result := 'true'
        else
          Result := 'false';
    end;
end;

class function VM.CoerceToType(const V: TValue; const ExpectedType: PTypeInfo): TValue;
begin
  Result := V.Cast(ExpectedType);
end;

class function VM.Compare(A, B: Extended): Integer;
begin
  if A > B then
    Result := -1
  else if A < B then
    Result := 1
  else
    Result := 0;
end;

class function VM.Compare(A, B: Int64): Integer;
begin
  if A > B then
    Result := -1
  else if A < B then
    Result := 1
  else
    Result := 0;
end;

class function VM.Compare(const A, B: TValue): Integer;
begin
  // Compare two objects after converting them to the same type.
  // If one of the objects is an integer, then the second object is converted to an integer type.
  // The same for other types.
  if Equals(A, B) then
    Result := 0
  else if IsBooleanOp(A, B) then
    Result := Compare(A.AsBoolean, B.AsBoolean)
  else if IsEnumOp(A, B) then
    Result := Compare(A.AsInt64, B.AsInt64)
  else if IsIntegerOp(A, B) then
    Result := Compare(A.AsInt64, B.AsInt64)
  else if IsExtendedOp(A, B) then
    Result := Compare(A.AsExtended, B.AsExtended)
  else if IsStringOp(A, B) then
    Result := Compare(A.AsString, B.AsString)
  else
    raise Exception.Create('error.compare');
end;

class function VM.Equals(const A, B: TValue): Boolean;
begin
  if @A = @B then
    Result := True
  else if A.IsEmpty or B.IsEmpty then
    Result := False
  else if IsExtendedOp(A, B) then
    Result := CoerceToDouble(A) = CoerceToDouble(B)
  else if IsBooleanOp(A, B) then
    Result := CoerceToBoolean(A) = CoerceToBoolean(B)
  else if IsEnumOp(A, B) then
    Result := CoerceToEnum(A) = CoerceToEnum(B)
  else if IsIntegerOp(A, B) then
    Result := CoerceToInteger(A) = CoerceToInteger(B)
  else if IsStringOp(A, B) then
    Result := CoerceToString(A) = CoerceToString(B)
  else
    Result := False;
end;

class function VM.IsBooleanOp(const A, B: TValue): Boolean;
begin
  Result := IsBoolean(A) or IsBoolean(B);
end;

class function VM.IsEnumOp(const A, B: TValue): Boolean;
begin
  Result := IsEnum(A) or IsEnum(B);
end;

class function VM.IsExtendedOp(const A, B: TValue): Boolean;
begin
  Result := (GetTValueType(A) = vtDouble) or (GetTValueType(B) = vtDouble);
end;

class function VM.IsIntegerOp(const A, B: TValue): Boolean;
begin
  Result := (GetTValueType(A) = vtInteger) or (GetTValueType(B) = vtInteger);
end;

class function VM.IsStringOp(const A, B: TValue): Boolean;
begin
  Result := (GetTValueType(A) = vtString) or (GetTValueType(B) = vtString);
end;

class function VM.Add(const A, B: TValue): TValue;
var
  X, Y: TValue;
begin
  if A.IsEmpty and B.IsEmpty then
    Result := 0
  else
  begin
    X := CoerceToNumber(A);
    Y := CoerceToNumber(B);
    if IsExtendedOp(X, Y) then
      Result := X.AsExtended + Y.AsExtended
    else
      Result := X.AsInt64 + Y.AsInt64;
  end;
end;

class function VM.Subtract(const A, B: TValue): TValue;
var
  X, Y: TValue;
begin
  if A.IsEmpty and B.IsEmpty then
    Result := 0
  else
  begin
    X := CoerceToNumber(A);
    Y := CoerceToNumber(B);
    if IsExtendedOp(X, Y) then
      Result := X.AsExtended - Y.AsExtended
    else
      Result := X.AsInt64 - Y.AsInt64;
  end;
end;

class function VM.Multiply(const A, B: TValue): TValue;
var
  X, Y: TValue;
begin
  if A.IsEmpty and B.IsEmpty then
    Result := 0
  else
  begin
    X := CoerceToNumber(A);
    Y := CoerceToNumber(B);
    if IsExtendedOp(X, Y) then
      Result := X.AsExtended * Y.AsExtended
    else
      Result := X.AsInt64 * Y.AsInt64;
  end;
end;

class function VM.Divide(const A, B: TValue): TValue;
var
  X, Y: TValue;
begin
  if A.IsEmpty and B.IsEmpty then
    Result := 0
  else
  begin
    X := CoerceToNumber(A);
    Y := CoerceToNumber(B);
    if IsExtendedOp(X, Y) then
      Result := X.AsExtended / Y.AsExtended
    else
      Result := X.AsInt64 div Y.AsInt64;
  end;
end;

class function VM.Modulo(const A, B: TValue): TValue;
var
  X, Y: TValue;
  N, D: Extended;
begin
  if A.IsEmpty and B.IsEmpty then
    Result := 0
  else
  begin
    X := CoerceToNumber(A);
    Y := CoerceToNumber(B);
    if VM.IsExtendedOp(A, B) then
    begin
      N := X.AsExtended; D := Y.AsExtended;
      Result := N - D * Trunc(N / D);
    end
    else
      Result := X.AsInt64 div B.AsInt64;
  end
end;

class function VM.Conjunction(const A, B: TValue): TValue;
begin
  if not CoerceToBoolean(A) then
    Result := False
  else
    Result := CoerceToBoolean(A);
end;

class function VM.Disjunction(const A, B: TValue): TValue;
begin
  if CoerceToBoolean(A) then
    Result := True
  else
    Result := CoerceToBoolean(A);
end;

class function VM.Empty(const V: TValue): TValue;
begin
  case GetTValueType(V) of
    vtNull:
      Result := True;
    vtString:
      Result := V.AsString.Length = 0;
    else
      Result := False;
  end;
end;

class function VM.Negate(const V: TValue): TValue;
begin
  case GetTValueType(V) of
    vtNull:
      Result := 0;
    vtInteger:
      Result := -V.AsInt64;
    vtDouble:
      Result := -V.AsExtended;
    vtString:
      begin
        Result := CoerceToNumber(V);
        if Result.Kind = tkFloat then
          Result := -Result.AsExtended
        else
          Result := -Result.AsInt64;
      end;
    else
      raise Exception.Create('unary minus');
  end;
end;

end.

