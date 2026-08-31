unit WAEditor.Application.IHtmlDocumentStorage;

interface

type
  /// Abstraction over persistence of HTML document content, decoupling the
  /// document use cases from any concrete file system API.
  IWAHtmlDocumentStorage = interface
    ['{2E9F6E9B-9F0B-4B7C-9C2A-6E9F2C7B3A02}']
    function LoadHtml(const AFileName: string): string;
    procedure SaveHtml(const AFileName, AHtml: string);
  end;

implementation

end.
