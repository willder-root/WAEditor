unit WAEditor.Tests.Domain.RichDocumentRoundTripTests;

interface

uses
  DUnitX.TestFramework,
  WAEditor.Domain.Types,
  WAEditor.Domain.RichDocument,
  WAEditor.Domain.HtmlDocumentRenderer,
  WAEditor.Domain.HtmlDocumentParser,
  WAEditor.Domain.RtfDocumentRenderer,
  WAEditor.Domain.RtfDocumentParser;

type
  [TestFixture]
  TWARichDocumentRoundTripTests = class
  public
    [Test]
    procedure HtmlRoundTrip_PreservesTextFormattingAndAlignment;

    [Test]
    procedure HtmlRoundTrip_PreservesTable;

    [Test]
    procedure RtfRoundTrip_PreservesTextFormattingAndAlignment;

    [Test]
    procedure RtfRoundTrip_PreservesTable;

    [Test]
    procedure HtmlToRtfToHtml_PreservesFormatting;

    [Test]
    procedure HtmlRoundTrip_PreservesOrderedList;

    [Test]
    procedure RtfRoundTrip_PreservesUnorderedListWithFormattedItem;

    [Test]
    procedure HtmlToRtfToHtml_PreservesOrderedList;

    [Test]
    procedure RtfToHtmlToRtf_PreservesCheckboxAndRadioState;

    [Test]
    procedure HtmlToRtfToHtml_PreservesImage;
  end;

implementation

uses
  System.SysUtils,
  System.NetEncoding;

function BuildTestPngBytes(AWidth, AHeight: Word): TBytes;
// A syntactically-minimal PNG: signature + one IHDR chunk carrying the
// requested width/height. No IDAT/IEND -- not viewable by a real image
// decoder, but enough for this project's own byte-preservation and
// TWAImageInfo.TryGetPixelSize round trip, which only reads IHDR.
begin
  SetLength(Result, 33);
  Result[0] := $89; Result[1] := Ord('P'); Result[2] := Ord('N'); Result[3] := Ord('G');
  Result[4] := $0D; Result[5] := $0A; Result[6] := $1A; Result[7] := $0A;
  Result[8] := 0; Result[9] := 0; Result[10] := 0; Result[11] := 13; // chunk length
  Result[12] := Ord('I'); Result[13] := Ord('H'); Result[14] := Ord('D'); Result[15] := Ord('R');
  Result[16] := 0; Result[17] := 0;
  Result[18] := Byte(AWidth shr 8); Result[19] := Byte(AWidth and $FF);
  Result[20] := 0; Result[21] := 0;
  Result[22] := Byte(AHeight shr 8); Result[23] := Byte(AHeight and $FF);
  Result[24] := 8; Result[25] := 6; Result[26] := 0; Result[27] := 0; Result[28] := 0;
  Result[29] := 0; Result[30] := 0; Result[31] := 0; Result[32] := 0; // dummy CRC
end;

function BuildSampleDocument: TWARichDocument;
begin
  Result := TWARichDocument.Create;
  Result.AddParagraph(taCenterAlign).AddRun('Title',
    TWARunFormat.Create(True, False, False, 'Arial', 20));
  Result.AddParagraph(taJustifyAlign).AddRun('Body text',
    TWARunFormat.Create(False, True, True, 'Consolas', 12));
end;

procedure TWARichDocumentRoundTripTests.HtmlRoundTrip_PreservesTextFormattingAndAlignment;
var
  LOriginal, LParsed: TWARichDocument;
  LHtml: string;
  LTitleRun, LBodyRun: TWARun;
begin
  LOriginal := BuildSampleDocument;
  try
    LHtml := TWAHtmlDocumentRenderer.Render(LOriginal);
    LParsed := TWAHtmlDocumentParser.Parse(LHtml);
    try
      Assert.AreEqual(2, LParsed.Blocks.Count);

      Assert.AreEqual(Ord(taCenterAlign), Ord(TWAParagraphBlock(LParsed.Blocks[0]).Alignment));
      LTitleRun := TWAParagraphBlock(LParsed.Blocks[0]).Runs[0];
      Assert.AreEqual('Title', LTitleRun.Text);
      Assert.IsTrue(LTitleRun.Format.Bold);
      Assert.AreEqual('Arial', LTitleRun.Format.FontName);
      Assert.AreEqual(20, LTitleRun.Format.FontSizeInPoints);

      Assert.AreEqual(Ord(taJustifyAlign), Ord(TWAParagraphBlock(LParsed.Blocks[1]).Alignment));
      LBodyRun := TWAParagraphBlock(LParsed.Blocks[1]).Runs[0];
      Assert.AreEqual('Body text', LBodyRun.Text);
      Assert.IsTrue(LBodyRun.Format.Italic);
      Assert.IsTrue(LBodyRun.Format.Underline);
      Assert.AreEqual('Consolas', LBodyRun.Format.FontName);
      Assert.AreEqual(12, LBodyRun.Format.FontSizeInPoints);
    finally
      LParsed.Free;
    end;
  finally
    LOriginal.Free;
  end;
