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

initialization
  TDUnitX.RegisterTestFixture(TWAHtmlDocumentParserTests);

end.
