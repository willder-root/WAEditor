unit WAEditor.Infrastructure.FileHtmlDocumentStorage;

interface

uses
  WAEditor.Application.IHtmlDocumentStorage;

type
  /// Reads and writes HTML documents as UTF-8 text files on disk. Kept
  /// deliberately thin: no business rules live here, only the translation
  /// from the storage contract to System.IOUtils calls.
  TWAFileHtmlDocumentStorage = class(TInterfacedObject, IWAHtmlDocumentStorage)
  public
    function LoadHtml(const AFileName: string): string;
    procedure SaveHtml(const AFileName, AHtml: string);
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils;

function TWAFileHtmlDocumentStorage.LoadHtml(const AFileName: string): string;
begin
  Result := TFile.ReadAllText(AFileName, TEncoding.UTF8);
end;

procedure TWAFileHtmlDocumentStorage.SaveHtml(const AFileName, AHtml: string);
begin
  TFile.WriteAllText(AFileName, AHtml, TEncoding.UTF8);
end;

end.