end;

procedure TWARichDocumentRoundTripTests.HtmlRoundTrip_PreservesTable;
var
  LOriginal, LParsed: TWARichDocument;
  LTable: TWATableBlock;
  LHtml: string;
  LParsedTable: TWATableBlock;
begin
  LOriginal := TWARichDocument.Create;
  try
    LTable := LOriginal.AddTable(2, 2, 2);
    LTable.Rows[0].Cells[0].AddRun('A1', TWARunFormat.Plain);
    LTable.Rows[1].Cells[1].AddRun('B2', TWARunFormat.Create(True, False, False, '', 0));

    LHtml := TWAHtmlDocumentRenderer.Render(LOriginal);
    LParsed := TWAHtmlDocumentParser.Parse(LHtml);
    try
      LParsedTable := TWATableBlock(LParsed.Blocks[0]);
      Assert.AreEqual(2, LParsedTable.BorderWidth);
      Assert.AreEqual(2, LParsedTable.Rows.Count);
      Assert.AreEqual('A1', LParsedTable.Rows[0].Cells[0].Runs[0].Text);
      Assert.AreEqual('B2', LParsedTable.Rows[1].Cells[1].Runs[0].Text);
      Assert.IsTrue(LParsedTable.Rows[1].Cells[1].Runs[0].Format.Bold);
    finally
      LParsed.Free;
    end;
  finally
    LOriginal.Free;
  end;
end;

procedure TWARichDocumentRoundTripTests.RtfRoundTrip_PreservesTextFormattingAndAlignment;
var
  LOriginal, LParsed: TWARichDocument;
  LRtf: string;
  LTitleRun, LBodyRun: TWARun;
begin
  LOriginal := BuildSampleDocument;
  try
    LRtf := TWARtfDocumentRenderer.Render(LOriginal);
    LParsed := TWARtfDocumentParser.Parse(LRtf);
    try
      Assert.AreEqual(2, LParsed.Blocks.Count);

      Assert.AreEqual(Ord(taCenterAlign), Ord(TWAParagraphBlock(LParsed.Blocks[0]).Alignment));
      LTitleRun := TWAParagraphBlock(LParsed.Blocks[0]).Runs[0];
      Assert.AreEqual('Title', LTitleRun.Text);
      Assert.IsTrue(LTitleRun.Format.Bold);
      Assert.AreEqual('Arial', LTitleRun.Format.FontName);
      Assert.AreEqual(20, LTitleRun.Format.FontSizeInPoints);

      Assert.AreEqual(Ord(taJustifyAlign), Ord(TWAParagraphBlock(LParsed.Blocks[1]).Alignment));
      LBodyRun := TWAParagraphBlock(LParsed.Blocks[1]).Runs[0];
      Assert.AreEqual('Body text', LBodyRun.Text);
      Assert.IsTrue(LBodyRun.Format.Italic);
      Assert.IsTrue(LBodyRun.Format.Underline);
      Assert.AreEqual('Consolas', LBodyRun.Format.FontName);
      Assert.AreEqual(12, LBodyRun.Format.FontSizeInPoints);
    finally
      LParsed.Free;
    end;
  finally
    LOriginal.Free;
  end;
end;

procedure TWARichDocumentRoundTripTests.RtfRoundTrip_PreservesTable;
var
  LOriginal, LParsed: TWARichDocument;
  LTable, LParsedTable: TWATableBlock;
  LRtf: string;
begin
  LOriginal := TWARichDocument.Create;
  try
    LTable := LOriginal.AddTable(2, 2, 1);
    LTable.Rows[0].Cells[0].AddRun('A1', TWARunFormat.Plain);
    LTable.Rows[1].Cells[1].AddRun('B2', TWARunFormat.Plain);

    LRtf := TWARtfDocumentRenderer.Render(LOriginal);
    LParsed := TWARtfDocumentParser.Parse(LRtf);
    try
      LParsedTable := TWATableBlock(LParsed.Blocks[0]);
      Assert.AreEqual(2, LParsedTable.Rows.Count);
      Assert.AreEqual('A1', LParsedTable.Rows[0].Cells[0].Runs[0].Text);
      Assert.AreEqual('B2', LParsedTable.Rows[1].Cells[1].Runs[0].Text);
    finally
      LParsed.Free;
    end;
  finally
    LOriginal.Free;
  end;
