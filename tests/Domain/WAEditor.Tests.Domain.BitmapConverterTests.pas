unit WAEditor.Tests.Domain.BitmapConverterTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TWABitmapConverterTests = class
  public
    [Test]
    procedure TryDibToBmp_PrependsFileHeaderWithPixelOffset;

    [Test]
    procedure TryBmpToDib_StripsFileHeader;

    [Test]
    procedure TryWmfToBmp_ExtractsBitmapFromDibStretchBltRecord;

    [Test]
    procedure TryWmfToBmp_VectorOnlyMetafile_ReturnsFalse;

    [Test]
    procedure TryGetPixelSize_Bmp_ReadsWidthAndHeight;
  end;

implementation

uses
  System.SysUtils,
  WAEditor.Domain.BitmapConverter,
  WAEditor.Domain.ImageInfo;

function BuildDib(AWidth, AHeight: Integer): TBytes;
// 24bpp uncompressed DIB: 40-byte info header + padded rows.
var
  LRowBytes: Integer;
begin
  LRowBytes := ((AWidth * 3 + 3) div 4) * 4;
  SetLength(Result, 40 + LRowBytes * AHeight);
  FillChar(Result[0], Length(Result), $7F);
  PCardinal(@Result[0])^ := 40;
  PInteger(@Result[4])^ := AWidth;
  PInteger(@Result[8])^ := AHeight;
  PWord(@Result[12])^ := 1;
  PWord(@Result[14])^ := 24;
  PCardinal(@Result[16])^ := 0;
  PCardinal(@Result[20])^ := LRowBytes * AHeight;
  FillChar(Result[24], 16, 0);
end;

function BuildWmfWithDib(const ADib: TBytes): TBytes;
// Standard WMF header, one META_DIBSTRETCHBLT record, META_EOF.
var
  LRecordWords: Cardinal;
  LOffset: Integer;
begin
  LRecordWords := (6 + 20 + Length(ADib)) div 2;
  SetLength(Result, 18 + Integer(LRecordWords) * 2 + 6);
  FillChar(Result[0], Length(Result), 0);
  PWord(@Result[0])^ := 1;
  PWord(@Result[2])^ := 9;
  PWord(@Result[4])^ := $0300;
  LOffset := 18;
  PCardinal(@Result[LOffset])^ := LRecordWords;
  PWord(@Result[LOffset + 4])^ := $0B41;
  Move(ADib[0], Result[LOffset + 6 + 20], Length(ADib));
  Inc(LOffset, Integer(LRecordWords) * 2);
  PCardinal(@Result[LOffset])^ := 3;
end;

procedure TWABitmapConverterTests.TryDibToBmp_PrependsFileHeaderWithPixelOffset;
var
  LDib, LBmp: TBytes;
begin
  LDib := BuildDib(2, 1);
  Assert.IsTrue(TWABitmapConverter.TryDibToBmp(LDib, LBmp));
  Assert.AreEqual(Length(LDib) + 14, Length(LBmp));
  Assert.AreEqual(Byte(Ord('B')), LBmp[0]);
  Assert.AreEqual(Byte(Ord('M')), LBmp[1]);
  Assert.AreEqual(Cardinal(54), PCardinal(@LBmp[10])^); // 14 + 40, no palette
end;

procedure TWABitmapConverterTests.TryBmpToDib_StripsFileHeader;
var
  LDib, LBmp, LBack: TBytes;
begin
  LDib := BuildDib(3, 2);
  TWABitmapConverter.TryDibToBmp(LDib, LBmp);
  Assert.IsTrue(TWABitmapConverter.TryBmpToDib(LBmp, LBack));
  Assert.AreEqual(Length(LDib), Length(LBack));
  Assert.IsTrue(CompareMem(@LDib[0], @LBack[0], Length(LDib)));
end;

procedure TWABitmapConverterTests.TryWmfToBmp_ExtractsBitmapFromDibStretchBltRecord;
var
  LDib, LWmf, LBmp: TBytes;
begin
  // WPTools stores a pasted bitmap as \wmetafile with exactly this
  // shape: one DibStretchBlt record carrying the DIB.
  LDib := BuildDib(4, 3);
  LWmf := BuildWmfWithDib(LDib);
  Assert.IsTrue(TWABitmapConverter.TryWmfToBmp(LWmf, LBmp));
  Assert.AreEqual(Length(LDib) + 14, Length(LBmp));
  Assert.IsTrue(CompareMem(@LDib[0], @LBmp[14], Length(LDib)));
end;

procedure TWABitmapConverterTests.TryWmfToBmp_VectorOnlyMetafile_ReturnsFalse;
var
  LWmf, LBmp: TBytes;
begin
  SetLength(LWmf, 24);
  FillChar(LWmf[0], 24, 0);
  PWord(@LWmf[0])^ := 1;
  PWord(@LWmf[2])^ := 9;
  PCardinal(@LWmf[18])^ := 3; // META_EOF only
  Assert.IsFalse(TWABitmapConverter.TryWmfToBmp(LWmf, LBmp));
end;

procedure TWABitmapConverterTests.TryGetPixelSize_Bmp_ReadsWidthAndHeight;
var
  LDib, LBmp: TBytes;
  LWidth, LHeight: Integer;
begin
  LDib := BuildDib(7, 5);
  TWABitmapConverter.TryDibToBmp(LDib, LBmp);
  Assert.IsTrue(TWAImageInfo.TryGetPixelSize(LBmp, LWidth, LHeight));
  Assert.AreEqual(7, LWidth);
  Assert.AreEqual(5, LHeight);
end;

initialization
  TDUnitX.RegisterTestFixture(TWABitmapConverterTests);

end.
