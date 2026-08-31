unit WAEditor.Tests.Fakes.FakeHtmlDocumentStorage;

interface

uses
  System.Generics.Collections,
  WAEditor.Application.IHtmlDocumentStorage;

type
  /// In-memory test double for IWAHtmlDocumentStorage, avoiding real file
  /// system access in Application-layer unit tests.
  TFakeHtmlDocumentStorage = class(TInterfacedObject, IWAHtmlDocumentStorage)
  private
    FFiles: TDictionary<string, string>;
    FSaveCallCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    function LoadHtml(const AFileName: string): string;
    procedure SaveHtml(const AFileName, AHtml: string);

    property SaveCallCount: Integer read FSaveCallCount;
  end;

implementation

uses
  System.SysUtils;

constructor TFakeHtmlDocumentStorage.Create;
begin
  inherited Create;
  FFiles := TDictionary<string, string>.Create;
end;

destructor TFakeHtmlDocumentStorage.Destroy;
begin
  FFiles.Free;
  inherited Destroy;
end;

function TFakeHtmlDocumentStorage.LoadHtml(const AFileName: string): string;
begin
  if not FFiles.TryGetValue(AFileName, Result) then
    raise EFileNotFoundException.CreateFmt('File "%s" was not found.', [AFileName]);
end;

procedure TFakeHtmlDocumentStorage.SaveHtml(const AFileName, AHtml: string);
begin
  FFiles.AddOrSetValue(AFileName, AHtml);
  Inc(FSaveCallCount);
end;

end.