end;

procedure TWARichDocumentRoundTripTests.HtmlToRtfToHtml_PreservesFormatting;
var
  LOriginal, LFromRtf: TWARichDocument;
  LHtml, LRtf, LHtmlAgain: string;
  LRun: TWARun;
begin
  LOriginal := BuildSampleDocument;
  try
    LHtml := TWAHtmlDocumentRenderer.Render(LOriginal);
    LFromRtf := TWAHtmlDocumentParser.Parse(LHtml);
    try
      LRtf := TWARtfDocumentRenderer.Render(LFromRtf);
    finally
      LFromRtf.Free;
    end;

    LFromRtf := TWARtfDocumentParser.Parse(LRtf);
    try
      LHtmlAgain := TWAHtmlDocumentRenderer.Render(LFromRtf);
      Assert.Contains(LHtmlAgain, 'Title');
      Assert.Contains(LHtmlAgain, 'text-align:center');

      LRun := TWAParagraphBlock(LFromRtf.Blocks[1]).Runs[0];
      Assert.AreEqual('Body text', LRun.Text);
      Assert.IsTrue(LRun.Format.Italic);
      Assert.IsTrue(LRun.Format.Underline);
    finally
      LFromRtf.Free;
    end;
  finally
    LOriginal.Free;
  end;
end;

procedure TWARichDocumentRoundTripTests.HtmlRoundTrip_PreservesOrderedList;
var
  LOriginal, LParsed: TWARichDocument;
  LList: TWAListBlock;
  LHtml: string;
  LParsedList: TWAListBlock;
begin
  LOriginal := TWARichDocument.Create;
  try
    LList := LOriginal.AddList(lkOrdered);
    LList.AddItem.AddRun('First', TWARunFormat.Plain);
    LList.AddItem.AddRun('Second', TWARunFormat.Create(True, False, False, '', 0));

    LHtml := TWAHtmlDocumentRenderer.Render(LOriginal);
    LParsed := TWAHtmlDocumentParser.Parse(LHtml);
    try
      Assert.AreEqual(1, LParsed.Blocks.Count);
      LParsedList := TWAListBlock(LParsed.Blocks[0]);
      Assert.AreEqual(Ord(lkOrdered), Ord(LParsedList.Kind));
      Assert.AreEqual('First', LParsedList.Items[0].Runs[0].Text);
      Assert.AreEqual('Second', LParsedList.Items[1].Runs[0].Text);
      Assert.IsTrue(LParsedList.Items[1].Runs[0].Format.Bold);
    finally
      LParsed.Free;
    end;
  finally
    LOriginal.Free;
  end;
end;

procedure TWARichDocumentRoundTripTests.RtfRoundTrip_PreservesUnorderedListWithFormattedItem;
var
  LOriginal, LParsed: TWARichDocument;
  LList: TWAListBlock;
  LRtf: string;
  LParsedList: TWAListBlock;
begin
  LOriginal := TWARichDocument.Create;
  try
    LList := LOriginal.AddList(lkUnordered);
    LList.AddItem.AddRun('Milk', TWARunFormat.Plain);
    LList.AddItem.AddRun('Eggs', TWARunFormat.Create(False, True, False, '', 0));

    LRtf := TWARtfDocumentRenderer.Render(LOriginal);
    LParsed := TWARtfDocumentParser.Parse(LRtf);
    try
      Assert.AreEqual(1, LParsed.Blocks.Count);
      LParsedList := TWAListBlock(LParsed.Blocks[0]);
      Assert.AreEqual(Ord(lkUnordered), Ord(LParsedList.Kind));
      Assert.AreEqual('Milk', LParsedList.Items[0].Runs[0].Text);
      Assert.AreEqual('Eggs', LParsedList.Items[1].Runs[0].Text);
      Assert.IsTrue(LParsedList.Items[1].Runs[0].Format.Italic);
    finally
      LParsed.Free;
    end;
  finally
    LOriginal.Free;
  end;
end;

procedure TWARichDocumentRoundTripTests.HtmlToRtfToHtml_PreservesOrderedList;
var
  LOriginal, LFromRtf: TWARichDocument;
  LHtml, LRtf, LHtmlAgain: string;
  LList: TWAListBlock;
