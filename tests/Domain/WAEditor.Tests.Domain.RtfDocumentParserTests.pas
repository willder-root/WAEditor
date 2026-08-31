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

    [Test]
    procedure Parse_UnorderedList_StripsBulletMarkerAndProducesItems;

    [Test]
    procedure Parse_OrderedList_StripsNumberMarkerAndDetectsOrderedKind;

    [Test]
    procedure Parse_ListFollowedByPlainParagraph_ClosesList;

    [Test]
    procedure Parse_IgnorableStarDestination_DoesNotLeakIntoDocument;

    [Test]
    procedure Parse_ColorTableWithoutStarPrefix_DoesNotLeakIntoDocument;

    [Test]
    procedure Parse_RealWorldListtextOrderedList_ProducesOrderedListWithItemText;

    [Test]
    procedure Parse_RealWorldListtextUnorderedList_ProducesUnorderedListFromFontSwitch;
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

procedure TWARtfDocumentParserTests.Parse_UnorderedList_StripsBulletMarkerAndProducesItems;
var
  LDocument: TWARichDocument;
  LList: TWAListBlock;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 ' +
    '\pard\fi-360\li720\ql \bullet\tab {First}\par' +
    '\pard\fi-360\li720\ql \bullet\tab {Second}\par' +
    '}');
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    LList := TWAListBlock(LDocument.Blocks[0]);
    Assert.AreEqual(Ord(lkUnordered), Ord(LList.Kind));
    Assert.AreEqual(2, LList.Items.Count);
    Assert.AreEqual('First', LList.Items[0].Runs[0].Text);
    Assert.AreEqual('Second', LList.Items[1].Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_OrderedList_StripsNumberMarkerAndDetectsOrderedKind;
var
  LDocument: TWARichDocument;
  LList: TWAListBlock;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 ' +
    '\pard\fi-360\li720\ql 1.\tab {First}\par' +
    '\pard\fi-360\li720\ql 2.\tab {Second}\par' +
    '}');
  try
    LList := TWAListBlock(LDocument.Blocks[0]);
    Assert.AreEqual(Ord(lkOrdered), Ord(LList.Kind));
    Assert.AreEqual('First', LList.Items[0].Runs[0].Text);
    Assert.AreEqual('Second', LList.Items[1].Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_ListFollowedByPlainParagraph_ClosesList;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 ' +
    '\pard\fi-360\li720\ql \bullet\tab {Item}\par' +
    '\pard\ql After\par' +
    '}');
  try
    Assert.AreEqual(2, LDocument.Blocks.Count);
    Assert.IsTrue(LDocument.Blocks[0] is TWAListBlock);
    Assert.IsTrue(LDocument.Blocks[1] is TWAParagraphBlock);
    Assert.AreEqual('After', TWAParagraphBlock(LDocument.Blocks[1]).Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_IgnorableStarDestination_DoesNotLeakIntoDocument;
var
  LDocument: TWARichDocument;
begin
  // {\*\generator ...} is the RTF convention for a destination a reader
  // is free to ignore entirely; its text must never become body content.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {\*\generator WPTools_5.202;}\pard\ql Real text\par}');
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    Assert.AreEqual('Real text', TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_ColorTableWithoutStarPrefix_DoesNotLeakIntoDocument;
var
  LDocument: TWARichDocument;
begin
  // Many real-world writers emit {\colortbl ...} without the \* prefix,
  // even though (like \fonttbl) it is never body content either.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {\colortbl\red0\green0\blue0;\red255\green0\blue0;}\pard\ql Real text\par}');
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    Assert.AreEqual('Real text', TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_RealWorldListtextOrderedList_ProducesOrderedListWithItemText;
var
  LDocument: TWARichDocument;
  LList: TWAListBlock;
begin
  // Modeled on real \lsN/\ilvlN list output (e.g. WPTools, Word): the
  // visible marker lives in a {\listtext ...} destination ahead of each
  // item's real text, and only the first item repeats \li/\fi.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 ' +
    '\pard\plain\par' +
    '\ls1\ilvl2{\listtext\fs22 1.\tab}\li360\fi-360\plain\fs22 225526\par' +
    '{\listtext\fs22 2.\tab}\plain\fs22 22665\par' +
    '\pard\plain\par' +
    '}');
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    LList := TWAListBlock(LDocument.Blocks[0]);
    Assert.AreEqual(Ord(lkOrdered), Ord(LList.Kind));
    Assert.AreEqual(2, LList.Items.Count);
    Assert.AreEqual('225526', LList.Items[0].Runs[0].Text);
    Assert.AreEqual('22665', LList.Items[1].Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_RealWorldListtextUnorderedList_ProducesUnorderedListFromFontSwitch;
var
  LDocument: TWARichDocument;
  LList: TWAListBlock;
begin
  // A {\listtext} marker that switches to a non-default font (the classic
  // "single Wingdings/Symbol glyph as a bullet" trick) signals an
  // unordered list, even though its literal fallback text is a letter.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}{\f1 Wingdings;}}' +
    '\ls2\ilvl0{\listtext\f1\fs22 l\tab}\li360\fi-360\plain\fs22 154545\par' +
    '{\listtext\f1\fs22 l\tab}\plain\fs22 51454543453\par' +
    '}');
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    LList := TWAListBlock(LDocument.Blocks[0]);
    Assert.AreEqual(Ord(lkUnordered), Ord(LList.Kind));
    Assert.AreEqual('154545', LList.Items[0].Runs[0].Text);
    Assert.AreEqual('51454543453', LList.Items[1].Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWARtfDocumentParserTests);

end.
