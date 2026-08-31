unit WAEditor.Tests.Domain.HtmlDocumentParserTests;

interface

uses
  DUnitX.TestFramework,
  WAEditor.Domain.Types,
  WAEditor.Domain.RichDocument,
  WAEditor.Domain.HtmlDocumentParser;

type
  [TestFixture]
  TWAHtmlDocumentParserTests = class
  public
    [Test]
    procedure Parse_SimpleParagraph_ProducesOneParagraphWithText;

    [Test]
    procedure Parse_BoldTag_MarksRunAsBold;

    [Test]
    procedure Parse_LegacyFontTag_SetsFontNameAndApproximateSize;

    [Test]
    procedure Parse_SpanStyleFontFamilyAndSize_SetsRunFormat;

    [Test]
    procedure Parse_ParagraphAlignAttribute_SetsAlignment;

    [Test]
    procedure Parse_DivWithTextAlignStyle_SetsAlignment;

    [Test]
    procedure Parse_Table_ProducesRowsAndCellsWithText;

    [Test]
    procedure Parse_NestedBoldItalic_AppliesBothToInnerRun;

    [Test]
    procedure Parse_HtmlEntities_AreDecoded;

    [Test]
    procedure Parse_UnorderedList_ProducesListBlockWithItems;

    [Test]
    procedure Parse_OrderedList_ProducesOrderedListBlock;

    [Test]
    procedure Parse_BrTag_InsertsLineBreakRunWithoutSplittingParagraph;

    [Test]
    procedure Parse_SingleQuotedMultiWordFontFamily_StripsQuotesAndKeepsSpace;

    [Test]
    procedure Parse_EmptyFontFamilyValue_DoesNotRaise;

    [Test]
    procedure Parse_ListItemWrappingContentInP_DoesNotCreateStrayParagraph;
  end;

implementation

