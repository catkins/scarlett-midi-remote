import Foundation

public protocol SettingsStoreProtocol: AnyObject, SettingsStoring {
    func saveMappings<T: Encodable>(_ items: T)
    func loadMappings<T: Decodable>() -> T?
}

public protocol SettingsStoring: AnyObject {
    var selectedMidiInputName: String? { get set }
}

public final class SettingsStore: SettingsStoreProtocol {
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let mappingsFileName = "mappings.json"
    
    public init() {}
    
    public var selectedMidiInputName: String? {
        get { userDefaults.string(forKey: "selectedMidiInputName") }
        set { userDefaults.set(newValue, forKey: "selectedMidiInputName") }
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

