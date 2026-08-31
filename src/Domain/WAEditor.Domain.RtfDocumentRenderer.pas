unit WAEditor.Domain.RtfDocumentRenderer;

interface

uses
  WAEditor.Domain.RichDocument;

type
  /// Renders a TWARichDocument to a minimal, valid RTF document: a font
  /// table built from the fonts actually used, paragraphs with alignment,
  /// character runs with bold/italic/underline/font/size, and simple
  /// tables. Hand-written control-word generation, with no dependency on
  /// any OS rich-edit control, so it is fully unit testable.
  TWARtfDocumentRenderer = class
  public
    class function Render(ADocument: TWARichDocument): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  WAEditor.Domain.Types;

const
  WA_DEFAULT_RTF_FONT = 'Segoe UI';
  WA_TWIPS_PER_COLUMN = 2000;

type
  TWAFontTable = class
  private
    FNames: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    function IndexOf(const AFontName: string): Integer;
    procedure CollectFrom(ADocument: TWARichDocument);
    function RenderTableGroup: string;
    property Names: TList<string> read FNames;
  end;

function EscapeRtf(const AText: string): string; forward;

constructor TWAFontTable.Create;
begin
  inherited Create;
  FNames := TList<string>.Create;
  FNames.Add(WA_DEFAULT_RTF_FONT);
end;

destructor TWAFontTable.Destroy;
begin
  FNames.Free;
  inherited Destroy;
end;

function TWAFontTable.IndexOf(const AFontName: string): Integer;
begin
  if AFontName = '' then
    Exit(0);
  Result := FNames.IndexOf(AFontName);
  if Result < 0 then
  begin
    FNames.Add(AFontName);
    Result := FNames.Count - 1;
  end;
end;

procedure TWAFontTable.CollectFrom(ADocument: TWARichDocument);

  procedure CollectRuns(ARuns: TObjectList<TWARun>);
  var
    LRun: TWARun;
  begin
    for LRun in ARuns do
      if LRun.Format.FontName <> '' then
        IndexOf(LRun.Format.FontName);
  end;

var
  LBlock: TWABlock;
  LRow: TWATableRow;
  LCell: TWATableCell;
  LItem: TWAListItem;
begin
  for LBlock in ADocument.Blocks do
  begin
    if LBlock is TWAParagraphBlock then
      CollectRuns(TWAParagraphBlock(LBlock).Runs)
    else if LBlock is TWATableBlock then
      for LRow in TWATableBlock(LBlock).Rows do
        for LCell in LRow.Cells do
          CollectRuns(LCell.Runs)
    else if LBlock is TWAListBlock then
      for LItem in TWAListBlock(LBlock).Items do
        CollectRuns(LItem.Runs);
  end;
end;

function TWAFontTable.RenderTableGroup: string;
var
  LBuilder: TStringBuilder;
  I: Integer;
  LFontName: string;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.Append('{\fonttbl');
    for I := 0 to FNames.Count - 1 do
    begin
      // Defense in depth: a font name could in principle contain RTF's
      // own special characters (\, {, }), which would otherwise corrupt
      // the font table's brace structure and desynchronize every parser
      // reading the rest of the document (this is exactly the failure
      // mode reported against a third-party RTF reader). Escaping here
      // guarantees a well-formed entry regardless of what produced the
      // name; an empty name falls back to the default font rather than
      // emitting a nameless entry.
      LFontName := Trim(FNames[I]);
      if LFontName = '' then
        LFontName := WA_DEFAULT_RTF_FONT;
      LBuilder.AppendFormat('{\f%d %s;}', [I, EscapeRtf(LFontName)]);
    end;
    LBuilder.Append('}');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function EscapeRtf(const AText: string): string;
var
  LBuilder: TStringBuilder;
  C: Char;
  LCode: Integer;
begin
  LBuilder := TStringBuilder.Create;
  try
    for C in AText do
    begin
      LCode := Ord(C);
      case C of
        '\': LBuilder.Append('\\');
        '{': LBuilder.Append('\{');
        '}': LBuilder.Append('\}');
        #9: LBuilder.Append('\tab ');
        #10, #13: ; // paragraph/line breaks are modeled as separate blocks
      else
        if (LCode >= 32) and (LCode <= 126) then
          LBuilder.Append(C)
        else
        begin
          if LCode > 32767 then
            LCode := LCode - 65536;
          LBuilder.AppendFormat('\u%d?', [LCode]);
        end;
      end;
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function RenderRunGroup(ARun: TWARun; AFontTable: TWAFontTable): string;
var
  LControlWords: string;
