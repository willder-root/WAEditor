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
  WAEditor.Domain.Types,
  WAEditor.Domain.BitmapConverter;

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
    // {\colortbl} entries in order, as $RRGGBB; -1 for an entry with no
    // \red/\green/\blue (the "auto" color Word writes first).
    FColorTable: TList<Integer>;
    // Cell shading words read since the last \cellx (color table indexes,
    // -1 = not given; \clshdng in hundredths of a percent) and the
    // resolved background of each \cellx of the row (-1 = none).
    FPendingCellBackIndex: Integer;
    FPendingCellForeIndex: Integer;
    FPendingCellShading: Integer;
    FPendingCellBackgrounds: TList<Integer>;
    FGroupStack: TStack<TWARtfGroupSnapshot>;
    FCurrentFormat: TWARunFormat;
    FCurrentAlignment: TWATextAlignment;
    FCurrentHasBorder: Boolean;
    FPendingTableLeft: Integer;
    // Signed \trleft and the row's width in twips (\trwWidth when
    // \trftsWidth3), used to fit the row to the table's right edge.
    FPendingRowLeft: Integer;
    FPendingRowWidthUnit: Integer;
    FPendingRowWidth: Integer;
    FCurrentLeftIndent: Integer;
    FCurrentRightIndent: Integer;
    FCurrentFirstLineIndent: Integer;
    FCurrentParagraph: TWAParagraphBlock;
    FCurrentTable: TWATableBlock;
    // The table most recently closed, kept so that consecutive row groups
    // (WPTools writes every row as its own {\trowd...\row} group inside
    // one \tblstart/\tblend span) are merged back into a single table
    // instead of becoming one table per row.
    FLastTable: TWATableBlock;
    FCurrentRow: TWATableRow;
    FCurrentCell: TWATableCell;
    // A \par inside a cell is a paragraph boundary within it; the model
    // has no per-cell paragraphs, so it becomes a line break run -- but
    // only once more content follows, so the \par that ends a cell's
    // last line does not leave a trailing blank line.
    FCellParagraphBreakPending: Boolean;
    // \cellx values accumulated for the row currently being read; each
    // is a cumulative right-edge position in twips, reset at \trowd and
    // turned into per-column widths (via consecutive differences) on
    // \row, once, from the table's first row.
    FPendingCellxValues: TList<Integer>;
    // Horizontal merge flag of each \cellx above (0 = none, 1 = \clmgf
    // first cell of a merge, 2 = \clmrg continuation), the flag pending
    // for the next \cellx, and the grid column of the cell being read.
    FPendingCellMerges: TList<Integer>;
    FPendingMerge: Integer;
    FCurrentGridIndex: Integer;
    // Right edge (absolute \cellx, twips) of every visible cell of each row
    // read so far. WPTools writes each row with its own \cellx set (a form
    // row may have 6 cells and the next one 2, the first of them as wide
    // as 5 of the row above), so the table grid is the union of the edges
    // of all rows, rebuilt at every \row (see RebuildTableGrid).
    FRowCellEdges: TDictionary<TWATableRow, TArray<Integer>>;
    // Every \cellx of each row, merged or not: the grid keeps the inner
    // edges of a \clmgf/\clmrg merge even when no other row repeats them.
    FRowGridEdges: TDictionary<TWATableRow, TArray<Integer>>;
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
    procedure FlushCellParagraphBreak;
    procedure ClosePendingParagraph;

    procedure HandleNestedGroupOpen;
    procedure ParseGroup;
    procedure ParseFontTableGroup;
    procedure ParseFontEntry;
    procedure ParseColorTableGroup;
    function TryGetTableColor(AIndex: Integer; out AColor: Integer): Boolean;
    function ResolvePendingCellBackground: Integer;
    procedure ResetPendingCellShading;
    procedure ParseTableGroup;
    procedure RecordRowCellEdges;
    procedure RebuildTableGrid(ATable: TWATableBlock);
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
  FColorTable := TList<Integer>.Create;
  FPendingCellBackgrounds := TList<Integer>.Create;
  ResetPendingCellShading;
  FGroupStack := TStack<TWARtfGroupSnapshot>.Create;
  FPendingCellxValues := TList<Integer>.Create;
  FPendingCellMerges := TList<Integer>.Create;
  FRowCellEdges := TDictionary<TWATableRow, TArray<Integer>>.Create;
  FRowGridEdges := TDictionary<TWATableRow, TArray<Integer>>.Create;
  FCurrentFormat := TWARunFormat.Plain;
  FCurrentAlignment := taLeftAlign;
