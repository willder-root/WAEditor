unit WAEditor.Application.Commands.ToggleItalicCommand;

interface

uses
  WAEditor.Application.ICommand,
  WAEditor.Application.IHtmlEditorEngine;

type
  TWAToggleItalicCommand = class(TInterfacedObject, IWAEditorCommand)
  private
    FEngine: IWAHtmlEditorEngine;
  public
    constructor Create(const AEngine: IWAHtmlEditorEngine);
    procedure Execute;
  end;

implementation

constructor TWAToggleItalicCommand.Create(const AEngine: IWAHtmlEditorEngine);
begin
  inherited Create;
  FEngine := AEngine;
end;

procedure TWAToggleItalicCommand.Execute;
begin
  FEngine.SetItalic(not FEngine.IsItalic);
end;

end.
