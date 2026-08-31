unit WAEditor.Domain.HtmlDocumentRenderer;

interface

uses
  WAEditor.Domain.RichDocument;

type
  /// Renders a TWARichDocument to an HTML fragment suitable for loading
  /// straight into the WYSIWYG (contentEditable) surface. Pure string
  /// composition: no COM/UI dependency, fully unit testable.
  TWAHtmlDocumentRenderer = class
  public
    class function Render(ADocument: TWARichDocument): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  WAEditor.Domain.Types,
  WAEditor.Domain.AlignmentMapper;

function EscapeHtml(const AText: string): string;
begin
  Result := AText;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function RenderRun(ARun: TWARun): string;
var
  LStyle: string;
begin
  Result := EscapeHtml(ARun.Text);
  if ARun.Format.Underline then
    Result := '<u>' + Result + '</u>';
  if ARun.Format.Italic then
    Result := '<i>' + Result + '</i>';
  if ARun.Format.Bold then
    Result := '<b>' + Result + '</b>';

  LStyle := '';
  if ARun.Format.FontName <> '' then
    LStyle := LStyle + Format('font-family:%s;', [ARun.Format.FontName]);
  if ARun.Format.FontSizeInPoints > 0 then
    LStyle := LStyle + Format('font-size:%dpt;', [ARun.Format.FontSizeInPoints]);
  if LStyle <> '' then
    Result := Format('<span style="%s">%s</span>', [LStyle, Result]);
end;

function RenderParagraph(AParagraph: TWAParagraphBlock): string;
var
  LBuilder: TStringBuilder;
  LRun: TWARun;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendFormat('<p style="text-align:%s;">',
      [TWAAlignmentMapper.ToHtmlAttribute(AParagraph.Alignment)]);
    for LRun in AParagraph.Runs do
      LBuilder.Append(RenderRun(LRun));
    if AParagraph.Runs.Count = 0 then
      LBuilder.Append('&nbsp;');
    LBuilder.Append('</p>');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function RenderTable(ATable: TWATableBlock): string;
var
  LBuilder: TStringBuilder;
  LRow: TWATableRow;
  LCell: TWATableCell;
  LRun: TWARun;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendFormat('<table border="%d">', [ATable.BorderWidth]);
    for LRow in ATable.Rows do
    begin
      LBuilder.Append('<tr>');
      for LCell in LRow.Cells do
      begin
        LBuilder.Append('<td>');
        for LRun in LCell.Runs do
          LBuilder.Append(RenderRun(LRun));
        if LCell.Runs.Count = 0 then
          LBuilder.Append('&nbsp;');
        LBuilder.Append('</td>');
      end;
      LBuilder.Append('</tr>');
    end;
    LBuilder.Append('</table>');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function RenderList(AList: TWAListBlock): string;
var
  LTag: string;
  LBuilder: TStringBuilder;
  LItem: TWAListItem;
  LRun: TWARun;
begin
  if AList.Kind = lkOrdered then
    LTag := 'ol'
  else
    LTag := 'ul';

  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendFormat('<%s>', [LTag]);
    for LItem in AList.Items do
    begin
      LBuilder.Append('<li>');
      for LRun in LItem.Runs do
        LBuilder.Append(RenderRun(LRun));
      if LItem.Runs.Count = 0 then
        LBuilder.Append('&nbsp;');
      LBuilder.Append('</li>');
    end;
    LBuilder.AppendFormat('</%s>', [LTag]);
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class function TWAHtmlDocumentRenderer.Render(ADocument: TWARichDocument): string;
var
  LBuilder: TStringBuilder;
  LBlock: TWABlock;
begin
  LBuilder := TStringBuilder.Create;
  try
    for LBlock in ADocument.Blocks do
    begin
      if LBlock is TWAParagraphBlock then
        LBuilder.Append(RenderParagraph(TWAParagraphBlock(LBlock)))
      else if LBlock is TWATableBlock then
        LBuilder.Append(RenderTable(TWATableBlock(LBlock)))
      else if LBlock is TWAListBlock then
        LBuilder.Append(RenderList(TWAListBlock(LBlock)));
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

end.
