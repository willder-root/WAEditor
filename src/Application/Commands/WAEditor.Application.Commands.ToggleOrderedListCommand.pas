unit WAEditor.Application.Commands.ToggleOrderedListCommand;

interface

uses
  WAEditor.Application.ICommand,
  WAEditor.Application.IHtmlEditorEngine;

type
  TWAToggleOrderedListCommand = class(TInterfacedObject, IWAEditorCommand)
  private
    FEngine: IWAHtmlEditorEngine;
  public
    constructor Create(const AEngine: IWAHtmlEditorEngine);
    procedure Execute;
  end;

implementation

constructor TWAToggleOrderedListCommand.Create(const AEngine: IWAHtmlEditorEngine);
begin
  inherited Create;
  FEngine := AEngine;
end;

procedure TWAToggleOrderedListCommand.Execute;
begin
  FEngine.SetOrderedList(not FEngine.IsOrderedList);
end;

end.