end;

destructor TWARtfParserState.Destroy;
begin
  FPendingCellMerges.Free;
  FRowCellEdges.Free;
  FRowGridEdges.Free;
  FPendingCellxValues.Free;
  FGroupStack.Free;
  FPendingCellBackgrounds.Free;
  FColorTable.Free;
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
  WA_SKIPPABLE_DESTINATIONS: array[0..5] of string = (
    'stylesheet', 'info', 'rsidtbl', 'listtable',
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
    else if MatchesControlWordAt(FPos, 'colortbl') then
      Result := 'colortbl'
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
    FCurrentParagraph.LeftIndentTwips := FCurrentLeftIndent;
    FCurrentParagraph.RightIndentTwips := FCurrentRightIndent;
    FCurrentParagraph.FirstLineIndentTwips := FCurrentFirstLineIndent;
  end;
end;

procedure TWARtfParserState.ClosePendingParagraph;
begin
  FCurrentParagraph := nil;
end;

procedure TWARtfParserState.FlushCellParagraphBreak;
begin
  if FCellParagraphBreakPending and (FCurrentCell <> nil) then
  begin
    if FCurrentCell.Runs.Count > 0 then
      FCurrentCell.Runs.Add(TWARun.CreateLineBreak);
    FCellParagraphBreakPending := False;
  end;
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
    FlushCellParagraphBreak;
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
  FlushCellParagraphBreak;
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
  FlushCellParagraphBreak;
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
  FlushCellParagraphBreak;
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
  LColor: Integer;
begin
  if AName = 'par' then
  begin
    if FCurrentCell <> nil then
      FCellParagraphBreakPending := True;
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
    FCurrentLeftIndent := 0;
    FCurrentRightIndent := 0;
    FCurrentFirstLineIndent := 0;
    FListItemPending := False;
  end
  else if AName = 'li' then
  begin
    if AHasParam then
      FCurrentLeftIndent := AParam;
  end
  else if AName = 'ri' then
  begin
    if AHasParam then
      FCurrentRightIndent := AParam;
  end
  else if (AName = 'brdrl') or (AName = 'brdrr') or (AName = 'brdrt') or (AName = 'brdrb') then
    FCurrentHasBorder := True
  else if AName = 'fi' then
  begin
    if AHasParam and (AParam >= 0) then
      FCurrentFirstLineIndent := AParam;
    // Only start a new item this way when one hasn't already been opened
    // by a preceding {\listtext...} group (real-world \lsN-based lists
    // carry their own list-item marker there; \fi-360 may still follow
    // it purely for indentation and must not create a duplicate item).
    if AHasParam and (AParam < 0) and (FCurrentListItem = nil) and (FCurrentCell = nil) then
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
  else if AName = 'cf' then
  begin
    // \cf0 is the default color: Word's first entry is the empty "auto"
    // one, and WPTools (whose table starts with black) writes \cf0 on
    // every run of normal text.
    FCurrentFormat.HasColor := AHasParam and (AParam > 0) and TryGetTableColor(AParam, LColor);
    if FCurrentFormat.HasColor then
      FCurrentFormat.Color := LColor
    else
      FCurrentFormat.Color := 0;
  end
  else if AName = 'clcbpat' then
  begin
    if AHasParam then
      FPendingCellBackIndex := AParam;
  end
  else if AName = 'clcfpat' then
  begin
    if AHasParam then
      FPendingCellForeIndex := AParam;
  end
  else if AName = 'clshdng' then
  begin
    if AHasParam then
      FPendingCellShading := AParam;
  end
  else if AName = 'trowd' then
  begin
    if FCurrentTable <> nil then
    begin
      FCurrentRow := FCurrentTable.AddRow;
      FPendingCellxValues.Clear;
      FPendingCellMerges.Clear;
      FPendingCellBackgrounds.Clear;
      ResetPendingCellShading;
      FPendingMerge := 0;
      FCurrentGridIndex := 0;
      FPendingTableLeft := 0;
      FPendingRowLeft := 0;
      FPendingRowWidthUnit := 0;
      FPendingRowWidth := 0;
    end;
  end
  else if AName = 'trleft' then
  begin
    // The table's distance from the text area's left edge; the \cellx
    // values that follow are absolute, so it is subtracted from the first
    // column below. Negative values (Word's cell-padding compensation)
    // are not modeled and keep the old flush-left reading.
    if AHasParam then
      FPendingRowLeft := AParam;
    if AHasParam and (AParam > 0) then
      FPendingTableLeft := AParam;
  end
  else if AName = 'trftsWidth' then
  begin
    if AHasParam then
      FPendingRowWidthUnit := AParam;
  end
  else if AName = 'trwWidth' then
  begin
    if AHasParam then
      FPendingRowWidth := AParam;
  end
  else if AName = 'cellx' then
  begin
    if AHasParam then
    begin
      FPendingCellxValues.Add(AParam);
      FPendingCellMerges.Add(FPendingMerge);
      FPendingCellBackgrounds.Add(ResolvePendingCellBackground);
    end;
    FPendingMerge := 0;
    ResetPendingCellShading;
  end
  else if AName = 'clmgf' then
    FPendingMerge := 1
  else if AName = 'clmrg' then
    FPendingMerge := 2
  else if (AName = 'clbrdrl') or (AName = 'clbrdrr') or (AName = 'clbrdrt') or
          (AName = 'clbrdrb') then
  begin
    // Any cell border at all makes the table bordered; \brdrw (below)
    // refines the width, otherwise it is the default 1.
    if (FCurrentTable <> nil) and (FCurrentRow <> nil) and (FCurrentCell = nil) and
       (FCurrentTable.BorderWidth = 0) then
      FCurrentTable.BorderWidth := 1;
  end
  else if AName = 'tblend' then
    FLastTable := nil
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
  begin
    if FCurrentCell <> nil then
    begin
      FCurrentCell.Alignment := FCurrentAlignment;
      if (FCurrentGridIndex < FPendingCellBackgrounds.Count) and
         (FPendingCellBackgrounds[FCurrentGridIndex] >= 0) then
      begin
        FCurrentCell.HasBackgroundColor := True;
        FCurrentCell.BackgroundColor := FPendingCellBackgrounds[FCurrentGridIndex];
      end;
    end;
    // A \clmrg grid cell is the continuation of the merge started by the
    // cell before it: its (normally empty) content is dropped and the
    // previous cell spans one more column (HTML colspan).
    if (FCurrentRow <> nil) and (FCurrentGridIndex < FPendingCellMerges.Count) and
       (FPendingCellMerges[FCurrentGridIndex] = 2) then
    begin
      if (FCurrentCell <> nil) and (FCurrentRow.Cells.Count >= 2) and
         (FCurrentRow.Cells.Last = FCurrentCell) then
      begin
        Inc(FCurrentRow.Cells[FCurrentRow.Cells.Count - 2].ColSpan);
        FCurrentRow.Cells.Delete(FCurrentRow.Cells.Count - 1);
      end
      else if (FCurrentCell = nil) and (FCurrentRow.Cells.Count >= 1) then
        // A bare \cell (no \intbl paragraph) for the continuation.
        Inc(FCurrentRow.Cells.Last.ColSpan);
    end;
    Inc(FCurrentGridIndex);
    FCurrentCell := nil;
    FCellParagraphBreakPending := False;
  end
  else if AName = 'row' then
  begin
    // \cellx values are cumulative right-edge positions in twips. The
    // table's left offset comes from its first row; the column grid is
    // the union of the cell edges of all rows read so far.
    if (FCurrentTable <> nil) and (FCurrentRow <> nil) and
       (FPendingCellxValues.Count > 0) then
    begin
      if Length(FCurrentTable.ColumnWidths) = 0 then
        FCurrentTable.LeftOffsetTwips := FPendingTableLeft;
      RecordRowCellEdges;
      RebuildTableGrid(FCurrentTable);
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

procedure TWARtfParserState.ParseColorTableGroup;
// {\colortbl;\red255\green0\blue0;...}: one entry per ';', each made of
// \red/\green/\blue. An entry with none of them (Word's leading empty one)
// is the automatic color.
var
  LNameStart, LDigitsStart, LParam: Integer;
  LName: string;
  LRed, LGreen, LBlue: Integer;
  LHasComponent: Boolean;
begin
  Inc(FPos, 9); // consume '\colortbl'
  LRed := 0;
  LGreen := 0;
  LBlue := 0;
  LHasComponent := False;
  while not AtEnd do
  begin
    case FRtf[FPos] of
      '\':
        begin
          Inc(FPos);
          LNameStart := FPos;
          while (not AtEnd) and IsAsciiLetter(FRtf[FPos]) do
            Inc(FPos);
          LName := Copy(FRtf, LNameStart, FPos - LNameStart);
          LDigitsStart := FPos;
          while (not AtEnd) and IsAsciiDigit(FRtf[FPos]) do
            Inc(FPos);
          LParam := StrToIntDef(Copy(FRtf, LDigitsStart, FPos - LDigitsStart), 0) and $FF;
          if (not AtEnd) and (FRtf[FPos] = ' ') then
            Inc(FPos);
          if LName = 'red' then
            LRed := LParam
          else if LName = 'green' then
            LGreen := LParam
          else if LName = 'blue' then
            LBlue := LParam
          else
            Continue;
          LHasComponent := True;
        end;
      ';':
        begin
          if LHasComponent then
            FColorTable.Add((LRed shl 16) or (LGreen shl 8) or LBlue)
          else
            FColorTable.Add(-1);
          LRed := 0;
          LGreen := 0;
          LBlue := 0;
          LHasComponent := False;
          Inc(FPos);
        end;
      '{':
        begin
          Inc(FPos);
          SkipGroup;
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

function TWARtfParserState.TryGetTableColor(AIndex: Integer; out AColor: Integer): Boolean;
begin
  Result := (AIndex >= 0) and (AIndex < FColorTable.Count) and (FColorTable[AIndex] >= 0);
  if Result then
    AColor := FColorTable[AIndex]
  else
    AColor := 0;
end;

procedure TWARtfParserState.ResetPendingCellShading;
begin
  FPendingCellBackIndex := -1;
  FPendingCellForeIndex := -1;
  FPendingCellShading := 0;
end;

function TWARtfParserState.ResolvePendingCellBackground: Integer;
// The cell's background as $RRGGBB, or -1 for none. \clcbpat is the
// background color; \clshdng N (hundredths of a percent) lays the
// \clcfpat color over it at N% (auto foreground = black, auto background
// = white). WPTools writes a filled cell as \clcfpatK\clcbpatK\clshdng10000,
// which is K under either reading. Index 0 is the automatic color, as for
// \cf.
var
  LBack, LFore, LShading: Integer;
  LHasBack, LHasFore: Boolean;

  function Blend(AShift: Integer): Integer;
  begin
    Result := (((LFore shr AShift) and $FF) * LShading +
      ((LBack shr AShift) and $FF) * (10000 - LShading) + 5000) div 10000;
  end;

begin
  LHasBack := (FPendingCellBackIndex > 0) and TryGetTableColor(FPendingCellBackIndex, LBack);
  LHasFore := (FPendingCellForeIndex > 0) and TryGetTableColor(FPendingCellForeIndex, LFore);
  LShading := FPendingCellShading;
  if LShading > 10000 then
    LShading := 10000;
  if LShading <= 0 then
  begin
    if LHasBack then
      Exit(LBack);
    Exit(-1);
  end;
  if not LHasFore then
    LFore := $000000;
  if not LHasBack then
    LBack := $FFFFFF;
  Result := (Blend(16) shl 16) or (Blend(8) shl 8) or Blend(0);
end;

procedure TWARtfParserState.RecordRowCellEdges;
// The right edge of each visible cell of the row just closed: a cell
// spanning N grid cells (\clmgf + \clmrg) ends at the \cellx of its last
// one. A row that ends with bare \cell words (no \intbl, so no cell in the
// model) simply has fewer edges.
//
// A row with a width in twips (\trftsWidth3\trwWidth, as WPTools writes
// every row) is fitted to it, the way WPTools draws it: the row ends at
// \trleft + \trwWidth, so a row whose last \cellx falls short is widened
// to the table's right edge and one that goes past it is cut there. The
// AIH form has rows ending at 8475 and 9896 in a 8886-wide table; WPTools
// shows them all flush, and without the fit they came out ragged, with
// cells sticking out of the table, both in the editor and in the RTF
// written back (which carries no \trwWidth).
var
  LEdges, LGridEdges: TArray<Integer>;
  LCellIndex, LGridEnd, LCellxIndex, LRowRight, I: Integer;
begin
  LGridEdges := FPendingCellxValues.ToArray;
  if (FPendingRowWidthUnit = 3) and (FPendingRowWidth > 0) and (Length(LGridEdges) > 0) then
  begin
    LRowRight := FPendingRowLeft + FPendingRowWidth;
    for I := 0 to High(LGridEdges) do
      if LGridEdges[I] > LRowRight then
        LGridEdges[I] := LRowRight;
    LGridEdges[High(LGridEdges)] := LRowRight;
    for I := 0 to High(LGridEdges) do
      FPendingCellxValues[I] := LGridEdges[I];
  end;

  SetLength(LEdges, FCurrentRow.Cells.Count);
  LGridEnd := 0;
  for LCellIndex := 0 to FCurrentRow.Cells.Count - 1 do
  begin
    Inc(LGridEnd, FCurrentRow.Cells[LCellIndex].ColSpan);
    LCellxIndex := LGridEnd - 1;
    if LCellxIndex >= FPendingCellxValues.Count then
      LCellxIndex := FPendingCellxValues.Count - 1;
    LEdges[LCellIndex] := FPendingCellxValues[LCellxIndex];
  end;
  FRowCellEdges.AddOrSetValue(FCurrentRow, LEdges);
  FRowGridEdges.AddOrSetValue(FCurrentRow, LGridEdges);
end;

procedure TWARtfParserState.RebuildTableGrid(ATable: TWATableBlock);
// Grid columns = the sorted union of the \cellx edges of every row; edges
// closer than WA_GRID_EDGE_TOLERANCE are one and the same edge (rows typed
// by hand rarely line up to the twip, and a 1-twip difference must not
// become a sliver column). Each cell then spans the grid columns between
// the previous cell's edge and its own (HTML colspan), so a 2-cell row
// under a 6-cell row keeps its real widths instead of the first two
// columns of the 6-cell row.
const
  WA_GRID_EDGE_TOLERANCE = 150; // twips, 10px: hand-drawn rows differ by a few px
var
  LAllEdges: TList<Integer>;
  LGrid: TList<Integer>;
  LRow: TWATableRow;
  LEdges: TArray<Integer>;
  LEdge, LIndex, LCellIndex, LGridIndex, LPreviousGridIndex: Integer;
begin
  LAllEdges := TList<Integer>.Create;
  LGrid := TList<Integer>.Create;
  try
    for LRow in ATable.Rows do
      if FRowGridEdges.TryGetValue(LRow, LEdges) then
        for LEdge in LEdges do
          LAllEdges.Add(LEdge);
    if LAllEdges.Count = 0 then
      Exit;
    LAllEdges.Sort;
    for LEdge in LAllEdges do
      if (LGrid.Count = 0) or (LEdge - LGrid.Last > WA_GRID_EDGE_TOLERANCE) then
        LGrid.Add(LEdge);

    SetLength(ATable.ColumnWidths, LGrid.Count);
    for LIndex := 0 to LGrid.Count - 1 do
      if LIndex = 0 then
        ATable.ColumnWidths[0] := LGrid[0] - ATable.LeftOffsetTwips
      else
        ATable.ColumnWidths[LIndex] := LGrid[LIndex] - LGrid[LIndex - 1];

    for LRow in ATable.Rows do
      if FRowCellEdges.TryGetValue(LRow, LEdges) then
      begin
        LPreviousGridIndex := -1;
        for LCellIndex := 0 to LRow.Cells.Count - 1 do
        begin
          // The grid edge this cell's edge was folded into
          LGridIndex := LGrid.Count - 1;
          for LIndex := 0 to LGrid.Count - 1 do
            if LGrid[LIndex] >= LEdges[LCellIndex] - WA_GRID_EDGE_TOLERANCE then
            begin
              LGridIndex := LIndex;
              Break;
            end;
          if LGridIndex - LPreviousGridIndex >= 1 then
            LRow.Cells[LCellIndex].ColSpan := LGridIndex - LPreviousGridIndex
          else
            LRow.Cells[LCellIndex].ColSpan := 1;
          LPreviousGridIndex := LPreviousGridIndex + LRow.Cells[LCellIndex].ColSpan;
        end;
      end;
  finally
    LGrid.Free;
    LAllEdges.Free;
  end;
end;

procedure TWARtfParserState.ParseTableGroup;
begin
  if (FLastTable <> nil) and (FDocument.Blocks.Count > 0) and
     (FDocument.Blocks.Last = FLastTable) then
    FCurrentTable := FLastTable
  else
  begin
    // RTF draws no table grid by itself: a table only has borders if
    // its cells carry \clbrdr* (see HandleControlWord), so it starts
    // borderless rather than assuming HTML's border="1".
    FCurrentTable := TWATableBlock.Create(0);
    FDocument.Blocks.Add(FCurrentTable);
  end;
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
          FLastTable := FCurrentTable;
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
  LData, LBmp: TBytes;
  I: Integer;
  LHex: string;
  LSourceKind: string;
begin
  Inc(FPos, 5); // consume '\pict'
  LDepth := 1;
  LFormat := 'png';
  LWidthPx := 0;
  LHeightPx := 0;
  LSourceKind := '';
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
            else if LWord = 'wmetafile' then
              LSourceKind := 'wmf'
            else if LWord = 'dibitmap' then
              LSourceKind := 'dib'
            else if (LWord = 'picw') and LHasParam then
              LWidthPx := LParam
            else if (LWord = 'pich') and LHasParam then
              LHeightPx := LParam
            else if (LWord = 'picwgoal') and LHasParam then
              LWidthPx := (LParam + 7) div 15
            else if (LWord = 'pichgoal') and LHasParam then
              LHeightPx := (LParam + 7) div 15;
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

    // A browser cannot display either of RTF's Windows-native picture
    // containers, so a bare DIB or a WMF-wrapped bitmap (how WPTools
    // stores a pasted bitmap) is re-wrapped as a plain .bmp. A WMF with
    // no bitmap record is purely vector and has nothing to show.
    if LSourceKind = 'wmf' then
    begin
      if not TWABitmapConverter.TryWmfToBmp(LData, LBmp) then
        Exit;
      LData := LBmp;
      LFormat := 'bmp';
    end
    else if LSourceKind = 'dib' then
    begin
      if not TWABitmapConverter.TryDibToBmp(LData, LBmp) then
        Exit;
      LData := LBmp;
      LFormat := 'bmp';
    end;

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
  else if LKeyword = 'colortbl' then
    ParseColorTableGroup
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
