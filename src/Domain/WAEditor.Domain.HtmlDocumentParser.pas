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
  System.NetEncoding,
  WAEditor.Domain.Types,
  WAEditor.Domain.AlignmentMapper,
  WAEditor.Domain.FontSizeScale,
  WAEditor.Domain.ImageInfo;

const
  // Width of the text area a percentage table width is relative to:
  // A4 (11906 twips) minus 2.54cm margins on both sides.
  WA_TEXT_AREA_WIDTH_TWIPS = 9026;

function DotDecimalFormatSettings: TFormatSettings;
begin
  // CSS numbers always use '.' as the decimal separator regardless of
  // locale; without forcing it here, TryStrToFloat would fail on a
  // system whose locale uses ',' (e.g. pt-BR), silently dropping any
  // fractional font size just like StrToIntDef does for non-integers.
  Result := TFormatSettings.Create;
  Result.DecimalSeparator := '.';
end;

const
  // Matches the common browser default of 16px/1em when a relative
  // unit (em/rem/%) has no concrete inherited size to scale from.
  WA_DEFAULT_BROWSER_FONT_SIZE_PT = 12;

/// Converts a CSS <length> font-size value (e.g. "10.5pt", "16px",
/// "1.5em", "150%", "0.5in") to whole points. ABaseFontSizeInPoints is
/// the size already inherited at this point (used to resolve the
/// relative units em/rem/%); pass 0 if there is none, in which case the
/// common 16px/12pt browser default is used instead. Returns False for
/// an empty value, a bare number (CSS requires a unit for font-size,
/// unlike line-height) or an unrecognized/keyword unit (e.g. "medium").
function TryParseCssFontSizeToPoints(const AValue: string; ABaseFontSizeInPoints: Integer;
  out APoints: Integer): Boolean;
var
  I: Integer;
  LNumberPart, LUnit: string;
  LNumericValue: Double;
  LBasePoints: Double;
begin
  Result := False;
  I := 1;
  if (I <= Length(AValue)) and CharInSet(AValue[I], ['+', '-']) then
    Inc(I);
  while (I <= Length(AValue)) and CharInSet(AValue[I], ['0'..'9', '.']) do
    Inc(I);
  LNumberPart := Trim(Copy(AValue, 1, I - 1));
  LUnit := LowerCase(Trim(Copy(AValue, I, MaxInt)));

  if (LNumberPart = '') or (LUnit = '') then
    Exit;
  if not TryStrToFloat(LNumberPart, LNumericValue, DotDecimalFormatSettings) then
    Exit;

  if ABaseFontSizeInPoints > 0 then
    LBasePoints := ABaseFontSizeInPoints
  else
    LBasePoints := WA_DEFAULT_BROWSER_FONT_SIZE_PT;

  Result := True;
  if LUnit = 'pt' then
    APoints := Round(LNumericValue)
  else if LUnit = 'px' then
    APoints := Round(LNumericValue * 0.75)
  else if LUnit = 'pc' then
    APoints := Round(LNumericValue * 12)
  else if LUnit = 'in' then
    APoints := Round(LNumericValue * 72)
  else if LUnit = 'cm' then
    APoints := Round(LNumericValue * 28.3464567)
  else if LUnit = 'mm' then
    APoints := Round(LNumericValue * 2.83464567)
  else if (LUnit = 'em') or (LUnit = 'rem') then
    APoints := Round(LNumericValue * LBasePoints)
  else if LUnit = '%' then
    APoints := Round(LNumericValue / 100 * LBasePoints)
  else
    Result := False; // unrecognized/keyword unit (e.g. "medium", "larger")
end;

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
    FCurrentTableWidthPercent: Double;
    FCurrentTableWidthPx: Double;
    FCurrentTableBorderless: Boolean;
    FCurrentTableLeftTwips: Integer;
    FCurrentTableLeftAuto: Boolean;
    FCurrentTableRightAuto: Boolean;
    FCurrentCell: TWATableCell;
    FCurrentList: TWAListBlock;
    FCurrentListItem: TWAListItem;

    function CurrentFormat: TWARunFormat;
    procedure EnsureParagraph;
    procedure AppendRun(ARun: TWARun);
    procedure AppendTextSegment(const AText: string);
    procedure AppendText(const AText: string);
    procedure AppendLineBreak;
    procedure ApplyTableOffset;
    procedure HandleOpenTag(const ATagName, AAttributes: string);
    procedure HandleCloseTag(const ATagName: string);
    procedure ProcessTag(const ATag: string);
  public
    constructor Create(const AHtml: string);
    destructor Destroy; override;
    function Parse: TWARichDocument;
  end;

