unit WAEditor.Application.DocumentService;

interface

uses
  WAEditor.Application.IHtmlEditorEngine,
  WAEditor.Application.IHtmlDocumentStorage;

const
  WA_BLANK_DOCUMENT_HTML = '<html><body></body></html>';

type
  /// Orchestrates the New/Open/Save use cases against the editing engine
  /// and the storage abstraction, keeping the file-name/dirty bookkeeping
  /// out of both the UI and the engine adapter.
  TWADocumentService = class
  private
    FEngine: IWAHtmlEditorEngine;
    FStorage: IWAHtmlDocumentStorage;
    FCurrentFileName: string;
  public
    constructor Create(const AEngine: IWAHtmlEditorEngine;
      const AStorage: IWAHtmlDocumentStorage);

    procedure NewDocument;
    procedure OpenDocument(const AFileName: string);
    procedure SaveDocument(const AFileName: string); overload;
    procedure SaveDocument; overload;

    property CurrentFileName: string read FCurrentFileName;
  end;

implementation

uses
  System.SysUtils;

constructor TWADocumentService.Create(const AEngine: IWAHtmlEditorEngine;
  const AStorage: IWAHtmlDocumentStorage);
begin
  inherited Create;
  FEngine := AEngine;
  FStorage := AStorage;
  FCurrentFileName := '';
end;

procedure TWADocumentService.NewDocument;
begin
  FEngine.SetHtml(WA_BLANK_DOCUMENT_HTML);
  FCurrentFileName := '';
end;

procedure TWADocumentService.OpenDocument(const AFileName: string);
var
  LHtml: string;
begin
  LHtml := FStorage.LoadHtml(AFileName);
  FEngine.SetHtml(LHtml);
  FCurrentFileName := AFileName;
end;

procedure TWADocumentService.SaveDocument(const AFileName: string);
begin
  FStorage.SaveHtml(AFileName, FEngine.GetHtml);
  FCurrentFileName := AFileName;
end;

procedure TWADocumentService.SaveDocument;
begin
  if FCurrentFileName = '' then
    raise EArgumentException.Create('There is no current file name; call SaveDocument(AFileName) instead.');
  SaveDocument(FCurrentFileName);
end;

end.
