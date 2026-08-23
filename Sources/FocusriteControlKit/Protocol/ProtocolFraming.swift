import Foundation

/// Classic Focusrite Control `Length=<6-hex> ` framing.
///
/// Verified against a live `FocusriteControlServer` on macOS: the server emits a
/// header only (no footer), and concatenates frames back-to-back. We send the
/// same header-only form. A trailing footer is still accepted when parsing.
public final class ProtocolFraming {
    private let headerPrefix = "Length="
    private let headerLengthDigits = 6
    
    public init() {}
    
    public func encode(xml: String) -> Data {
        let payload = Data(xml.utf8)
        let lenHex = String(format: "%06X", payload.count)
        var data = Data()
        data.append(Data((headerPrefix + lenHex + " ").utf8))
        data.append(payload)
        return data
    }
    
    public func tryParseFrames(from buffer: inout Data) -> [String] {
        var messages: [String] = []
        while true {
            guard let (payload, range) = parseOneFrame(from: buffer) else { break }
            messages.append(payload)
            buffer.removeSubrange(range)
        }
        return messages
    }
    
    private func parseOneFrame(from buffer: Data) -> (String, Range<Data.Index>)? {
        guard let headerRange = buffer.range(of: Data(headerPrefix.utf8)) else { return nil }
        let lenStart = headerRange.upperBound
        guard let digitsEnd = buffer.index(lenStart, offsetBy: headerLengthDigits, limitedBy: buffer.endIndex) else {
            return nil
        }
        let lenData = buffer[lenStart..<digitsEnd]
        guard let lenHex = String(data: lenData, encoding: .utf8),
              let length = Int(lenHex, radix: 16) else { return nil }
        guard digitsEnd < buffer.endIndex, buffer[digitsEnd] == 0x20 else { return nil }
        let payloadStart = buffer.index(after: digitsEnd)
        guard let payloadEnd = buffer.index(payloadStart, offsetBy: length, limitedBy: buffer.endIndex),
              payloadEnd <= buffer.endIndex else { return nil }
        let payloadData = buffer[payloadStart..<payloadEnd]
        guard let xml = String(data: payloadData, encoding: .utf8) else { return nil }
        
        let footerExpected = Data((" " + headerPrefix + String(format: "%06X", length)).utf8)
        if let footerEnd = buffer.index(payloadEnd, offsetBy: footerExpected.count, limitedBy: buffer.endIndex),
           footerEnd <= buffer.endIndex,
           buffer[payloadEnd..<footerEnd] == footerExpected {
            return (xml, headerRange.lowerBound..<footerEnd)
        }
        return (xml, headerRange.lowerBound..<payloadEnd)
    }
}
