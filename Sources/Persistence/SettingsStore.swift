import Foundation

public protocol SettingsStoreProtocol: AnyObject, SettingsStoring {
    func saveMappings<T: Encodable>(_ items: T)
    func loadMappings<T: Decodable>() -> T?
}

public protocol SettingsStoring: AnyObject {
    var selectedMidiInputUID: Int32? { get set }
    var clientName: String { get set }
    var autoReconnect: Bool { get set }
}

public final class SettingsStore: SettingsStoreProtocol {
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let mappingsFileName = "mappings.json"
    
    public init() {}
    
    public var selectedMidiInputUID: Int32? {
        get {
            let value = userDefaults.integer(forKey: "selectedMidiInputUID")
            return value == 0 ? nil : Int32(value)
        }
        set {
            if let v = newValue {
                userDefaults.set(Int(v), forKey: "selectedMidiInputUID")
            } else {
                userDefaults.removeObject(forKey: "selectedMidiInputUID")
            }
        }
    }
    
    public var clientName: String {
        get { userDefaults.string(forKey: "clientName") ?? "Scarlett MIDI Control" }
        set { userDefaults.set(newValue, forKey: "clientName") }
    }
    
    public var autoReconnect: Bool {
        get { userDefaults.object(forKey: "autoReconnect") as? Bool ?? true }
        set { userDefaults.set(newValue, forKey: "autoReconnect") }
    }
    
    public func saveMappings<T: Encodable>(_ items: T) {
        do {
            let url = try mappingsURL()
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save mappings: \(error)")
        }
    }
    
    public func loadMappings<T: Decodable>() -> T? {
        do {
            let url = try mappingsURL()
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }
    
    private func mappingsURL() throws -> URL {
        let dir = try appSupportDirectory()
        return dir.appendingPathComponent(mappingsFileName)
    }
    
    private func appSupportDirectory() throws -> URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard var url = urls.first else {
            throw NSError(domain: "SettingsStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "No app support dir"])
        }
        url.appendPathComponent("ScarlettMidiControl", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
}

