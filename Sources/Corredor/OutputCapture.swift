import Foundation

final class OutputCapture {
    private let shouldPrint: Bool
    private let onLine: (@Sendable (String) -> Void)?
    private var bytes: [UInt8] = []
    private var pendingLine: [UInt8] = []

    init(shouldPrint: Bool, onLine: (@Sendable (String) -> Void)?) {
        self.shouldPrint = shouldPrint
        self.onLine = onLine
    }

    var text: String {
        String(decoding: bytes, as: UTF8.self)
    }

    func append(_ chunk: ArraySlice<UInt8>) {
        bytes.append(contentsOf: chunk)
        if shouldPrint {
            print(String(decoding: chunk, as: UTF8.self), terminator: "")
        }
        guard let onLine else { return }

        pendingLine.append(contentsOf: chunk)
        var lineStart = pendingLine.startIndex
        while let newline = pendingLine[lineStart...].firstIndex(of: UInt8(ascii: "\n")) {
            let line = String(decoding: pendingLine[lineStart..<newline], as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty {
                onLine(line)
            }
            lineStart = newline + 1
        }
        pendingLine.removeFirst(lineStart)
    }
}

extension OutputCapture {
    /// Reads every descriptor to EOF on the calling thread, so `run()` never waits on a thread pool its caller may be exhausting.
    /// Returns the `errno` of the first unrecoverable failure, if any.
    static func drain(_ streams: [(fd: Int32, capture: OutputCapture)]) -> Int32? {
        var descriptors = streams.map { pollfd(fd: $0.fd, events: Int16(POLLIN), revents: 0) }
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        var open = descriptors.count

        while open > 0 {
            if poll(&descriptors, nfds_t(descriptors.count), -1) < 0 {
                if errno == EINTR { continue }
                return errno
            }
            for index in descriptors.indices where descriptors[index].revents != 0 {
                let count = read(descriptors[index].fd, &buffer, buffer.count)
                if count > 0 {
                    streams[index].capture.append(buffer[..<count])
                } else if count == 0 {
                    descriptors[index].fd = -1
                    open -= 1
                } else if errno != EINTR {
                    return errno
                }
            }
        }
        return nil
    }
}
