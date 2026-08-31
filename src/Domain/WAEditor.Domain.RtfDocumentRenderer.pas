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
begin
  for LBlock in ADocument.Blocks do
  begin
    if LBlock is TWAParagraphBlock then
      CollectRuns(TWAParagraphBlock(LBlock).Runs)
    else if LBlock is TWATableBlock then
      for LRow in TWATableBlock(LBlock).Rows do
        for LCell in LRow.Cells do
          CollectRuns(LCell.Runs);
  end;
end;

function TWAFontTable.RenderTableGroup: string;
var
  LBuilder: TStringBuilder;
  I: Integer;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.Append('{\fonttbl');
    for I := 0 to FNames.Count - 1 do
      LBuilder.AppendFormat('{\f%d %s;}', [I, FNames[I]]);
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
    LBuilder.Append('\pard').Append(AlignmentControlWord(AParagraph.Alignment)).Append(' ');
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
        LBuilder.Append(RenderTable(TWATableBlock(LBlock), LFontTable));
    end;

    LBuilder.Append('}');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
    LFontTable.Free;
  end;
end;

end.
