unit WAEditor.Presentation.MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.UITypes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Buttons, Vcl.OleCtrls, SHDocVw,
  WAEditor.Domain.Types,
  WAEditor.Application.IHtmlEditorEngine,
  WAEditor.Application.IHtmlDocumentStorage,
  WAEditor.Application.DocumentService;

type
  TWAMainForm = class(TForm)
    MainMenu1: TMainMenu;
    MenuFile: TMenuItem;
    MenuFileNew: TMenuItem;
    MenuFileOpen: TMenuItem;
    MenuFileSave: TMenuItem;
    MenuFileSaveAs: TMenuItem;
    MenuFileSeparator: TMenuItem;
    MenuFileExit: TMenuItem;
    ToolbarPanel: TPanel;
    ButtonBold: TSpeedButton;
    ButtonItalic: TSpeedButton;
    ButtonUnderline: TSpeedButton;
    ComboFontName: TComboBox;
    ComboFontSize: TComboBox;
    ButtonAlignLeft: TSpeedButton;
    ButtonAlignCenter: TSpeedButton;
    ButtonAlignRight: TSpeedButton;
    ButtonAlignJustify: TSpeedButton;
    ButtonInsertTable: TButton;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure WebBrowser1DocumentComplete(ASender: TObject; const pDisp: IDispatch;
      const URL: OleVariant);
    procedure MenuFileNewClick(Sender: TObject);
    procedure MenuFileOpenClick(Sender: TObject);
    procedure MenuFileSaveClick(Sender: TObject);
    procedure MenuFileSaveAsClick(Sender: TObject);
    procedure MenuFileExitClick(Sender: TObject);
    procedure ButtonBoldClick(Sender: TObject);
    procedure ButtonItalicClick(Sender: TObject);
    procedure ButtonUnderlineClick(Sender: TObject);
    procedure ComboFontNameChange(Sender: TObject);
    procedure ComboFontSizeChange(Sender: TObject);
    procedure ButtonAlignLeftClick(Sender: TObject);
    procedure ButtonAlignCenterClick(Sender: TObject);
    procedure ButtonAlignRightClick(Sender: TObject);
    procedure ButtonAlignJustifyClick(Sender: TObject);
    procedure ButtonInsertTableClick(Sender: TObject);
  private
    // Created dynamically in FormCreate rather than streamed from the
    // .dfm: TWebBrowser is an ActiveX control whose hand-authored DFM
    // ControlData binary blob would be fragile to maintain by hand.
    WebBrowser1: TWebBrowser;
    FEngine: IWAHtmlEditorEngine;
    FStorage: IWAHtmlDocumentStorage;
    FDocumentService: TWADocumentService;
    FEditorReady: Boolean;
    procedure SetToolbarEnabled(AEnabled: Boolean);
    procedure ApplyAlignment(AAlignment: TWATextAlignment);
    procedure SaveAs;
  public
    destructor Destroy; override;
  end;

var
  WAMainForm: TWAMainForm;

implementation

{$R *.dfm}

uses
  WAEditor.Infrastructure.WebBrowserEditorEngine,
  WAEditor.Infrastructure.FileHtmlDocumentStorage,
  WAEditor.Application.Commands.SetFontNameCommand,
  WAEditor.Application.Commands.SetFontSizeCommand,
  WAEditor.Application.Commands.SetAlignmentCommand,
  WAEditor.Application.Commands.InsertTableCommand,
  WAEditor.Application.Commands.ToggleBoldCommand,
  WAEditor.Application.Commands.ToggleItalicCommand,
  WAEditor.Application.Commands.ToggleUnderlineCommand,
  WAEditor.Application.ICommand,
  WAEditor.Presentation.InsertTableDialog;

const
  WA_HTML_DOCUMENT_FILTER = 'Documentos HTML (*.html;*.htm)|*.html;*.htm|Todos os arquivos (*.*)|*.*';

procedure TWAMainForm.FormCreate(Sender: TObject);
begin
  WebBrowser1 := TWebBrowser.Create(Self);
  // TWebBrowser redeclares "Parent" as its read-only OLE automation
  // property, shadowing TWinControl.Parent; go through the ancestor
  // type to reach the VCL parenting property instead.
  TWinControl(WebBrowser1).Parent := Self;
  WebBrowser1.Align := alClient;
  WebBrowser1.OnDocumentComplete := WebBrowser1DocumentComplete;

  FEngine := TWAWebBrowserEditorEngine.Create(WebBrowser1);
  FStorage := TWAFileHtmlDocumentStorage.Create;
  FDocumentService := TWADocumentService.Create(FEngine, FStorage);

  OpenDialog1.Filter := WA_HTML_DOCUMENT_FILTER;
  SaveDialog1.Filter := WA_HTML_DOCUMENT_FILTER;
  SaveDialog1.DefaultExt := 'html';

  SetToolbarEnabled(False);
  WebBrowser1.Navigate('about:blank');
