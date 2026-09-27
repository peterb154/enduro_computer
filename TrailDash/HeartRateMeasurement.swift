import Foundation

/// Decodes the BLE Heart Rate Measurement characteristic (0x2A37).
/// Byte 0 is flags; bit 0 set means the HR value is UInt16 little-endian, else UInt8.
/// Remaining fields (energy expended, RR intervals) are ignored for now.
nonisolated func parseHeartRate(_ data: Data) -> Int? {
    let bytes = [UInt8](data)
    guard let flags = bytes.first else { return nil }

    if flags & 0x01 == 0 {
        guard bytes.count >= 2 else { return nil }
        return Int(bytes[1])
    } else {
        guard bytes.count >= 3 else { return nil }
        return Int(bytes[1]) | (Int(bytes[2]) << 8)
    }
}