function DecodeNumericCharacterReferences(const AText: string): string;
// &#60; (decimal) and &#x3C; (hex) character references.
var
  LBuilder: TStringBuilder;
  I, LEnd, LCode: Integer;
  LDigits: string;
  LIsHex: Boolean;
begin
  LBuilder := TStringBuilder.Create;
  try
    I := 1;
    while I <= Length(AText) do
    begin
      if (AText[I] = '&') and (I + 2 <= Length(AText)) and (AText[I + 1] = '#') then
      begin
        LEnd := PosEx(';', AText, I + 2);
        if (LEnd > 0) and (LEnd - I <= 10) then
        begin
          LIsHex := CharInSet(AText[I + 2], ['x', 'X']);
          if LIsHex then
            LDigits := Copy(AText, I + 3, LEnd - I - 3)
          else
            LDigits := Copy(AText, I + 2, LEnd - I - 2);
          if LDigits <> '' then
            if LIsHex then
              LCode := StrToIntDef('$' + LDigits, -1)
            else
              LCode := StrToIntDef(LDigits, -1)
          else
            LCode := -1;
          if (LCode > 0) and (LCode <= $FFFF) then
          begin
            LBuilder.Append(Char(LCode));
            I := LEnd + 1;
            Continue;
          end;
        end;
      end;
      LBuilder.Append(AText[I]);
      Inc(I);
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function DecodeHtmlEntities(const AText: string): string;
// Order matters: named entities first, numeric references next, '&amp;'
// last, so no decoded '&' is ever re-read as the start of another entity
// ("&amp;lt;" and "&#38;lt;" both stay the literal text "&lt;").
begin
  Result := AText;
  Result := StringReplace(Result, '&nbsp;', ' ', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll, rfIgnoreCase]);
  Result := DecodeNumericCharacterReferences(Result);
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

function HasBooleanAttribute(const AAttributes, AAttrName: string): Boolean;
// HTML boolean attributes (checked, disabled, ...) can appear bare,
// with no "=value" at all, so ExtractAttribute's name= search does not
// find them. Looks for the name as a standalone token (not, e.g., the
// "checked" inside "unchecked") anywhere in the attribute text.
var
  LLower, LNameLower: string;
  LPos, LBefore, LAfter: Integer;
begin
  Result := False;
  LLower := LowerCase(AAttributes);
  LNameLower := LowerCase(AAttrName);
  LPos := Pos(LNameLower, LLower);
  while LPos > 0 do
  begin
    LBefore := LPos - 1;
    LAfter := LPos + Length(LNameLower);
    if ((LBefore < 1) or not CharInSet(LLower[LBefore], ['a'..'z'])) and
       ((LAfter > Length(LLower)) or not CharInSet(LLower[LAfter], ['a'..'z'])) then
      Exit(True);
    LPos := PosEx(LNameLower, LLower, LPos + 1);
  end;
end;

function FindStylePropertyPos(const ALowerStyle, APropName: string): Integer;
// Finds APropName as an actual property name (not, e.g., "width" inside
// "min-width"): the match must not be immediately preceded by a letter
// or hyphen.
var
  LPos, LBefore: Integer;
begin
  Result := 0;
  LPos := Pos(APropName, ALowerStyle);
  while LPos > 0 do
  begin
    LBefore := LPos - 1;
    if (LBefore < 1) or not CharInSet(ALowerStyle[LBefore], ['a'..'z', '-']) then
      Exit(LPos);
    LPos := PosEx(APropName, ALowerStyle, LPos + 1);
  end;
end;

function ExtractColumnWidthInTwips(const AAttributes, AAttrName: string): Integer;
// A live WYSIWYG surface records a <col>'s width as a bare "width"
// attribute or as "width:Npx" in its style, and a <td>'s width as a
// bare "colwidth" attribute. Reads whichever applies and converts px
// to twips (RTF's native unit) at the standard 96dpi reference
// (1px = 15 twips). Returns 0 if no usable width was found.
var
  LStyle, LLowerStyle, LValueText, LDigits: string;
  LWidthPos, LColonPos, LSemiPos, I: Integer;
begin
  Result := 0;
  LValueText := Trim(ExtractAttribute(AAttributes, AAttrName));
  if (LValueText = '') and (LowerCase(AAttrName) = 'width') then
  begin
    LStyle := ExtractAttribute(AAttributes, 'style');
    LLowerStyle := LowerCase(LStyle);
    LWidthPos := FindStylePropertyPos(LLowerStyle, 'width');
    if LWidthPos = 0 then
      Exit;
    LColonPos := PosEx(':', LStyle, LWidthPos);
    if LColonPos = 0 then
      Exit;
    LSemiPos := PosEx(';', LStyle, LColonPos);
    if LSemiPos = 0 then
      LSemiPos := Length(LStyle) + 1;
    LValueText := Trim(Copy(LStyle, LColonPos + 1, LSemiPos - LColonPos - 1));
  end;

  LDigits := '';
  I := 1;
  while (I <= Length(LValueText)) and CharInSet(LValueText[I], ['0'..'9']) do
  begin
    LDigits := LDigits + LValueText[I];
    Inc(I);
  end;
  if LDigits <> '' then
    Result := StrToIntDef(LDigits, 0) * 15; // px -> twips at 96dpi
