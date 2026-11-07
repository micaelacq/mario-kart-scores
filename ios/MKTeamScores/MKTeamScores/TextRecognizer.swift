import UIKit
import Vision

/// On-device text recognition with Apple's Vision framework.
/// Returns the screen as rows of words, each with its position, so the parser can tell the
/// position/icon columns apart from the name and score columns.
enum TextRecognizer {

    enum RecognizerError: LocalizedError {
        case badImage
        var errorDescription: String? { "The image could not be opened." }
    }

    static func recognizeRows(in image: UIImage) async throws -> [[OCRWord]] {
        guard let cgImage = image.cgImage else { throw RecognizerError.badImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        let observations: [VNRecognizedTextObservation] = try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false   // gamer tags aren't dictionary words
                request.minimumTextHeight = 0.01
                do {
                    try VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:]).perform([request])
                    cont.resume(returning: request.results ?? [])
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
        return groupIntoRows(words(from: observations))
    }

    /// Split each recognised phrase into words with their own boxes.
    private static func words(from observations: [VNRecognizedTextObservation]) -> [OCRWord] {
        var out: [OCRWord] = []
        for obs in observations {
            guard let candidate = obs.topCandidates(1).first else { continue }
            let string = candidate.string
            var start = string.startIndex
            while start < string.endIndex {
                guard let wordStart = string[start...].firstIndex(where: { !$0.isWhitespace }) else { break }
                let wordEnd = string[wordStart...].firstIndex(where: \.isWhitespace) ?? string.endIndex
                let range = wordStart..<wordEnd
                // Vision: origin bottom-left. Convert so y grows downwards.
                let box = (try? candidate.boundingBox(for: range))?.boundingBox ?? obs.boundingBox
                out.append(OCRWord(text: String(string[range]), x0: box.minX, x1: box.maxX, y: 1 - box.midY))
                start = wordEnd
            }
        }
        return out
    }

    private static func groupIntoRows(_ words: [OCRWord]) -> [[OCRWord]] {
        guard !words.isEmpty else { return [] }
        let sorted = words.sorted { $0.y < $1.y }
        // Row spacing = typical vertical gap between neighbouring words that are on different rows.
        let gaps = zip(sorted.dropFirst(), sorted).map { $0.y - $1.y }.filter { $0 > 0.004 }.sorted()
        let rowGap = gaps.isEmpty ? 0.02 : gaps[gaps.count / 2]
        var rows: [[OCRWord]] = []
        for w in sorted {
            if let last = rows.last {
                let mid = last.map(\.y).reduce(0, +) / CGFloat(last.count)
                if abs(w.y - mid) < rowGap * 0.5 {
                    rows[rows.count - 1].append(w)
                    continue
                }
            }
            rows.append([w])
        }
        return rows.map { $0.sorted { $0.x0 < $1.x0 } }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
