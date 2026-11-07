import UIKit
import Vision

/// On-device text recognition with Apple's Vision framework.
/// Vision returns separate boxes for text that is far apart (e.g. a name and its score),
/// so boxes are grouped into rows by their vertical position and read left to right.
enum TextRecognizer {

    enum RecognizerError: LocalizedError {
        case badImage
        var errorDescription: String? { "The image could not be opened." }
    }

    static func recognizeLines(in image: UIImage) async throws -> [String] {
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
        return groupIntoRows(observations)
    }

    private struct Piece {
        let text: String
        let box: CGRect   // normalised, origin bottom-left
    }

    static func groupIntoRows(_ observations: [VNRecognizedTextObservation]) -> [String] {
        let pieces = observations.compactMap { obs -> Piece? in
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            return Piece(text: text, box: obs.boundingBox)
        }
        // Top of screen first.
        let sorted = pieces.sorted { $0.box.midY > $1.box.midY }
        var rows: [[Piece]] = []
        for p in sorted {
            if let lastRow = rows.last {
                let rowMid = lastRow.map(\.box.midY).reduce(0, +) / CGFloat(lastRow.count)
                let rowHeight = lastRow.map(\.box.height).max() ?? p.box.height
                if abs(p.box.midY - rowMid) < max(rowHeight, p.box.height) * 0.5 {
                    rows[rows.count - 1].append(p)
                    continue
                }
            }
            rows.append([p])
        }
        return rows.map { row in
            row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ")
        }
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
