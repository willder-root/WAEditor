unit WAEditor.Application.Commands.SetFontNameCommand;

interface

uses
  WAEditor.Application.ICommand,
  WAEditor.Application.IHtmlEditorEngine;

type
  TWASetFontNameCommand = class(TInterfacedObject, IWAEditorCommand)
  private
    FEngine: IWAHtmlEditorEngine;
    FFontName: string;
  public
    constructor Create(const AEngine: IWAHtmlEditorEngine; const AFontName: string);
    procedure Execute;
  end;

implementation

uses
  System.SysUtils,
  WAEditor.Domain.Types;

constructor TWASetFontNameCommand.Create(const AEngine: IWAHtmlEditorEngine;
  const AFontName: string);
begin
  inherited Create;
  if Trim(AFontName) = '' then
    raise EWADomainValidationError.Create('Font name must not be empty.');
  FEngine := AEngine;
  FFontName := AFontName;
end;

procedure TWASetFontNameCommand.Execute;
begin
  FEngine.SetFontName(FFontName);
end;

end.