end;

function TryDecodeDataUriImage(const ASrc: string; out AData: TBytes;
  out AFormat: string): Boolean;
// Only inline "data:image/<subtype>;base64,<payload>" sources are
// supported -- exactly what a WYSIWYG surface's own paste/upload
// produces -- not a remote http(s) URL, which this bounded model has
// no way to fetch and embed a byte-for-byte copy of.
const
  WA_DATA_IMAGE_PREFIX = 'data:image/';
  WA_BASE64_MARKER = ';base64,';
var
  LLowerSrc: string;
  LSubtypeStart, LSemiPos, LCommaPos: Integer;
begin
  Result := False;
  AData := nil;
  AFormat := '';
  LLowerSrc := LowerCase(ASrc);
  if Copy(LLowerSrc, 1, Length(WA_DATA_IMAGE_PREFIX)) <> WA_DATA_IMAGE_PREFIX then
    Exit;
  LSubtypeStart := Length(WA_DATA_IMAGE_PREFIX) + 1;
  LSemiPos := PosEx(';', ASrc, LSubtypeStart);
  LCommaPos := Pos(',', LLowerSrc);
  if (LSemiPos = 0) or (LCommaPos = 0) or (LCommaPos <= LSemiPos) then
    Exit;
  if Copy(LLowerSrc, LSemiPos, Length(WA_BASE64_MARKER)) <> WA_BASE64_MARKER then
    Exit; // only base64-encoded payloads are supported, not URL-encoded text
  AFormat := LowerCase(Copy(ASrc, LSubtypeStart, LSemiPos - LSubtypeStart));
  try
    AData := TNetEncoding.Base64.DecodeStringToBytes(Copy(ASrc, LCommaPos + 1, MaxInt));
  except
    Exit; // malformed base64: treat as "no image" rather than propagate
  end;
  Result := True;
end;

function ExtractStyleWidthNumber(const AAttributes, AUnit: string): Double;
// A table resized in a live WYSIWYG surface carries style="width: N%" (or
// "width: Npx"). Returns N when the style's width is in AUnit ('%' or
// 'px'), 0 when there is no width or it is in another unit.
var
  LStyle, LLowerStyle, LValueText: string;
  LWidthPos, LColonPos, LSemiPos: Integer;
begin
  Result := 0;
  LStyle := ExtractAttribute(AAttributes, 'style');
  LLowerStyle := LowerCase(LStyle);
  LWidthPos := FindStylePropertyPos(LLowerStyle, 'width');
  if LWidthPos = 0 then
    Exit;
  LColonPos := PosEx(':', LStyle, LWidthPos);
  if LColonPos = 0 then
    Exit;
  LSemiPos := PosEx(';', LStyle, LColonPos);
  if LSemiPos = 0 then
    LSemiPos := Length(LStyle) + 1;
  LValueText := LowerCase(Trim(Copy(LStyle, LColonPos + 1, LSemiPos - LColonPos - 1)));
  if (LValueText = '') or (not LValueText.EndsWith(AUnit)) then
    Exit;
  Delete(LValueText, Length(LValueText) - Length(AUnit) + 1, Length(AUnit));
  if not TryStrToFloat(Trim(LValueText), Result, DotDecimalFormatSettings) then
    Result := 0;
end;

function ExtractWidthPercent(const AAttributes: string): Double;
begin
  Result := ExtractStyleWidthNumber(AAttributes, '%');
end;

function ExtractWidthPx(const AAttributes: string): Double;
begin
  Result := ExtractStyleWidthNumber(AAttributes, 'px');
end;

procedure ScaleColumnWidthsToTotal(var AWidths: TArray<Integer>; ATotalTwips: Double);
// An explicit table width (a percentage of the page's text area, or an
// absolute px width) governs over the stale <col> widths a live WYSIWYG
// surface keeps. Column proportions are kept and the columns are scaled
// so they sum to ATotalTwips (cumulative rounding, so the total never
// drifts by a twip per column).
var
  LSum, I: Integer;
  LTotal, LCumulativeSource: Double;
  LPreviousEdge, LEdge: Integer;
