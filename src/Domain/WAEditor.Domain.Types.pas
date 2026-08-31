unit WAEditor.Domain.Types;

{$M+}

interface

uses
  System.SysUtils;

type
  EWADomainValidationError = class(Exception);

  TWATextAlignment = (taLeftAlign, taCenterAlign, taRightAlign, taJustifyAlign);

  TWAFontSpec = record
  private
    FName: string;
    FSizeInPoints: Integer;
  public
    class function Create(const AName: string; ASizeInPoints: Integer): TWAFontSpec; static;
    function IsValid: Boolean;
    procedure Validate;
    property Name: string read FName;
    property SizeInPoints: Integer read FSizeInPoints;
  end;

  TWATableSpec = record
  private
    FRowCount: Integer;
    FColumnCount: Integer;
    FBorderWidth: Integer;
  public
    class function Create(ARowCount, AColumnCount: Integer;
      ABorderWidth: Integer = 1): TWATableSpec; static;
    function IsValid: Boolean;
    procedure Validate;
    property RowCount: Integer read FRowCount;
    property ColumnCount: Integer read FColumnCount;
    property BorderWidth: Integer read FBorderWidth;
  end;

const
  WA_MIN_FONT_SIZE = 1;
  WA_MAX_FONT_SIZE = 409;
  WA_MIN_TABLE_DIMENSION = 1;
  WA_MAX_TABLE_DIMENSION = 100;

implementation

{ TWAFontSpec }

class function TWAFontSpec.Create(const AName: string; ASizeInPoints: Integer): TWAFontSpec;
begin
  Result.FName := AName;
  Result.FSizeInPoints := ASizeInPoints;
  Result.Validate;
end;

function TWAFontSpec.IsValid: Boolean;
begin
  Result := (Trim(FName) <> '') and
    (FSizeInPoints >= WA_MIN_FONT_SIZE) and (FSizeInPoints <= WA_MAX_FONT_SIZE);
end;

procedure TWAFontSpec.Validate;
begin
  if Trim(FName) = '' then
    raise EWADomainValidationError.Create('Font name must not be empty.');
  if (FSizeInPoints < WA_MIN_FONT_SIZE) or (FSizeInPoints > WA_MAX_FONT_SIZE) then
    raise EWADomainValidationError.CreateFmt(
      'Font size must be between %d and %d points.', [WA_MIN_FONT_SIZE, WA_MAX_FONT_SIZE]);
end;

{ TWATableSpec }

class function TWATableSpec.Create(ARowCount, AColumnCount: Integer;
  ABorderWidth: Integer): TWATableSpec;
begin
  Result.FRowCount := ARowCount;
  Result.FColumnCount := AColumnCount;
  Result.FBorderWidth := ABorderWidth;
  Result.Validate;
end;

function TWATableSpec.IsValid: Boolean;
begin
  Result :=
    (FRowCount >= WA_MIN_TABLE_DIMENSION) and (FRowCount <= WA_MAX_TABLE_DIMENSION) and
    (FColumnCount >= WA_MIN_TABLE_DIMENSION) and (FColumnCount <= WA_MAX_TABLE_DIMENSION) and
    (FBorderWidth >= 0);
end;

procedure TWATableSpec.Validate;
begin
  if (FRowCount < WA_MIN_TABLE_DIMENSION) or (FRowCount > WA_MAX_TABLE_DIMENSION) then
    raise EWADomainValidationError.CreateFmt(
      'Table row count must be between %d and %d.',
      [WA_MIN_TABLE_DIMENSION, WA_MAX_TABLE_DIMENSION]);
  if (FColumnCount < WA_MIN_TABLE_DIMENSION) or (FColumnCount > WA_MAX_TABLE_DIMENSION) then
    raise EWADomainValidationError.CreateFmt(
      'Table column count must be between %d and %d.',
      [WA_MIN_TABLE_DIMENSION, WA_MAX_TABLE_DIMENSION]);
  if FBorderWidth < 0 then
    raise EWADomainValidationError.Create('Table border width must not be negative.');
end;

end.