end;

destructor TWAMainForm.Destroy;
begin
  FDocumentService.Free;
  inherited Destroy;
end;

procedure TWAMainForm.WebBrowser1DocumentComplete(ASender: TObject;
  const pDisp: IDispatch; const URL: OleVariant);
begin
  if FEditorReady or (pDisp <> WebBrowser1.Application) then
    Exit;

  FEngine.BeginEditing;
  FDocumentService.NewDocument;
  FEditorReady := True;
  SetToolbarEnabled(True);
end;

procedure TWAMainForm.SetToolbarEnabled(AEnabled: Boolean);
begin
  ToolbarPanel.Enabled := AEnabled;
  MenuFileNew.Enabled := AEnabled;
  MenuFileOpen.Enabled := AEnabled;
  MenuFileSave.Enabled := AEnabled;
  MenuFileSaveAs.Enabled := AEnabled;
end;

procedure TWAMainForm.MenuFileNewClick(Sender: TObject);
begin
  FDocumentService.NewDocument;
end;

procedure TWAMainForm.MenuFileOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    try
      FDocumentService.OpenDocument(OpenDialog1.FileName);
    except
      on E: Exception do
        MessageDlg('Não foi possível abrir o arquivo: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TWAMainForm.SaveAs;
begin
  if SaveDialog1.Execute then
  begin
    try
      FDocumentService.SaveDocument(SaveDialog1.FileName);
    except
      on E: Exception do
        MessageDlg('Não foi possível salvar o arquivo: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TWAMainForm.MenuFileSaveClick(Sender: TObject);
begin
  if FDocumentService.CurrentFileName = '' then
    SaveAs
  else
    FDocumentService.SaveDocument;
end;

procedure TWAMainForm.MenuFileSaveAsClick(Sender: TObject);
begin
  SaveAs;
end;

procedure TWAMainForm.MenuFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TWAMainForm.ButtonBoldClick(Sender: TObject);
var
  LCommand: IWAEditorCommand;
begin
  LCommand := TWAToggleBoldCommand.Create(FEngine);
  LCommand.Execute;
end;

procedure TWAMainForm.ButtonItalicClick(Sender: TObject);
var
  LCommand: IWAEditorCommand;
begin
  LCommand := TWAToggleItalicCommand.Create(FEngine);
  LCommand.Execute;
end;

procedure TWAMainForm.ButtonUnderlineClick(Sender: TObject);
var
  LCommand: IWAEditorCommand;
begin
  LCommand := TWAToggleUnderlineCommand.Create(FEngine);
  LCommand.Execute;
end;

procedure TWAMainForm.ComboFontNameChange(Sender: TObject);
var
  LCommand: IWAEditorCommand;
begin
  if Trim(ComboFontName.Text) = '' then
    Exit;
  LCommand := TWASetFontNameCommand.Create(FEngine, ComboFontName.Text);
  LCommand.Execute;
end;

procedure TWAMainForm.ComboFontSizeChange(Sender: TObject);
var
  LCommand: IWAEditorCommand;
  LSize: Integer;
begin
  if not TryStrToInt(ComboFontSize.Text, LSize) then
    Exit;
  LCommand := TWASetFontSizeCommand.Create(FEngine, LSize);
  LCommand.Execute;
end;

procedure TWAMainForm.ApplyAlignment(AAlignment: TWATextAlignment);
var
  LCommand: IWAEditorCommand;
begin
  LCommand := TWASetAlignmentCommand.Create(FEngine, AAlignment);
  LCommand.Execute;
end;

procedure TWAMainForm.ButtonAlignLeftClick(Sender: TObject);
begin
  ApplyAlignment(taLeftAlign);
end;

procedure TWAMainForm.ButtonAlignCenterClick(Sender: TObject);
begin
  ApplyAlignment(taCenterAlign);
end;

procedure TWAMainForm.ButtonAlignRightClick(Sender: TObject);
begin
  ApplyAlignment(taRightAlign);
end;

procedure TWAMainForm.ButtonAlignJustifyClick(Sender: TObject);
begin
  ApplyAlignment(taJustifyAlign);
end;

procedure TWAMainForm.ButtonInsertTableClick(Sender: TObject);
var
  LTableSpec: TWATableSpec;
  LCommand: IWAEditorCommand;
begin
  if TWAInsertTableDialog.Execute(Self, LTableSpec) then
  begin
    LCommand := TWAInsertTableCommand.Create(FEngine, LTableSpec);
    LCommand.Execute;
  end;
end;

end.
