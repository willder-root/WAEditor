unit WAEditor.Application.Commands.SetFontSizeCommand;

interface

uses
  WAEditor.Application.ICommand,
  WAEditor.Application.IHtmlEditorEngine;

type
  TWASetFontSizeCommand = class(TInterfacedObject, IWAEditorCommand)
  private
    FEngine: IWAHtmlEditorEngine;
    FSizeInPoints: Integer;
  public
    constructor Create(const AEngine: IWAHtmlEditorEngine; ASizeInPoints: Integer);
    procedure Execute;
  end;

implementation

uses
  WAEditor.Domain.Types;

constructor TWASetFontSizeCommand.Create(const AEngine: IWAHtmlEditorEngine;
  ASizeInPoints: Integer);
begin
  inherited Create;
  if (ASizeInPoints < WA_MIN_FONT_SIZE) or (ASizeInPoints > WA_MAX_FONT_SIZE) then
    raise EWADomainValidationError.CreateFmt(
      'Font size must be between %d and %d points.', [WA_MIN_FONT_SIZE, WA_MAX_FONT_SIZE]);
  FEngine := AEngine;
  FSizeInPoints := ASizeInPoints;
end;

procedure TWASetFontSizeCommand.Execute;
begin
  FEngine.SetFontSize(FSizeInPoints);
end;

end.
