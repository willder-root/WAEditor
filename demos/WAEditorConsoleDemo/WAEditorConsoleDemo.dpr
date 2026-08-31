program WAEditorConsoleDemo;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  WAEditor.Domain.RichDocument in '..\..\src\Domain\WAEditor.Domain.RichDocument.pas',
  WAEditor.Domain.HtmlDocumentParser in '..\..\src\Domain\WAEditor.Domain.HtmlDocumentParser.pas',
  WAEditor.Domain.HtmlDocumentRenderer in '..\..\src\Domain\WAEditor.Domain.HtmlDocumentRenderer.pas',
  WAEditor.Domain.RtfDocumentRenderer in '..\..\src\Domain\WAEditor.Domain.RtfDocumentRenderer.pas',
  WAEditor.Domain.RtfDocumentParser in '..\..\src\Domain\WAEditor.Domain.RtfDocumentParser.pas';

const
  // A small WYSIWYG HTML fragment, as if it had just come out of the
  // editor's contentEditable surface: a centered bold title, a
  // paragraph with italic/underline text, and a table.
  WA_SAMPLE_HTML =
   { '<p style="text-align:center;"><span style="font-family:Arial;font-size:20pt;"><b>Relatorio Mensal</b></span></p>' +
    '<p style="text-align:left;"><i><u>Resumo dos resultados do periodo.</u></i></p>' +
    '<table border="1"><tr><td>Item</td><td>Valor</td></tr><tr><td>Vendas</td><td>1000</td></tr></table>';}



'<p><font style="text-align: center;"><font><font><br><strong><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">RESSON�NCIA MAGN�TICA DA COLUNA LOMBAR</font></strong></font></font></font></p><font style="text-align: center;">'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;"><br><strong>DADOS CL�NICOS:</strong> Lombalgia com irradia��o para a direita.&nbsp;</font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;"><strong>T�CNICA:</strong> Sequ�ncias T1, T2 e STIR, nos planos sagital, coronal e axial, sem contraste.&nbsp;</font></font></font></p>'+
'<p><font style="text-align: left;"><font><strong><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">AN�LISE:</font></strong></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">1. Retifica��o da lordose lombar fisiol�gica.&nbsp;</font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">2. Corpos vertebrais lombares tem altura preservada, sem evid�ncias de edema �sseo. Ped�culos mantidos.&nbsp;</font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">3. Nota-se �rea de lipossubstitui��o medular e leve irregularidade do contorno'+
' posterosuperior da v�rtebra S1 ( degenerativa ? sequela de destacamento do anel apofis�rio?).&nbsp;</font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">4. Leves altera��es degenerativas interapofis�rias de L3-L4 at� L5-S1.&nbsp;</font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">5. <em>Desidrata��o e redu��o da altura discal no n�vel L5-S1 (discopatia degenerativa).</em></font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">6. <em>Abaulamento discal associado a componente protruso central em L5-S1, que comprime a face anterior do saco dural, e mant�m'+
' contato com a raiz descendente S1 deste lado. H� tamb�m, leve extens�o discal para a base foraminal direita, tangenciando a raiz emergente correspondente.</em></font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">7. N�o definimos protrus�es ou abaulamentos discais nos demais n�veis lombares.&nbsp;</font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">8. Os forames neurais lombares tem boa amplitude.&nbsp;</font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">9. Cone medular ao n�vel de L1, sem altera��es.&nbsp;</font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">10. Distribui��o habitual das ra�zes da cauda equina.&nbsp;</font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">11. Canal raquiano �sseo central tem dimens�es conservadas neste segmento.&nbsp;</font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">12. Musculatura paravertebral avaliada sem anormalidades a referir.&nbsp;</font></font></font></p>'+
'<p><font style="text-align: left;"><font><font style="font-family: arial, helvetica, sans-serif; font-size: 12px;">/</font></font></font></p>';


var
  LDocument: TWARichDocument;
  LRtf: string;
  LHtmlFromRtf: string;
begin
  try
    WriteLn('=== HTML de entrada ===');
    WriteLn(WA_SAMPLE_HTML);
    WriteLn;

    // HTML -> RTF
    LDocument := TWAHtmlDocumentParser.Parse(WA_SAMPLE_HTML);
    try
      LRtf := TWARtfDocumentRenderer.Render(LDocument);
    finally
      LDocument.Free;
    end;

    WriteLn('=== RTF gerado ===');
    WriteLn(LRtf);
    WriteLn;

    // RTF -> HTML (o caminho inverso: TWARtfDocumentParser.Parse entra
    // com uma string RTF e devolve o mesmo TWARichDocument; renderize
    // esse documento com TWAHtmlDocumentRenderer para obter HTML de volta)
    LDocument := TWARtfDocumentParser.Parse(LRtf);
    try
      LHtmlFromRtf := TWAHtmlDocumentRenderer.Render(LDocument);
    finally
      LDocument.Free;
    end;

    WriteLn('=== HTML reconvertido a partir do RTF ===');
    WriteLn(LHtmlFromRtf);
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