begin
  LSum := 0;
  for I := 0 to High(AWidths) do
    Inc(LSum, AWidths[I]);
  if (LSum <= 0) or (ATotalTwips <= 0) then
    Exit;
  LTotal := ATotalTwips;
  LCumulativeSource := 0;
  LPreviousEdge := 0;
  for I := 0 to High(AWidths) do
  begin
    LCumulativeSource := LCumulativeSource + AWidths[I];
    LEdge := Round(LTotal * LCumulativeSource / LSum);
    AWidths[I] := LEdge - LPreviousEdge;
    LPreviousEdge := LEdge;
  end;
end;

function ParseStyleFormat(const AStyle: string; ABase: TWARunFormat): TWARunFormat;
var
  LParts: TArray<string>;
  LPart, LProp, LValue: string;
  LColonPos, LSizeInPoints: Integer;
begin
  Result := ABase;
  // Decode entities before splitting on ';': an HTML entity like &quot;
  // itself ends in a semicolon (as every named/numeric entity does), so
  // splitting the raw attribute text first cuts entities like
  // font-family: &quot;Courier New&quot;; into fragments mid-entity
  // (e.g. "font-family: &quot" / "Courier New&quot" / ""), corrupting
  // the font name instead of just unescaping it.
  LParts := DecodeHtmlEntities(AStyle).Split([';']);
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
      // A live WYSIWYG surface can report font-size in any CSS length
      // unit (pt, px, em, %, ...) depending on how it computed the
      // style, and as a fractional value; only recognizing a bare
      // integer "pt" silently dropped everything else, discarding the
      // configured size entirely instead of converting it.
      if TryParseCssFontSizeToPoints(Trim(LValue), Result.FontSizeInPoints, LSizeInPoints) then
        Result.FontSizeInPoints := LSizeInPoints;
    end
    else if (LProp = 'font-weight') and (LowerCase(LValue) = 'bold') then
      Result.Bold := True
    else if (LProp = 'font-style') and (LowerCase(LValue) = 'italic') then
      Result.Italic := True
    else if (LProp = 'text-decoration') and (Pos('underline', LowerCase(LValue)) > 0) then
      Result.Underline := True;
  end;
end;

function TryCssLengthToTwips(const AValue: string; out ATwips: Integer): Boolean;
// Converts any absolute or relative CSS length (px, pt, pc, in, cm, mm, q,
// em, rem, ex, ch, %) to twips, RTF's native unit. A unitless value is
// only valid for 0, as in CSS. "auto", calc() and viewport units have no
// fixed meaning in a paragraph indent and return False.
var
  LValue, LNumberPart, LUnit: string;
  LNumber, LBaseTwips: Double;
  I: Integer;
begin
  Result := False;
  ATwips := 0;
  LValue := Trim(AValue);
  I := 1;
  if (I <= Length(LValue)) and CharInSet(LValue[I], ['+', '-']) then
    Inc(I);
  while (I <= Length(LValue)) and CharInSet(LValue[I], ['0'..'9', '.']) do
    Inc(I);
  LNumberPart := Copy(LValue, 1, I - 1);
  LUnit := LowerCase(Trim(Copy(LValue, I, MaxInt)));
  if not TryStrToFloat(LNumberPart, LNumber, DotDecimalFormatSettings) then
    Exit;
  LBaseTwips := WA_DEFAULT_BROWSER_FONT_SIZE_PT * 20;
  Result := True;
  if LUnit = '' then
    Result := LNumber = 0
  else if LUnit = 'px' then
    ATwips := Round(LNumber * 15)
  else if LUnit = 'pt' then
    ATwips := Round(LNumber * 20)
  else if LUnit = 'pc' then
    ATwips := Round(LNumber * 240)
  else if LUnit = 'in' then
    ATwips := Round(LNumber * 1440)
  else if LUnit = 'cm' then
    ATwips := Round(LNumber * 1440 / 2.54)
  else if LUnit = 'mm' then
    ATwips := Round(LNumber * 1440 / 25.4)
  else if LUnit = 'q' then
    ATwips := Round(LNumber * 1440 / 101.6)
  else if (LUnit = 'em') or (LUnit = 'rem') then
    ATwips := Round(LNumber * LBaseTwips)
  else if (LUnit = 'ex') or (LUnit = 'ch') then
    ATwips := Round(LNumber * LBaseTwips / 2)
  else if LUnit = '%' then
    ATwips := Round(LNumber * WA_TEXT_AREA_WIDTH_TWIPS / 100)
  else
    Result := False;
end;

procedure ParseParagraphIndents(const AAttributes: string;
  out ALeft, ARight, AFirstLine: Integer);
