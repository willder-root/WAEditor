unit WAEditor.Domain.HtmlDocumentParser;

interface

uses
  WAEditor.Domain.RichDocument;

type
  /// Parses the bounded HTML subset produced either by
  /// TWAHtmlDocumentRenderer or by the live WYSIWYG surface's
  /// execCommand-based markup (legacy <b>/<i>/<u>/<font>, or <span
  /// style="...">) into a TWARichDocument. Not a general-purpose HTML
  /// parser: it targets exactly the tags this editor can produce.
  TWAHtmlDocumentParser = class
  public
    class function Parse(const AHtml: string): TWARichDocument; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  System.Generics.Collections,
  WAEditor.Domain.Types,
  WAEditor.Domain.AlignmentMapper,
  WAEditor.Domain.FontSizeScale;

type
  TWAHtmlParserState = class
  private
    FHtml: string;
    FPos: Integer;
    FLength: Integer;
    FDocument: TWARichDocument;
    FFormatStack: TStack<TWARunFormat>;
    FCurrentParagraph: TWAParagraphBlock;
    FCurrentTable: TWATableBlock;
    FCurrentRow: TWATableRow;
    FCurrentCell: TWATableCell;
    FCurrentList: TWAListBlock;
    FCurrentListItem: TWAListItem;

    function CurrentFormat: TWARunFormat;
    procedure EnsureParagraph;
    procedure AppendText(const AText: string);
    procedure AppendLineBreak;
    procedure HandleOpenTag(const ATagName, AAttributes: string);
    procedure HandleCloseTag(const ATagName: string);
    procedure ProcessTag(const ATag: string);
  public
    constructor Create(const AHtml: string);
    destructor Destroy; override;
    function Parse: TWARichDocument;
  end;

