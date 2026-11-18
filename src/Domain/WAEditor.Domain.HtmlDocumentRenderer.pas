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
  System.NetEncoding,
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

/// Escapes run text and keeps its spaces visible. RTF spaces are all
/// significant, but HTML collapses a run of spaces into one and drops a
/// space that stands alone, so a space that opens the run or follows
/// another space is written as &nbsp;. Without it a cell or line holding
/// only a space (what an empty cell becomes after one round trip) came
/// back as a collapsed "<td> </td>", and form blanks such as "(   ) CNS"
/// showed as "( ) CNS".
function EscapeHtmlText(const AText: string): string;
var
  LBuilder: TStringBuilder;
  I: Integer;
  LEscaped: string;
begin
  LEscaped := EscapeHtml(AText);
  LBuilder := TStringBuilder.Create;
  try
    for I := 1 to Length(LEscaped) do
      if (LEscaped[I] = ' ') and ((I = 1) or (LEscaped[I - 1] = ' ')) then
        LBuilder.Append('&nbsp;')
      else
        LBuilder.Append(LEscaped[I]);
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function RenderRun(ARun: TWARun): string;
var
  LStyle: string;
  LBase64: TBase64Encoding;
begin
  if ARun.IsLineBreak then
    Exit('<br>');
  if ARun.IsCheckbox then
  begin
    if ARun.IsRadio then
      Result := '<input type="radio"'
    else
      Result := '<input type="checkbox"';
    if ARun.IsChecked then
      Result := Result + ' checked';
    Exit(Result + '>');
  end;
  if ARun.IsImage then
  begin
    // TNetEncoding.Base64's shared instance wraps output every 76 chars
    // with a line break by default (the classic MIME convention), which
    // would litter the data: URI with embedded newlines. A zero
    // CharsPerLine encoding keeps it on one line, matching what a
    // WYSIWYG surface's own data: URI looks like.
    LBase64 := TBase64Encoding.Create(0);
    try
      Result := Format('<img src="data:image/%s;base64,%s"',
        [ARun.ImageFormat, LBase64.EncodeBytesToString(ARun.ImageData)]);
    finally
      LBase64.Free;
    end;
    if ARun.ImageWidthPx > 0 then
      Result := Result + Format(' width="%d"', [ARun.ImageWidthPx]);
    if ARun.ImageHeightPx > 0 then
      Result := Result + Format(' height="%d"', [ARun.ImageHeightPx]);
    Exit(Result + '>');
  end;

  Result := EscapeHtmlText(ARun.Text);
  if ARun.Format.Underline then
    Result := '<u>' + Result + '</u>';
  if ARun.Format.Italic then
    Result := '<i>' + Result + '</i>';
  if ARun.Format.Bold then
    Result := '<b>' + Result + '</b>';
  if ARun.Format.Superscript then
    Result := '<sup>' + Result + '</sup>'
  else if ARun.Format.Subscript then
    Result := '<sub>' + Result + '</sub>';

  LStyle := '';
  if ARun.Format.FontName <> '' then
    // Always quote the font name: an unquoted multi-word CSS
    // font-family (e.g. font-family:Courier New;) is invalid per spec,
    // and MSHTML/Trident silently falls back to a default font instead
    // of applying it. Single quotes are used because the surrounding
    // style="..." attribute itself uses double quotes; EscapeHtml still
    // protects against a font name that contains one of its own (can
    // happen with RTF).
    LStyle := LStyle + Format('font-family:''%s'';', [EscapeHtml(ARun.Format.FontName)]);
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
    // margin:0 keeps consecutive paragraphs exactly one line-height apart,
    // matching RTF's \par semantics (a plain line break, not a full
    // block with its own spacing before/after). Without it, the host's
    // default <p> margin gets added on top of every paragraph boundary
    // and, in quirks-mode hosts (e.g. innerHTML on a script-created
    // document, where adjacent margins don't collapse), stacks up on
    // both neighbors instead of collapsing, visibly multiplying blank
    // lines.
    LBuilder.Append('<p style="margin:0;');
    if AParagraph.HasBorder then
      LBuilder.Append('border:1px solid #000000;padding:2px;');
    // Indents are written in px (15 twips each) after margin:0 so they
    // override it; omitted when zero to keep the common case unchanged.
    if AParagraph.LeftIndentTwips <> 0 then
      LBuilder.AppendFormat('margin-left:%dpx;', [Round(AParagraph.LeftIndentTwips / 15)]);
    if AParagraph.RightIndentTwips <> 0 then
      LBuilder.AppendFormat('margin-right:%dpx;', [Round(AParagraph.RightIndentTwips / 15)]);
    if AParagraph.FirstLineIndentTwips <> 0 then
      LBuilder.AppendFormat('text-indent:%dpx;', [Round(AParagraph.FirstLineIndentTwips / 15)]);
    LBuilder.AppendFormat('text-align:%s;">',
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

/// Twips -> nearest px (half up) at 1px = 15 twips.
function TwipsToNearestPx(ATwips: Integer): Integer;
begin
  if ATwips >= 0 then
    Result := (ATwips * 2 + 15) div 30
  else
    Result := -((-ATwips * 2 + 15) div 30);
end;

/// Column widths in px taken from the rounded cumulative column edges, not
/// from each width on its own: truncating every column separately lost up
/// to 14 twips per column, and the losses added up along the row (the AIH
/// form's right edge came back 49 twips short after RTF -> HTML -> RTF).
/// Rounding the edges keeps every edge within 7 twips of the original and
/// the error never accumulates.
function ColumnWidthsInPx(ATable: TWATableBlock): TArray<Integer>;
var
  I, LEdgeTwips, LPreviousEdgePx, LEdgePx: Integer;
begin
  SetLength(Result, Length(ATable.ColumnWidths));
  LEdgeTwips := 0;
  LPreviousEdgePx := 0;
  for I := 0 to High(ATable.ColumnWidths) do
  begin
    Inc(LEdgeTwips, ATable.ColumnWidths[I]);
    LEdgePx := TwipsToNearestPx(LEdgeTwips);
    Result[I] := LEdgePx - LPreviousEdgePx;
    LPreviousEdgePx := LEdgePx;
  end;
end;

function RenderTable(ATable: TWATableBlock): string;
var
  LBuilder: TStringBuilder;
  LRow: TWATableRow;
  LCell: TWATableCell;
  LRun: TWARun;
  I: Integer;
  LColumnWidthsPx: TArray<Integer>;
  LGridIndex, LSpanIndex: Integer;
  LColWidthList: string;
  LTableStyle: string;
  LTableWidthPx: Integer;
begin
  LColumnWidthsPx := ColumnWidthsInPx(ATable);
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendFormat('<table border="%d"', [ATable.BorderWidth]);
    // With known column widths the table is laid out as fixed, at the sum
    // of its columns: the browser's default auto layout (what Jodit uses)
    // treats <col> widths only as hints and redistributes the columns by
    // content, so in a form with merged cells a long text in a wide merge
    // squeezes the narrow columns (the 219px "Sistema Unico de Saude"
    // column of the AIH form came out ~85px wide).
    LTableStyle := '';
    if Length(ATable.ColumnWidths) > 0 then
    begin
      LTableWidthPx := 0;
      for I := 0 to High(LColumnWidthsPx) do
        Inc(LTableWidthPx, LColumnWidthsPx[I]);
      LTableStyle := Format('table-layout: fixed; width: %dpx;', [LTableWidthPx]);
    end;
    if ATable.LeftOffsetTwips > 0 then
      LTableStyle := LTableStyle + Format(' margin-left: %dpx;', [Round(ATable.LeftOffsetTwips / 15)]);
    if LTableStyle <> '' then
      LBuilder.AppendFormat(' style="%s"', [Trim(LTableStyle)]);
    LBuilder.Append('>');
    // Twips -> px at the standard 96dpi reference (1px = 15 twips),
    // written back out as <colgroup><col> (and each <td>'s colwidth,
    // matching what a live WYSIWYG surface itself produces) so column
    // widths survive an HTML round trip instead of collapsing back to
    // whatever the host's default auto-layout picks.
    if Length(ATable.ColumnWidths) > 0 then
    begin
      LBuilder.Append('<colgroup>');
      for I := 0 to High(LColumnWidthsPx) do
        LBuilder.AppendFormat('<col style="width:%dpx;">', [LColumnWidthsPx[I]]);
      LBuilder.Append('</colgroup>');
    end;
    for LRow in ATable.Rows do
    begin
      LBuilder.Append('<tr>');
      LGridIndex := 0;
      for I := 0 to LRow.Cells.Count - 1 do
      begin
        LCell := LRow.Cells[I];
        LBuilder.Append('<td');
        if LCell.ColSpan > 1 then
          LBuilder.AppendFormat(' colspan="%d"', [LCell.ColSpan]);
        // colwidth lists one px width per grid column the cell covers
        // ("120,80" for colspan="2"), as the editor itself writes it.
        LColWidthList := '';
        for LSpanIndex := 0 to LCell.ColSpan - 1 do
          if (LGridIndex + LSpanIndex < Length(LColumnWidthsPx)) and
             (LColumnWidthsPx[LGridIndex + LSpanIndex] > 0) then
          begin
            if LColWidthList <> '' then
              LColWidthList := LColWidthList + ',';
            LColWidthList := LColWidthList + IntToStr(LColumnWidthsPx[LGridIndex + LSpanIndex]);
          end
          else
          begin
            LColWidthList := '';
            Break;
          end;
        if LColWidthList <> '' then
          LBuilder.AppendFormat(' colwidth="%s"', [LColWidthList]);
        Inc(LGridIndex, LCell.ColSpan);
        if LCell.Alignment <> taLeftAlign then
          LBuilder.AppendFormat(' style="text-align: %s;"',
            [TWAAlignmentMapper.ToHtmlAttribute(LCell.Alignment)]);
        LBuilder.Append('>');
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