// Reads a paragraph's indentation from its inline style: margin-left /
// margin-right / padding-left / padding-right (and the margin and padding
// shorthands with 1 to 4 values, applied in declaration order like CSS)
// plus text-indent. The left/right indent is margin + padding, in twips.
var
  LDeclarations, LTokens: TArray<string>;
  LDeclaration, LName, LValue: string;
  LColonPos, LBangPos, LTwips: Integer;
  LMarginLeft, LMarginRight, LPaddingLeft, LPaddingRight: Integer;

  function Convert(const AText: string): Integer;
  begin
    if not TryCssLengthToTwips(AText, Result) then
      Result := 0;
  end;

  procedure ApplyShorthand(var ALeftSide, ARightSide: Integer);
  var
    LRightIndex, LLeftIndex: Integer;
  begin
    LTokens := LValue.Split([' '], TStringSplitOptions.ExcludeEmpty);
    if Length(LTokens) = 0 then
      Exit;
    // 1 value: all sides; 2: vertical horizontal; 3: top horizontal
    // bottom; 4: top right bottom left.
    if Length(LTokens) >= 2 then
      LRightIndex := 1
    else
      LRightIndex := 0;
    if Length(LTokens) = 4 then
      LLeftIndex := 3
    else
      LLeftIndex := LRightIndex;
    ALeftSide := Convert(LTokens[LLeftIndex]);
    ARightSide := Convert(LTokens[LRightIndex]);
  end;

begin
  ALeft := 0;
  ARight := 0;
  AFirstLine := 0;
  LMarginLeft := 0;
  LMarginRight := 0;
  LPaddingLeft := 0;
  LPaddingRight := 0;
  LDeclarations := DecodeHtmlEntities(ExtractAttribute(AAttributes, 'style')).Split([';']);
  for LDeclaration in LDeclarations do
  begin
    LColonPos := Pos(':', LDeclaration);
    if LColonPos = 0 then
      Continue;
    LName := LowerCase(Trim(Copy(LDeclaration, 1, LColonPos - 1)));
    LValue := Trim(Copy(LDeclaration, LColonPos + 1, MaxInt));
    LBangPos := Pos('!', LValue);
    if LBangPos > 0 then
      LValue := Trim(Copy(LValue, 1, LBangPos - 1));
    if LName = 'margin' then
      ApplyShorthand(LMarginLeft, LMarginRight)
    else if LName = 'padding' then
      ApplyShorthand(LPaddingLeft, LPaddingRight)
    else if (LName = 'margin-left') or (LName = 'margin-inline-start') then
      LMarginLeft := Convert(LValue)
    else if (LName = 'margin-right') or (LName = 'margin-inline-end') then
      LMarginRight := Convert(LValue)
    else if (LName = 'padding-left') or (LName = 'padding-inline-start') then
      LPaddingLeft := Convert(LValue)
    else if (LName = 'padding-right') or (LName = 'padding-inline-end') then
      LPaddingRight := Convert(LValue)
    else if LName = 'text-indent' then
    begin
      // "text-indent: 2em each-line" etc.: only the length matters.
      LTokens := LValue.Split([' '], TStringSplitOptions.ExcludeEmpty);
      if (Length(LTokens) > 0) and TryCssLengthToTwips(LTokens[0], LTwips) then
        AFirstLine := LTwips;
    end;
  end;
  ALeft := LMarginLeft + LPaddingLeft;
  ARight := LMarginRight + LPaddingRight;
end;

function HasZeroBorder(const AAttributes: string): Boolean;
// True when a tag explicitly says "no border": border="0" (the legacy
// attribute), or in its inline style border / border-width with a zero
// width, or border / border-style with none or hidden. Per-side
// properties (border-left, ...) are not a whole-table statement.
var
  LAttribute, LName, LValue, LToken: string;
  LDeclaration: string;
  LColonPos, LBangPos, LTwips: Integer;
begin
  Result := False;
  LAttribute := LowerCase(Trim(ExtractAttribute(AAttributes, 'border')));
  if (LAttribute <> '') and TryCssLengthToTwips(LAttribute, LTwips) and (LTwips = 0) then
    Exit(True);
  if (LAttribute = '0px') or (LAttribute = '0pt') then
    Exit(True);
  for LDeclaration in DecodeHtmlEntities(ExtractAttribute(AAttributes, 'style')).Split([';']) do
  begin
    LColonPos := Pos(':', LDeclaration);
    if LColonPos = 0 then
      Continue;
    LName := LowerCase(Trim(Copy(LDeclaration, 1, LColonPos - 1)));
    if (LName <> 'border') and (LName <> 'border-width') and (LName <> 'border-style') then
      Continue;
    LValue := LowerCase(Trim(Copy(LDeclaration, LColonPos + 1, MaxInt)));
    LBangPos := Pos('!', LValue);
    if LBangPos > 0 then
      LValue := Trim(Copy(LValue, 1, LBangPos - 1));
    for LToken in LValue.Split([' '], TStringSplitOptions.ExcludeEmpty) do
    begin
      if (LName <> 'border-width') and ((LToken = 'none') or (LToken = 'hidden')) then
        Exit(True);
      if (LName <> 'border-style') and TryCssLengthToTwips(LToken, LTwips) and (LTwips = 0) then
        Exit(True);
    end;
  end;
