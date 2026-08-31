unit WAEditor.Application.Commands.ToggleUnorderedListCommand;

interface

uses
  WAEditor.Application.ICommand,
  WAEditor.Application.IHtmlEditorEngine;

type
  TWAToggleUnorderedListCommand = class(TInterfacedObject, IWAEditorCommand)
  private
    FEngine: IWAHtmlEditorEngine;
  public
    constructor Create(const AEngine: IWAHtmlEditorEngine);
    procedure Execute;
  end;

implementation

constructor TWAToggleUnorderedListCommand.Create(const AEngine: IWAHtmlEditorEngine);
begin
  inherited Create;
  FEngine := AEngine;
end;

procedure TWAToggleUnorderedListCommand.Execute;
begin
  FEngine.SetUnorderedList(not FEngine.IsUnorderedList);
end;

end.
