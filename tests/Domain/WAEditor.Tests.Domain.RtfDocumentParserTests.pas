unit WAEditor.Tests.Domain.RtfDocumentParserTests;

interface

uses
  System.SysUtils,
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

    [Test]
    procedure Parse_BlankRtfLine_IsPreservedAsEmptyParagraph;

    [Test]
    procedure Parse_ConsecutiveBlankRtfLines_ProduceOneEmptyParagraphEach;

    [Test]
    procedure Parse_LineControlWord_InsertsLineBreakRunWithoutSplittingParagraph;

    [Test]
    procedure Parse_BorderControlWords_SetHasBorderOnParagraph;

    [Test]
    procedure Parse_PlainControlWord_ResetsCharacterFormattingBetweenParagraphs;

    [Test]
    procedure Parse_FormCheckboxField_Checked_ProducesCheckedCheckboxRun;

    [Test]
    procedure Parse_FormCheckboxField_RadioOff_ProducesUncheckedRadioRun;

    [Test]
    procedure Parse_TextImmediatelyAfterCheckboxField_IsNotMergedIntoCheckboxRun;

    [Test]
    procedure Parse_CellxPositions_DeriveColumnWidthsFromCumulativeDifferences;

    [Test]
    procedure Parse_CellBorderControlWords_SetTableBorderWidthFromTwips;

    [Test]
    procedure Parse_RealWorldWPToolsCellBorders_SetTableBorderWidth;

    [Test]
    procedure Parse_TableWithoutCellBorderControlWords_IsBorderless;
    [Test]
    procedure Parse_TableCellAlignment_IsKeptPerCell;
    [Test]
    procedure Parse_HorizontalMerge_BecomesColSpan;
    [Test]
    procedure Parse_RowsWithDifferentCellx_ShareUnionGrid;
    [Test]
    procedure Parse_RowWithNewEdge_SplitsGridForEveryRow;

    [Test]
    procedure Parse_RowsWithTwipsWidth_AreFittedToTheTableRightEdge;

    [Test]
    procedure Parse_CellBordersWithoutWidth_AreBorderedWithDefaultWidth;

    [Test]
    procedure Parse_WPToolsRowGroups_AreMergedIntoOneTable;

    [Test]
    procedure Parse_NegativeFirstLineIndentInsideCell_DoesNotStartAList;

    [Test]
    procedure Parse_SuperControlWord_SetsSuperscriptOnRunFormat;

    [Test]
    procedure Parse_SubControlWord_SetsSubscriptOnRunFormat;

    [Test]
    procedure Parse_PictGroup_ProducesImageRunWithDecodedBytesAndGoalDimensions;

    [Test]
    procedure Parse_PictGroupJpeg_SetsJpegFormat;

    [Test]
    procedure Parse_PictWmetafileWithBitmap_ProducesBmpImageRun;

    [Test]
    procedure Parse_PictDibitmap_ProducesBmpImageRun;

    [Test]
    procedure Parse_ParInsideTableCell_BecomesLineBreakBetweenLines;

    [Test]
    procedure Parse_PlainRunGroupStartingWithSpace_PreservesLeadingSpace;

    [Test]
    procedure Parse_CascadeOfSuperscriptAndSubscriptRuns_PreservesSurroundingSpaces;

    [Test]
    procedure Parse_FormCheckboxFieldInsideTableCell_ProducesCheckboxRunInCell;

    [Test]
    procedure Parse_FormCheckboxRadioInsideTableCell_ProducesRadioRunInCell;

    [Test]
    procedure Parse_ColorTableAndCf_SetsRunColor;

    [Test]
    procedure Parse_WPToolsShadedCell_SetsBackgroundAndTextColor;

    [Test]
    procedure Parse_CellShadingWithoutPatternColor_BlendsOverWhite;
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
    // The leading and trailing \pard\plain\par are blank lines and are
    // now preserved as their own empty paragraphs (see
    // Parse_BlankRtfLine_IsPreservedAsEmptyParagraph), so the list sits
    // between them rather than being the document's only block.
    Assert.AreEqual(3, LDocument.Blocks.Count);
    LList := TWAListBlock(LDocument.Blocks[1]);
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

procedure TWARtfDocumentParserTests.Parse_BlankRtfLine_IsPreservedAsEmptyParagraph;
var
  LDocument: TWARichDocument;
