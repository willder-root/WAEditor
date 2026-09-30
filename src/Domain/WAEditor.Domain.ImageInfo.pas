unit WAEditor.Domain.ImageInfo;

interface

uses
  System.SysUtils;

type
  /// Reads the intrinsic pixel dimensions straight out of a raster
  /// image's own bytes (PNG's IHDR chunk, JPEG's Start-Of-Frame
  /// segment). Used as the source of truth for RTF's \picw/\pich,
  /// which the format requires regardless of what display size (if
  /// any) the HTML side specified.
  TWAImageInfo = class
  public
    class function TryGetPixelSize(const AData: TBytes; out AWidthPx, AHeightPx: Integer): Boolean; static;
  end;

implementation

class function TWAImageInfo.TryGetPixelSize(const AData: TBytes; out AWidthPx,
  AHeightPx: Integer): Boolean;
const
  WA_PNG_SIGNATURE: array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);
var
  I, LLen: Integer;
  LMarker: Byte;
  LSegLen: Integer;
  LIsPng: Boolean;
begin
  AWidthPx := 0;
  AHeightPx := 0;
  LLen := Length(AData);

  // PNG: signature + IHDR, which is mandated to be the very first
  // chunk, so width/height sit at a fixed offset: 8-byte signature +
  // 4-byte chunk length + 4-byte "IHDR" tag, then two big-endian
  // 32-bit fields.
  if LLen >= 24 then
  begin
    LIsPng := True;
    for I := 0 to 7 do
      if AData[I] <> WA_PNG_SIGNATURE[I] then
      begin
        LIsPng := False;
        Break;
      end;
    if LIsPng then
    begin
      AWidthPx := (AData[16] shl 24) or (AData[17] shl 16) or (AData[18] shl 8) or AData[19];
      AHeightPx := (AData[20] shl 24) or (AData[21] shl 16) or (AData[22] shl 8) or AData[23];
      Exit(True);
    end;
  end;

  // JPEG: scan markers for the first Start-Of-Frame segment
  // (0xC0-0xCF except the non-SOF 0xC4/0xC8/0xCC), which carries
  // [length:2][precision:1][height:2][width:2] right after the marker.
  if (LLen >= 4) and (AData[0] = $FF) and (AData[1] = $D8) then
  begin
    I := 2;
    while I + 1 < LLen do
    begin
      if AData[I] <> $FF then
        Break;
      while (I < LLen) and (AData[I] = $FF) do
        Inc(I);
      if I >= LLen then
        Break;
      LMarker := AData[I];
      Inc(I);
      // SOI/EOI/TEM/RSTn carry no length field and no payload.
      if (LMarker = $D8) or (LMarker = $D9) or (LMarker = $01) or
         ((LMarker >= $D0) and (LMarker <= $D7)) then
        Continue;
      if LMarker = $DA then
        Break; // start of entropy-coded scan data: no SOF seen before it
      if I + 1 >= LLen then
        Break;
      LSegLen := (AData[I] shl 8) or AData[I + 1]; // includes these 2 length bytes
      if (LMarker >= $C0) and (LMarker <= $CF) and
         (LMarker <> $C4) and (LMarker <> $C8) and (LMarker <> $CC) then
      begin
        if I + 6 >= LLen then
          Break;
        AHeightPx := (AData[I + 3] shl 8) or AData[I + 4];
        AWidthPx := (AData[I + 5] shl 8) or AData[I + 6];
        Exit(True);
      end;
      Inc(I, LSegLen);
    end;
  end;

  Result := False;
end;

end.
