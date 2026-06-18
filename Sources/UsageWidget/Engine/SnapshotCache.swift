import Foundation

/// Persists the last-good usage snapshot per provider to JSON in Application Support, so the
/// popover shows data instantly on open and survives relaunches. Never stores credentials.
actor SnapshotCache {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(bundleID: String = "com.flukelaster.usagewidget", filename: String = "snapshots.json") {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(bundleID, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(filename)

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    /// Load all cached snapshots. Keyed by `ProviderID.rawValue` on disk for clean JSON.
    func load() -> [ProviderID: ProviderUsage] {
        guard let data = try? Data(contentsOf: fileURL),
              let raw = try? decoder.decode([String: ProviderUsage].self, from: data) else {
            return [:]
        }
        var result: [ProviderID: ProviderUsage] = [:]
        for (key, value) in raw {
            result[ProviderID(rawValue: key)] = value
        }
        return result
    }

    /// Atomically persist the current snapshots.
    func save(_ snapshots: [ProviderID: ProviderUsage]) {
        var raw: [String: ProviderUsage] = [:]
        for (id, usage) in snapshots {
            raw[id.rawValue] = usage
        }
        guard let data = try? encoder.encode(raw) else {
            Log.engine.error("SnapshotCache: failed to encode snapshots")
            return
        }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.engine.error("SnapshotCache: failed to write: \(error.localizedDescription)")
        }
    }
}