begin
  // A \par with nothing between it and the preceding \pard is a blank
  // line in the source document and must survive as an empty paragraph,
  // not vanish: otherwise the line break it represents is lost, and
  // renderers that add spacing per <p> end up misrepresenting the gap
  // between the surrounding real paragraphs.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard\ql First\par\pard\ql \par\pard\ql Second\par}');
  try
    Assert.AreEqual(3, LDocument.Blocks.Count);
    Assert.AreEqual('First', TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Text);
    Assert.AreEqual(0, TWAParagraphBlock(LDocument.Blocks[1]).Runs.Count);
    Assert.AreEqual('Second', TWAParagraphBlock(LDocument.Blocks[2]).Runs[0].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_ConsecutiveBlankRtfLines_ProduceOneEmptyParagraphEach;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard\ql First\par\pard\ql \par\pard\ql \par\pard\ql Second\par}');
  try
    Assert.AreEqual(4, LDocument.Blocks.Count);
    Assert.AreEqual(0, TWAParagraphBlock(LDocument.Blocks[1]).Runs.Count);
    Assert.AreEqual(0, TWAParagraphBlock(LDocument.Blocks[2]).Runs.Count);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_LineControlWord_InsertsLineBreakRunWithoutSplittingParagraph;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
begin
  // \line is a soft break within one paragraph, not a paragraph
  // boundary: it must not produce a second TWAParagraphBlock (which
  // would turn one line break into two <p> when rendered to HTML).
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard\ql Line one\line Line two\par}');
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

procedure TWARtfDocumentParserTests.Parse_BorderControlWords_SetHasBorderOnParagraph;
var
  LDocument: TWARichDocument;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard\plain\brdrl\brdrs\brdrr\brdrs\brdrt\brdrs\brdrb\brdrs\plain Boxed\par' +
    '\pard\ql Not boxed\par}');
  try
    Assert.IsTrue(TWAParagraphBlock(LDocument.Blocks[0]).HasBorder);
    Assert.IsFalse(TWAParagraphBlock(LDocument.Blocks[1]).HasBorder);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_PlainControlWord_ResetsCharacterFormattingBetweenParagraphs;
var
  LDocument: TWARichDocument;
begin
  // Writers that don't scope each run in its own {...} group rely on
  // \plain between paragraphs to reset bold/italic/underline/font; if
  // \plain is ignored, formatting bleeds from one paragraph into the
  // next one that doesn't explicitly override it.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard\ql \plain\b Bold text\par' +
    '\pard\ql \plain Plain text\par}');
  try
    Assert.IsTrue(TWAParagraphBlock(LDocument.Blocks[0]).Runs[0].Format.Bold);
    Assert.IsFalse(TWAParagraphBlock(LDocument.Blocks[1]).Runs[0].Format.Bold);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_FormCheckboxField_Checked_ProducesCheckedCheckboxRun;
var
  LDocument: TWARichDocument;
  LRun: TWARun;
begin
  // Matches WPTools' own serialization of a checked FORMCHECKBOX field.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard\ql ' +
    '{\field{\*\fldinst{FORMCHECKBOX _Check=true}}{\*\fldrslt{true}}} Teste\par}');
  try
    LRun := TWAParagraphBlock(LDocument.Blocks[0]).Runs[0];
    Assert.IsTrue(LRun.IsCheckbox);
    Assert.IsTrue(LRun.IsChecked);
    Assert.IsFalse(LRun.IsRadio);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_FormCheckboxField_RadioOff_ProducesUncheckedRadioRun;
var
  LDocument: TWARichDocument;
  LRun: TWARun;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard\ql ' +
    '{\field{\*\fldinst{FORMCHECKBOX _Radio=off}}{\*\fldrslt{off}}} Teste\par}');
  try
    LRun := TWAParagraphBlock(LDocument.Blocks[0]).Runs[0];
    Assert.IsTrue(LRun.IsCheckbox);
    Assert.IsFalse(LRun.IsChecked);
    Assert.IsTrue(LRun.IsRadio);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_TextImmediatelyAfterCheckboxField_IsNotMergedIntoCheckboxRun;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
