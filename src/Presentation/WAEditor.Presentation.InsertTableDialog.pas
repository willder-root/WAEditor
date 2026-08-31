unit WAEditor.Presentation.InsertTableDialog;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.UITypes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  WAEditor.Domain.Types;

type
  TWAInsertTableDialog = class(TForm)
    LabelRows: TLabel;
    LabelColumns: TLabel;
    LabelBorder: TLabel;
    EditRows: TEdit;
    EditColumns: TEdit;
    EditBorder: TEdit;
    ButtonOK: TButton;
    ButtonCancel: TButton;
    procedure ButtonOKClick(Sender: TObject);
  private
    FTableSpec: TWATableSpec;
  public
    property TableSpec: TWATableSpec read FTableSpec;

    /// Shows the dialog modally; returns True and populates ATableSpec
    /// when the user confirms a valid table size, False otherwise.
    class function Execute(AOwner: TComponent; out ATableSpec: TWATableSpec): Boolean;
  end;

implementation

{$R *.dfm}

class function TWAInsertTableDialog.Execute(AOwner: TComponent;
  out ATableSpec: TWATableSpec): Boolean;
var
  LDialog: TWAInsertTableDialog;
begin
  LDialog := TWAInsertTableDialog.Create(AOwner);
  try
    Result := LDialog.ShowModal = mrOk;
    if Result then
      ATableSpec := LDialog.TableSpec;
  finally
    LDialog.Free;
  end;
end;

procedure TWAInsertTableDialog.ButtonOKClick(Sender: TObject);
var
  LRows, LColumns, LBorder: Integer;
begin
  if not TryStrToInt(Trim(EditRows.Text), LRows) then
  begin
    MessageDlg('Informe um número válido de linhas.', mtError, [mbOK], 0);
    ModalResult := mrNone;
    Exit;
  end;
  if not TryStrToInt(Trim(EditColumns.Text), LColumns) then
  begin
    MessageDlg('Informe um número válido de colunas.', mtError, [mbOK], 0);
    ModalResult := mrNone;
    Exit;
  end;
  if not TryStrToInt(Trim(EditBorder.Text), LBorder) then
    LBorder := 1;

  try
    FTableSpec := TWATableSpec.Create(LRows, LColumns, LBorder);
  except
    on E: EWADomainValidationError do
    begin
      MessageDlg(E.Message, mtError, [mbOK], 0);
      ModalResult := mrNone;
    end;
  end;
end;

end.
