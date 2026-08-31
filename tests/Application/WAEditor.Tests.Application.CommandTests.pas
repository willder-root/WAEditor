unit WAEditor.Tests.Application.CommandTests;

interface

uses
  DUnitX.TestFramework,
  WAEditor.Domain.Types,
  WAEditor.Application.IHtmlEditorEngine,
  WAEditor.Tests.Fakes.FakeHtmlEditorEngine;

type
  [TestFixture]
  TWACommandTests = class
  private
    // FEngineRef keeps the fake alive (TInterfacedObject is reference
    // counted) independently of whatever the command under test does
    // with its own reference to it; FEngine is the typed view used to
    // assert on recorded calls.
    FEngineRef: IWAHtmlEditorEngine;
    FEngine: TFakeHtmlEditorEngine;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure SetFontNameCommand_Execute_SetsFontNameOnEngine;

    [Test]
    procedure SetFontNameCommand_Create_WithBlankName_RaisesValidationError;

    [Test]
    procedure SetFontSizeCommand_Execute_SetsFontSizeOnEngine;

    [Test]
    procedure SetFontSizeCommand_Create_WithSizeOutOfRange_RaisesValidationError;

    [Test]
    procedure SetAlignmentCommand_Execute_SetsAlignmentOnEngine;

    [Test]
    procedure InsertTableCommand_Execute_InsertsGeneratedTableHtml;

    [Test]
    procedure InsertTableCommand_Create_WithInvalidSpec_RaisesValidationError;

    [Test]
    procedure ToggleBoldCommand_Execute_TwiceRestoresOriginalState;

    [Test]
    procedure ToggleItalicCommand_Execute_FlipsItalicState;

    [Test]
    procedure ToggleUnderlineCommand_Execute_FlipsUnderlineState;
  end;

implementation

uses
  WAEditor.Application.Commands.SetFontNameCommand,
  WAEditor.Application.Commands.SetFontSizeCommand,
  WAEditor.Application.Commands.SetAlignmentCommand,
  WAEditor.Application.Commands.InsertTableCommand,
  WAEditor.Application.Commands.ToggleBoldCommand,
  WAEditor.Application.Commands.ToggleItalicCommand,
  WAEditor.Application.Commands.ToggleUnderlineCommand;

procedure TWACommandTests.Setup;
begin
  FEngine := TFakeHtmlEditorEngine.Create;
  FEngineRef := FEngine;
end;

procedure TWACommandTests.TearDown;
begin
  FEngineRef := nil;
  FEngine := nil;
end;

procedure TWACommandTests.SetFontNameCommand_Execute_SetsFontNameOnEngine;
var
  LCommand: TWASetFontNameCommand;
begin
  LCommand := TWASetFontNameCommand.Create(FEngine, 'Consolas');
  try
    LCommand.Execute;
    Assert.AreEqual('Consolas', FEngine.FontName);
    Assert.AreEqual(1, FEngine.SetFontNameCallCount);
  finally
    LCommand.Free;
  end;
end;

procedure TWACommandTests.SetFontNameCommand_Create_WithBlankName_RaisesValidationError;
begin
  Assert.WillRaise(
    procedure
    begin
      TWASetFontNameCommand.Create(FEngine, '   ').Free;
    end,
    EWADomainValidationError);
end;

procedure TWACommandTests.SetFontSizeCommand_Execute_SetsFontSizeOnEngine;
var
  LCommand: TWASetFontSizeCommand;
begin
  LCommand := TWASetFontSizeCommand.Create(FEngine, 18);
  try
    LCommand.Execute;
    Assert.AreEqual(18, FEngine.FontSize);
  finally
    LCommand.Free;
  end;
end;

procedure TWACommandTests.SetFontSizeCommand_Create_WithSizeOutOfRange_RaisesValidationError;
begin
  Assert.WillRaise(
    procedure
    begin
      TWASetFontSizeCommand.Create(FEngine, 0).Free;
    end,
    EWADomainValidationError);
end;

procedure TWACommandTests.SetAlignmentCommand_Execute_SetsAlignmentOnEngine;
var
  LCommand: TWASetAlignmentCommand;
begin
  LCommand := TWASetAlignmentCommand.Create(FEngine, taRightAlign);
  try
    LCommand.Execute;
    Assert.AreEqual(Ord(taRightAlign), Ord(FEngine.Alignment));
    Assert.AreEqual(1, FEngine.SetAlignmentCallCount);
  finally
    LCommand.Free;
  end;
end;

procedure TWACommandTests.InsertTableCommand_Execute_InsertsGeneratedTableHtml;
var
  LCommand: TWAInsertTableCommand;
  LSpec: TWATableSpec;
begin
  LSpec := TWATableSpec.Create(2, 2);
  LCommand := TWAInsertTableCommand.Create(FEngine, LSpec);
  try
    LCommand.Execute;
    Assert.AreEqual(1, FEngine.InsertHtmlCallCount);
    Assert.Contains(FEngine.LastInsertedHtml, '<table');
    Assert.Contains(FEngine.LastInsertedHtml, '<td>');
  finally
    LCommand.Free;
  end;
end;

procedure TWACommandTests.InsertTableCommand_Create_WithInvalidSpec_RaisesValidationError;
var
  LSpec: TWATableSpec;
begin
  LSpec := Default(TWATableSpec);
  Assert.WillRaise(
    procedure
    begin
      TWAInsertTableCommand.Create(FEngine, LSpec).Free;
    end,
    EWADomainValidationError);
end;

procedure TWACommandTests.ToggleBoldCommand_Execute_TwiceRestoresOriginalState;
var
  LCommand: TWAToggleBoldCommand;
begin
  LCommand := TWAToggleBoldCommand.Create(FEngine);
  try
    Assert.IsFalse(FEngine.IsBold);
    LCommand.Execute;
    Assert.IsTrue(FEngine.IsBold);
    LCommand.Execute;
    Assert.IsFalse(FEngine.IsBold);
  finally
    LCommand.Free;
  end;
end;

procedure TWACommandTests.ToggleItalicCommand_Execute_FlipsItalicState;
var
  LCommand: TWAToggleItalicCommand;
begin
  LCommand := TWAToggleItalicCommand.Create(FEngine);
  try
    LCommand.Execute;
    Assert.IsTrue(FEngine.IsItalic);
  finally
    LCommand.Free;
  end;
end;

procedure TWACommandTests.ToggleUnderlineCommand_Execute_FlipsUnderlineState;
var
  LCommand: TWAToggleUnderlineCommand;
begin
  LCommand := TWAToggleUnderlineCommand.Create(FEngine);
  try
    LCommand.Execute;
    Assert.IsTrue(FEngine.IsUnderline);
  finally
    LCommand.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWACommandTests);

end.
