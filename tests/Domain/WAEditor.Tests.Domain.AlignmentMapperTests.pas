unit WAEditor.Tests.Domain.AlignmentMapperTests;

interface

uses
  DUnitX.TestFramework,
  WAEditor.Domain.Types,
  WAEditor.Domain.AlignmentMapper;

type
  [TestFixture]
  TWAAlignmentMapperTests = class
  public
    [Test]
    [TestCase('Left', 'left')]
    [TestCase('Center', 'center')]
    [TestCase('Right', 'right')]
    [TestCase('Justify', 'justify')]
    procedure ToHtmlAttribute_AndBack_RoundTrips(const AExpected: string);

    [Test]
    procedure ToExecCommandName_ForCenter_ReturnsJustifyCenter;

    [Test]
    procedure FromHtmlAttribute_IsCaseInsensitiveAndTrims;

    [Test]
    procedure FromHtmlAttribute_WithUnknownValue_RaisesValidationError;
  end;

implementation

procedure TWAAlignmentMapperTests.ToHtmlAttribute_AndBack_RoundTrips(const AExpected: string);
var
  LAlignment: TWATextAlignment;
  LActual: string;
begin
  LAlignment := TWAAlignmentMapper.FromHtmlAttribute(AExpected);
  LActual := TWAAlignmentMapper.ToHtmlAttribute(LAlignment);

  Assert.AreEqual(AExpected, LActual);
end;

procedure TWAAlignmentMapperTests.ToExecCommandName_ForCenter_ReturnsJustifyCenter;
begin
  Assert.AreEqual('JustifyCenter', TWAAlignmentMapper.ToExecCommandName(taCenterAlign));
end;

procedure TWAAlignmentMapperTests.FromHtmlAttribute_IsCaseInsensitiveAndTrims;
begin
  Assert.AreEqual(taRightAlign, TWAAlignmentMapper.FromHtmlAttribute('  RIGHT  '));
end;

procedure TWAAlignmentMapperTests.FromHtmlAttribute_WithUnknownValue_RaisesValidationError;
begin
  Assert.WillRaise(
    procedure
    begin
      TWAAlignmentMapper.FromHtmlAttribute('diagonal');
    end,
    EWADomainValidationError);
end;

initialization
  TDUnitX.RegisterTestFixture(TWAAlignmentMapperTests);

end.
