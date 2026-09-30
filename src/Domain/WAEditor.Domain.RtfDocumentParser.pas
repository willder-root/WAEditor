unit WAEditor.Domain.RtfDocumentParser;

interface

uses
  WAEditor.Domain.RichDocument;

type
  /// Parses the bounded RTF subset produced by TWARtfDocumentRenderer:
  /// a font table, \pard/\par paragraphs with \ql/\qc/\qr/\qj alignment,
  /// \b/\i/\ul/\f/\fs character formatting scoped by {...} groups, and
  /// \trowd/\cellx/\intbl/\cell/\row tables wrapped in their own group.
  /// This is not a general-purpose RTF engine: it targets exactly the
  /// control words this editor's own writer emits, so round-tripping
  /// RTF produced elsewhere is only best-effort.
  TWARtfDocumentParser = class
  public
    class function Parse(const ARtf: string): TWARichDocument; static;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  WAEditor.Domain.Types;

type
  TWARtfGroupSnapshot = record
    Format: TWARunFormat;
    Alignment: TWATextAlignment;
  end;

  TWARtfParserState = class
  private
    FRtf: string;
    FPos: Integer;
    FLength: Integer;
    FDocument: TWARichDocument;
    FFontTable: TDictionary<Integer, string>;
    FGroupStack: TStack<TWARtfGroupSnapshot>;
    FCurrentFormat: TWARunFormat;
    FCurrentAlignment: TWATextAlignment;
    FCurrentHasBorder: Boolean;
    FCurrentParagraph: TWAParagraphBlock;
    FCurrentTable: TWATableBlock;
    FCurrentRow: TWATableRow;
    FCurrentCell: TWATableCell;
    // \cellx values accumulated for the row currently being read; each
    // is a cumulative right-edge position in twips, reset at \trowd and
    // turned into per-column widths (via consecutive differences) on
    // \row, once, from the table's first row.
    FPendingCellxValues: TList<Integer>;
    FCurrentList: TWAListBlock;
    FCurrentListItem: TWAListItem;
    // A list item is rendered as \pard\fi-360\li720 followed by a literal
    // \bullet or "N." marker and \tab (see TWARtfDocumentRenderer). These
    // two flags track, respectively, "the paragraph now open is a list
    // item" and "we are still inside its marker, before real content
    // starts" so the marker text/control words can be recognized and
    // stripped instead of becoming part of the item's runs.
    FListItemPending: Boolean;
    FMarkerPending: Boolean;
    FOrdinalBuffer: string;

    function AtEnd: Boolean;
    function MatchesControlWordAt(APos: Integer; const AName: string): Boolean;
    function PeekKeywordAfterWhitespace: string;
    procedure SkipWhitespace;
    procedure EnsureParagraph;
    procedure AppendChar(AChar: Char);
    procedure AppendLineBreak;
    procedure ClosePendingParagraph;

    procedure HandleNestedGroupOpen;
    procedure ParseGroup;
    procedure ParseFontTableGroup;
    procedure ParseFontEntry;
    procedure ParseTableGroup;
    procedure ParseListTextGroup;
    procedure ParseFieldGroup;
    procedure AppendCheckbox(AChecked: Boolean; AIsRadio: Boolean);
    procedure ParsePictGroup;
    procedure AppendImage(const AData: TBytes; const AFormat: string; AWidthPx, AHeightPx: Integer);
    procedure SkipGroup;

    procedure HandleControlWord(const AName: string; AHasParam: Boolean; AParam: Integer);
    procedure HandleBackslashEscape;
  public
    constructor Create(const ARtf: string);
    destructor Destroy; override;
    function Parse: TWARichDocument;
  end;

function IsAsciiLetter(AChar: Char): Boolean;
begin
  Result := (AChar >= 'a') and (AChar <= 'z') or (AChar >= 'A') and (AChar <= 'Z');
end;

function IsAsciiDigit(AChar: Char): Boolean;
begin
  Result := (AChar >= '0') and (AChar <= '9');
end;

{ TWARtfParserState }

constructor TWARtfParserState.Create(const ARtf: string);
begin
  inherited Create;
  FRtf := ARtf;
  FPos := 1;
  FLength := Length(ARtf);
  FDocument := TWARichDocument.Create;
  FFontTable := TDictionary<Integer, string>.Create;
  FGroupStack := TStack<TWARtfGroupSnapshot>.Create;
  FPendingCellxValues := TList<Integer>.Create;
  FCurrentFormat := TWARunFormat.Plain;
  FCurrentAlignment := taLeftAlign;
