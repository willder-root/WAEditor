unit WAEditor.Application.Commands.ToggleUnderlineCommand;

interface

uses
  WAEditor.Application.ICommand,
  WAEditor.Application.IHtmlEditorEngine;

type
  TWAToggleUnderlineCommand = class(TInterfacedObject, IWAEditorCommand)
  private
    FEngine: IWAHtmlEditorEngine;
  public
    constructor Create(const AEngine: IWAHtmlEditorEngine);
    procedure Execute;
  end;

implementation

constructor TWAToggleUnderlineCommand.Create(const AEngine: IWAHtmlEditorEngine);
begin
  inherited Create;
  FEngine := AEngine;
end;

procedure TWAToggleUnderlineCommand.Execute;
begin
  FEngine.SetUnderline(not FEngine.IsUnderline);
end;

end.
