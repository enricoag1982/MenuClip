import Foundation

/// The ordered clipboard history, newest first.
public struct ClipHistory: Equatable {
    public private(set) var clips: [Clip]

    public init(clips: [Clip] = []) {
        self.clips = clips
    }

    /// Puts `clip` at the top. An older clip with the same content is removed
    /// first, so copying the same thing twice doesn't create a duplicate.
    public mutating func add(_ clip: Clip, limit: Int) {
        clips.removeAll { $0.hasSameContent(as: clip) }
        clips.insert(clip, at: 0)
        trim(to: limit)
    }

    public mutating func moveToTop(id: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == id }), index > 0 else { return }
        var clip = clips.remove(at: index)
        clip.date = Date()
        clips.insert(clip, at: 0)
    }

    public mutating func remove(id: UUID) {
        clips.removeAll { $0.id == id }
    }

    public mutating func removeAll() {
        clips.removeAll()
    }

    public mutating func trim(to limit: Int) {
        let limit = max(limit, 0)
        if clips.count > limit {
            clips.removeLast(clips.count - limit)
        }
    }

    public func clip(withID id: UUID) -> Clip? {
        clips.first { $0.id == id }
    }
}
