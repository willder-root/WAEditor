unit WAEditor.Domain.BitmapConverter;

interface

uses
  System.SysUtils;

type
  /// Pure byte-level conversions between the bitmap containers RTF can
  /// carry (a bare DIB in \dibitmap, or a DIB wrapped in a Windows
  /// Metafile record, as WPTools writes it for \wmetafile) and a plain
  /// .bmp file image that a browser can display from a data: URI.
  TWABitmapConverter = class
  public
    /// Prepends the 14-byte BITMAPFILEHEADER a DIB lacks.
    class function TryDibToBmp(const ADib: TBytes; out ABmp: TBytes): Boolean; static;
    /// Reverse of TryDibToBmp: strips the file header.
    class function TryBmpToDib(const ABmp: TBytes; out ADib: TBytes): Boolean; static;
    /// Finds the first bitmap-drawing record (DibStretchBlt,
    /// StretchDIBits, SetDIBitsToDevice, DibBitBlt) in a WMF and returns
    /// its bitmap as a .bmp. A purely vector metafile has no such record
    /// and yields False: there is nothing a browser could be given.
    class function TryWmfToBmp(const AWmf: TBytes; out ABmp: TBytes): Boolean; static;
  end;

implementation

const
  WA_BITMAPFILEHEADER_SIZE = 14;
  WA_WMF_PLACEABLE_KEY = $9AC6CDD7;
  WA_WMF_HEADER_SIZE = 18;
  WA_WMF_DIBBITBLT = $0940;
  WA_WMF_DIBSTRETCHBLT = $0B41;
  WA_WMF_SETDIBTODEV = $0D33;
  WA_WMF_STRETCHDIBITS = $0F43;

function ReadWord(const AData: TBytes; AOffset: Integer): Integer;
begin
  Result := AData[AOffset] or (AData[AOffset + 1] shl 8);
end;

function ReadDWord(const AData: TBytes; AOffset: Integer): Cardinal;
begin
  Result := Cardinal(AData[AOffset]) or (Cardinal(AData[AOffset + 1]) shl 8) or
    (Cardinal(AData[AOffset + 2]) shl 16) or (Cardinal(AData[AOffset + 3]) shl 24);
end;

function PixelDataOffset(const ADib: TBytes): Cardinal;
// Offset of the pixel bits from the start of a DIB: info header, then
// the palette (explicit count, or the full 2^bpp table for <=8bpp), or
// the 3 channel masks BI_BITFIELDS adds after a 40-byte header.
var
  LHeaderSize, LColorsUsed: Cardinal;
  LBitCount, LCompression: Integer;
begin
  LHeaderSize := ReadDWord(ADib, 0);
  Result := LHeaderSize;
  if LHeaderSize < 40 then
    Exit; // BITMAPCOREHEADER: 3-byte palette entries are not handled
  LBitCount := ReadWord(ADib, 14);
  LCompression := Integer(ReadDWord(ADib, 16));
  LColorsUsed := ReadDWord(ADib, 32);
  if LBitCount <= 8 then
  begin
    if LColorsUsed = 0 then
      LColorsUsed := Cardinal(1) shl LBitCount;
    Inc(Result, LColorsUsed * 4);
  end
  else if (LCompression = 3) and (LHeaderSize = 40) then
    Inc(Result, 12);
end;

class function TWABitmapConverter.TryDibToBmp(const ADib: TBytes; out ABmp: TBytes): Boolean;
var
  LTotal, LPixelOffset: Cardinal;
begin
  Result := False;
  ABmp := nil;
  if (Length(ADib) < 40) or (ReadDWord(ADib, 0) < 40) then
    Exit;
  LPixelOffset := WA_BITMAPFILEHEADER_SIZE + PixelDataOffset(ADib);
  LTotal := WA_BITMAPFILEHEADER_SIZE + Cardinal(Length(ADib));
  if LPixelOffset > LTotal then
    Exit;
  SetLength(ABmp, LTotal);
  ABmp[0] := Ord('B');
  ABmp[1] := Ord('M');
  Move(LTotal, ABmp[2], 4);
  FillChar(ABmp[6], 4, 0);
  Move(LPixelOffset, ABmp[10], 4);
  Move(ADib[0], ABmp[WA_BITMAPFILEHEADER_SIZE], Length(ADib));
  Result := True;
end;

class function TWABitmapConverter.TryBmpToDib(const ABmp: TBytes; out ADib: TBytes): Boolean;
begin
  Result := False;
  ADib := nil;
  if (Length(ABmp) < WA_BITMAPFILEHEADER_SIZE + 40) or (ABmp[0] <> Ord('B')) or
     (ABmp[1] <> Ord('M')) then
    Exit;
  SetLength(ADib, Length(ABmp) - WA_BITMAPFILEHEADER_SIZE);
  Move(ABmp[WA_BITMAPFILEHEADER_SIZE], ADib[0], Length(ADib));
  Result := True;
end;

class function TWABitmapConverter.TryWmfToBmp(const AWmf: TBytes; out ABmp: TBytes): Boolean;
var
  LOffset, LRecordEnd, LDibOffset: Cardinal;
  LRecordWords: Cardinal;
  LFunction: Integer;
  LDib: TBytes;
begin
  Result := False;
  ABmp := nil;
  LOffset := WA_WMF_HEADER_SIZE;
  if (Length(AWmf) >= 22) and (ReadDWord(AWmf, 0) = WA_WMF_PLACEABLE_KEY) then
    LOffset := 22 + WA_WMF_HEADER_SIZE;
  while LOffset + 6 <= Cardinal(Length(AWmf)) do
  begin
    LRecordWords := ReadDWord(AWmf, LOffset);
    LFunction := ReadWord(AWmf, LOffset + 4);
    if LRecordWords < 3 then
      Break;
    LRecordEnd := LOffset + LRecordWords * 2;
    if LRecordEnd > Cardinal(Length(AWmf)) then
      LRecordEnd := Cardinal(Length(AWmf));
    LDibOffset := 0;
    case LFunction of
      WA_WMF_DIBSTRETCHBLT: LDibOffset := LOffset + 6 + 20;
      WA_WMF_STRETCHDIBITS: LDibOffset := LOffset + 6 + 22;
      WA_WMF_SETDIBTODEV: LDibOffset := LOffset + 6 + 18;
      WA_WMF_DIBBITBLT: LDibOffset := LOffset + 6 + 16;
    end;
    if (LDibOffset > 0) and (LDibOffset + 40 <= LRecordEnd) then
    begin
      SetLength(LDib, LRecordEnd - LDibOffset);
      Move(AWmf[LDibOffset], LDib[0], Length(LDib));
      if TryDibToBmp(LDib, ABmp) then
        Exit(True);
    end;
    LOffset := LRecordEnd;
  end;
end;

end.