begin
  // AppendChar's "merge into the last run if the format matches"
  // optimization did not check IsCheckbox, so plain text typed right
  // after a FORMCHECKBOX field silently got absorbed into that
  // (textless) checkbox run's Text property instead of starting its
  // own run -- the run stayed IsCheckbox=True and the text became
  // invisible to anything that branched on that flag.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard\ql ' +
    '{\field{\*\fldinst{FORMCHECKBOX _Check=false}}{\*\fldrslt{false}}}ABC\par}');
  try
    LParagraph := TWAParagraphBlock(LDocument.Blocks[0]);
    Assert.AreEqual(2, LParagraph.Runs.Count);
    Assert.IsTrue(LParagraph.Runs[0].IsCheckbox);
    Assert.AreEqual('', LParagraph.Runs[0].Text);
    Assert.IsFalse(LParagraph.Runs[1].IsCheckbox);
    Assert.AreEqual('ABC', LParagraph.Runs[1].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_CellxPositions_DeriveColumnWidthsFromCumulativeDifferences;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
begin
  // \cellx values are cumulative right-edge positions, not per-column
  // widths: column widths must come from consecutive differences
  // (3495, then 4500-3495=1005), not the raw \cellx values themselves.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '\trowd\cellx3495\cellx4500' +
    '\pard\intbl A\cell' +
    '\pard\intbl B\cell' +
    '\row' +
    '}}');
  try
    LTable := TWATableBlock(LDocument.Blocks[0]);
    Assert.AreEqual(2, Length(LTable.ColumnWidths));
    Assert.AreEqual(3495, LTable.ColumnWidths[0]);
    Assert.AreEqual(1005, LTable.ColumnWidths[1]);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_CellBorderControlWords_SetTableBorderWidthFromTwips;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
begin
  // \brdrw is in twips; this project's renderer emits BorderWidth * 20,
  // so 20 twips must come back as a BorderWidth of 1.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '\trowd\clbrdrl\brdrs\brdrw20\clbrdrt\brdrs\brdrw20\clbrdrr\brdrs\brdrw20\clbrdrb\brdrs\brdrw20\cellx2000' +
    '\pard\intbl A\cell' +
    '\row' +
    '}}');
  try
    LTable := TWATableBlock(LDocument.Blocks[0]);
    Assert.AreEqual(1, LTable.BorderWidth);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_RealWorldWPToolsCellBorders_SetTableBorderWidth;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
begin
  // Real WPTools output orders the sides differently (right/top/left/
  // bottom) and uses a thinner \brdrw10 (0.5pt); a value below 20 twips
  // still must produce a visible border rather than falling back to 0.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '\trowd\clbrdrr\brdrs\brdrw10\clbrdrt\brdrs\brdrw10\clbrdrl\brdrs\brdrw10\clbrdrb\brdrs\brdrw10\cellx2000' +
    '\pard\intbl A\cell' +
    '\row' +
    '}}');
  try
    LTable := TWATableBlock(LDocument.Blocks[0]);
    Assert.AreEqual(1, LTable.BorderWidth);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_HorizontalMerge_BecomesColSpan;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
begin
  // \clmgf starts a merge, \clmrg continues it: three grid columns, the
  // first two merged into one cell spanning 2 (HTML colspan="2").
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '\trowd\clmgf\cellx1000\clmrg\cellx2500\cellx3000' +
    '\pard\intbl {Merged}\cell\pard\intbl \cell\pard\intbl {C}\cell\row' +
    '\trowd\cellx1000\cellx2500\cellx3000' +
    '\pard\intbl {1}\cell\pard\intbl {2}\cell\pard\intbl {3}\cell\row}}');
  try
    LTable := TWATableBlock(LDocument.Blocks[0]);
    Assert.AreEqual(2, LTable.Rows[0].Cells.Count);
    Assert.AreEqual(2, LTable.Rows[0].Cells[0].ColSpan);
    Assert.AreEqual('Merged', LTable.Rows[0].Cells[0].Runs[0].Text);
    Assert.AreEqual(1, LTable.Rows[0].Cells[1].ColSpan);
    Assert.AreEqual('C', LTable.Rows[0].Cells[1].Runs[0].Text);
    Assert.AreEqual(3, LTable.Rows[1].Cells.Count);
    // The grid keeps all three columns.
    Assert.AreEqual(3, Length(LTable.ColumnWidths));
    Assert.AreEqual(1500, LTable.ColumnWidths[1]);
  finally
    LDocument.Free;
  end;

  // Continuation written as a bare \cell, with no \pard\intbl paragraph.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '\trowd\clmgf\cellx1000\clmrg\cellx2000\cellx3000' +
    '\pard\intbl {Merged}\cell\cell\pard\intbl {C}\cell\row}}');
  try
    LTable := TWATableBlock(LDocument.Blocks[0]);
    Assert.AreEqual(2, LTable.Rows[0].Cells.Count);
    Assert.AreEqual(2, LTable.Rows[0].Cells[0].ColSpan);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_RowsWithDifferentCellx_ShareUnionGrid;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
