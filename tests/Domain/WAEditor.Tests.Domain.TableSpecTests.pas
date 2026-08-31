unit WAEditor.Tests.Domain.TableSpecTests;

interface

uses
  DUnitX.TestFramework,
  WAEditor.Domain.Types;

type
  [TestFixture]
  TWATableSpecTests = class
  public
    [Test]
    procedure Create_WithValidDimensions_PopulatesProperties;

    [Test]
    [TestCase('ZeroRows', '0,3')]
    [TestCase('ZeroColumns', '3,0')]
    [TestCase('TooManyRows', '101,3')]
    [TestCase('TooManyColumns', '3,101')]
    procedure Create_WithInvalidDimensions_RaisesValidationError(ARows, AColumns: Integer);

    [Test]
    procedure Create_WithNegativeBorderWidth_RaisesValidationError;

    [Test]
    procedure Create_WithDefaultBorderWidth_UsesOne;
  end;

implementation

procedure TWATableSpecTests.Create_WithValidDimensions_PopulatesProperties;
var
  LSpec: TWATableSpec;
begin
  LSpec := TWATableSpec.Create(3, 4, 2);

  Assert.AreEqual(3, LSpec.RowCount);
  Assert.AreEqual(4, LSpec.ColumnCount);
  Assert.AreEqual(2, LSpec.BorderWidth);
end;

procedure TWATableSpecTests.Create_WithInvalidDimensions_RaisesValidationError(ARows, AColumns: Integer);
begin
  Assert.WillRaise(
    procedure
    begin
      TWATableSpec.Create(ARows, AColumns);
    end,
    EWADomainValidationError);
end;

procedure TWATableSpecTests.Create_WithNegativeBorderWidth_RaisesValidationError;
begin
  Assert.WillRaise(
    procedure
    begin
      TWATableSpec.Create(2, 2, -1);
    end,
    EWADomainValidationError);
end;

procedure TWATableSpecTests.Create_WithDefaultBorderWidth_UsesOne;
var
  LSpec: TWATableSpec;
begin
  LSpec := TWATableSpec.Create(2, 2);

  Assert.AreEqual(1, LSpec.BorderWidth);
end;

initialization
  TDUnitX.RegisterTestFixture(TWATableSpecTests);

end.
