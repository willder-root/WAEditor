unit WAEditor.Domain.TableHtmlBuilder;

interface

uses
  System.SysUtils,
  WAEditor.Domain.Types;

type
  /// Builds an HTML table fragment from a validated table specification.
  /// Pure string composition, with no UI/COM dependency, so it is fully
  /// unit testable.
  TWATableHtmlBuilder = class
  public
    class function Build(const ASpec: TWATableSpec): string; static;
  end;

implementation

class function TWATableHtmlBuilder.Build(const ASpec: TWATableSpec): string;
var
  LBuilder: TStringBuilder;
  LRow, LColumn: Integer;
begin
  ASpec.Validate;

  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendFormat('<table border="%d">', [ASpec.BorderWidth]).AppendLine;
    for LRow := 1 to ASpec.RowCount do
    begin
      LBuilder.Append('<tr>').AppendLine;
      for LColumn := 1 to ASpec.ColumnCount do
        LBuilder.Append('<td>&nbsp;</td>').AppendLine;
      LBuilder.Append('</tr>').AppendLine;
    end;
    LBuilder.Append('</table>');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

end.
