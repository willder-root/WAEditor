unit WAEditor.Domain.FontSizeScale;

interface

type
  /// Maps a font size expressed in points to the closest legacy HTML
  /// <font size="1".."7"> scale used by the execCommand('FontSize', ...)
  /// call that browser engines (including MSHTML/Trident) still honor.
  /// Kept as a pure function so the size buckets are unit testable
  /// independently of the COM-based editing engine that consumes them.
  TWAFontSizeScale = class
  public
    class function ToHtmlLegacySize(APointSize: Integer): Integer; static;
  end;

implementation

uses
  WAEditor.Domain.Types;

class function TWAFontSizeScale.ToHtmlLegacySize(APointSize: Integer): Integer;
begin
  if (APointSize < WA_MIN_FONT_SIZE) or (APointSize > WA_MAX_FONT_SIZE) then
    raise EWADomainValidationError.CreateFmt(
      'Font size must be between %d and %d points.', [WA_MIN_FONT_SIZE, WA_MAX_FONT_SIZE]);

  if APointSize <= 8 then
    Result := 1
  else if APointSize <= 10 then
    Result := 2
  else if APointSize <= 12 then
    Result := 3
  else if APointSize <= 14 then
    Result := 4
  else if APointSize <= 18 then
    Result := 5
  else if APointSize <= 24 then
    Result := 6
  else
    Result := 7;
end;

end.
