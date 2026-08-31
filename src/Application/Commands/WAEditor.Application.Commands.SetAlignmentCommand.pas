unit WAEditor.Application.Commands.SetAlignmentCommand;

interface

uses
  WAEditor.Application.ICommand,
  WAEditor.Application.IHtmlEditorEngine,
  WAEditor.Domain.Types;

type
  TWASetAlignmentCommand = class(TInterfacedObject, IWAEditorCommand)
  private
    FEngine: IWAHtmlEditorEngine;
    FAlignment: TWATextAlignment;
  public
    constructor Create(const AEngine: IWAHtmlEditorEngine; AAlignment: TWATextAlignment);
    procedure Execute;
  end;

implementation

constructor TWASetAlignmentCommand.Create(const AEngine: IWAHtmlEditorEngine;
  AAlignment: TWATextAlignment);
begin
  inherited Create;
  FEngine := AEngine;
  FAlignment := AAlignment;
end;

procedure TWASetAlignmentCommand.Execute;
begin
  FEngine.SetTextAlignment(FAlignment);
end;

end.
