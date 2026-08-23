import Foundation

/// Handles the classic Focusrite Control server message framing.
/// Reverse-engineered notes (UNVERIFIED — verify against a running server):
/// - Each message is framed by a length header and footer in ASCII: `Length=<6-hex>` (e.g. `Length=0001AF`)
/// - The length refers to the number of bytes of the XML payload (UTF-8)
/// - Prefix and suffix may both appear; when both exist, they should match
public final class ProtocolFraming {
    private let headerPrefix = "Length="
    private let headerLengthDigits = 6
    
    public init() {}
    
    public func encode(xml: String) -> Data {
        let payload = Data(xml.utf8)
        let lenHex = String(format: "%06X", payload.count)
        let header = Data((headerPrefix + lenHex + " ").utf8)
        let footer = Data((" " + headerPrefix + lenHex).utf8)
        var data = Data()
        data.append(header)
        data.append(payload)
        data.append(footer)
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
        let digitsEnd = buffer.index(lenStart, offsetBy: headerLengthDigits, limitedBy: buffer.endIndex) ?? buffer.endIndex
        guard digitsEnd > lenStart else { return nil }
        let lenData = buffer[lenStart..<digitsEnd]
        guard let lenHex = String(data: lenData, encoding: .utf8),
              let length = Int(lenHex, radix: 16) else { return nil }
        // Expect a space after digits
        let afterDigits = digitsEnd
        guard afterDigits < buffer.endIndex, buffer[afterDigits] == 0x20 /* space */ else { return nil }
        let payloadStart = buffer.index(afterDigits, offsetBy: 1, limitedBy: buffer.endIndex) ?? buffer.endIndex
        let payloadEnd = buffer.index(payloadStart, offsetBy: length, limitedBy: buffer.endIndex) ?? buffer.endIndex
        guard payloadEnd <= buffer.endIndex else { return nil }
        guard payloadEnd <= buffer.endIndex else { return nil }
        guard payloadEnd <= buffer.endIndex, payloadStart <= buffer.endIndex, payloadStart <= payloadEnd else { return nil }
        guard payloadEnd <= buffer.endIndex else { return nil }
        guard payloadEnd <= buffer.endIndex else { return nil }
        let payloadData = buffer[payloadStart..<payloadEnd]
        guard let xml = String(data: payloadData, encoding: .utf8) else { return nil }
        // Footer (optional for our parser): ` Length=XXXXXX`
        let footerExpected = Data((" " + headerPrefix + String(format: "%06X", length)).utf8)
        let footerEnd = buffer.index(payloadEnd, offsetBy: footerExpected.count, limitedBy: buffer.endIndex) ?? buffer.endIndex
        if footerEnd <= buffer.endIndex, buffer[payloadEnd..<footerEnd] == footerExpected {
            return (xml, headerRange.lowerBound..<footerEnd)
        } else {
            // Accept frames without footer too
            return (xml, headerRange.lowerBound..<payloadEnd)
        }
    }
}

