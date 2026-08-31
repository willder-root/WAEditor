unit WAEditor.Tests.Domain.FontSizeScaleTests;

interface

uses
  DUnitX.TestFramework,
  WAEditor.Domain.Types,
  WAEditor.Domain.FontSizeScale;

type
  [TestFixture]
  TWAFontSizeScaleTests = class
  public
    [Test]
    [TestCase('AtLowerBoundary', '1,1')]
    [TestCase('SmallText', '8,1')]
    [TestCase('JustAboveSmall', '9,2')]
    [TestCase('DefaultBodyText', '12,3')]
    [TestCase('Subheading', '18,5')]
    [TestCase('Heading', '24,6')]
    [TestCase('LargeDisplayText', '48,7')]
    procedure ToHtmlLegacySize_MapsPointsToExpectedBucket(APoints, AExpectedBucket: Integer);

    [Test]
    [TestCase('BelowMinimum', '0')]
    [TestCase('AboveMaximum', '500')]
    procedure ToHtmlLegacySize_WithSizeOutOfRange_RaisesValidationError(APoints: Integer);
  end;

implementation

procedure TWAFontSizeScaleTests.ToHtmlLegacySize_MapsPointsToExpectedBucket(APoints, AExpectedBucket: Integer);
begin
  Assert.AreEqual(AExpectedBucket, TWAFontSizeScale.ToHtmlLegacySize(APoints));
end;

procedure TWAFontSizeScaleTests.ToHtmlLegacySize_WithSizeOutOfRange_RaisesValidationError(APoints: Integer);
begin
  Assert.WillRaise(
    procedure
    begin
      TWAFontSizeScale.ToHtmlLegacySize(APoints);
    end,
    EWADomainValidationError);
end;

initialization
  TDUnitX.RegisterTestFixture(TWAFontSizeScaleTests);

end.