end;

procedure ParseTableMargins(const AAttributes: string; out ALeftTwips: Integer;
  out ALeftAuto, ARightAuto: Boolean);
// A table is positioned with margin-left / margin-right (or the margin
// shorthand) on the <table>: a length (any CSS unit, % of the text area)
// pushes it from the left; "auto" on both sides centers it, "auto" on the
// left only pushes it to the right edge. The legacy align="center|right"
// attribute is honored when the style says nothing about it.
var
  LDeclaration, LName, LValue, LAlign: string;
  LTokens: TArray<string>;
  LColonPos, LBangPos, LRightIndex, LLeftIndex: Integer;

  procedure ApplySide(const AText: string; out ATwipsOut: Integer; out AAuto: Boolean);
  begin
    AAuto := LowerCase(Trim(AText)) = 'auto';
    if AAuto or not TryCssLengthToTwips(AText, ATwipsOut) then
      ATwipsOut := 0;
  end;

var
  LRightTwips: Integer;
begin
  ALeftTwips := 0;
  ALeftAuto := False;
  ARightAuto := False;
  LRightTwips := 0;
  for LDeclaration in DecodeHtmlEntities(ExtractAttribute(AAttributes, 'style')).Split([';']) do
  begin
    LColonPos := Pos(':', LDeclaration);
    if LColonPos = 0 then
      Continue;
    LName := LowerCase(Trim(Copy(LDeclaration, 1, LColonPos - 1)));
    LValue := Trim(Copy(LDeclaration, LColonPos + 1, MaxInt));
    LBangPos := Pos('!', LValue);
    if LBangPos > 0 then
      LValue := Trim(Copy(LValue, 1, LBangPos - 1));
    if LName = 'margin' then
    begin
      LTokens := LValue.Split([' '], TStringSplitOptions.ExcludeEmpty);
      if Length(LTokens) > 0 then
      begin
        if Length(LTokens) >= 2 then
          LRightIndex := 1
        else
          LRightIndex := 0;
        if Length(LTokens) = 4 then
          LLeftIndex := 3
        else
          LLeftIndex := LRightIndex;
        ApplySide(LTokens[LLeftIndex], ALeftTwips, ALeftAuto);
        ApplySide(LTokens[LRightIndex], LRightTwips, ARightAuto);
      end;
    end
    else if (LName = 'margin-left') or (LName = 'margin-inline-start') then
      ApplySide(LValue, ALeftTwips, ALeftAuto)
    else if (LName = 'margin-right') or (LName = 'margin-inline-end') then
      ApplySide(LValue, LRightTwips, ARightAuto);
  end;
  if (ALeftTwips = 0) and (not ALeftAuto) and (not ARightAuto) then
  begin
    LAlign := LowerCase(Trim(ExtractAttribute(AAttributes, 'align')));
    if LAlign = 'center' then
    begin
      ALeftAuto := True;
      ARightAuto := True;
    end
    else if LAlign = 'right' then
      ALeftAuto := True;
  end;
  if ALeftTwips < 0 then
    ALeftTwips := 0;
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

procedure TWAHtmlParserState.AppendRun(ARun: TWARun);
begin
  if FCurrentCell <> nil then
    FCurrentCell.Runs.Add(ARun)
  else if FCurrentListItem <> nil then
    FCurrentListItem.Runs.Add(ARun)
  else
  begin
    EnsureParagraph;
    FCurrentParagraph.Runs.Add(ARun);
  end;
end;

procedure TWAHtmlParserState.AppendTextSegment(const AText: string);
begin
  if AText = '' then
    Exit;
  if FCurrentCell <> nil then
    FCurrentCell.AddRun(AText, CurrentFormat)
  else if FCurrentListItem <> nil then
    FCurrentListItem.AddRun(AText, CurrentFormat)
  else
  begin
    EnsureParagraph;
    FCurrentParagraph.AddRun(AText, CurrentFormat);
  end;
end;

procedure TWAHtmlParserState.AppendText(const AText: string);
var
  LDecoded, LSegment: string;
  I: Integer;