function DecodeHtmlEntities(const AText: string): string;
begin
  Result := AText;
  Result := StringReplace(Result, '&nbsp;', ' ', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&#39;', '''', [rfReplaceAll]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll, rfIgnoreCase]);
end;

function ExtractAttribute(const AAttributes, AAttrName: string): string;
var
  LLower, LNameLower: string;
  LPos, LStart: Integer;
  LQuoteChar: Char;
begin
  Result := '';
  LLower := LowerCase(AAttributes);
  LNameLower := LowerCase(AAttrName);
  LPos := Pos(LNameLower + '=', LLower);
  if LPos = 0 then
    Exit;
  LPos := LPos + Length(LNameLower) + 1;
  if (LPos > Length(AAttributes)) then
    Exit;
  if (AAttributes[LPos] = '"') or (AAttributes[LPos] = '''') then
  begin
    LQuoteChar := AAttributes[LPos];
    Inc(LPos);
    LStart := LPos;
    while (LPos <= Length(AAttributes)) and (AAttributes[LPos] <> LQuoteChar) do
      Inc(LPos);
    Result := Copy(AAttributes, LStart, LPos - LStart);
  end
  else
  begin
    LStart := LPos;
    while (LPos <= Length(AAttributes)) and (AAttributes[LPos] <> ' ') do
      Inc(LPos);
    Result := Copy(AAttributes, LStart, LPos - LStart);
  end;
end;

function ParseStyleFormat(const AStyle: string; ABase: TWARunFormat): TWARunFormat;
var
  LParts: TArray<string>;
  LPart, LProp, LValue: string;
  LColonPos, LPtPos: Integer;
begin
  Result := ABase;
  LParts := AStyle.Split([';']);
  for LPart in LParts do
  begin
    LColonPos := Pos(':', LPart);
    if LColonPos = 0 then
      Continue;
    LProp := LowerCase(Trim(Copy(LPart, 1, LColonPos - 1)));
    LValue := Trim(Copy(LPart, LColonPos + 1, MaxInt));
    if LProp = 'font-family' then
    begin
      // LValue.Split([',']) returns a zero-length array for an empty
      // string (e.g. a malformed "font-family:;" with nothing before
      // the separator), so indexing [0] unconditionally would read out
      // of bounds.
      if LValue <> '' then
        Result.FontName :=
          DecodeHtmlEntities(Trim(LValue.Split([','])[0])).DequotedString('"').DequotedString('''');
    end
    else if LProp = 'font-size' then
    begin
      LPtPos := Pos('pt', LowerCase(LValue));
      if LPtPos > 0 then
        Result.FontSizeInPoints := StrToIntDef(Trim(Copy(LValue, 1, LPtPos - 1)), Result.FontSizeInPoints);
    end
    else if (LProp = 'font-weight') and (LowerCase(LValue) = 'bold') then
      Result.Bold := True
    else if (LProp = 'font-style') and (LowerCase(LValue) = 'italic') then
      Result.Italic := True
    else if (LProp = 'text-decoration') and (Pos('underline', LowerCase(LValue)) > 0) then
      Result.Underline := True;
  end;
end;

function ParseAlignmentAttribute(const AAttributes: string; ADefault: TWATextAlignment): TWATextAlignment;
var
  LAlign, LStyle: string;
  LStyleAlignPos: Integer;
begin
  Result := ADefault;
  LAlign := Trim(ExtractAttribute(AAttributes, 'align'));
  if LAlign <> '' then
  begin
    try
      Exit(TWAAlignmentMapper.FromHtmlAttribute(LAlign));
    except
      on EWADomainValidationError do
        ; // fall through to style-based lookup / default
    end;
  end;
  LStyle := ExtractAttribute(AAttributes, 'style');
  LStyleAlignPos := Pos('text-align', LowerCase(LStyle));
  if LStyleAlignPos > 0 then
  begin
    LAlign := Trim(Copy(LStyle, LStyleAlignPos + Length('text-align'), MaxInt));
    LAlign := Trim(LAlign.TrimLeft([':', ' ']));
    LAlign := LAlign.Split([';'])[0];
    try
      Result := TWAAlignmentMapper.FromHtmlAttribute(LAlign);
    except
      on EWADomainValidationError do
        ; // keep default
    end;
  end;
end;

{ TWAHtmlParserState }

constructor TWAHtmlParserState.Create(const AHtml: string);
begin
  inherited Create;
  FHtml := AHtml;
  FPos := 1;
  FLength := Length(AHtml);
  FDocument := TWARichDocument.Create;
  FFormatStack := TStack<TWARunFormat>.Create;
  FFormatStack.Push(TWARunFormat.Plain);
end;

destructor TWAHtmlParserState.Destroy;
begin
  FFormatStack.Free;
  inherited Destroy;
end;

function TWAHtmlParserState.CurrentFormat: TWARunFormat;
begin
  Result := FFormatStack.Peek;
end;

procedure TWAHtmlParserState.EnsureParagraph;
begin
  if (FCurrentCell = nil) and (FCurrentListItem = nil) and (FCurrentParagraph = nil) then
    FCurrentParagraph := FDocument.AddParagraph(taLeftAlign);
end;

procedure TWAHtmlParserState.AppendText(const AText: string);
var
  LDecoded: string;
begin
  LDecoded := DecodeHtmlEntities(AText);
  if LDecoded = '' then
    Exit;
  if FCurrentCell <> nil then
    FCurrentCell.AddRun(LDecoded, CurrentFormat)
  else if FCurrentListItem <> nil then
    FCurrentListItem.AddRun(LDecoded, CurrentFormat)
  else
  begin
    EnsureParagraph;
    FCurrentParagraph.AddRun(LDecoded, CurrentFormat);
  end;
end;

procedure TWAHtmlParserState.AppendLineBreak;
begin
  if FCurrentCell <> nil then
    FCurrentCell.Runs.Add(TWARun.CreateLineBreak)
  else if FCurrentListItem <> nil then
    FCurrentListItem.Runs.Add(TWARun.CreateLineBreak)
  else
  begin
    EnsureParagraph;
    FCurrentParagraph.Runs.Add(TWARun.CreateLineBreak);
  end;
end;

procedure TWAHtmlParserState.HandleOpenTag(const ATagName, AAttributes: string);
var
  LFormat: TWARunFormat;
  LFace: string;
  LSize: Integer;
  LBorder: Integer;
begin
  if (ATagName = 'b') or (ATagName = 'strong') then
  begin
    LFormat := CurrentFormat;
    LFormat.Bold := True;
    FFormatStack.Push(LFormat);
  end
  else if (ATagName = 'i') or (ATagName = 'em') then
  begin
    LFormat := CurrentFormat;
    LFormat.Italic := True;
    FFormatStack.Push(LFormat);
  end
  else if ATagName = 'u' then
  begin
    LFormat := CurrentFormat;
    LFormat.Underline := True;
    FFormatStack.Push(LFormat);
  end
  else if ATagName = 'font' then
  begin
    LFormat := CurrentFormat;
    LFace := ExtractAttribute(AAttributes, 'face');
    if LFace <> '' then
      LFormat.FontName := LFace;
    if TryStrToInt(ExtractAttribute(AAttributes, 'size'), LSize) then
      LFormat.FontSizeInPoints := TWAFontSizeScale.FromHtmlLegacySize(LSize);
    FFormatStack.Push(LFormat);
  end
  else if ATagName = 'span' then
  begin
    LFormat := ParseStyleFormat(ExtractAttribute(AAttributes, 'style'), CurrentFormat);
    FFormatStack.Push(LFormat);
  end
  else if (ATagName = 'p') or (ATagName = 'div') then
  begin
    // A live WYSIWYG surface commonly wraps each <li>'s content in its
    // own <p> (<li><p>text</p></li>), and can do the same inside a
    // <td>. That <p> is not a new top-level paragraph in that case --
    // the list item/cell already is the content container -- so
    // creating one here would leave a stray empty TWAParagraphBlock in
    // the document for every list item, growing the block count (and
    // visible blank lines) a little more on every RTF/HTML round trip.
    if (FCurrentCell = nil) and (FCurrentListItem = nil) then
    begin
      FCurrentParagraph := FDocument.AddParagraph(ParseAlignmentAttribute(AAttributes, taLeftAlign));
      FCurrentParagraph.HasBorder :=
        Pos('border', LowerCase(ExtractAttribute(AAttributes, 'style'))) > 0;
    end;
  end
  else if ATagName = 'br' then
    AppendLineBreak
  else if ATagName = 'table' then
  begin
    if not TryStrToInt(ExtractAttribute(AAttributes, 'border'), LBorder) then
      LBorder := 1;
    FCurrentTable := TWATableBlock.Create(LBorder);
    FDocument.Blocks.Add(FCurrentTable);
    FCurrentParagraph := nil;
  end
  else if ATagName = 'tr' then
  begin
    if FCurrentTable <> nil then
      FCurrentRow := FCurrentTable.AddRow;
  end
  else if (ATagName = 'td') or (ATagName = 'th') then
  begin
    if FCurrentRow <> nil then
      FCurrentCell := FCurrentRow.AddCell;
  end
  else if (ATagName = 'ul') or (ATagName = 'ol') then
  begin
    if ATagName = 'ol' then
      FCurrentList := FDocument.AddList(lkOrdered)
    else
      FCurrentList := FDocument.AddList(lkUnordered);
    FCurrentParagraph := nil;
  end
  else if ATagName = 'li' then
  begin
    if FCurrentList <> nil then
      FCurrentListItem := FCurrentList.AddItem;
  end;
end;

procedure TWAHtmlParserState.HandleCloseTag(const ATagName: string);
begin
  if (ATagName = 'b') or (ATagName = 'strong') or (ATagName = 'i') or (ATagName = 'em') or
     (ATagName = 'u') or (ATagName = 'font') or (ATagName = 'span') then
  begin
    if FFormatStack.Count > 1 then
      FFormatStack.Pop;
  end
  else if (ATagName = 'td') or (ATagName = 'th') then
    FCurrentCell := nil
  else if ATagName = 'tr' then
    FCurrentRow := nil
  else if ATagName = 'table' then
  begin
    FCurrentTable := nil;
    FCurrentParagraph := nil;
  end
  else if ATagName = 'li' then
    FCurrentListItem := nil
  else if (ATagName = 'ul') or (ATagName = 'ol') then
  begin
    FCurrentList := nil;
    FCurrentParagraph := nil;
  end;
end;

procedure TWAHtmlParserState.ProcessTag(const ATag: string);
var
  LContent: string;
  LIsClosing: Boolean;
  LIsSelfClosing: Boolean;
  LSpacePos, I: Integer;
  LTagName, LAttributes: string;
begin
  LContent := Copy(ATag, 2, Length(ATag) - 2); // strip < and >
  LIsClosing := (LContent <> '') and (LContent[1] = '/');
  if LIsClosing then
    Delete(LContent, 1, 1);

  LIsSelfClosing := (LContent <> '') and (LContent[Length(LContent)] = '/');
  if LIsSelfClosing then
    Delete(LContent, Length(LContent), 1);

  LSpacePos := 0;
  for I := 1 to Length(LContent) do
    if CharInSet(LContent[I], [' ', #9, #10, #13]) then
    begin
      LSpacePos := I;
      Break;
    end;

  if LSpacePos > 0 then
  begin
    LTagName := LowerCase(Trim(Copy(LContent, 1, LSpacePos - 1)));
    LAttributes := Trim(Copy(LContent, LSpacePos + 1, MaxInt));
  end
  else
  begin
    LTagName := LowerCase(Trim(LContent));
    LAttributes := '';
  end;

  if LTagName = '' then
    Exit;

  if LIsClosing then
    HandleCloseTag(LTagName)
  else
  begin
    HandleOpenTag(LTagName, LAttributes);
    if LIsSelfClosing or (LTagName = 'br') then
      HandleCloseTag(LTagName);
  end;
end;

function TWAHtmlParserState.Parse: TWARichDocument;
var
  LTagStart, LTagEnd: Integer;
  LText: string;
begin
  while FPos <= FLength do
  begin
    if FHtml[FPos] = '<' then
    begin
      LTagStart := FPos;
      LTagEnd := PosEx('>', FHtml, LTagStart);
      if LTagEnd = 0 then
        Break;
      ProcessTag(Copy(FHtml, LTagStart, LTagEnd - LTagStart + 1));
      FPos := LTagEnd + 1;
    end
    else
    begin
      LTagStart := FPos;
      LTagEnd := PosEx('<', FHtml, LTagStart);
      if LTagEnd = 0 then
        LTagEnd := FLength + 1;
      LText := Copy(FHtml, LTagStart, LTagEnd - LTagStart);
      AppendText(LText);
      FPos := LTagEnd;
    end;
  end;
  Result := FDocument;
end;

{ TWAHtmlDocumentParser }

class function TWAHtmlDocumentParser.Parse(const AHtml: string): TWARichDocument;
var
  LState: TWAHtmlParserState;
begin
  LState := TWAHtmlParserState.Create(AHtml);
  try
    Result := LState.Parse;
  finally
    LState.Free;
  end;
end;

end.
