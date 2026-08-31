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

    procedure ParseGroup;
    procedure ParseFontTableGroup;
    procedure ParseFontEntry;
    procedure ParseTableGroup;
    procedure ParseListTextGroup;
    procedure ParseFieldGroup;
    procedure AppendCheckbox(AChecked: Boolean; AIsRadio: Boolean);
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
  FCurrentFormat := TWARunFormat.Plain;
  FCurrentAlignment := taLeftAlign;
end;

destructor TWARtfParserState.Destroy;
begin
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
  WA_SKIPPABLE_DESTINATIONS: array[0..7] of string = (
    'colortbl', 'stylesheet', 'info', 'rsidtbl', 'listtable',
    'listoverridetable', 'generator', 'pict');
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
       FCurrentCell.Runs.Last.Format.EqualsFormat(FCurrentFormat) then
      FCurrentCell.Runs.Last.Text := FCurrentCell.Runs.Last.Text + AChar
    else
      FCurrentCell.AddRun(AChar, FCurrentFormat);
  end
  else if FCurrentListItem <> nil then
  begin
    if (FCurrentListItem.Runs.Count > 0) and (not FCurrentListItem.Runs.Last.IsLineBreak) and
       FCurrentListItem.Runs.Last.Format.EqualsFormat(FCurrentFormat) then
      FCurrentListItem.Runs.Last.Text := FCurrentListItem.Runs.Last.Text + AChar
    else
      FCurrentListItem.AddRun(AChar, FCurrentFormat);
  end
  else
  begin
    EnsureParagraph;
    if (FCurrentParagraph.Runs.Count > 0) and (not FCurrentParagraph.Runs.Last.IsLineBreak) and
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

procedure TWARtfParserState.HandleControlWord(const AName: string; AHasParam: Boolean;
  AParam: Integer);
var
  LFontName: string;
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
      FCurrentRow := FCurrentTable.AddRow;
  end
  else if AName = 'intbl' then
  begin
    if (FCurrentCell = nil) and (FCurrentRow <> nil) then
      FCurrentCell := FCurrentRow.AddCell;
  end
  else if AName = 'cell' then
    FCurrentCell := nil
  else if AName = 'row' then
    FCurrentRow := nil
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
      '{': begin Inc(FPos); ParseGroup; end;
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

procedure TWARtfParserState.ParseGroup;
var
  LSnapshot: TWARtfGroupSnapshot;
  LKeyword: string;
begin
  LSnapshot.Format := FCurrentFormat;
  LSnapshot.Alignment := FCurrentAlignment;
  FGroupStack.Push(LSnapshot);
  try
    while not AtEnd do
    begin
      case FRtf[FPos] of
        '\': HandleBackslashEscape;
        '{':
          begin
            LKeyword := PeekKeywordAfterWhitespace;
            Inc(FPos); // consume '{'
            SkipWhitespace; // skip any whitespace before the keyword
            if LKeyword = 'fonttbl' then
              ParseFontTableGroup
            else if LKeyword = 'trowd' then
              ParseTableGroup
            else if LKeyword = 'listtext' then
              ParseListTextGroup
            else if LKeyword = 'field' then
              ParseFieldGroup
            else if LKeyword = 'skip' then
              SkipGroup
            else
              ParseGroup;
          end;
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