begin
  // Reported case (WPTools forms): every row has its own \cellx set. A
  // 2-cell row under a 3-cell row must keep its real widths, so its first
  // cell spans the first two grid columns. An edge 10 twips off (3010) is
  // the same grid edge, not a sliver column.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '\trowd\cellx1000\cellx2000\cellx3000' +
    '\pard\intbl {A}\cell\pard\intbl {B}\cell\pard\intbl {C}\cell\row' +
    '\trowd\cellx2000\cellx3000' +
    '\pard\intbl {X}\cell\pard\intbl {Y}\cell\row' +
    '\trowd\cellx1000\cellx3010' +
    '\pard\intbl {P}\cell\pard\intbl {Q}\cell\row}}');
  try
    LTable := TWATableBlock(LDocument.Blocks[0]);
    Assert.AreEqual(3, Length(LTable.ColumnWidths));
    Assert.AreEqual(1000, LTable.ColumnWidths[0]);
    Assert.AreEqual(1000, LTable.ColumnWidths[1]);
    Assert.AreEqual(1000, LTable.ColumnWidths[2]);
    Assert.AreEqual(1, LTable.Rows[0].Cells[0].ColSpan);
    Assert.AreEqual(2, LTable.Rows[1].Cells[0].ColSpan);
    Assert.AreEqual('X', LTable.Rows[1].Cells[0].Runs[0].Text);
    Assert.AreEqual(1, LTable.Rows[1].Cells[1].ColSpan);
    Assert.AreEqual(1, LTable.Rows[2].Cells[0].ColSpan);
    Assert.AreEqual(2, LTable.Rows[2].Cells[1].ColSpan);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_RowsWithTwipsWidth_AreFittedToTheTableRightEdge;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
  LRowIndex, LCellIndex, LGridIndex, LSpan, LEdge: Integer;
begin
  // AIH form (WPTools): every row says \trftsWidth3\trwWidth8916 with
  // \trleft-30, so it ends at 8886. WPTools draws a row ending at 8475
  // widened to 8886 and one ending at 9896 cut at 8886; without the fit
  // they came out ragged, with a cell sticking out of the table.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '{\trowd\trleft-30\trftsWidth3\trwWidth8916\cellx7403\cellx8886' +
    '\pard\intbl {Nome}\cell\pard\intbl {CNES}\cell\row}' +
    '{\trowd\trleft-30\trftsWidth3\trwWidth8916\cellx6392\cellx8473\cellx9896' +
    '\pard\intbl {Mae}\cell\pard\intbl {Telefone}\cell\pard\intbl \cell\row}' +
    '{\trowd\trleft-30\trftsWidth3\trwWidth8916\cellx6392\cellx7402\clmrg\cellx8475' +
    '\pard\intbl {MAE}\cell\pard\intbl {TEL}\cell\pard\intbl \cell\row}' +
    '{\trowd\cellx3000' +
    '\pard\intbl {Sem largura}\cell\row}}}');
  try
    LTable := TWATableBlock(LDocument.Blocks[0]);
    Assert.AreEqual(4, LTable.Rows.Count);
    // Right edge of the last cell of each row
    for LRowIndex := 0 to 2 do
    begin
      LEdge := LTable.LeftOffsetTwips;
      LGridIndex := 0;
      for LCellIndex := 0 to LTable.Rows[LRowIndex].Cells.Count - 1 do
        for LSpan := 1 to LTable.Rows[LRowIndex].Cells[LCellIndex].ColSpan do
        begin
          Inc(LEdge, LTable.ColumnWidths[LGridIndex]);
          Inc(LGridIndex);
        end;
      Assert.AreEqual(8886, LEdge, 'right edge of row ' + LRowIndex.ToString);
    end;
    // No grid column past the table's right edge (9896 is gone)
    LEdge := 0;
    for LGridIndex := 0 to High(LTable.ColumnWidths) do
      Inc(LEdge, LTable.ColumnWidths[LGridIndex]);
    Assert.AreEqual(8886, LEdge, 'grid width');
    Assert.AreEqual(3, LTable.Rows[1].Cells.Count);
    Assert.AreEqual(2, LTable.Rows[2].Cells.Count);
    // A row without \trwWidth keeps its own \cellx (3000)
    Assert.AreEqual(1, LTable.Rows[3].Cells.Count);
    Assert.AreEqual(3000, LTable.ColumnWidths[0]);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_RowWithNewEdge_SplitsGridForEveryRow;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
