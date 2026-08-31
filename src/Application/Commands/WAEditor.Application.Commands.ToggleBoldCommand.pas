unit WAEditor.Application.Commands.ToggleBoldCommand;

interface

uses
  WAEditor.Application.ICommand,
  WAEditor.Application.IHtmlEditorEngine;

type
  TWAToggleBoldCommand = class(TInterfacedObject, IWAEditorCommand)
  private
    FEngine: IWAHtmlEditorEngine;
  public
    constructor Create(const AEngine: IWAHtmlEditorEngine);
    procedure Execute;
  end;

implementation

constructor TWAToggleBoldCommand.Create(const AEngine: IWAHtmlEditorEngine);
begin
  inherited Create;
  FEngine := AEngine;
end;

procedure TWAToggleBoldCommand.Execute;
begin
  FEngine.SetBold(not FEngine.IsBold);
end;

end.
