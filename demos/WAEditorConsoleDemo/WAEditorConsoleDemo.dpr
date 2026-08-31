program WAEditorConsoleDemo;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  WAEditor.Domain.RichDocument in '..\..\src\Domain\WAEditor.Domain.RichDocument.pas',
  WAEditor.Domain.HtmlDocumentParser in '..\..\src\Domain\WAEditor.Domain.HtmlDocumentParser.pas',
  WAEditor.Domain.RtfDocumentRenderer in '..\..\src\Domain\WAEditor.Domain.RtfDocumentRenderer.pas';

const
  // A small WYSIWYG HTML fragment, as if it had just come out of the
  // editor's contentEditable surface: a centered bold title, a
  // paragraph with italic/underline text, and a table.
  WA_SAMPLE_HTML =
    '<p style="text-align:center;"><span style="font-family:Arial;font-size:20pt;"><b>Relatorio Mensal</b></span></p>' +
    '<p style="text-align:left;"><i><u>Resumo dos resultados do periodo.</u></i></p>' +
    '<table border="1"><tr><td>Item</td><td>Valor</td></tr><tr><td>Vendas</td><td>1000</td></tr></table>';

var
  LDocument: TWARichDocument;
  LRtf: string;
begin
  try
    WriteLn('=== HTML de entrada ===');
    WriteLn(WA_SAMPLE_HTML);
    WriteLn;

    LDocument := TWAHtmlDocumentParser.Parse(WA_SAMPLE_HTML);
    try
      LRtf := TWARtfDocumentRenderer.Render(LDocument);
    finally
      LDocument.Free;
    end;

    WriteLn('=== RTF gerado ===');
    WriteLn(LRtf);
  except
    on E: Exception do
      WriteLn('Erro: ', E.ClassName, ': ', E.Message);
  end;

  {$IFNDEF CI}
  WriteLn;
  Write('Pressione ENTER para sair...');
  ReadLn;
  {$ENDIF}
end.
