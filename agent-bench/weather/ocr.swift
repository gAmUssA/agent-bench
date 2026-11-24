// Prints the text found in an image, one line per recognized line.   usage: ocr <image.png>
import Foundation
import Vision
import AppKit

guard CommandLine.arguments.count == 2,
      let image = NSImage(contentsOfFile: CommandLine.arguments[1]),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("ocr: cannot read the image; pass a PNG path\n".utf8))
    exit(1)
}
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
try VNImageRequestHandler(cgImage: cg).perform([request])
for obs in request.results ?? [] {
    if let top = obs.topCandidates(1).first { print(top.string) }
}
