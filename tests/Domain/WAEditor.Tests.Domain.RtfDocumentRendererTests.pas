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
  end;

implementation

uses
  System.SysUtils;

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

initialization
  TDUnitX.RegisterTestFixture(TWARtfDocumentRendererTests);

end.
