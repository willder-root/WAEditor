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
  end;

implementation

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

initialization
  TDUnitX.RegisterTestFixture(TWARichDocumentRoundTripTests);

end.