end;

destructor TWARtfParserState.Destroy;
begin
  FPendingCellxValues.Free;
  FGroupStack.Free;
  FFontTable.Free;
  inherited Destroy;
end;

function TWARtfParserState.AtEnd: Boolean;
begin
  Result := FPos > FLength;
end;

procedure TWARtfParserState.SkipWhitespace;
begin
  while (not AtEnd) and CharInSet(FRtf[FPos], [' ', #9, #10, #13]) do
    Inc(FPos);
end;

function TWARtfParserState.MatchesControlWordAt(APos: Integer; const AName: string): Boolean;
var
  LAfter: Integer;
begin
  LAfter := APos + 1 + Length(AName);
  Result := (Copy(FRtf, APos, Length(AName) + 1) = '\' + AName) and
    ((LAfter > FLength) or not IsAsciiLetter(FRtf[LAfter]));
end;

function TWARtfParserState.PeekKeywordAfterWhitespace: string;
const
  // Destinations that never contribute visible body text even when not
  // marked with the generic \* "ignorable if unrecognized" prefix (many
  // real-world writers omit \* on these even though the RTF spec treats
  // them the same way \fonttbl is treated: known, but not body content).
  WA_SKIPPABLE_DESTINATIONS: array[0..6] of string = (
    'colortbl', 'stylesheet', 'info', 'rsidtbl', 'listtable',
    'listoverridetable', 'generator');
var
  LSavedPos: Integer;
  I: Integer;
begin
  // Called with FPos still pointing at the '{' being examined; peek at
  // whatever immediately follows it (skipping whitespace) to decide how
  // this group should be parsed.
  LSavedPos := FPos;
  Inc(FPos);
  SkipWhitespace;
  Result := '';
  if not AtEnd then
  begin
    if Copy(FRtf, FPos, 2) = '\*' then
      Result := 'skip' // \* marks an ignorable destination: always safe to skip whole
    else if MatchesControlWordAt(FPos, 'fonttbl') then
      Result := 'fonttbl'
    else if MatchesControlWordAt(FPos, 'trowd') then
      Result := 'trowd'
    else if MatchesControlWordAt(FPos, 'listtext') then
      Result := 'listtext'
    else if MatchesControlWordAt(FPos, 'field') then
      Result := 'field'
    else if MatchesControlWordAt(FPos, 'pict') then
      Result := 'pict'
    else
      for I := Low(WA_SKIPPABLE_DESTINATIONS) to High(WA_SKIPPABLE_DESTINATIONS) do
        if MatchesControlWordAt(FPos, WA_SKIPPABLE_DESTINATIONS[I]) then
        begin
          Result := 'skip';
          Break;
        end;
  end;
  FPos := LSavedPos;
end;

procedure TWARtfParserState.EnsureParagraph;
begin
  if (FCurrentCell = nil) and (FCurrentListItem = nil) and (FCurrentParagraph = nil) then
  begin
    FCurrentParagraph := FDocument.AddParagraph(FCurrentAlignment);
    FCurrentParagraph.HasBorder := FCurrentHasBorder;
  end;
end;

procedure TWARtfParserState.ClosePendingParagraph;
begin
  FCurrentParagraph := nil;
end;

procedure TWARtfParserState.AppendChar(AChar: Char);
begin
  if FMarkerPending then
  begin
    if CharInSet(AChar, ['0'..'9']) then
    begin
      FOrdinalBuffer := FOrdinalBuffer + AChar;
      Exit;
    end;
    if AChar = '.' then
      Exit; // ordinal separator, e.g. the '.' in "1."; discarded either way
    FMarkerPending := False; // unexpected char: stop treating this as a marker
  end;

  if FCurrentCell <> nil then
  begin
    if (FCurrentCell.Runs.Count > 0) and (not FCurrentCell.Runs.Last.IsLineBreak) and
       (not FCurrentCell.Runs.Last.IsCheckbox) and (not FCurrentCell.Runs.Last.IsImage) and
       FCurrentCell.Runs.Last.Format.EqualsFormat(FCurrentFormat) then
      FCurrentCell.Runs.Last.Text := FCurrentCell.Runs.Last.Text + AChar
    else
      FCurrentCell.AddRun(AChar, FCurrentFormat);
  end
  else if FCurrentListItem <> nil then
  begin
    if (FCurrentListItem.Runs.Count > 0) and (not FCurrentListItem.Runs.Last.IsLineBreak) and
       (not FCurrentListItem.Runs.Last.IsCheckbox) and (not FCurrentListItem.Runs.Last.IsImage) and
       FCurrentListItem.Runs.Last.Format.EqualsFormat(FCurrentFormat) then
      FCurrentListItem.Runs.Last.Text := FCurrentListItem.Runs.Last.Text + AChar
    else
      FCurrentListItem.AddRun(AChar, FCurrentFormat);
  end
  else
  begin
    EnsureParagraph;
    if (FCurrentParagraph.Runs.Count > 0) and (not FCurrentParagraph.Runs.Last.IsLineBreak) and
       (not FCurrentParagraph.Runs.Last.IsCheckbox) and (not FCurrentParagraph.Runs.Last.IsImage) and
       FCurrentParagraph.Runs.Last.Format.EqualsFormat(FCurrentFormat) then
      FCurrentParagraph.Runs.Last.Text := FCurrentParagraph.Runs.Last.Text + AChar
    else
      FCurrentParagraph.AddRun(AChar, FCurrentFormat);
  end;
end;

procedure TWARtfParserState.AppendLineBreak;
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

procedure TWARtfParserState.AppendCheckbox(AChecked: Boolean; AIsRadio: Boolean);
begin
  if FCurrentCell <> nil then
    FCurrentCell.Runs.Add(TWARun.CreateCheckbox(AChecked, AIsRadio))
  else if FCurrentListItem <> nil then
    FCurrentListItem.Runs.Add(TWARun.CreateCheckbox(AChecked, AIsRadio))
  else
  begin
    EnsureParagraph;
    FCurrentParagraph.Runs.Add(TWARun.CreateCheckbox(AChecked, AIsRadio));
  end;
end;

procedure TWARtfParserState.AppendImage(const AData: TBytes; const AFormat: string;
  AWidthPx, AHeightPx: Integer);
begin
  if FCurrentCell <> nil then
    FCurrentCell.Runs.Add(TWARun.CreateImage(AData, AFormat, AWidthPx, AHeightPx))
  else if FCurrentListItem <> nil then
    FCurrentListItem.Runs.Add(TWARun.CreateImage(AData, AFormat, AWidthPx, AHeightPx))
  else
  begin
    EnsureParagraph;
    FCurrentParagraph.Runs.Add(TWARun.CreateImage(AData, AFormat, AWidthPx, AHeightPx));
  end;
end;

procedure TWARtfParserState.HandleControlWord(const AName: string; AHasParam: Boolean;
  AParam: Integer);
var
  LFontName: string;
  LCellxIndex: Integer;
begin
  if AName = 'par' then
  begin
    if FCurrentCell = nil then
    begin
      if FListItemPending then
        FCurrentListItem := nil // ready for the next \pard\fi-360 item, if any
      else
      begin
        FCurrentList := nil; // a plain paragraph ends any list that was open
        FCurrentListItem := nil;
        // A \par with no text in between (a blank RTF line) must still
        // become an empty paragraph rather than vanish: otherwise the
        // line break it represents is silently dropped from the model.
        EnsureParagraph;
        ClosePendingParagraph;
      end;
    end;
  end
  else if AName = 'pard' then
  begin
    FCurrentAlignment := taLeftAlign;
    FCurrentHasBorder := False;
    FListItemPending := False;
  end
  else if (AName = 'brdrl') or (AName = 'brdrr') or (AName = 'brdrt') or (AName = 'brdrb') then
    FCurrentHasBorder := True
  else if AName = 'fi' then
  begin
    // Only start a new item this way when one hasn't already been opened
    // by a preceding {\listtext...} group (real-world \lsN-based lists
    // carry their own list-item marker there; \fi-360 may still follow
    // it purely for indentation and must not create a duplicate item).
    if AHasParam and (AParam < 0) and (FCurrentListItem = nil) then
    begin
      FListItemPending := True;
      FMarkerPending := True;
      FOrdinalBuffer := '';
      if FCurrentList = nil then
        FCurrentList := FDocument.AddList(lkUnordered); // corrected below once the marker is read
      FCurrentListItem := FCurrentList.AddItem;
    end;
  end
  else if AName = 'bullet' then
  begin
    if FMarkerPending then
    begin
      if FCurrentList <> nil then
        FCurrentList.Kind := lkUnordered;
    end
    else
      AppendChar(Chr($2022)); // literal bullet character outside a marker
  end
  else if AName = 'tab' then
  begin
    if FMarkerPending then
    begin
      if FOrdinalBuffer <> '' then
      begin
        if FCurrentList <> nil then
          FCurrentList.Kind := lkOrdered;
        FOrdinalBuffer := '';
      end;
      FMarkerPending := False;
    end
    else
      AppendChar(#9);
  end
  else if AName = 'ql' then
    FCurrentAlignment := taLeftAlign
  else if AName = 'qc' then
    FCurrentAlignment := taCenterAlign
  else if AName = 'qr' then
    FCurrentAlignment := taRightAlign
  else if AName = 'qj' then
    FCurrentAlignment := taJustifyAlign
  else if AName = 'plain' then
    // Resets character formatting to the document default. Writers that
    // don't scope each run in its own {...} group (relying on \plain
    // between paragraphs instead) need this to avoid bold/italic/
    // underline/font from one paragraph bleeding into the next.
    FCurrentFormat := TWARunFormat.Plain
  else if AName = 'b' then
    FCurrentFormat.Bold := (not AHasParam) or (AParam <> 0)
  else if AName = 'i' then
    FCurrentFormat.Italic := (not AHasParam) or (AParam <> 0)
  else if AName = 'ul' then
    FCurrentFormat.Underline := (not AHasParam) or (AParam <> 0)
  else if AName = 'ulnone' then
    FCurrentFormat.Underline := False
  else if AName = 'super' then
  begin
    FCurrentFormat.Superscript := True;
    FCurrentFormat.Subscript := False;
  end
  else if AName = 'sub' then
  begin
    FCurrentFormat.Subscript := True;
    FCurrentFormat.Superscript := False;
  end
  else if AName = 'nosupersub' then
  begin
    FCurrentFormat.Superscript := False;
    FCurrentFormat.Subscript := False;
  end
  else if AName = 'fs' then
  begin
    if AHasParam then
      FCurrentFormat.FontSizeInPoints := AParam div 2;
  end
  else if AName = 'f' then
  begin
    if AHasParam and FFontTable.TryGetValue(AParam, LFontName) then
      FCurrentFormat.FontName := LFontName;
  end
  else if AName = 'trowd' then
  begin
    if FCurrentTable <> nil then
    begin
      FCurrentRow := FCurrentTable.AddRow;
      FPendingCellxValues.Clear;
    end;
  end
  else if AName = 'cellx' then
  begin
    if AHasParam then
      FPendingCellxValues.Add(AParam);
  end
  else if AName = 'brdrw' then
  begin
    // \brdrw appears between \trowd and the row's \cellx values (e.g.
    // \clbrdrl\brdrs\brdrw10...\cellx960), giving the cell border width
    // in twips; only the first value found is kept, matching this
    // model's single BorderWidth applying to the whole table.
    if AHasParam and (FCurrentTable <> nil) and (FCurrentRow <> nil) and
       (FCurrentCell = nil) then
    begin
      if AParam div 20 > 1 then
        FCurrentTable.BorderWidth := AParam div 20
      else
        FCurrentTable.BorderWidth := 1;
    end;
  end
  else if AName = 'intbl' then
  begin
    if (FCurrentCell = nil) and (FCurrentRow <> nil) then
      FCurrentCell := FCurrentRow.AddCell;
  end
  else if AName = 'cell' then
    FCurrentCell := nil
  else if AName = 'row' then
  begin
    // \cellx values are cumulative right-edge positions in twips; only
    // the first row's layout is kept, matching this model's single
    // ColumnWidths array applying to the whole table.
    if (FCurrentTable <> nil) and (Length(FCurrentTable.ColumnWidths) = 0) and
       (FPendingCellxValues.Count > 0) then
    begin
      SetLength(FCurrentTable.ColumnWidths, FPendingCellxValues.Count);
      for LCellxIndex := 0 to FPendingCellxValues.Count - 1 do
        if LCellxIndex = 0 then
          FCurrentTable.ColumnWidths[0] := FPendingCellxValues[0]
        else
          FCurrentTable.ColumnWidths[LCellxIndex] :=
            FPendingCellxValues[LCellxIndex] - FPendingCellxValues[LCellxIndex - 1];
    end;
    FCurrentRow := nil;
  end
  else if AName = 'line' then
    AppendLineBreak;
  // Any other control word (\rtf, \ansi, \ansicpg, \deff, \uc, \viewkind,
  // \cellx and similar) carries no meaning for the bounded model and is
  // intentionally ignored.
end;

procedure TWARtfParserState.HandleBackslashEscape;
var
  LNameStart, LDigitsStart: Integer;
  LName: string;
  LHasParam, LNegative: Boolean;
  LParam, LCodePoint: Integer;
  LHex: string;
begin
  Inc(FPos); // consume backslash
  if AtEnd then
    Exit;

  case FRtf[FPos] of
    '\', '{', '}':
      begin
        AppendChar(FRtf[FPos]);
        Inc(FPos);
        Exit;
      end;
    '''':
      begin
        Inc(FPos);
        LHex := Copy(FRtf, FPos, 2);
        Inc(FPos, 2);
        if TryStrToInt('$' + LHex, LParam) then
          AppendChar(Chr(LParam));
        Exit;
      end;
  end;

  if not IsAsciiLetter(FRtf[FPos]) then
  begin
    // Unrecognized control symbol (e.g. \~, \-, \_): skip it.
    Inc(FPos);
    Exit;
  end;

  LNameStart := FPos;
  while (not AtEnd) and IsAsciiLetter(FRtf[FPos]) do
    Inc(FPos);
  LName := Copy(FRtf, LNameStart, FPos - LNameStart);

  LNegative := (not AtEnd) and (FRtf[FPos] = '-');
  if LNegative then
    Inc(FPos);
  LDigitsStart := FPos;
  while (not AtEnd) and IsAsciiDigit(FRtf[FPos]) do
    Inc(FPos);
  LHasParam := FPos > LDigitsStart;
  LParam := 0;
  if LHasParam then
  begin
    LParam := StrToInt(Copy(FRtf, LDigitsStart, FPos - LDigitsStart));
    if LNegative then
      LParam := -LParam;
  end;

  if LName = 'u' then
  begin
    // \uN is followed by exactly one fallback character (this writer
    // always emits \uc1), which must be skipped rather than rendered.
    LCodePoint := LParam;
    if LCodePoint < 0 then
      LCodePoint := LCodePoint + 65536;
    if not AtEnd then
      Inc(FPos);
    AppendChar(Chr(LCodePoint));
    Exit;
  end;

  if (not AtEnd) and (FRtf[FPos] = ' ') then
    Inc(FPos);

  HandleControlWord(LName, LHasParam, LParam);
end;

procedure TWARtfParserState.ParseFontEntry;
var
  LFontIndex: Integer;
  LNameBuilder: string;
  LDigitsStart: Integer;
begin
  LFontIndex := -1;
  LNameBuilder := '';
  while not AtEnd do
  begin
    case FRtf[FPos] of
      '\':
        begin
          Inc(FPos);
          if (not AtEnd) and (FRtf[FPos] = 'f') and (FPos + 1 <= FLength) and IsAsciiDigit(FRtf[FPos + 1]) then
          begin
            Inc(FPos);
            LDigitsStart := FPos;
            while (not AtEnd) and IsAsciiDigit(FRtf[FPos]) do
              Inc(FPos);
            LFontIndex := StrToInt(Copy(FRtf, LDigitsStart, FPos - LDigitsStart));
          end
          else
          begin
            // Font family control word (\fnil, \froman, \fcharset0, ...):
            while (not AtEnd) and IsAsciiLetter(FRtf[FPos]) do
              Inc(FPos);
            while (not AtEnd) and IsAsciiDigit(FRtf[FPos]) do
              Inc(FPos);
          end;
          if (not AtEnd) and (FRtf[FPos] = ' ') then
            Inc(FPos);
        end;
      '}':
        begin
          Inc(FPos);
          if LFontIndex >= 0 then
            FFontTable.AddOrSetValue(LFontIndex, Trim(LNameBuilder));
          Exit;
        end;
      ';':
        Inc(FPos);
    else
      LNameBuilder := LNameBuilder + FRtf[FPos];
      Inc(FPos);
    end;
  end;
end;

procedure TWARtfParserState.ParseFontTableGroup;
begin
  Inc(FPos, 8); // consume '\fonttbl'
  while not AtEnd do
  begin
    case FRtf[FPos] of
      '{':
        begin
          Inc(FPos);
          ParseFontEntry;
        end;
      '}':
        begin
          Inc(FPos);
          Exit;
        end;
    else
      Inc(FPos);
    end;
  end;
end;

procedure TWARtfParserState.ParseTableGroup;
begin
  FCurrentTable := TWATableBlock.Create(1);
  FDocument.Blocks.Add(FCurrentTable);
  while not AtEnd do
  begin
    case FRtf[FPos] of
      '\': HandleBackslashEscape;
      // Was previously always "Inc(FPos); ParseGroup" without checking
      // for a recognized destination keyword first: a checkbox/radio
      // {\field{\*\fldinst ...}{\*\fldrslt ...}} inside a table cell
      // fell into plain ParseGroup, whose own nested-group handling
      // then saw the \*-marked \fldinst/\fldrslt sub-groups as generic
      // ignorable destinations and discarded them outright -- silently
      // dropping the checkbox/radio run entirely instead of decoding
      // it via ParseFieldGroup.
      '{': HandleNestedGroupOpen;
      '}':
        begin
          Inc(FPos);
          FCurrentRow := nil;
          FCurrentCell := nil;
          FCurrentTable := nil;
          Exit;
        end;
      #10, #13: Inc(FPos);
    else
      AppendChar(FRtf[FPos]);
      Inc(FPos);
    end;
  end;
end;

procedure TWARtfParserState.ParseListTextGroup;
// Real-world \lsN/\ilvlN lists (unlike this renderer's own \fi-360
// convention) carry their visible marker in a {\listtext ...} destination
// ahead of the item's actual text. Its content (a number, a tab, or a
// single character from a symbol font standing in for a bullet) is
// decorative only and must not become part of the item's runs; instead
// it starts a new list item and, by checking whether the marker switched
// to a non-default font (the common "Wingdings/Symbol single glyph"
// bullet trick), infers whether the list is ordered or unordered.
var
  LSawNonDefaultFont: Boolean;
  LDepth: Integer;
  LNameStart, LDigitsStart: Integer;
  LName: string;
  LParam: Integer;
  LHasParam: Boolean;
begin
  Inc(FPos, 9); // consume '\listtext'
  LSawNonDefaultFont := False;
  LDepth := 1;
  while (not AtEnd) and (LDepth > 0) do
  begin
    case FRtf[FPos] of
      '\':
        begin
          Inc(FPos);
          if AtEnd then
            Break;
          if CharInSet(FRtf[FPos], ['\', '{', '}']) then
            Inc(FPos)
          else if FRtf[FPos] = '''' then
            Inc(FPos, 3)
          else if IsAsciiLetter(FRtf[FPos]) then
          begin
            LNameStart := FPos;
            while (not AtEnd) and IsAsciiLetter(FRtf[FPos]) do
              Inc(FPos);
            LName := Copy(FRtf, LNameStart, FPos - LNameStart);
            LDigitsStart := FPos;
            while (not AtEnd) and IsAsciiDigit(FRtf[FPos]) do
              Inc(FPos);
            LHasParam := FPos > LDigitsStart;
            if LHasParam then
              LParam := StrToInt(Copy(FRtf, LDigitsStart, FPos - LDigitsStart))
            else
              LParam := 0;
            if (not AtEnd) and (FRtf[FPos] = ' ') then
              Inc(FPos);
            if (LName = 'f') and LHasParam and (LParam <> 0) then
              LSawNonDefaultFont := True;
          end
          else
            Inc(FPos);
        end;
      '{': begin Inc(LDepth); Inc(FPos); end;
      '}': begin Dec(LDepth); Inc(FPos); end;
    else
      Inc(FPos); // marker text/tab: decorative only, discarded
    end;
  end;

  FListItemPending := True;
  if FCurrentList = nil then
    FCurrentList := FDocument.AddList(lkUnordered);
  if LSawNonDefaultFont then
    FCurrentList.Kind := lkUnordered
  else
    FCurrentList.Kind := lkOrdered;
  FCurrentListItem := FCurrentList.AddItem;
end;

procedure TWARtfParserState.ParseFieldGroup;
// A Word-style form field: {\field{\*\fldinst FORMCHECKBOX ...}
// {\*\fldrslt ...}}. Unlike SkipGroup (used for destinations this
// model has no representation for at all), a \field's content is
// scanned into a plain-text buffer -- including inside its \*-marked
// \fldinst/\fldrslt sub-groups, which a generic \* skip would
// otherwise discard entirely -- so the "_Check="/"_Radio="/"=true"/
// "=on" markers this project's own renderer (and WPTools) use to
// encode the field's kind and state can be recovered from it.
var
  LDepth: Integer;
  LBuffer: string;
  LIsRadio, LChecked: Boolean;
begin
  Inc(FPos, 6); // consume '\field'
  LDepth := 1;
  LBuffer := '';
  while (not AtEnd) and (LDepth > 0) do
  begin
    case FRtf[FPos] of
      '\':
        begin
          Inc(FPos);
          if AtEnd then
            Break;
          if CharInSet(FRtf[FPos], ['\', '{', '}']) then
          begin
            LBuffer := LBuffer + FRtf[FPos];
            Inc(FPos);
          end
          else if FRtf[FPos] = '''' then
            Inc(FPos, 3)
          else if IsAsciiLetter(FRtf[FPos]) then
          begin
            while (not AtEnd) and IsAsciiLetter(FRtf[FPos]) do
              Inc(FPos);
            if (not AtEnd) and (FRtf[FPos] = '-') then
              Inc(FPos);
            while (not AtEnd) and IsAsciiDigit(FRtf[FPos]) do
              Inc(FPos);
            if (not AtEnd) and (FRtf[FPos] = ' ') then
              Inc(FPos);
          end
          else
            Inc(FPos);
        end;
      '{': begin Inc(LDepth); Inc(FPos); end;
      '}': begin Dec(LDepth); Inc(FPos); end;
    else
      LBuffer := LBuffer + FRtf[FPos];
      Inc(FPos);
    end;
  end;

  LIsRadio := Pos('radio', LowerCase(LBuffer)) > 0;
  LChecked := (Pos('=true', LowerCase(LBuffer)) > 0) or (Pos('=on', LowerCase(LBuffer)) > 0);
  AppendCheckbox(LChecked, LIsRadio);
end;

procedure TWARtfParserState.ParsePictGroup;
// {\pict\<format>blip\picw<nativeW>\pich<nativeH>\picwgoal<goalWtwips>
// \pichgoal<goalHtwips> <hex bytes...>}: this project's own renderer
// always writes native size in pixels and goal size in twips (the
// latter converted at this model's usual 1px = 15twips reference), in
// that order, so goal -- read second -- naturally wins when both are
// present, matching the intended display size. Other \pict control
// words (\picscalex, \wmetafile, etc.) are recognized but ignored;
// \binN raw-binary picture data (as opposed to hex text) is not
// supported, consistent with this parser targeting its own writer's
// output and known real-world patterns rather than being a
// general-purpose RTF engine.
var
  LDepth: Integer;
  LFormat: string;
  LWidthPx, LHeightPx: Integer;
  LHexBuffer: TStringBuilder;
  LWordStart, LDigitsStart: Integer;
  LWord: string;
  LNegative, LHasParam: Boolean;
  LParam: Integer;
  LData: TBytes;
  I: Integer;
  LHex: string;
begin
  Inc(FPos, 5); // consume '\pict'
  LDepth := 1;
  LFormat := 'png';
  LWidthPx := 0;
  LHeightPx := 0;
  LHexBuffer := TStringBuilder.Create;
  try
    while (not AtEnd) and (LDepth > 0) do
    begin
      case FRtf[FPos] of
        '\':
          begin
            Inc(FPos);
            if AtEnd then
              Break;
            LWordStart := FPos;
            while (not AtEnd) and IsAsciiLetter(FRtf[FPos]) do
              Inc(FPos);
            LWord := Copy(FRtf, LWordStart, FPos - LWordStart);
            LNegative := (not AtEnd) and (FRtf[FPos] = '-');
            if LNegative then
              Inc(FPos);
            LDigitsStart := FPos;
            while (not AtEnd) and IsAsciiDigit(FRtf[FPos]) do
              Inc(FPos);
            LHasParam := FPos > LDigitsStart;
            LParam := 0;
            if LHasParam then
            begin
              LParam := StrToInt(Copy(FRtf, LDigitsStart, FPos - LDigitsStart));
              if LNegative then
                LParam := -LParam;
            end;
            if (not AtEnd) and (FRtf[FPos] = ' ') then
              Inc(FPos);

            if LWord = 'jpegblip' then
              LFormat := 'jpeg'
            else if LWord = 'pngblip' then
              LFormat := 'png'
            else if (LWord = 'picw') and LHasParam then
              LWidthPx := LParam
            else if (LWord = 'pich') and LHasParam then
              LHeightPx := LParam
            else if (LWord = 'picwgoal') and LHasParam then
              LWidthPx := LParam div 15
            else if (LWord = 'pichgoal') and LHasParam then
              LHeightPx := LParam div 15;
            // any other \pict control word is recognized-but-ignored
          end;
        '{': begin Inc(LDepth); Inc(FPos); end;
        '}':
          begin
            Dec(LDepth);
            Inc(FPos);
          end;
        ' ', #9, #10, #13: Inc(FPos); // whitespace between hex digit pairs
      else
        LHexBuffer.Append(FRtf[FPos]);
        Inc(FPos);
      end;
    end;

    LHex := LHexBuffer.ToString;
    SetLength(LData, Length(LHex) div 2);
    for I := 0 to Length(LData) - 1 do
      LData[I] := Byte(StrToInt('$' + Copy(LHex, I * 2 + 1, 2)));

    AppendImage(LData, LFormat, LWidthPx, LHeightPx);
  finally
    LHexBuffer.Free;
  end;
end;

procedure TWARtfParserState.SkipGroup;
// Discards an entire ignorable/unsupported destination group (already
// past its opening '{'), including any nested groups, without treating
// any of its plain text as document content.
var
  LDepth: Integer;
begin
  LDepth := 1;
  while (not AtEnd) and (LDepth > 0) do
  begin
    case FRtf[FPos] of
      '\':
        begin
          Inc(FPos);
          if AtEnd then
            Break;
          if CharInSet(FRtf[FPos], ['\', '{', '}']) then
            Inc(FPos)
          else if FRtf[FPos] = '''' then
            Inc(FPos, 3)
          else if IsAsciiLetter(FRtf[FPos]) then
          begin
            while (not AtEnd) and IsAsciiLetter(FRtf[FPos]) do
              Inc(FPos);
            if (not AtEnd) and (FRtf[FPos] = '-') then
              Inc(FPos);
            while (not AtEnd) and IsAsciiDigit(FRtf[FPos]) do
              Inc(FPos);
            if (not AtEnd) and (FRtf[FPos] = ' ') then
              Inc(FPos);
          end
          else
            Inc(FPos);
        end;
      '{': begin Inc(LDepth); Inc(FPos); end;
      '}': begin Dec(LDepth); Inc(FPos); end;
    else
      Inc(FPos);
    end;
  end;
end;

procedure TWARtfParserState.HandleNestedGroupOpen;
var
  LKeyword: string;
begin
  LKeyword := PeekKeywordAfterWhitespace;
  Inc(FPos); // consume '{'
  // Only skip whitespace ahead of a recognized destination keyword
  // (e.g. "{ \fonttbl ...}"). An ordinary nested run group ("{ and
  // CO}", produced whenever a plain-text run happens to start with a
  // space, e.g. right after a superscript/subscript span closes)
  // falls through to the plain ParseGroup branch below, where a
  // leading space is real text content and must be preserved, not
  // discarded.
  if LKeyword <> '' then
    SkipWhitespace;
  if LKeyword = 'fonttbl' then
    ParseFontTableGroup
  else if LKeyword = 'trowd' then
    ParseTableGroup
  else if LKeyword = 'listtext' then
    ParseListTextGroup
  else if LKeyword = 'field' then
    ParseFieldGroup
  else if LKeyword = 'pict' then
    ParsePictGroup
  else if LKeyword = 'skip' then
    SkipGroup
  else
    ParseGroup;
end;

procedure TWARtfParserState.ParseGroup;
var
  LSnapshot: TWARtfGroupSnapshot;
begin
  LSnapshot.Format := FCurrentFormat;
  LSnapshot.Alignment := FCurrentAlignment;
  FGroupStack.Push(LSnapshot);
  try
    while not AtEnd do
    begin
      case FRtf[FPos] of
        '\': HandleBackslashEscape;
        '{': HandleNestedGroupOpen;
        '}':
          begin
            Inc(FPos);
            Exit;
          end;
        #10, #13: Inc(FPos);
      else
        AppendChar(FRtf[FPos]);
        Inc(FPos);
      end;
    end;
  finally
    LSnapshot := FGroupStack.Pop;
    FCurrentFormat := LSnapshot.Format;
    FCurrentAlignment := LSnapshot.Alignment;
  end;
end;

function TWARtfParserState.Parse: TWARichDocument;
begin
  SkipWhitespace;
  if (not AtEnd) and (FRtf[FPos] = '{') then
  begin
    Inc(FPos);
    ParseGroup;
  end;
  Result := FDocument;
end;

{ TWARtfDocumentParser }

class function TWARtfDocumentParser.Parse(const ARtf: string): TWARichDocument;
var
  LState: TWARtfParserState;
begin
  LState := TWARtfParserState.Create(ARtf);
  try
    Result := LState.Parse;
  finally
    LState.Free;
  end;
end;

end.
