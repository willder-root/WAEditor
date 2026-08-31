unit WAEditor.Domain.RichDocument;

interface

uses
  System.Generics.Collections,
  WAEditor.Domain.Types;

type
  /// Character-level formatting for one run of text. Deliberately
  /// independent of both RTF control words and HTML markup, so the same
  /// model can be rendered to (or parsed from) either format.
  TWARunFormat = record
    Bold: Boolean;
    Italic: Boolean;
    Underline: Boolean;
    FontName: string;
    FontSizeInPoints: Integer;
    class function Create(ABold, AItalic, AUnderline: Boolean;
      const AFontName: string; AFontSizeInPoints: Integer): TWARunFormat; static;
    class function Plain: TWARunFormat; static;
    function EqualsFormat(const AOther: TWARunFormat): Boolean;
  end;

  TWARun = class
  public
    Text: string;
    Format: TWARunFormat;
    constructor Create(const AText: string; const AFormat: TWARunFormat);
  end;

  TWABlock = class abstract
  end;

  TWAParagraphBlock = class(TWABlock)
  public
    Alignment: TWATextAlignment;
    Runs: TObjectList<TWARun>;
    constructor Create(AAlignment: TWATextAlignment = taLeftAlign);
    destructor Destroy; override;
    function AddRun(const AText: string; const AFormat: TWARunFormat): TWARun;
  end;

  TWATableCell = class
  public
    Runs: TObjectList<TWARun>;
    constructor Create;
    destructor Destroy; override;
    function AddRun(const AText: string; const AFormat: TWARunFormat): TWARun;
  end;

  TWATableRow = class
  public
    Cells: TObjectList<TWATableCell>;
    constructor Create;
    destructor Destroy; override;
    function AddCell: TWATableCell;
  end;

  TWATableBlock = class(TWABlock)
  public
    BorderWidth: Integer;
    Rows: TObjectList<TWATableRow>;
    constructor Create(ABorderWidth: Integer = 1);
    destructor Destroy; override;
    function AddRow: TWATableRow;
  end;

  TWARichDocument = class
  public
    Blocks: TObjectList<TWABlock>;
    constructor Create;
    destructor Destroy; override;
    function AddParagraph(AAlignment: TWATextAlignment = taLeftAlign): TWAParagraphBlock;
    function AddTable(ARowCount, AColumnCount: Integer; ABorderWidth: Integer = 1): TWATableBlock;
  end;

implementation

{ TWARunFormat }

class function TWARunFormat.Create(ABold, AItalic, AUnderline: Boolean;
  const AFontName: string; AFontSizeInPoints: Integer): TWARunFormat;
begin
  Result.Bold := ABold;
  Result.Italic := AItalic;
  Result.Underline := AUnderline;
  Result.FontName := AFontName;
  Result.FontSizeInPoints := AFontSizeInPoints;
end;

class function TWARunFormat.Plain: TWARunFormat;
begin
  Result := TWARunFormat.Create(False, False, False, '', 0);
end;

function TWARunFormat.EqualsFormat(const AOther: TWARunFormat): Boolean;
begin
  Result :=
    (Bold = AOther.Bold) and (Italic = AOther.Italic) and (Underline = AOther.Underline) and
    (FontName = AOther.FontName) and (FontSizeInPoints = AOther.FontSizeInPoints);
end;

{ TWARun }

constructor TWARun.Create(const AText: string; const AFormat: TWARunFormat);
begin
  inherited Create;
  Text := AText;
  Format := AFormat;
end;

{ TWAParagraphBlock }

constructor TWAParagraphBlock.Create(AAlignment: TWATextAlignment);
begin
  inherited Create;
  Alignment := AAlignment;
  Runs := TObjectList<TWARun>.Create(True);
end;

destructor TWAParagraphBlock.Destroy;
begin
  Runs.Free;
  inherited Destroy;
end;

function TWAParagraphBlock.AddRun(const AText: string; const AFormat: TWARunFormat): TWARun;
begin
  Result := TWARun.Create(AText, AFormat);
  Runs.Add(Result);
end;

{ TWATableCell }

constructor TWATableCell.Create;
begin
  inherited Create;
  Runs := TObjectList<TWARun>.Create(True);
end;

destructor TWATableCell.Destroy;
begin
  Runs.Free;
  inherited Destroy;
end;

function TWATableCell.AddRun(const AText: string; const AFormat: TWARunFormat): TWARun;
begin
  Result := TWARun.Create(AText, AFormat);
  Runs.Add(Result);
end;

{ TWATableRow }

constructor TWATableRow.Create;
begin
  inherited Create;
  Cells := TObjectList<TWATableCell>.Create(True);
end;

destructor TWATableRow.Destroy;
begin
  Cells.Free;
  inherited Destroy;
end;

function TWATableRow.AddCell: TWATableCell;
begin
  Result := TWATableCell.Create;
  Cells.Add(Result);
end;

{ TWATableBlock }

constructor TWATableBlock.Create(ABorderWidth: Integer);
begin
  inherited Create;
  BorderWidth := ABorderWidth;
  Rows := TObjectList<TWATableRow>.Create(True);
end;

destructor TWATableBlock.Destroy;
begin
  Rows.Free;
  inherited Destroy;
end;

function TWATableBlock.AddRow: TWATableRow;
begin
  Result := TWATableRow.Create;
  Rows.Add(Result);
end;

{ TWARichDocument }

constructor TWARichDocument.Create;
begin
  inherited Create;
  Blocks := TObjectList<TWABlock>.Create(True);
end;

destructor TWARichDocument.Destroy;
begin
  Blocks.Free;
  inherited Destroy;
end;

function TWARichDocument.AddParagraph(AAlignment: TWATextAlignment): TWAParagraphBlock;
begin
  Result := TWAParagraphBlock.Create(AAlignment);
  Blocks.Add(Result);
end;

function TWARichDocument.AddTable(ARowCount, AColumnCount: Integer;
  ABorderWidth: Integer): TWATableBlock;
var
  LRow: TWATableRow;
  R, C: Integer;
begin
  Result := TWATableBlock.Create(ABorderWidth);
  Blocks.Add(Result);
  for R := 1 to ARowCount do
  begin
    LRow := Result.AddRow;
    for C := 1 to AColumnCount do
      LRow.AddCell;
  end;
end;

end.
