unit WAEditor.Tests.Application.DocumentServiceTests;

interface

uses
  DUnitX.TestFramework,
  WAEditor.Application.IHtmlEditorEngine,
  WAEditor.Application.IHtmlDocumentStorage,
  WAEditor.Application.DocumentService,
  WAEditor.Tests.Fakes.FakeHtmlEditorEngine,
  WAEditor.Tests.Fakes.FakeHtmlDocumentStorage;

type
  [TestFixture]
  TWADocumentServiceTests = class
  private
    FEngineRef: IWAHtmlEditorEngine;
    FEngine: TFakeHtmlEditorEngine;
    FStorageRef: IWAHtmlDocumentStorage;
    FStorage: TFakeHtmlDocumentStorage;
    FService: TWADocumentService;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure NewDocument_ResetsEngineHtmlAndCurrentFileName;

    [Test]
    procedure OpenDocument_LoadsHtmlFromStorageIntoEngine;

    [Test]
    procedure SaveDocumentWithFileName_PersistsEngineHtmlAndUpdatesCurrentFileName;

    [Test]
    procedure SaveDocumentWithoutFileName_UsesPreviouslyOpenedFileName;

    [Test]
    procedure SaveDocumentWithoutFileName_WhenNoFileIsOpen_RaisesException;
  end;

implementation

uses
  System.SysUtils;

procedure TWADocumentServiceTests.Setup;
begin
  FEngine := TFakeHtmlEditorEngine.Create;
  FEngineRef := FEngine;
  FStorage := TFakeHtmlDocumentStorage.Create;
  FStorageRef := FStorage;
  FService := TWADocumentService.Create(FEngineRef, FStorageRef);
end;

procedure TWADocumentServiceTests.TearDown;
begin
  FService.Free;
  FStorageRef := nil;
  FStorage := nil;
  FEngineRef := nil;
  FEngine := nil;
end;

procedure TWADocumentServiceTests.NewDocument_ResetsEngineHtmlAndCurrentFileName;
begin
  FEngine.SetHtml('<html><body>old</body></html>');

  FService.NewDocument;

  Assert.AreEqual(WA_BLANK_DOCUMENT_HTML, FEngine.GetHtml);
  Assert.AreEqual('', FService.CurrentFileName);
end;

procedure TWADocumentServiceTests.OpenDocument_LoadsHtmlFromStorageIntoEngine;
begin
  FStorage.SaveHtml('C:\docs\letter.html', '<html><body>Hello</body></html>');

  FService.OpenDocument('C:\docs\letter.html');

  Assert.AreEqual('<html><body>Hello</body></html>', FEngine.GetHtml);
  Assert.AreEqual('C:\docs\letter.html', FService.CurrentFileName);
end;

procedure TWADocumentServiceTests.SaveDocumentWithFileName_PersistsEngineHtmlAndUpdatesCurrentFileName;
begin
  FEngine.SetHtml('<html><body>report</body></html>');

  FService.SaveDocument('C:\docs\report.html');

  Assert.AreEqual(1, FStorage.SaveCallCount);
  Assert.AreEqual('<html><body>report</body></html>', FStorage.LoadHtml('C:\docs\report.html'));
  Assert.AreEqual('C:\docs\report.html', FService.CurrentFileName);
end;

procedure TWADocumentServiceTests.SaveDocumentWithoutFileName_UsesPreviouslyOpenedFileName;
begin
  FStorage.SaveHtml('C:\docs\memo.html', '<html><body>memo</body></html>');
  FService.OpenDocument('C:\docs\memo.html');
  FEngine.SetHtml('<html><body>memo edited</body></html>');

  FService.SaveDocument;

  Assert.AreEqual('<html><body>memo edited</body></html>', FStorage.LoadHtml('C:\docs\memo.html'));
end;

procedure TWADocumentServiceTests.SaveDocumentWithoutFileName_WhenNoFileIsOpen_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      FService.SaveDocument;
    end,
    EArgumentException);
end;

initialization
  TDUnitX.RegisterTestFixture(TWADocumentServiceTests);

end.
