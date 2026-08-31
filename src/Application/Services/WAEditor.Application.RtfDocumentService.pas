unit WAEditor.Application.RtfDocumentService;

interface

uses
  WAEditor.Application.IHtmlEditorEngine,
  WAEditor.Application.IHtmlDocumentStorage;

type
  /// Opens and saves RTF files against the same WYSIWYG engine used for
  /// HTML documents, converting through the framework-agnostic
  /// TWARichDocument model (see WAEditor.Domain.RtfDocumentRenderer/
  /// Parser and WAEditor.Domain.HtmlDocumentRenderer/Parser).
  TWARtfDocumentService = class
  private
    FEngine: IWAHtmlEditorEngine;
    FStorage: IWAHtmlDocumentStorage;
  public
    constructor Create(const AEngine: IWAHtmlEditorEngine;
      const AStorage: IWAHtmlDocumentStorage);

    procedure OpenRtfDocument(const AFileName: string);
    procedure SaveRtfDocument(const AFileName: string);
  end;

implementation

uses
  WAEditor.Domain.RichDocument,
  WAEditor.Domain.HtmlDocumentRenderer,
  WAEditor.Domain.HtmlDocumentParser,
  WAEditor.Domain.RtfDocumentRenderer,
  WAEditor.Domain.RtfDocumentParser;

constructor TWARtfDocumentService.Create(const AEngine: IWAHtmlEditorEngine;
  const AStorage: IWAHtmlDocumentStorage);
begin
  inherited Create;
  FEngine := AEngine;
  FStorage := AStorage;
end;

procedure TWARtfDocumentService.OpenRtfDocument(const AFileName: string);
var
  LRtf: string;
  LDocument: TWARichDocument;
begin
  LRtf := FStorage.LoadHtml(AFileName);
  LDocument := TWARtfDocumentParser.Parse(LRtf);
  try
    FEngine.SetHtml(TWAHtmlDocumentRenderer.Render(LDocument));
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentService.SaveRtfDocument(const AFileName: string);
var
  LDocument: TWARichDocument;
  LRtf: string;
begin
  LDocument := TWAHtmlDocumentParser.Parse(FEngine.GetHtml);
  try
    LRtf := TWARtfDocumentRenderer.Render(LDocument);
  finally
    LDocument.Free;
  end;
  FStorage.SaveHtml(AFileName, LRtf);
end;

end.
