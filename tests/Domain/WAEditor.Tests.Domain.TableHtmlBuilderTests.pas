unit WAEditor.Tests.Domain.TableHtmlBuilderTests;

interface

uses
  System.SysUtils,
  System.StrUtils,
  DUnitX.TestFramework,
  WAEditor.Domain.Types,
  WAEditor.Domain.TableHtmlBuilder;

type
  [TestFixture]
  TWATableHtmlBuilderTests = class
  public
    [Test]
    procedure Build_ProducesExpectedNumberOfRowsAndCells;

    [Test]
    procedure Build_IncludesRequestedBorderWidth;

    [Test]
    procedure Build_WithInvalidSpec_RaisesValidationError;
  end;

implementation

function CountOccurrences(const AText, ASubstring: string): Integer;
var
  LPosition: Integer;
begin
  Result := 0;
  LPosition := PosEx(ASubstring, AText, 1);
  while LPosition > 0 do
  begin
    Inc(Result);
    LPosition := PosEx(ASubstring, AText, LPosition + Length(ASubstring));
  end;
end;

procedure TWATableHtmlBuilderTests.Build_ProducesExpectedNumberOfRowsAndCells;
var
  LSpec: TWATableSpec;
  LHtml: string;
begin
  LSpec := TWATableSpec.Create(2, 3);
  LHtml := TWATableHtmlBuilder.Build(LSpec);

  Assert.AreEqual(2, CountOccurrences(LHtml, '<tr>'));
  Assert.AreEqual(6, CountOccurrences(LHtml, '<td>'));
  Assert.IsTrue(LHtml.StartsWith('<table'));
  Assert.IsTrue(LHtml.EndsWith('</table>'));
end;

procedure TWATableHtmlBuilderTests.Build_IncludesRequestedBorderWidth;
var
  LSpec: TWATableSpec;
  LHtml: string;
begin
  LSpec := TWATableSpec.Create(1, 1, 3);
  LHtml := TWATableHtmlBuilder.Build(LSpec);

  Assert.Contains(LHtml, 'border="3"');
end;

procedure TWATableHtmlBuilderTests.Build_WithInvalidSpec_RaisesValidationError;
var
  LSpec: TWATableSpec;
begin
  LSpec := Default(TWATableSpec);

  Assert.WillRaise(
    procedure
    begin
      TWATableHtmlBuilder.Build(LSpec);
    end,
    EWADomainValidationError);
end;

initialization
  TDUnitX.RegisterTestFixture(TWATableHtmlBuilderTests);

end.
