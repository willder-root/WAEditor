unit WAEditor.Tests.Domain.HtmlDocumentRendererTests;

interface

uses
  DUnitX.TestFramework,
  WAEditor.Domain.Types,
  WAEditor.Domain.RichDocument,
  WAEditor.Domain.HtmlDocumentRenderer;

type
  [TestFixture]
  TWAHtmlDocumentRendererTests = class
  public
    [Test]
    procedure Render_ParagraphWithBoldRun_WrapsTextInBoldTag;

    [Test]
    procedure Render_ParagraphAlignment_EmitsTextAlignStyle;

    [Test]
    procedure Render_RunWithFontNameAndSize_EmitsInlineStyleSpan;

    [Test]
    procedure Render_Table_EmitsRowsAndCells;

    [Test]
    procedure Render_EscapesHtmlSpecialCharactersInText;
  end;

implementation

procedure TWAHtmlDocumentRendererTests.Render_ParagraphWithBoldRun_WrapsTextInBoldTag;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
  LHtml: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LParagraph := LDocument.AddParagraph(taLeftAlign);
    LParagraph.AddRun('Hello', TWARunFormat.Create(True, False, False, '', 0));
    LHtml := TWAHtmlDocumentRenderer.Render(LDocument);

    Assert.Contains(LHtml, '<b>Hello</b>');
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentRendererTests.Render_ParagraphAlignment_EmitsTextAlignStyle;
var
  LDocument: TWARichDocument;
  LHtml: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph(taCenterAlign).AddRun('Hi', TWARunFormat.Plain);
    LHtml := TWAHtmlDocumentRenderer.Render(LDocument);

    Assert.Contains(LHtml, 'text-align:center');
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentRendererTests.Render_RunWithFontNameAndSize_EmitsInlineStyleSpan;
var
  LDocument: TWARichDocument;
  LHtml: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph.AddRun('Sized',
      TWARunFormat.Create(False, False, False, 'Consolas', 18));
    LHtml := TWAHtmlDocumentRenderer.Render(LDocument);

    Assert.Contains(LHtml, 'font-family:Consolas');
    Assert.Contains(LHtml, 'font-size:18pt');
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentRendererTests.Render_Table_EmitsRowsAndCells;
var
  LDocument: TWARichDocument;
  LTable: TWATableBlock;
  LHtml: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LTable := LDocument.AddTable(2, 3, 1);
    LTable.Rows[0].Cells[0].AddRun('R1C1', TWARunFormat.Plain);
    LHtml := TWAHtmlDocumentRenderer.Render(LDocument);

    Assert.Contains(LHtml, '<table border="1">');
    Assert.Contains(LHtml, 'R1C1');
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentRendererTests.Render_EscapesHtmlSpecialCharactersInText;
var
  LDocument: TWARichDocument;
  LHtml: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph.AddRun('<script>&"quote"</script>', TWARunFormat.Plain);
    LHtml := TWAHtmlDocumentRenderer.Render(LDocument);

    Assert.Contains(LHtml, '&lt;script&gt;&amp;&quot;quote&quot;&lt;/script&gt;');
  finally
    LDocument.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWAHtmlDocumentRendererTests);

end.