begin
  // A later row with an edge (1500) the first row does not have splits
  // that grid column for the whole table: the first row's cell that
  // covers it now spans two columns, together with a \clmrg merge.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '\trowd\cellx1000\clmgf\cellx2000\clmrg\cellx3000' +
    '\pard\intbl {A}\cell\pard\intbl {B}\cell\pard\intbl \cell\row' +
    '\trowd\cellx1500\cellx3000' +
    '\pard\intbl {X}\cell\pard\intbl {Y}\cell\row}}');
  try
    LTable := TWATableBlock(LDocument.Blocks[0]);
    Assert.AreEqual(4, Length(LTable.ColumnWidths));
    Assert.AreEqual(500, LTable.ColumnWidths[1]);
    Assert.AreEqual(2, LTable.Rows[0].Cells.Count);
    Assert.AreEqual(1, LTable.Rows[0].Cells[0].ColSpan);
    Assert.AreEqual(3, LTable.Rows[0].Cells[1].ColSpan);
    Assert.AreEqual(2, LTable.Rows[1].Cells[0].ColSpan);
    Assert.AreEqual(2, LTable.Rows[1].Cells[1].ColSpan);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_TableCellAlignment_IsKeptPerCell;
var
  LDocument: TWARichDocument;
  LRow: TWATableRow;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '\trowd\cellx1000\cellx2000\cellx3000' +
    '\pard\intbl\qc {A}\cell\pard\intbl\qr {B}\cell\pard\intbl {C}\cell\row}}');
  try
    LRow := TWATableBlock(LDocument.Blocks[0]).Rows[0];
    Assert.AreEqual(3, LRow.Cells.Count);
    Assert.AreEqual(Ord(taCenterAlign), Ord(LRow.Cells[0].Alignment));
    Assert.AreEqual(Ord(taRightAlign), Ord(LRow.Cells[1].Alignment));
    Assert.AreEqual(Ord(taLeftAlign), Ord(LRow.Cells[2].Alignment));
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_TableWithoutCellBorderControlWords_IsBorderless;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '\trowd\cellx2000' +
    '\pard\intbl A\cell' +
    '\row' +
    '}}');
  try
    LTable := TWATableBlock(LDocument.Blocks[0]);
    Assert.AreEqual(0, LTable.BorderWidth);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_CellBordersWithoutWidth_AreBorderedWithDefaultWidth;
var
  LDocument: TWARichDocument;
begin
  // WPTools marks a bordered cell with \clbrdrt\brdrs etc. and no
  // \brdrw at all.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '\trowd\clbrdrt\brdrs\clbrdrl\brdrs\cellx2000' +
    '\pard\intbl A\cell' +
    '\row' +
    '}}');
  try
    Assert.AreEqual(1, TWATableBlock(LDocument.Blocks[0]).BorderWidth);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_WPToolsRowGroups_AreMergedIntoOneTable;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
begin
  // WPTools writes every row as its own {\trowd...\row} group inside one
  // \tblstart/\tblend span; each used to become a separate table.
  // \tblend then separates two genuinely distinct adjacent tables.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \tblstart1' +
    '{\trowd\clbrdrt\brdrs\cellx2000\pard\intbl A\cell\row}' +
    '{\trowd\clbrdrt\brdrs\cellx2000\pard\intbl B\cell\row}' +
    '\tblend1\tblstart1' +
    '{\trowd\cellx2000\pard\intbl C\cell\row}' +
    '\tblend1}');
  try
    Assert.AreEqual(2, LDocument.Blocks.Count);
    LTable := TWATableBlock(LDocument.Blocks[0]);
    Assert.AreEqual(2, LTable.Rows.Count);
    Assert.AreEqual(1, LTable.BorderWidth);
    LTable := TWATableBlock(LDocument.Blocks[1]);
    Assert.AreEqual(1, LTable.Rows.Count);
    Assert.AreEqual(0, LTable.BorderWidth);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_NegativeFirstLineIndentInsideCell_DoesNotStartAList;
var
  LDocument: TWARichDocument;
