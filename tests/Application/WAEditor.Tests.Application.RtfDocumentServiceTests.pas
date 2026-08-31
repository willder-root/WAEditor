unit WAEditor.Tests.Application.RtfDocumentServiceTests;

interface

uses
  DUnitX.TestFramework,
  WAEditor.Application.IHtmlEditorEngine,
  WAEditor.Application.IHtmlDocumentStorage,
  WAEditor.Application.RtfDocumentService,
  WAEditor.Tests.Fakes.FakeHtmlEditorEngine,
  WAEditor.Tests.Fakes.FakeHtmlDocumentStorage;

type
  [TestFixture]
  TWARtfDocumentServiceTests = class
  private
    FEngineRef: IWAHtmlEditorEngine;
    FEngine: TFakeHtmlEditorEngine;
    FStorageRef: IWAHtmlDocumentStorage;
    FStorage: TFakeHtmlDocumentStorage;
    FService: TWARtfDocumentService;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure OpenRtfDocument_ConvertsStoredRtfToHtmlAndLoadsIntoEngine;

    [Test]
    procedure SaveRtfDocument_ConvertsEngineHtmlToRtfAndPersistsIt;
  end;

implementation

procedure TWARtfDocumentServiceTests.Setup;
begin
  FEngine := TFakeHtmlEditorEngine.Create;
  FEngineRef := FEngine;
  FStorage := TFakeHtmlDocumentStorage.Create;
  FStorageRef := FStorage;
  FService := TWARtfDocumentService.Create(FEngineRef, FStorageRef);
end;

procedure TWARtfDocumentServiceTests.TearDown;
begin
  FService.Free;
  FStorageRef := nil;
  FStorage := nil;
  FEngineRef := nil;
  FEngine := nil;
end;

procedure TWARtfDocumentServiceTests.OpenRtfDocument_ConvertsStoredRtfToHtmlAndLoadsIntoEngine;
begin
  FStorage.SaveHtml('C:\docs\letter.rtf',
    '{\rtf1\ansi\deff0 \pard\qc {\b Title}\par}');

  FService.OpenRtfDocument('C:\docs\letter.rtf');

  Assert.Contains(FEngine.GetHtml, 'Title');
  Assert.Contains(FEngine.GetHtml, 'text-align:center');
  Assert.Contains(FEngine.GetHtml, '<b>Title</b>');
end;

procedure TWARtfDocumentServiceTests.SaveRtfDocument_ConvertsEngineHtmlToRtfAndPersistsIt;
begin
  FEngine.SetHtml('<p style="text-align:right;"><i>Report</i></p>');

  FService.SaveRtfDocument('C:\docs\report.rtf');

  Assert.AreEqual(1, FStorage.SaveCallCount);
  Assert.Contains(FStorage.LoadHtml('C:\docs\report.rtf'), '\qr');
  Assert.Contains(FStorage.LoadHtml('C:\docs\report.rtf'), '\i');
  Assert.Contains(FStorage.LoadHtml('C:\docs\report.rtf'), 'Report');
end;

initialization
  TDUnitX.RegisterTestFixture(TWARtfDocumentServiceTests);

end.