begin
  LDecoded := DecodeHtmlEntities(AText);
  if LDecoded = '' then
    Exit;

  // A checkbox/radio glyph (this renderer's own inline representation
  // of such a run) can appear anywhere within a run of decoded text; it
  // must become its own run rather than plain characters, so splitting
  // it back out to RTF still emits FORMCHECKBOX.
  LSegment := '';
  for I := 1 to Length(LDecoded) do
  begin
    // Note: these glyphs all have an ordinal value above 255, so they
    // cannot be tested with CharInSet/a Pascal char set (TSysCharSet
    // tops out at 255, silently truncating anything above it) -- plain
    // equality is required here.
    if (LDecoded[I] = WA_CHECKED_BOX_GLYPH) or (LDecoded[I] = WA_UNCHECKED_BOX_GLYPH) or
       (LDecoded[I] = WA_CHECKED_RADIO_GLYPH) or (LDecoded[I] = WA_UNCHECKED_RADIO_GLYPH) then
    begin
      AppendTextSegment(LSegment);
      LSegment := '';
      AppendRun(TWARun.CreateCheckbox(
        (LDecoded[I] = WA_CHECKED_BOX_GLYPH) or (LDecoded[I] = WA_CHECKED_RADIO_GLYPH),
        (LDecoded[I] = WA_CHECKED_RADIO_GLYPH) or (LDecoded[I] = WA_UNCHECKED_RADIO_GLYPH)));
    end
    else
      LSegment := LSegment + LDecoded[I];
  end;
  AppendTextSegment(LSegment);
end;

procedure TWAHtmlParserState.AppendLineBreak;
begin
  AppendRun(TWARun.CreateLineBreak);
end;

procedure TWAHtmlParserState.ApplyTableOffset;
// Resolves the table's position once its final width is known: an explicit
// margin-left is used as is; margin auto centers (both sides) or pushes
// the table to the right edge (left side only) of the text area.
var
  LTotal, I, LOffset: Integer;
begin
  LTotal := 0;
  for I := 0 to High(FCurrentTable.ColumnWidths) do
    Inc(LTotal, FCurrentTable.ColumnWidths[I]);
  LOffset := FCurrentTableLeftTwips;
  if FCurrentTableLeftAuto then
  begin
    if LTotal <= 0 then
      Exit;
    if FCurrentTableRightAuto then
      LOffset := (WA_TEXT_AREA_WIDTH_TWIPS - LTotal) div 2
    else
      LOffset := WA_TEXT_AREA_WIDTH_TWIPS - LTotal;
  end;
  if LOffset < 0 then
    LOffset := 0;
  FCurrentTable.LeftOffsetTwips := LOffset;
end;

procedure TWAHtmlParserState.HandleOpenTag(const ATagName, AAttributes: string);
var
  LFormat: TWARunFormat;
  LFace: string;
  LSize: Integer;
  LBorder: Integer;
  LInputType: string;
  LColumnWidth: Integer;
  LImageData: TBytes;
  LImageFormat: string;
  LImageWidthPx, LImageHeightPx: Integer;
  LNativeWidthPx, LNativeHeightPx: Integer;