begin
  // A hanging indent (\fi-3075) in a cell paragraph is just indentation;
  // outside a cell it is this project's list-item marker.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {\trowd\cellx2000\pard\intbl\fi-3075 A\cell\row}}');
  try
    Assert.AreEqual(1, LDocument.Blocks.Count);
    Assert.IsTrue(LDocument.Blocks[0] is TWATableBlock);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_SuperControlWord_SetsSuperscriptOnRunFormat;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard sergio{\super 11}\par}');
  try
    LParagraph := TWAParagraphBlock(LDocument.Blocks[0]);
    Assert.AreEqual(2, LParagraph.Runs.Count);
    Assert.AreEqual('11', LParagraph.Runs[1].Text);
    Assert.IsTrue(LParagraph.Runs[1].Format.Superscript);
    Assert.IsFalse(LParagraph.Runs[1].Format.Subscript);
    Assert.IsFalse(LParagraph.Runs[0].Format.Superscript);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_SubControlWord_SetsSubscriptOnRunFormat;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard sergio{\sub 22}\par}');
  try
    LParagraph := TWAParagraphBlock(LDocument.Blocks[0]);
    Assert.AreEqual(2, LParagraph.Runs.Count);
    Assert.AreEqual('22', LParagraph.Runs[1].Text);
    Assert.IsTrue(LParagraph.Runs[1].Format.Subscript);
    Assert.IsFalse(LParagraph.Runs[1].Format.Superscript);
    Assert.IsFalse(LParagraph.Runs[0].Format.Subscript);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_PlainRunGroupStartingWithSpace_PreservesLeadingSpace;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
begin
  // A plain-text run that happens to start with a space (e.g. right
  // after a superscript/subscript span closes) is still just an
  // ordinary nested {...} group. The group dispatcher must not treat
  // its leading space as cosmetic whitespace ahead of a destination
  // keyword (as it would for "{ \fonttbl ...}") and discard it.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard {\super 2+}{ and CO}\par}');
  try
    LParagraph := TWAParagraphBlock(LDocument.Blocks[0]);
    Assert.AreEqual(2, LParagraph.Runs.Count);
    Assert.AreEqual('2+', LParagraph.Runs[0].Text);
    Assert.AreEqual(' and CO', LParagraph.Runs[1].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_CascadeOfSuperscriptAndSubscriptRuns_PreservesSurroundingSpaces;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
  LText: string;
  I: Integer;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard {H}{\sub 2}{O}{\super 2+}{ and CO}{\sub 2}{ plus x}{\super 2}{y}{\super 3}\par}');
  try
    LParagraph := TWAParagraphBlock(LDocument.Blocks[0]);
    LText := '';
    for I := 0 to LParagraph.Runs.Count - 1 do
      LText := LText + LParagraph.Runs[I].Text;
    Assert.AreEqual('H2O2+ and CO2 plus x2y3', LText);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_FormCheckboxFieldInsideTableCell_ProducesCheckboxRunInCell;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
  LCell: TWATableCell;
