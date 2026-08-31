unit WAEditor.Domain.AlignmentMapper;

interface

uses
  System.SysUtils,
  WAEditor.Domain.Types;

type
  /// Pure mapping between the domain alignment enum and the HTML/DOM
  /// representations used by the editing engine. Kept free of any UI or
  /// COM dependency so it can be unit tested in isolation.
  TWAAlignmentMapper = class
  public
    class function ToHtmlAttribute(AAlignment: TWATextAlignment): string; static;
    class function ToExecCommandName(AAlignment: TWATextAlignment): string; static;
    class function FromHtmlAttribute(const AValue: string): TWATextAlignment; static;
  end;

implementation

class function TWAAlignmentMapper.ToHtmlAttribute(AAlignment: TWATextAlignment): string;
begin
  case AAlignment of
    taLeftAlign: Result := 'left';
    taCenterAlign: Result := 'center';
    taRightAlign: Result := 'right';
    taJustifyAlign: Result := 'justify';
  else
    raise EWADomainValidationError.Create('Unsupported text alignment.');
  end;
end;

class function TWAAlignmentMapper.ToExecCommandName(AAlignment: TWATextAlignment): string;
begin
  case AAlignment of
    taLeftAlign: Result := 'JustifyLeft';
    taCenterAlign: Result := 'JustifyCenter';
    taRightAlign: Result := 'JustifyRight';
    taJustifyAlign: Result := 'JustifyFull';
  else
    raise EWADomainValidationError.Create('Unsupported text alignment.');
  end;
end;

class function TWAAlignmentMapper.FromHtmlAttribute(const AValue: string): TWATextAlignment;
var
  LValue: string;
begin
  LValue := LowerCase(Trim(AValue));
  if LValue = 'left' then
    Result := taLeftAlign
  else if LValue = 'center' then
    Result := taCenterAlign
  else if LValue = 'right' then
    Result := taRightAlign
  else if LValue = 'justify' then
    Result := taJustifyAlign
  else
    raise EWADomainValidationError.CreateFmt('Unrecognized HTML alignment value "%s".', [AValue]);
end;

end.
