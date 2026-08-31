program WAEditorDemo;

uses
  Vcl.Forms,
  WAEditor.Presentation.MainForm in '..\..\src\Presentation\WAEditor.Presentation.MainForm.pas' {WAMainForm},
  WAEditor.Presentation.InsertTableDialog in '..\..\src\Presentation\WAEditor.Presentation.InsertTableDialog.pas' {WAInsertTableDialog};

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TWAMainForm, WAMainForm);
  Application.Run;
end.