begin
  // ParseTableGroup used to dispatch every nested "{" straight into
  // plain ParseGroup without checking for a recognized destination
  // keyword first, so a {\field{\*\fldinst ...}{\*\fldrslt ...}}
  // checkbox inside a cell fell into ParseGroup's own nested-group
  // handling, which treated the \*-marked \fldinst/\fldrslt groups as
  // generic ignorable destinations and discarded the whole field.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '\trowd\cellx2000' +
    '\pard\intbl {\field{\*\fldinst{FORMCHECKBOX _Check=true}}{\*\fldrslt{true}}}{texto}\cell' +
    '\row' +
    '}}');
  try
    LTable := TWATableBlock(LDocument.Blocks[0]);
    LCell := LTable.Rows[0].Cells[0];
    Assert.AreEqual(2, LCell.Runs.Count);
    Assert.IsTrue(LCell.Runs[0].IsCheckbox);
    Assert.IsTrue(LCell.Runs[0].IsChecked);
    Assert.IsFalse(LCell.Runs[0].IsRadio);
    Assert.AreEqual('texto', LCell.Runs[1].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_FormCheckboxRadioInsideTableCell_ProducesRadioRunInCell;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
  LCell: TWATableCell;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {' +
    '\trowd\cellx2000' +
    '\pard\intbl {\field{\*\fldinst{FORMCHECKBOX _Radio=on}}{\*\fldrslt{on}}}{radio}\cell' +
    '\row' +
    '}}');
  try
    LTable := TWATableBlock(LDocument.Blocks[0]);
    LCell := LTable.Rows[0].Cells[0];
    Assert.AreEqual(2, LCell.Runs.Count);
    Assert.IsTrue(LCell.Runs[0].IsCheckbox);
    Assert.IsTrue(LCell.Runs[0].IsRadio);
    Assert.IsTrue(LCell.Runs[0].IsChecked);
    Assert.AreEqual('radio', LCell.Runs[1].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_PictGroup_ProducesImageRunWithDecodedBytesAndGoalDimensions;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
  LRun: TWARun;
begin
  // \picwgoal/\pichgoal (in twips, at this model's 1px = 15twips
  // reference) are the intended DISPLAY size and are written after
  // \picw/\pich (the native size) by this project's own renderer, so
  // they must win when both are present. Using deliberately different
  // native (10x20) vs. goal (300/150 twips = 20x10) values here proves
  // precedence rather than leaving it ambiguous.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard {\pict\pngblip\picw10\pich20\picwgoal300\pichgoal150 89504e47}\par}');
  try
    LParagraph := TWAParagraphBlock(LDocument.Blocks[0]);
    Assert.AreEqual(1, LParagraph.Runs.Count);
    LRun := LParagraph.Runs[0];
    Assert.IsTrue(LRun.IsImage);
    Assert.AreEqual('png', LRun.ImageFormat);
    Assert.AreEqual(4, Length(LRun.ImageData));
    Assert.AreEqual(Byte($89), LRun.ImageData[0]);
    Assert.AreEqual(Byte($50), LRun.ImageData[1]);
    Assert.AreEqual(Byte($4E), LRun.ImageData[2]);
    Assert.AreEqual(Byte($47), LRun.ImageData[3]);
    Assert.AreEqual(20, LRun.ImageWidthPx);
    Assert.AreEqual(10, LRun.ImageHeightPx);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_PictGroupJpeg_SetsJpegFormat;
var
  LDocument: TWARichDocument;
  LRun: TWARun;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard {\pict\jpegblip\picw5\pich5 ab}\par}');
  try
    LRun := TWAParagraphBlock(LDocument.Blocks[0]).Runs[0];
    Assert.AreEqual('jpeg', LRun.ImageFormat);
    Assert.AreEqual(1, Length(LRun.ImageData));
    Assert.AreEqual(Byte($AB), LRun.ImageData[0]);
    Assert.AreEqual(5, LRun.ImageWidthPx);
    Assert.AreEqual(5, LRun.ImageHeightPx);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_PictWmetafileWithBitmap_ProducesBmpImageRun;
const
  // Header, one META_DIBSTRETCHBLT record carrying a 1x1 24bpp DIB, META_EOF.
  WA_WMF_HEX = '0100090000032f000000000023000000000023000000410b2000cc000100010000000000010001000000000028000000010000000100000001001800000000000400000000000000000000000000000000000000FF00FF00030000000000';
var
  LDocument: TWARichDocument;
  LRun: TWARun;
begin
  // \wmetafile is how WPTools stores a pasted bitmap. A browser cannot
  // show a WMF, so the bitmap must come out as .bmp -- previously it was
  // mislabeled image/png and rendered as a broken image.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard {\pict\wmetafile8\picw100\pich100\picwgoal300\pichgoal300 ' +
    WA_WMF_HEX + '}\par}');
  try
    LRun := TWAParagraphBlock(LDocument.Blocks[0]).Runs[0];
    Assert.IsTrue(LRun.IsImage);
    Assert.AreEqual('bmp', LRun.ImageFormat);
    Assert.AreEqual(14 + 44, Length(LRun.ImageData));
    Assert.AreEqual(Byte(Ord('B')), LRun.ImageData[0]);
    Assert.AreEqual(20, LRun.ImageWidthPx);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_PictDibitmap_ProducesBmpImageRun;
var
  LDocument: TWARichDocument;
  LRun: TWARun;
  LHex: string;
begin
  // A bare 1x1 24bpp DIB: 40-byte BITMAPINFOHEADER + one padded row.
  LHex := '28000000' + '01000000' + '01000000' + '0100' + '1800' + '00000000' +
    '04000000' + '00000000' + '00000000' + '00000000' + '00000000' +
    'FF00FF00';
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 \pard {\pict\dibitmap0\picw1\pich1\picwgoal15\pichgoal15 ' + LHex + '}\par}');
  try
    LRun := TWAParagraphBlock(LDocument.Blocks[0]).Runs[0];
    Assert.IsTrue(LRun.IsImage);
    Assert.AreEqual('bmp', LRun.ImageFormat);
    Assert.AreEqual(14 + Length(LHex) div 2, Length(LRun.ImageData));
    Assert.AreEqual(Byte(Ord('B')), LRun.ImageData[0]);
    Assert.AreEqual(1, LRun.ImageWidthPx);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_ParInsideTableCell_BecomesLineBreakBetweenLines;
