unit WAEditor.Tests.Fakes.FakeHtmlEditorEngine;

interface

uses
  WAEditor.Application.IHtmlEditorEngine,
  WAEditor.Domain.Types;

type
  /// In-memory test double for IWAHtmlEditorEngine. Records every call so
  /// tests can assert on the interactions made by commands and services
  /// without needing a live WebBrowser/COM control.
  TFakeHtmlEditorEngine = class(TInterfacedObject, IWAHtmlEditorEngine)
  private
    FBold: Boolean;
    FItalic: Boolean;
    FUnderline: Boolean;
    FFontName: string;
    FFontSize: Integer;
    FAlignment: TWATextAlignment;
    FHtml: string;
    FLastInsertedHtml: string;
    FSetFontNameCallCount: Integer;
    FSetFontSizeCallCount: Integer;
    FSetAlignmentCallCount: Integer;
    FInsertHtmlCallCount: Integer;
  public
    procedure SetBold(AEnabled: Boolean);
    procedure SetItalic(AEnabled: Boolean);
    procedure SetUnderline(AEnabled: Boolean);
    procedure SetFontName(const AFontName: string);
    procedure SetFontSize(ASizeInPoints: Integer);
    procedure SetTextAlignment(AAlignment: TWATextAlignment);
    procedure InsertHtml(const AHtml: string);

    function IsBold: Boolean;
    function IsItalic: Boolean;
    function IsUnderline: Boolean;

    function GetHtml: string;
    procedure SetHtml(const AHtml: string);

    property FontName: string read FFontName;
    property FontSize: Integer read FFontSize;
    property Alignment: TWATextAlignment read FAlignment;
    property LastInsertedHtml: string read FLastInsertedHtml;
    property SetFontNameCallCount: Integer read FSetFontNameCallCount;
    property SetFontSizeCallCount: Integer read FSetFontSizeCallCount;
    property SetAlignmentCallCount: Integer read FSetAlignmentCallCount;
    property InsertHtmlCallCount: Integer read FInsertHtmlCallCount;
  end;

implementation

procedure TFakeHtmlEditorEngine.SetBold(AEnabled: Boolean);
begin
  FBold := AEnabled;
end;

procedure TFakeHtmlEditorEngine.SetItalic(AEnabled: Boolean);
begin
  FItalic := AEnabled;
end;

procedure TFakeHtmlEditorEngine.SetUnderline(AEnabled: Boolean);
begin
  FUnderline := AEnabled;
end;

procedure TFakeHtmlEditorEngine.SetFontName(const AFontName: string);
begin
  FFontName := AFontName;
  Inc(FSetFontNameCallCount);
end;

procedure TFakeHtmlEditorEngine.SetFontSize(ASizeInPoints: Integer);
begin
  FFontSize := ASizeInPoints;
  Inc(FSetFontSizeCallCount);
end;

procedure TFakeHtmlEditorEngine.SetTextAlignment(AAlignment: TWATextAlignment);
begin
  FAlignment := AAlignment;
  Inc(FSetAlignmentCallCount);
end;

procedure TFakeHtmlEditorEngine.InsertHtml(const AHtml: string);
begin
  FLastInsertedHtml := AHtml;
  Inc(FInsertHtmlCallCount);
end;

function TFakeHtmlEditorEngine.IsBold: Boolean;
begin
  Result := FBold;
end;

function TFakeHtmlEditorEngine.IsItalic: Boolean;
begin
  Result := FItalic;
end;

function TFakeHtmlEditorEngine.IsUnderline: Boolean;
begin
  Result := FUnderline;
end;

function TFakeHtmlEditorEngine.GetHtml: string;
begin
  Result := FHtml;
end;

procedure TFakeHtmlEditorEngine.SetHtml(const AHtml: string);
begin
  FHtml := AHtml;
end;

end.
