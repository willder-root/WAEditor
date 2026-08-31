unit WAEditor.Infrastructure.WebBrowserEditorEngine;

interface

uses
  SHDocVw,
  MSHTML,
  WAEditor.Application.IHtmlEditorEngine,
  WAEditor.Domain.Types;

type
  /// Adapts a TWebBrowser hosting an HTML document in design mode
  /// (contentEditable) to the IWAHtmlEditorEngine contract, translating
  /// every formatting request into IHTMLDocument2.execCommand calls.
  /// This unit is intentionally free of business rules: validation
  /// already happened in the Application-layer commands that call it.
  TWAWebBrowserEditorEngine = class(TInterfacedObject, IWAHtmlEditorEngine)
  private
    FBrowser: TWebBrowser;
    function GetHtmlDocument: IHTMLDocument2;
    procedure ExecCommand(const ACommandName: string); overload;
    procedure ExecCommand(const ACommandName: string; const AValue: OleVariant); overload;
    function QueryCommandState(const ACommandName: string): Boolean;
  public
    constructor Create(ABrowser: TWebBrowser);

    procedure BeginEditing;
    procedure SetBold(AEnabled: Boolean);
    procedure SetItalic(AEnabled: Boolean);
    procedure SetUnderline(AEnabled: Boolean);
    procedure SetFontName(const AFontName: string);
    procedure SetFontSize(ASizeInPoints: Integer);
    procedure SetTextAlignment(AAlignment: TWATextAlignment);
    procedure SetUnorderedList(AEnabled: Boolean);
    procedure SetOrderedList(AEnabled: Boolean);
    procedure InsertHtml(const AHtml: string);

    function IsBold: Boolean;
    function IsItalic: Boolean;
    function IsUnderline: Boolean;
    function IsUnorderedList: Boolean;
    function IsOrderedList: Boolean;

    function GetHtml: string;
    procedure SetHtml(const AHtml: string);
  end;

implementation

uses
  System.SysUtils,
  System.Variants,
  WAEditor.Domain.AlignmentMapper,
  WAEditor.Domain.FontSizeScale;

constructor TWAWebBrowserEditorEngine.Create(ABrowser: TWebBrowser);
begin
  inherited Create;
  if ABrowser = nil then
    raise EArgumentNilException.Create('ABrowser must not be nil.');
  FBrowser := ABrowser;
end;

function TWAWebBrowserEditorEngine.GetHtmlDocument: IHTMLDocument2;
begin
  if (FBrowser.Document = nil) or not Supports(FBrowser.Document, IHTMLDocument2, Result) then
    raise EInvalidOpException.Create('The browser document is not ready for editing.');
end;

procedure TWAWebBrowserEditorEngine.ExecCommand(const ACommandName: string);
begin
  ExecCommand(ACommandName, Unassigned);
end;

procedure TWAWebBrowserEditorEngine.ExecCommand(const ACommandName: string; const AValue: OleVariant);
begin
  GetHtmlDocument.execCommand(ACommandName, False, AValue);
end;

function TWAWebBrowserEditorEngine.QueryCommandState(const ACommandName: string): Boolean;
begin
  Result := GetHtmlDocument.queryCommandState(ACommandName);
end;

procedure TWAWebBrowserEditorEngine.BeginEditing;
begin
  GetHtmlDocument.designMode := 'On';
end;

procedure TWAWebBrowserEditorEngine.SetBold(AEnabled: Boolean);
begin
  if IsBold <> AEnabled then
    ExecCommand('Bold');
end;

procedure TWAWebBrowserEditorEngine.SetItalic(AEnabled: Boolean);
begin
  if IsItalic <> AEnabled then
    ExecCommand('Italic');
end;

procedure TWAWebBrowserEditorEngine.SetUnderline(AEnabled: Boolean);
begin
  if IsUnderline <> AEnabled then
    ExecCommand('Underline');
end;

procedure TWAWebBrowserEditorEngine.SetFontName(const AFontName: string);
begin
  ExecCommand('FontName', AFontName);
end;

procedure TWAWebBrowserEditorEngine.SetFontSize(ASizeInPoints: Integer);
begin
  ExecCommand('FontSize', TWAFontSizeScale.ToHtmlLegacySize(ASizeInPoints));
end;

procedure TWAWebBrowserEditorEngine.SetTextAlignment(AAlignment: TWATextAlignment);
begin
  ExecCommand(TWAAlignmentMapper.ToExecCommandName(AAlignment));
end;

procedure TWAWebBrowserEditorEngine.SetUnorderedList(AEnabled: Boolean);
begin
  if IsUnorderedList <> AEnabled then
    ExecCommand('InsertUnorderedList');
end;

procedure TWAWebBrowserEditorEngine.SetOrderedList(AEnabled: Boolean);
begin
  if IsOrderedList <> AEnabled then
    ExecCommand('InsertOrderedList');
end;

procedure TWAWebBrowserEditorEngine.InsertHtml(const AHtml: string);
begin
  ExecCommand('InsertHTML', AHtml);
end;

function TWAWebBrowserEditorEngine.IsBold: Boolean;
begin
  Result := QueryCommandState('Bold');
end;

function TWAWebBrowserEditorEngine.IsItalic: Boolean;
begin
  Result := QueryCommandState('Italic');
end;

function TWAWebBrowserEditorEngine.IsUnderline: Boolean;
begin
  Result := QueryCommandState('Underline');
end;

function TWAWebBrowserEditorEngine.IsUnorderedList: Boolean;
begin
  Result := QueryCommandState('InsertUnorderedList');
end;

function TWAWebBrowserEditorEngine.IsOrderedList: Boolean;
begin
  Result := QueryCommandState('InsertOrderedList');
end;

function TWAWebBrowserEditorEngine.GetHtml: string;
begin
  Result := GetHtmlDocument.body.innerHTML;
end;

procedure TWAWebBrowserEditorEngine.SetHtml(const AHtml: string);
var
  LDoc: IHTMLDocument2;
begin
  LDoc := GetHtmlDocument;
  LDoc.body.innerHTML := AHtml;
end;

end.