var
  LDocument: TWARichDocument;
  LCell: TWATableCell;
begin
  // Two paragraphs inside one cell used to be glued together
  // ("manhaHorarios..."): \par was ignored whenever a cell was open.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 {\trowd\cellx3000\pard\intbl Linha um\par' + #13#10 +
    'Linha dois\par' + #13#10 + '\cell\row}}');
  try
    LCell := TWATableBlock(LDocument.Blocks[0]).Rows[0].Cells[0];
    Assert.AreEqual(3, LCell.Runs.Count);
    Assert.AreEqual('Linha um', LCell.Runs[0].Text);
    Assert.IsTrue(LCell.Runs[1].IsLineBreak);
    Assert.AreEqual('Linha dois', LCell.Runs[2].Text);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_ColorTableAndCf_SetsRunColor;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
begin
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0{\colortbl;\red255\green0\blue0;\red0\green0\blue255;}' +
    '\pard{\cf1 Red}{\cf2 Blue}{\cf0 Auto}\par}');
  try
    LParagraph := TWAParagraphBlock(LDocument.Blocks[0]);
    Assert.AreEqual(3, LParagraph.Runs.Count);
    Assert.IsTrue(LParagraph.Runs[0].Format.HasColor);
    Assert.AreEqual(Integer($FF0000), LParagraph.Runs[0].Format.Color);
    Assert.AreEqual(Integer($0000FF), LParagraph.Runs[1].Format.Color);
    Assert.IsFalse(LParagraph.Runs[2].Format.HasColor, '\cf0 is the automatic color');
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_WPToolsShadedCell_SetsBackgroundAndTextColor;
var
  LDocument: TWARichDocument;
  LRow: TWATableRow;
begin
  // The AIH form's black title bars: WPTools' color table has no empty
  // first entry (index 0 is black, \cf0 still means "normal text"), the
  // cell is \clcfpatK\clcbpatK\clshdng10000 (repeated in the paragraph)
  // and the text is \cf of the white entry.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0{\colortbl\red0\green0\blue0;\red255\green255\blue255;\red0\green0\blue0;}' +
    '{\trowd\trleft-30\clcfpat2\clcbpat2\clshdng10000\cellx3000\cellx6000' +
    '\pard\intbl\qc\clcfpat2\clcbpat2\clshdng10000\plain\cf1\b TITULO\cell' +
    '\pard\intbl\plain\cf0 x\cell\row}}');
  try
    LRow := TWATableBlock(LDocument.Blocks[0]).Rows[0];
    Assert.IsTrue(LRow.Cells[0].HasBackgroundColor);
    Assert.AreEqual(Integer($000000), LRow.Cells[0].BackgroundColor);
    Assert.IsTrue(LRow.Cells[0].Runs[0].Format.HasColor);
    Assert.AreEqual(Integer($FFFFFF), LRow.Cells[0].Runs[0].Format.Color);
    Assert.IsFalse(LRow.Cells[1].HasBackgroundColor, 'the shading must not leak into the next cell');
    Assert.IsFalse(LRow.Cells[1].Runs[0].Format.HasColor);
  finally
    LDocument.Free;
  end;
end;

procedure TWARtfDocumentParserTests.Parse_CellShadingWithoutPatternColor_BlendsOverWhite;
var
  LDocument: TWARichDocument;
  LRow: TWATableRow;
begin
  // \clshdng alone is a percentage of black over white; \clcbpat alone is
  // a plain background color.
  LDocument := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0{\colortbl;\red255\green255\blue0;}' +
    '{\trowd\clshdng2500\cellx3000\clcbpat1\cellx6000\cellx9000' +
    '\pard\intbl a\cell\pard\intbl b\cell\pard\intbl c\cell\row}}');
  try
    LRow := TWATableBlock(LDocument.Blocks[0]).Rows[0];
    Assert.AreEqual(Integer($BFBFBF), LRow.Cells[0].BackgroundColor);
    Assert.AreEqual(Integer($FFFF00), LRow.Cells[1].BackgroundColor);
    Assert.IsFalse(LRow.Cells[2].HasBackgroundColor);
  finally
    LDocument.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWARtfDocumentParserTests);

end.