begin
  // This model has one border setting per table, so a "no border" on any
  // of its structural tags (<thead>, <tbody>, <tfoot>, <tr>, <td>, <th>;
  // the <table> itself is handled below) makes the whole table borderless.
  if (FCurrentTable <> nil) and
     ((ATagName = 'thead') or (ATagName = 'tbody') or (ATagName = 'tfoot') or
      (ATagName = 'tr') or (ATagName = 'td') or (ATagName = 'th')) and
     HasZeroBorder(AAttributes) then
    FCurrentTableBorderless := True;
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
  else if ATagName = 'sup' then
  begin
    LFormat := CurrentFormat;
    LFormat.Superscript := True;
    LFormat.Subscript := False;
    FFormatStack.Push(LFormat);
  end
  else if ATagName = 'sub' then
  begin
    LFormat := CurrentFormat;
    LFormat.Subscript := True;
    LFormat.Superscript := False;
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
      ParseParagraphIndents(AAttributes, FCurrentParagraph.LeftIndentTwips,
        FCurrentParagraph.RightIndentTwips, FCurrentParagraph.FirstLineIndentTwips);
    end;
  end
  else if ATagName = 'br' then
    AppendLineBreak
  else if ATagName = 'input' then
  begin
    LInputType := LowerCase(Trim(ExtractAttribute(AAttributes, 'type')));
    if (LInputType = 'checkbox') or (LInputType = 'radio') then
      AppendRun(TWARun.CreateCheckbox(
        HasBooleanAttribute(AAttributes, 'checked'), LInputType = 'radio'));
  end
  else if ATagName = 'img' then
  begin
    if TryDecodeDataUriImage(ExtractAttribute(AAttributes, 'src'), LImageData, LImageFormat) then
    begin
      if not TryStrToInt(Trim(ExtractAttribute(AAttributes, 'width')), LImageWidthPx) then
        LImageWidthPx := 0;
      if not TryStrToInt(Trim(ExtractAttribute(AAttributes, 'height')), LImageHeightPx) then
        LImageHeightPx := 0;
      // An HTML side that left one or both of width/height unset (or
      // the RTF -> HTML direction, where the image was never given an
      // explicit display size to begin with) still needs a concrete
      // display size to emit an <img>. Fall back to the image's own
      // intrinsic pixel size, decoded straight from its bytes -- and
      // when only one side was given, scale the missing one to match
      // the native aspect ratio rather than discarding the side that
      // WAS specified (a browser does exactly this for <img width=
      // "300"> with no height).
      if (LImageWidthPx <= 0) or (LImageHeightPx <= 0) then
      begin
        if TWAImageInfo.TryGetPixelSize(LImageData, LNativeWidthPx, LNativeHeightPx) and
           (LNativeWidthPx > 0) and (LNativeHeightPx > 0) then
        begin
          if (LImageWidthPx <= 0) and (LImageHeightPx <= 0) then
          begin
            LImageWidthPx := LNativeWidthPx;
            LImageHeightPx := LNativeHeightPx;
          end
          else if LImageWidthPx <= 0 then
            LImageWidthPx := Round(LImageHeightPx * LNativeWidthPx / LNativeHeightPx)
          else
            LImageHeightPx := Round(LImageWidthPx * LNativeHeightPx / LNativeWidthPx);
        end;
      end;
      AppendRun(TWARun.CreateImage(LImageData, LImageFormat, LImageWidthPx, LImageHeightPx));
    end;
  end
  else if ATagName = 'table' then
  begin
    if not TryStrToInt(ExtractAttribute(AAttributes, 'border'), LBorder) then
      LBorder := 1;
    FCurrentTable := TWATableBlock.Create(LBorder);
    FCurrentTableWidthPercent := ExtractWidthPercent(AAttributes);
    FCurrentTableWidthPx := ExtractWidthPx(AAttributes);
    FCurrentTableBorderless := HasZeroBorder(AAttributes);
    ParseTableMargins(AAttributes, FCurrentTableLeftTwips, FCurrentTableLeftAuto,
      FCurrentTableRightAuto);
    FDocument.Blocks.Add(FCurrentTable);
    FCurrentParagraph := nil;
  end
  else if ATagName = 'col' then
  begin
    if FCurrentTable <> nil then
    begin
      LColumnWidth := ExtractColumnWidthInTwips(AAttributes, 'width');
      if LColumnWidth > 0 then
      begin
        SetLength(FCurrentTable.ColumnWidths, Length(FCurrentTable.ColumnWidths) + 1);
        FCurrentTable.ColumnWidths[High(FCurrentTable.ColumnWidths)] := LColumnWidth;
      end;
    end;
  end
  else if ATagName = 'tr' then
  begin
    if FCurrentTable <> nil then
      FCurrentRow := FCurrentTable.AddRow;
  end
  else if (ATagName = 'td') or (ATagName = 'th') then
  begin
    if FCurrentRow <> nil then
    begin
      // <colgroup><col> (handled above) is preferred; "colwidth" on the
      // cell itself (MSHTML's own per-cell width attribute) is only a
      // fallback for whichever columns colgroup didn't already cover.
      if (FCurrentTable <> nil) and (FCurrentRow.Cells.Count >= Length(FCurrentTable.ColumnWidths)) then
      begin
        LColumnWidth := ExtractColumnWidthInTwips(AAttributes, 'colwidth');
        if LColumnWidth > 0 then
        begin
          SetLength(FCurrentTable.ColumnWidths, FCurrentRow.Cells.Count + 1);
          FCurrentTable.ColumnWidths[FCurrentRow.Cells.Count] := LColumnWidth;
        end;
      end;
      FCurrentCell := FCurrentRow.AddCell;
      FCurrentCell.Alignment := ParseAlignmentAttribute(AAttributes, taLeftAlign);
    end;
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
     (ATagName = 'u') or (ATagName = 'font') or (ATagName = 'span') or
     (ATagName = 'sup') or (ATagName = 'sub') then
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
    if FCurrentTable <> nil then
    begin
      if FCurrentTableBorderless then
        FCurrentTable.BorderWidth := 0;
      if FCurrentTableWidthPercent > 0 then
        ScaleColumnWidthsToTotal(FCurrentTable.ColumnWidths,
          WA_TEXT_AREA_WIDTH_TWIPS * FCurrentTableWidthPercent / 100)
      else if FCurrentTableWidthPx > 0 then
        ScaleColumnWidthsToTotal(FCurrentTable.ColumnWidths, FCurrentTableWidthPx * 15);
      ApplyTableOffset;
    end;
    FCurrentTable := nil;
    FCurrentTableWidthPercent := 0;
    FCurrentTableWidthPx := 0;
    FCurrentTableBorderless := False;
    FCurrentTableLeftTwips := 0;
    FCurrentTableLeftAuto := False;
    FCurrentTableRightAuto := False;
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
