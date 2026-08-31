unit WAEditor.Tests.Domain.FontSpecTests;

interface

uses
  DUnitX.TestFramework,
  WAEditor.Domain.Types;

type
  [TestFixture]
  TWAFontSpecTests = class
  public
    [Test]
    procedure Create_WithValidNameAndSize_PopulatesProperties;

    [Test]
    procedure Create_WithEmptyName_RaisesValidationError;

    [Test]
    [TestCase('BelowMinimum', '0')]
    [TestCase('AboveMaximum', '500')]
    procedure Create_WithSizeOutOfRange_RaisesValidationError(ASize: Integer);

    [Test]
    procedure IsValid_WithValidData_ReturnsTrue;

    [Test]
    procedure IsValid_WithBlankName_ReturnsFalse;
  end;

implementation

procedure TWAFontSpecTests.Create_WithValidNameAndSize_PopulatesProperties;
var
  LSpec: TWAFontSpec;
begin
  LSpec := TWAFontSpec.Create('Segoe UI', 12);

  Assert.AreEqual('Segoe UI', LSpec.Name);
  Assert.AreEqual(12, LSpec.SizeInPoints);
end;

procedure TWAFontSpecTests.Create_WithEmptyName_RaisesValidationError;
begin
  Assert.WillRaise(
    procedure
    begin
      TWAFontSpec.Create('   ', 12);
    end,
    EWADomainValidationError);
end;

procedure TWAFontSpecTests.Create_WithSizeOutOfRange_RaisesValidationError(ASize: Integer);
begin
  Assert.WillRaise(
    procedure
    begin
      TWAFontSpec.Create('Arial', ASize);
    end,
    EWADomainValidationError);
end;

procedure TWAFontSpecTests.IsValid_WithValidData_ReturnsTrue;
var
  LSpec: TWAFontSpec;
begin
  LSpec := TWAFontSpec.Create('Calibri', 14);

  Assert.IsTrue(LSpec.IsValid);
end;

procedure TWAFontSpecTests.IsValid_WithBlankName_ReturnsFalse;
var
  LSpec: TWAFontSpec;
begin
  LSpec := Default(TWAFontSpec);

  Assert.IsFalse(LSpec.IsValid);
end;

initialization
  TDUnitX.RegisterTestFixture(TWAFontSpecTests);

end.
