import Foundation

public enum BackupScheduler {
    @discardableResult
    public static func runIfNeeded(
        repository: GRDBNoteRepository,
        backupsDir: URL,
        now: Date = Date(),
        keep: Int = 7
    ) throws -> Bool {
        let fm = FileManager.default
        try fm.createDirectory(at: backupsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let target = backupsDir.appendingPathComponent("galpi-\(formatter.string(from: now)).sqlite")
        guard !fm.fileExists(atPath: target.path) else { return false }

        try repository.backup(to: target)

        let backups = try fm.contentsOfDirectory(at: backupsDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("galpi-") && $0.pathExtension == "sqlite" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for old in backups.dropLast(keep) {
            try fm.removeItem(at: old)
        }
        return true
    }
}