begin
  LOriginal := TWARichDocument.Create;
  try
    LList := LOriginal.AddList(lkOrdered);
    LList.AddItem.AddRun('Step one', TWARunFormat.Plain);
    LList.AddItem.AddRun('Step two', TWARunFormat.Plain);

    LHtml := TWAHtmlDocumentRenderer.Render(LOriginal);
    LFromRtf := TWAHtmlDocumentParser.Parse(LHtml);
    try
      LRtf := TWARtfDocumentRenderer.Render(LFromRtf);
    finally
      LFromRtf.Free;
    end;

    LFromRtf := TWARtfDocumentParser.Parse(LRtf);
    try
      LHtmlAgain := TWAHtmlDocumentRenderer.Render(LFromRtf);
      Assert.Contains(LHtmlAgain, '<ol>');
      Assert.Contains(LHtmlAgain, '<li>Step one</li>');
      Assert.Contains(LHtmlAgain, '<li>Step two</li>');
    finally
      LFromRtf.Free;
    end;
  finally
    LOriginal.Free;
  end;
end;

procedure TWARichDocumentRoundTripTests.RtfToHtmlToRtf_PreservesCheckboxAndRadioState;
var
  LFromRtf, LFromHtml: TWARichDocument;
  LHtml, LRtf2: string;
  LParagraph: TWAParagraphBlock;
begin
  // Modeled on WPTools' own FORMCHECKBOX serialization: a checked
  // checkbox and an unchecked radio button, each inline with real text.
  LFromRtf := TWARtfDocumentParser.Parse(
    '{\rtf1\ansi\deff0 ' +
    '\pard\ql {\field{\*\fldinst{FORMCHECKBOX _Check=true}}{\*\fldrslt{true}}} Um\par' +
    '\pard\ql {\field{\*\fldinst{FORMCHECKBOX _Radio=off}}{\*\fldrslt{off}}} Dois\par' +
    '}');
  try
    LHtml := TWAHtmlDocumentRenderer.Render(LFromRtf);
  finally
    LFromRtf.Free;
  end;

  LFromHtml := TWAHtmlDocumentParser.Parse(LHtml);
  try
    LParagraph := TWAParagraphBlock(LFromHtml.Blocks[0]);
    Assert.IsTrue(LParagraph.Runs[0].IsCheckbox);
    Assert.IsTrue(LParagraph.Runs[0].IsChecked);
    Assert.IsFalse(LParagraph.Runs[0].IsRadio);

    LParagraph := TWAParagraphBlock(LFromHtml.Blocks[1]);
    Assert.IsTrue(LParagraph.Runs[0].IsCheckbox);
    Assert.IsFalse(LParagraph.Runs[0].IsChecked);
    Assert.IsTrue(LParagraph.Runs[0].IsRadio);

    LRtf2 := TWARtfDocumentRenderer.Render(LFromHtml);
  finally
    LFromHtml.Free;
  end;

  Assert.Contains(LRtf2, 'FORMCHECKBOX _Check=true');
  Assert.Contains(LRtf2, 'FORMCHECKBOX _Radio=off');
end;

procedure TWARichDocumentRoundTripTests.HtmlToRtfToHtml_PreservesImage;
var
  LOriginal, LFromHtml, LFromRtf: TWARichDocument;
  LHtml, LRtf, LHtmlAgain: string;
  LImageBytes: TBytes;
  LRun: TWARun;
begin
  // The reported defect: an <img> with an embedded data: URI (exactly
  // what a WYSIWYG surface's own paste/upload produces) was silently
  // dropped on the way to RTF -- there was no image support in either
  // the HTML parser or the RTF renderer/parser at all.
  LImageBytes := BuildTestPngBytes(200, 100);
  LOriginal := TWARichDocument.Create;
  try
    LOriginal.AddParagraph.Runs.Add(TWARun.CreateImage(LImageBytes, 'png', 200, 100));
    LHtml := TWAHtmlDocumentRenderer.Render(LOriginal);
  finally
    LOriginal.Free;
  end;

  Assert.Contains(LHtml, '<img src="data:image/png;base64,');

  LFromHtml := TWAHtmlDocumentParser.Parse(LHtml);
  try
    LRtf := TWARtfDocumentRenderer.Render(LFromHtml);
  finally
    LFromHtml.Free;
  end;

  Assert.Contains(LRtf, '\pict');
  Assert.Contains(LRtf, '\pngblip');

  LFromRtf := TWARtfDocumentParser.Parse(LRtf);
  try
    LHtmlAgain := TWAHtmlDocumentRenderer.Render(LFromRtf);
    Assert.Contains(LHtmlAgain, '<img src="data:image/png;base64,');

    LRun := TWAParagraphBlock(LFromRtf.Blocks[0]).Runs[0];
    Assert.IsTrue(LRun.IsImage);
    Assert.AreEqual('png', LRun.ImageFormat);
    Assert.AreEqual(Length(LImageBytes), Length(LRun.ImageData));
    Assert.AreEqual(200, LRun.ImageWidthPx);
    Assert.AreEqual(100, LRun.ImageHeightPx);
  finally
    LFromRtf.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWARichDocumentRoundTripTests);

end.
