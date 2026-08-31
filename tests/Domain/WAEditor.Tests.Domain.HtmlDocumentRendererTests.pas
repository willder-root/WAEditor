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

    [Test]
    procedure Render_UnorderedList_EmitsUlWithLiItems;

    [Test]
    procedure Render_OrderedList_EmitsOlWithLiItems;

    [Test]
    procedure Render_Paragraph_EmitsZeroMarginToAvoidHostSpacing;

    [Test]
    procedure Render_LineBreakRun_EmitsSingleBrTagNotNewParagraph;

    [Test]
    procedure Render_MultiWordFontName_IsQuotedInStyle;

    [Test]
    procedure Render_CheckedCheckboxRun_EmitsCheckedInputCheckbox;

    [Test]
    procedure Render_UncheckedRadioRun_EmitsUncheckedInputRadio;
  end;

implementation

uses
  System.SysUtils;

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

    Assert.Contains(LHtml, 'font-family:''Consolas''');
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

procedure TWAHtmlDocumentRendererTests.Render_UnorderedList_EmitsUlWithLiItems;
var
  LDocument: TWARichDocument;
  LList: TWAListBlock;
  LHtml: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LList := LDocument.AddList(lkUnordered);
    LList.AddItem.AddRun('First', TWARunFormat.Plain);
    LList.AddItem.AddRun('Second', TWARunFormat.Plain);
    LHtml := TWAHtmlDocumentRenderer.Render(LDocument);

    Assert.IsTrue(LHtml.StartsWith('<ul>'));
    Assert.IsTrue(LHtml.EndsWith('</ul>'));
    Assert.Contains(LHtml, '<li>First</li>');
    Assert.Contains(LHtml, '<li>Second</li>');
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentRendererTests.Render_OrderedList_EmitsOlWithLiItems;
var
  LDocument: TWARichDocument;
  LList: TWAListBlock;
  LHtml: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LList := LDocument.AddList(lkOrdered);
    LList.AddItem.AddRun('Step one', TWARunFormat.Plain);
    LHtml := TWAHtmlDocumentRenderer.Render(LDocument);

    Assert.IsTrue(LHtml.StartsWith('<ol>'));
    Assert.IsTrue(LHtml.EndsWith('</ol>'));
    Assert.Contains(LHtml, '<li>Step one</li>');
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentRendererTests.Render_Paragraph_EmitsZeroMarginToAvoidHostSpacing;
var
  LDocument: TWARichDocument;
  LHtml: string;
begin
  // Without an explicit margin:0, a host applying its own default <p>
  // margin (e.g. innerHTML in a quirks-mode document, where adjacent
  // margins don't collapse) visibly multiplies the gap a blank RTF line
  // is supposed to represent.
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph.AddRun('Hi', TWARunFormat.Plain);
    LHtml := TWAHtmlDocumentRenderer.Render(LDocument);

    Assert.Contains(LHtml, 'margin:0;');
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentRendererTests.Render_LineBreakRun_EmitsSingleBrTagNotNewParagraph;
var
  LDocument: TWARichDocument;
  LParagraph: TWAParagraphBlock;
  LHtml: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LParagraph := LDocument.AddParagraph;
    LParagraph.AddRun('Line one', TWARunFormat.Plain);
    LParagraph.Runs.Add(TWARun.CreateLineBreak);
    LParagraph.AddRun('Line two', TWARunFormat.Plain);

    LHtml := TWAHtmlDocumentRenderer.Render(LDocument);

    // A single, unsplit paragraph: if <br> had wrongly started a new
    // TWAParagraphBlock, "Line one" and "Line two" would land in
    // separate <p>...</p> elements instead of sharing one.
    Assert.Contains(LHtml, 'Line one<br>Line two');
    Assert.IsFalse(LHtml.Contains('</p><p'));
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentRendererTests.Render_MultiWordFontName_IsQuotedInStyle;
var
  LDocument: TWARichDocument;
  LHtml: string;
begin
  // An unquoted multi-word font-family (font-family:Courier New;) is
  // invalid CSS; MSHTML/Trident silently ignores it instead of applying
  // the font.
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph.AddRun('Monospace',
      TWARunFormat.Create(False, False, False, 'Courier New', 12));
    LHtml := TWAHtmlDocumentRenderer.Render(LDocument);

    Assert.Contains(LHtml, 'font-family:''Courier New'';');
    // Single quotes, never HTML-escaped double quotes: the value must
    // not break out of the surrounding style="..." attribute.
    Assert.IsFalse(LHtml.Contains('&quot;'));
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentRendererTests.Render_CheckedCheckboxRun_EmitsCheckedInputCheckbox;
var
  LDocument: TWARichDocument;
  LHtml: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph.Runs.Add(TWARun.CreateCheckbox(True, False));
    LHtml := TWAHtmlDocumentRenderer.Render(LDocument);

    Assert.Contains(LHtml, '<input type="checkbox" checked>');
  finally
    LDocument.Free;
  end;
end;

procedure TWAHtmlDocumentRendererTests.Render_UncheckedRadioRun_EmitsUncheckedInputRadio;
var
  LDocument: TWARichDocument;
  LHtml: string;
begin
  LDocument := TWARichDocument.Create;
  try
    LDocument.AddParagraph.Runs.Add(TWARun.CreateCheckbox(False, True));
    LHtml := TWAHtmlDocumentRenderer.Render(LDocument);

    Assert.Contains(LHtml, '<input type="radio">');
    Assert.IsFalse(LHtml.Contains('checked'));
  finally
    LDocument.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TWAHtmlDocumentRendererTests);

end.