procedure TWAHtmlDocumentParserTests.Parse_SimpleParagraph_ProducesOneParagraphWithText;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWAHtmlDocumentParser.Parse('<p>Hello world</p>');
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    Assert.IsTrue(LDocument.Blocks[0] is TWAParagraphBlock);
    Assert.AreEqual('Hello world', TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_BoldTag_MarksRunAsBold;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWAHtmlDocumentParser.Parse('<p><b>Strong</b></p>');
  try
    Assert.IsTrue(TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Format.Bold);
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_LegacyFontTag_SetsFontNameAndApproximateSize;
var
  LDocument: TWARichDocument;
  LRun: TWARun;
begin
  LDocument := TWAHtmlDocumentParser.Parse('<p><font face="Arial" size="5">Big</font></p>');
  try
    LRun := TWAParagraphBlock(LDocument.Blocks[0]).Runs[0];
    Assert.AreEqual('Arial', LRun.Format.FontName);
    Assert.AreEqual(18, LRun.Format.FontSizeInPoints);
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_SpanStyleFontFamilyAndSize_SetsRunFormat;
var
  LDocument: TWARichDocument;
  LRun: TWARun;
begin
  LDocument := TWAHtmlDocumentParser.Parse(
    '<p><span style="font-family:Consolas;font-size:16pt;">Code</span></p>');
  try
    LRun := TWAParagraphBlock(LDocument.Blocks[0]).Runs[0];
    Assert.AreEqual('Consolas', LRun.Format.FontName);
    Assert.AreEqual(16, LRun.Format.FontSizeInPoints);
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_ParagraphAlignAttribute_SetsAlignment;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWAHtmlDocumentParser.Parse('<p align="center">Centered</p>');
  try
    Assert.AreEqual(Ord(taCenterAlign), Ord(TWAParagraphBlock(LDocument.Blocks[0]).Alignment));
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_DivWithTextAlignStyle_SetsAlignment;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWAHtmlDocumentParser.Parse('<div style="text-align:right;">Right</div>');
  try
    Assert.AreEqual(Ord(taRightAlign), Ord(TWAParagraphBlock(LDocument.Blocks[0]).Alignment));
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_Table_ProducesRowsAndCellsWithText;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
begin
  LDocument := TWAHtmlDocumentParser.Parse(
    '<table border="1"><tr><td>A1</td><td>B1</td></tr><tr><td>A2</td><td>B2</td></tr></table>');
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    LTable := TWATableBlock(LDocument.Blocks[0]);
    Assert.AreEqual(1, LTable.BorderWidth);
    Assert.AreEqual(2, LTable.Rows.Count);
    Assert.AreEqual(2, LTable.Rows[0].Cells.Count);
    Assert.AreEqual('A1', LTable.Rows[0].Cells[0].Runs[0].Text);
    Assert.AreEqual('B2', LTable.Rows[1].Cells[1].Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_NestedBoldItalic_AppliesBothToInnerRun;
var
  LDocument: TWARichDocument;
  LRun: TWARun;
begin
  LDocument := TWAHtmlDocumentParser.Parse('<p><b><i>Both</i></b></p>');
  try
    LRun := TWAParagraphBlock(LDocument.Blocks[0]).Runs[0];
    Assert.IsTrue(LRun.Format.Bold);
    Assert.IsTrue(LRun.Format.Italic);
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_HtmlEntities_AreDecoded;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWAHtmlDocumentParser.Parse('<p>Tom &amp; Jerry &lt;3&gt;</p>');
  try
    Assert.AreEqual('Tom & Jerry <3>', TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_UnorderedList_ProducesListBlockWithItems;
var
  LDocument: TWARichDocument;
  LList: TWAListBlock;
begin
  LDocument := TWAHtmlDocumentParser.Parse('<ul><li>First</li><li>Second</li></ul>');
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    Assert.IsTrue(LDocument.Blocks[0] is TWAListBlock);
    LList := TWAListBlock(LDocument.Blocks[0]);
    Assert.AreEqual(Ord(lkUnordered), Ord(LList.Kind));
    Assert.AreEqual(2, LList.Items.Count);
    Assert.AreEqual('First', LList.Items[0].Runs[0].Text);
    Assert.AreEqual('Second', LList.Items[1].Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_OrderedList_ProducesOrderedListBlock;
var
  LDocument: TWARichDocument;
  LList: TWAListBlock;
begin
  LDocument := TWAHtmlDocumentParser.Parse('<ol><li><b>Step one</b></li></ol>');
  try
    LList := TWAListBlock(LDocument.Blocks[0]);
    Assert.AreEqual(Ord(lkOrdered), Ord(LList.Kind));
    Assert.AreEqual('Step one', LList.Items[0].Runs[0].Text);
    Assert.IsTrue(LList.Items[0].Runs[0].Format.Bold);
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_BrTag_InsertsLineBreakRunWithoutSplittingParagraph;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
begin
  // A <br> is a soft break within one paragraph, not a paragraph
  // boundary: it must not produce a second TWAParagraphBlock (which
  // would turn one line break into two \par when rendered to RTF).
  LDocument := TWAHtmlDocumentParser.Parse('<p>Line one<br>Line two</p>');
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    LParagraph := TWAParagraphBlock(LDocument.Blocks[0]);
    Assert.AreEqual(3, LParagraph.Runs.Count);
    Assert.AreEqual('Line one', LParagraph.Runs[0].Text);
    Assert.IsTrue(LParagraph.Runs[1].IsLineBreak);
    Assert.AreEqual('Line two', LParagraph.Runs[2].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_SingleQuotedMultiWordFontFamily_StripsQuotesAndKeepsSpace;
var
  LDocument: TWARichDocument;
  LRun: TWARun;
begin
  // Matches this renderer's own output: font-family is single-quoted
  // because the surrounding style="..." attribute uses double quotes.
  LDocument := TWAHtmlDocumentParser.Parse(
    '<p><span style="font-family:''Courier New'';font-size:12pt;">Mono</span></p>');
  try
    LRun := TWAParagraphBlock(LDocument.Blocks[0]).Runs[0];
    Assert.AreEqual('Courier New', LRun.Format.FontName);
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_EmptyFontFamilyValue_DoesNotRaise;
var
  LDocument: TWARichDocument;
begin
  // font-family:; (nothing before the separator) must not crash: an
  // empty string split by ',' returns a zero-length array in Delphi, so
  // indexing [0] unconditionally would read out of bounds.
  LDocument := TWAHtmlDocumentParser.Parse(
    '<p><span style="font-family:;font-size:12pt;">Text</span></p>');
  try
    Assert.AreEqual('', TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Format.FontName);
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentParserTests.Parse_ListItemWrappingContentInP_DoesNotCreateStrayParagraph;
var
  LDocument: TWARichDocument;
  LList: TWAListBlock;
begin
  // A live WYSIWYG surface (e.g. MSHTML) commonly wraps each <li>'s
  // content in its own <p>: <ul><li><p>text</p></li></ul>. That nested
  // <p> must not create a stray top-level empty paragraph -- it did,
  // once per list item, growing the document a little on every
  // RTF/HTML round trip through a real editor.
  LDocument := TWAHtmlDocumentParser.Parse(
    '<ul><li><p><span style="font-size:11pt;">First item</span></p></li>' +
    '<li><p><span style="font-size:11pt;">Second item</span></p></li></ul>');
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    LList := TWAListBlock(LDocument.Blocks[0]);
    Assert.AreEqual(2, LList.Items.Count);
    Assert.AreEqual('First item', LList.Items[0].Runs[0].Text);
    Assert.AreEqual('Second item', LList.Items[1].Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWAHtmlDocumentParserTests);

end.
