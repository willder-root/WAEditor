unit WAEditor.Tests.Domain.RtfDocumentParserTests;

interface

uses
  DUnitX.TestFramework,
  WAEditor.Domain.Types,
  WAEditor.Domain.RichDocument,
  WAEditor.Domain.RtfDocumentParser;

type
  [TestFixture]
  TWARtfDocumentParserTests = class
  public
    [Test]
    procedure Parse_SimpleParagraph_ProducesOneParagraphWithText;

    [Test]
    procedure Parse_BoldControlWord_MarksRunAsBold;

    [Test]
    procedure Parse_BoldOffAfterGroupCloses_DoesNotLeakIntoNextRun;

    [Test]
    procedure Parse_AlignmentControlWord_SetsParagraphAlignment;

    [Test]
    procedure Parse_FontTableReference_ResolvesFontName;

    [Test]
    procedure Parse_FontSizeInHalfPoints_ConvertsToPoints;

    [Test]
    procedure Parse_Table_ProducesRowsAndCellsWithText;

    [Test]
    procedure Parse_EscapedBackslashAndBraces_AreUnescaped;

    [Test]
    procedure Parse_UnicodeEscape_DecodesCodepointAndSkipsFallbackChar;
  end;

implementation

procedure TWARtfDocumentParserTests.Parse_SimpleParagraph_ProducesOneParagraphWithText;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWARtfDocumentParser.Parse('{\rtf1\ansi\deff0 \pard\ql Hello world\par}');
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    Assert.AreEqual('Hello world', TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_BoldControlWord_MarksRunAsBold;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWARtfDocumentParser.Parse('{\rtf1\ansi\deff0 \pard\ql {\b Strong}\par}');
  try
    Assert.IsTrue(TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Format.Bold);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_BoldOffAfterGroupCloses_DoesNotLeakIntoNextRun;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
begin
  LDocument := TWARtfDocumentParser.Parse('{\rtf1\ansi\deff0 \pard\ql {\b Bold} Plain\par}');
  try
    LParagraph := TWAParagraphBlock(LDocument.Blocks[0]);
    Assert.IsTrue(LParagraph.Runs[0].Format.Bold);
    Assert.IsFalse(LParagraph.Runs[1].Format.Bold);
    Assert.AreEqual(' Plain', LParagraph.Runs[1].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_AlignmentControlWord_SetsParagraphAlignment;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWARtfDocumentParser.Parse('{\rtf1\ansi\deff0 \pard\qc Centered\par}');
  try
    Assert.AreEqual(Ord(taCenterAlign), Ord(TWAParagraphBlock(LDocument.Blocks[0]).Alignment));
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_FontTableReference_ResolvesFontName;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0{\fonttbl{\f0 Segoe UI;}{\f1 Consolas;}}\pard\ql {\f1 Code}\par}');
  try
    Assert.AreEqual('Consolas', TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Format.FontName);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_FontSizeInHalfPoints_ConvertsToPoints;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWARtfDocumentParser.Parse('{\rtf1\ansi\deff0 \pard\ql {\fs28 Big}\par}');
  try
    Assert.AreEqual(14, TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Format.FontSizeInPoints);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_Table_ProducesRowsAndCellsWithText;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
  LRtf: string;
begin
  LRtf := '{\rtf1\ansi\deff0 ' +
    '{' +
    '\trowd\cellx2000\cellx4000' +
    '\pard\intbl A1\cell' +
    '\pard\intbl B1\cell' +
    '\row' +
    '}' +
    '}';
  LDocument := TWARtfDocumentParser.Parse(LRtf);
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    LTable := TWATableBlock(LDocument.Blocks[0]);
    Assert.AreEqual(1, LTable.Rows.Count);
    Assert.AreEqual(2, LTable.Rows[0].Cells.Count);
    Assert.AreEqual('A1', LTable.Rows[0].Cells[0].Runs[0].Text);
    Assert.AreEqual('B1', LTable.Rows[0].Cells[1].Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_EscapedBackslashAndBraces_AreUnescaped;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWARtfDocumentParser.Parse('{\rtf1\ansi\deff0 \pard\ql a\\b\{c\}\par}');
  try
    Assert.AreEqual('a\b{c}', TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_UnicodeEscape_DecodesCodepointAndSkipsFallbackChar;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWARtfDocumentParser.Parse('{\rtf1\ansi\deff0 \pard\ql caf\u233?\par}');
  try
    Assert.AreEqual('caf' + Chr(233), TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWARtfDocumentParserTests);

end.
