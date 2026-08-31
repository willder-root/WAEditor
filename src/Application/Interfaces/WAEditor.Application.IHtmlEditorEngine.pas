unit WAEditor.Application.IHtmlEditorEngine;

interface

uses
  WAEditor.Domain.Types;

type
  /// Abstraction over the actual HTML editing surface (e.g. a WebBrowser
  /// control in design mode). The Application layer depends only on this
  /// contract, letting the concrete Infrastructure adapter be swapped or
  /// replaced by a test double without touching use-case code.
  IWAHtmlEditorEngine = interface
    ['{B4C1B7B0-9C1F-4A6F-8A3E-7B2E2E5C2B01}']
    /// Switches the hosted document into an editable state. Must be called
    /// once the underlying surface has finished loading, before any other
    /// method on this interface is used.
    procedure BeginEditing;

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
  end;

implementation

end.
