unit WAEditor.Tests.Domain.RtfDocumentRendererTests;

interface

uses
  DUnitX.TestFramework,
  WAEditor.Domain.Types,
  WAEditor.Domain.RichDocument,
  WAEditor.Domain.RtfDocumentRenderer;

type
  [TestFixture]
  TWARtfDocumentRendererTests = class
  public
    [Test]
    procedure Render_StartsWithRtfHeaderAndFontTable;

    [Test]
    procedure Render_BoldItalicUnderlineRun_EmitsControlWords;

    [Test]
    procedure Render_ParagraphAlignment_EmitsAlignmentControlWord;

    [Test]
    procedure Render_FontNameAndSize_EmitsFontTableReferenceAndHalfPointSize;

    [Test]
    procedure Render_Table_EmitsTrowdIntblCellRow;

    [Test]
    procedure Render_EscapesBackslashAndBraces;

    [Test]
    procedure Render_NonAsciiCharacter_EmitsUnicodeEscape;

    [Test]
    procedure Render_UnorderedList_EmitsBulletMarkerPerItem;

    [Test]
    procedure Render_OrderedList_EmitsIncrementingNumberMarkerPerItem;

    [Test]
    procedure Render_LineBreakRun_EmitsSingleLineControlWordNotPar;

    [Test]
    procedure Render_ParagraphWithBorder_EmitsBorderControlWords;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils;

function CountOccurrences(const AText, ASubstring: string): Integer;
var
  LPosition: Integer;
begin
  Result := 0;
  LPosition := PosEx(ASubstring, AText, 1);
  while LPosition > 0 do
  begin
    Inc(Result);
    LPosition := PosEx(ASubstring, AText, LPosition + Length(ASubstring));
  end;
end;

procedure TWARtfDocumentRendererTests.Render_StartsWithRtfHeaderAndFontTable;
var
  LDocument: TWARichDocument;
  LRtf: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph.AddRun('Hi', TWARunFormat.Plain);
    LRtf := TWARtfDocumentRenderer.Render(LDocument);

    Assert.IsTrue(LRtf.StartsWith('{\rtf1'));
    Assert.Contains(LRtf, '\fonttbl');
    Assert.IsTrue(LRtf.EndsWith('}'));
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentRendererTests.Render_BoldItalicUnderlineRun_EmitsControlWords;
var
  LDocument: TWARichDocument;
  LRtf: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph.AddRun('Styled', TWARunFormat.Create(True, True, True, '', 0));
    LRtf := TWARtfDocumentRenderer.Render(LDocument);

    Assert.Contains(LRtf, '\b');
    Assert.Contains(LRtf, '\i');
    Assert.Contains(LRtf, '\ul');
    Assert.Contains(LRtf, 'Styled');
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentRendererTests.Render_ParagraphAlignment_EmitsAlignmentControlWord;
var
  LDocument: TWARichDocument;
  LRtf: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph(taRightAlign).AddRun('Right', TWARunFormat.Plain);
    LRtf := TWARtfDocumentRenderer.Render(LDocument);

    Assert.Contains(LRtf, '\qr');
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentRendererTests.Render_FontNameAndSize_EmitsFontTableReferenceAndHalfPointSize;
var
  LDocument: TWARichDocument;
  LRtf: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph.AddRun('Sized', TWARunFormat.Create(False, False, False, 'Consolas', 14));
    LRtf := TWARtfDocumentRenderer.Render(LDocument);

    Assert.Contains(LRtf, 'Consolas;');
    Assert.Contains(LRtf, '\fs28');
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentRendererTests.Render_Table_EmitsTrowdIntblCellRow;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
  LRtf: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LTable := LDocument.AddTable(1, 2, 1);
    LTable.Rows[0].Cells[0].AddRun('A', TWARunFormat.Plain);
    LTable.Rows[0].Cells[1].AddRun('B', TWARunFormat.Plain);
    LRtf := TWARtfDocumentRenderer.Render(LDocument);

    Assert.Contains(LRtf, '\trowd');
    Assert.Contains(LRtf, '\intbl');
    Assert.Contains(LRtf, '\cell');
    Assert.Contains(LRtf, '\row');
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentRendererTests.Render_EscapesBackslashAndBraces;
var
  LDocument: TWARichDocument;
  LRtf: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph.AddRun('a\b{c}', TWARunFormat.Plain);
    LRtf := TWARtfDocumentRenderer.Render(LDocument);

    Assert.Contains(LRtf, 'a\\b\{c\}');
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentRendererTests.Render_NonAsciiCharacter_EmitsUnicodeEscape;
var
  LDocument: TWARichDocument;
  LRtf: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph.AddRun('caf' + Chr(233), TWARunFormat.Plain); // 'é'
    LRtf := TWARtfDocumentRenderer.Render(LDocument);

    Assert.Contains(LRtf, '\u233?');
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentRendererTests.Render_UnorderedList_EmitsBulletMarkerPerItem;
var
  LDocument: TWARichDocument;
  LList: TWAListBlock;
  LRtf: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LList := LDocument.AddList(lkUnordered);
    LList.AddItem.AddRun('First', TWARunFormat.Plain);
    LList.AddItem.AddRun('Second', TWARunFormat.Plain);
    LRtf := TWARtfDocumentRenderer.Render(LDocument);

    Assert.Contains(LRtf, '\fi-360\li720');
    Assert.Contains(LRtf, '\bullet\tab');
    Assert.Contains(LRtf, 'First');
    Assert.Contains(LRtf, 'Second');
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentRendererTests.Render_OrderedList_EmitsIncrementingNumberMarkerPerItem;
var
  LDocument: TWARichDocument;
  LList: TWAListBlock;
  LRtf: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LList := LDocument.AddList(lkOrdered);
    LList.AddItem.AddRun('First', TWARunFormat.Plain);
    LList.AddItem.AddRun('Second', TWARunFormat.Plain);
    LRtf := TWARtfDocumentRenderer.Render(LDocument);

    Assert.Contains(LRtf, '1.\tab');
    Assert.Contains(LRtf, '2.\tab');
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentRendererTests.Render_LineBreakRun_EmitsSingleLineControlWordNotPar;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
  LRtf: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LParagraph := LDocument.AddParagraph;
    LParagraph.AddRun('Line one', TWARunFormat.Plain);
    LParagraph.Runs.Add(TWARun.CreateLineBreak);
    LParagraph.AddRun('Line two', TWARunFormat.Plain);

    LRtf := TWARtfDocumentRenderer.Render(LDocument);

    // A single paragraph: if the line break had wrongly closed one
    // paragraph and opened another, there would be a second \par
    // terminator. Search for '\par' + a line break specifically since
    // '\par' alone is also a prefix of '\pard'.
    Assert.Contains(LRtf, '\line');
    Assert.AreEqual(1, CountOccurrences(LRtf, '\par' + sLineBreak));
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentRendererTests.Render_ParagraphWithBorder_EmitsBorderControlWords;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
  LRtf: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LParagraph := LDocument.AddParagraph;
    LParagraph.HasBorder := True;
    LParagraph.AddRun('Boxed', TWARunFormat.Plain);

    LRtf := TWARtfDocumentRenderer.Render(LDocument);

    Assert.Contains(LRtf, '\brdrl');
    Assert.Contains(LRtf, '\brdrr');
    Assert.Contains(LRtf, '\brdrt');
    Assert.Contains(LRtf, '\brdrb');
  finally
    LDocument.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWARtfDocumentRendererTests);

end.