begin
  if ARun.IsLineBreak then
    Exit('\line' + sLineBreak);

  LControlWords := '';
  if ARun.Format.FontName <> '' then
    LControlWords := LControlWords + Format('\f%d', [AFontTable.IndexOf(ARun.Format.FontName)]);
  if ARun.Format.FontSizeInPoints > 0 then
    LControlWords := LControlWords + Format('\fs%d', [ARun.Format.FontSizeInPoints * 2]);
  if ARun.Format.Bold then
    LControlWords := LControlWords + '\b';
  if ARun.Format.Italic then
    LControlWords := LControlWords + '\i';
  if ARun.Format.Underline then
    LControlWords := LControlWords + '\ul';

  if LControlWords <> '' then
    LControlWords := LControlWords + ' '; // delimiter, consumed by the reader and not part of the text
  Result := '{' + LControlWords + EscapeRtf(ARun.Text) + '}';
end;

function AlignmentControlWord(AAlignment: TWATextAlignment): string;
begin
  case AAlignment of
    taLeftAlign: Result := '\ql';
    taCenterAlign: Result := '\qc';
    taRightAlign: Result := '\qr';
    taJustifyAlign: Result := '\qj';
  else
    Result := '\ql';
  end;
end;

function RenderParagraph(AParagraph: TWAParagraphBlock; AFontTable: TWAFontTable): string;
var
  LBuilder: TStringBuilder;
  LRun: TWARun;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.Append('\pard').Append(AlignmentControlWord(AParagraph.Alignment));
    if AParagraph.HasBorder then
      LBuilder.Append('\brdrl\brdrs\brdrr\brdrs\brdrt\brdrs\brdrb\brdrs');
    LBuilder.Append(' ');
    for LRun in AParagraph.Runs do
      LBuilder.Append(RenderRunGroup(LRun, AFontTable));
    LBuilder.Append('\par').Append(sLineBreak);
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function RenderTable(ATable: TWATableBlock; AFontTable: TWAFontTable): string;
var
  LBuilder: TStringBuilder;
  LRow: TWATableRow;
  LCell: TWATableCell;
  LRun: TWARun;
  I: Integer;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.Append('{').Append(sLineBreak);
    for LRow in ATable.Rows do
    begin
      LBuilder.Append('\trowd');
      for I := 1 to LRow.Cells.Count do
        LBuilder.AppendFormat('\cellx%d', [I * WA_TWIPS_PER_COLUMN]);
      LBuilder.Append(sLineBreak);
      for LCell in LRow.Cells do
      begin
        LBuilder.Append('\pard\intbl ');
        for LRun in LCell.Runs do
          LBuilder.Append(RenderRunGroup(LRun, AFontTable));
        LBuilder.Append('\cell').Append(sLineBreak);
      end;
      LBuilder.Append('\row').Append(sLineBreak);
    end;
    LBuilder.Append('}').Append(sLineBreak);
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function RenderList(AList: TWAListBlock; AFontTable: TWAFontTable): string;
var
  LBuilder: TStringBuilder;
  LRun: TWARun;
  I: Integer;
begin
  LBuilder := TStringBuilder.Create;
  try
    for I := 0 to AList.Items.Count - 1 do
    begin
      // A hand-rolled "poor man's list": each item is a hanging-indent
      // paragraph (\fi-360\li720) whose marker is a literal \bullet or
      // "N." followed by \tab. The parser recognizes this exact
      // \pard\fi-360 signature and strips the marker back out, rather
      // than relying on the full RTF list-table machinery.
      LBuilder.Append('\pard\fi-360\li720\ql ');
      if AList.Kind = lkOrdered then
        LBuilder.AppendFormat('%d.\tab ', [I + 1])
      else
        LBuilder.Append('\bullet\tab ');
      for LRun in AList.Items[I].Runs do
        LBuilder.Append(RenderRunGroup(LRun, AFontTable));
      LBuilder.Append('\par').Append(sLineBreak);
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class function TWARtfDocumentRenderer.Render(ADocument: TWARichDocument): string;
var
  LFontTable: TWAFontTable;
  LBuilder: TStringBuilder;
  LBlock: TWABlock;
begin
  LFontTable := TWAFontTable.Create;
  LBuilder := TStringBuilder.Create;
  try
    LFontTable.CollectFrom(ADocument);

    LBuilder.Append('{\rtf1\ansi\ansicpg1252\deff0\uc1').Append(sLineBreak);
    LBuilder.Append(LFontTable.RenderTableGroup).Append(sLineBreak);
    LBuilder.Append('\viewkind4').Append(sLineBreak);

    for LBlock in ADocument.Blocks do
    begin
      if LBlock is TWAParagraphBlock then
        LBuilder.Append(RenderParagraph(TWAParagraphBlock(LBlock), LFontTable))
      else if LBlock is TWATableBlock then
        LBuilder.Append(RenderTable(TWATableBlock(LBlock), LFontTable))
      else if LBlock is TWAListBlock then
        LBuilder.Append(RenderList(TWAListBlock(LBlock), LFontTable));
    end;

    LBuilder.Append('}');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
    LFontTable.Free;
  end;
end;

end.
