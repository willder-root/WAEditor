unit WAEditor.Application.Commands.InsertTableCommand;

interface

uses
  WAEditor.Application.ICommand,
  WAEditor.Application.IHtmlEditorEngine,
  WAEditor.Domain.Types;

type
  TWAInsertTableCommand = class(TInterfacedObject, IWAEditorCommand)
  private
    FEngine: IWAHtmlEditorEngine;
    FTableSpec: TWATableSpec;
  public
    constructor Create(const AEngine: IWAHtmlEditorEngine; const ATableSpec: TWATableSpec);
    procedure Execute;
  end;

implementation

uses
  WAEditor.Domain.TableHtmlBuilder;

constructor TWAInsertTableCommand.Create(const AEngine: IWAHtmlEditorEngine;
  const ATableSpec: TWATableSpec);
begin
  inherited Create;
  ATableSpec.Validate;
  FEngine := AEngine;
  FTableSpec := ATableSpec;
end;

procedure TWAInsertTableCommand.Execute;
begin
  FEngine.InsertHtml(TWATableHtmlBuilder.Build(FTableSpec));
end;

end.
