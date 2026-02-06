import Foundation
import zlib

enum GTFSArchivePreparationError: LocalizedError {
    case unsupportedInput
    case invalidZipStructure
    case unsupportedCompressionMethod(UInt16, String)
    case invalidEntryPath(String)
    case failedToDecompress(String)
    case zip64NotSupported

    var errorDescription: String? {
        switch self {
        case .unsupportedInput:
            return "Select an extracted GTFS folder or a .zip archive."
        case .invalidZipStructure:
            return "The selected GTFS zip file is invalid or corrupted."
        case .unsupportedCompressionMethod(let method, let entry):
            return "Zip entry \(entry) uses unsupported compression method \(method)."
        case .invalidEntryPath(let path):
            return "Zip entry has an invalid path: \(path)"
        case .failedToDecompress(let entry):
            return "Could not decompress zip entry \(entry)."
        case .zip64NotSupported:
            return "Zip64 archives are not supported yet."
        }
    }
}

final class GTFSArchivePreparationService: GTFSArchivePreparationServiceProtocol {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func prepareImportDirectory(from sourceURL: URL) throws -> GTFSPreparedImportDirectory {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
            throw GTFSArchivePreparationError.unsupportedInput
        }

        if isDirectory.boolValue {
            return GTFSPreparedImportDirectory(directoryURL: sourceURL, cleanupURL: nil)
        }

        guard sourceURL.pathExtension.lowercased() == "zip" else {
            throw GTFSArchivePreparationError.unsupportedInput
        }

        let extractionURL = try makeExtractionDirectory()
        do {
            try extractZipArchive(at: sourceURL, to: extractionURL)
            return GTFSPreparedImportDirectory(directoryURL: extractionURL, cleanupURL: extractionURL)
        } catch {
            try? fileManager.removeItem(at: extractionURL)
            throw error
        }
    }

    private func makeExtractionDirectory() throws -> URL {
        let extractionURL = fileManager.temporaryDirectory
            .appendingPathComponent("gtfs-import-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        return extractionURL
    }

    private func extractZipArchive(at archiveURL: URL, to outputDirectory: URL) throws {
        let archiveData = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
        let endOfCentralDirectoryOffset = try locateEndOfCentralDirectory(in: archiveData)

        let totalEntries = Int(try readUInt16(in: archiveData, at: endOfCentralDirectoryOffset + 10))
        let centralDirectoryOffsetRaw = try readUInt32(in: archiveData, at: endOfCentralDirectoryOffset + 16)

        guard totalEntries != 0xFFFF, centralDirectoryOffsetRaw != 0xFFFFFFFF else {
            throw GTFSArchivePreparationError.zip64NotSupported
        }

        var cursor = Int(centralDirectoryOffsetRaw)
        for _ in 0..<totalEntries {
            guard try readUInt32(in: archiveData, at: cursor) == 0x02014B50 else {
                throw GTFSArchivePreparationError.invalidZipStructure
            }

            let compressionMethod = try readUInt16(in: archiveData, at: cursor + 10)
            let compressedSize = Int(try readUInt32(in: archiveData, at: cursor + 20))
            let uncompressedSize = Int(try readUInt32(in: archiveData, at: cursor + 24))
            let fileNameLength = Int(try readUInt16(in: archiveData, at: cursor + 28))
            let extraLength = Int(try readUInt16(in: archiveData, at: cursor + 30))
            let commentLength = Int(try readUInt16(in: archiveData, at: cursor + 32))
            let localHeaderOffset = Int(try readUInt32(in: archiveData, at: cursor + 42))

            let fileNameRangeStart = cursor + 46
            let fileNameRangeEnd = fileNameRangeStart + fileNameLength
            guard fileNameRangeEnd <= archiveData.count else {
                throw GTFSArchivePreparationError.invalidZipStructure
            }

            let entryNameRaw = String(decoding: archiveData[fileNameRangeStart..<fileNameRangeEnd], as: UTF8.self)
            if entryNameRaw.hasSuffix("/") {
                cursor = fileNameRangeEnd + extraLength + commentLength
                continue
            }
            let normalizedEntryPath = try normalizedPath(from: entryNameRaw)
            if normalizedEntryPath.isEmpty {
                cursor = fileNameRangeEnd + extraLength + commentLength
                continue
            }

            guard try readUInt32(in: archiveData, at: localHeaderOffset) == 0x04034B50 else {
                throw GTFSArchivePreparationError.invalidZipStructure
            }

            let localFileNameLength = Int(try readUInt16(in: archiveData, at: localHeaderOffset + 26))
            let localExtraLength = Int(try readUInt16(in: archiveData, at: localHeaderOffset + 28))
            let compressedDataStart = localHeaderOffset + 30 + localFileNameLength + localExtraLength
            let compressedDataEnd = compressedDataStart + compressedSize
            guard compressedDataEnd <= archiveData.count else {
                throw GTFSArchivePreparationError.invalidZipStructure
            }

            let compressedData = Data(archiveData[compressedDataStart..<compressedDataEnd])
            let outputData: Data
            switch compressionMethod {
            case 0:
                outputData = compressedData
            case 8:
                outputData = try decompressDeflateData(
                    compressedData,
                    expectedSize: uncompressedSize,
                    entryName: normalizedEntryPath
                )
            default:
                throw GTFSArchivePreparationError.unsupportedCompressionMethod(compressionMethod, normalizedEntryPath)
            }

            let outputFileURL = outputDirectory.appendingPathComponent(normalizedEntryPath)
            let outputParentDirectory = outputFileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: outputParentDirectory, withIntermediateDirectories: true)
            try outputData.write(to: outputFileURL, options: .atomic)

            cursor = fileNameRangeEnd + extraLength + commentLength
        }
    }

    private func decompressDeflateData(_ compressedData: Data, expectedSize: Int, entryName: String) throws -> Data {
        var stream = z_stream()
        let initStatus = inflateInit2_(
            &stream,
            -MAX_WBITS,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )

        guard initStatus == Z_OK else {
            throw GTFSArchivePreparationError.failedToDecompress(entryName)
        }

        defer {
            inflateEnd(&stream)
        }

        let chunkSize = 64 * 1024
        var decompressed = Data()

        try compressedData.withUnsafeBytes { sourceBuffer in
            guard let sourceBaseAddress = sourceBuffer.baseAddress else {
                return
            }

            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: sourceBaseAddress.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(sourceBuffer.count)

            var inflateStatus: Int32 = Z_OK
            repeat {
                var chunk = [UInt8](repeating: 0, count: chunkSize)
                inflateStatus = chunk.withUnsafeMutableBufferPointer { chunkBuffer in
                    stream.next_out = chunkBuffer.baseAddress
                    stream.avail_out = uInt(chunkSize)
                    return inflate(&stream, Z_NO_FLUSH)
                }

                guard inflateStatus == Z_OK || inflateStatus == Z_STREAM_END else {
                    throw GTFSArchivePreparationError.failedToDecompress(entryName)
                }

                let writtenBytes = chunkSize - Int(stream.avail_out)
                if writtenBytes > 0 {
                    decompressed.append(contentsOf: chunk[0..<writtenBytes])
                }
            } while inflateStatus != Z_STREAM_END
        }

        if expectedSize > 0, decompressed.count != expectedSize {
            throw GTFSArchivePreparationError.failedToDecompress(entryName)
        }

        return decompressed
    }

    private func locateEndOfCentralDirectory(in archiveData: Data) throws -> Int {
        let minimumEOCDSize = 22
        guard archiveData.count >= minimumEOCDSize else {
            throw GTFSArchivePreparationError.invalidZipStructure
        }

        let scanStart = max(0, archiveData.count - (minimumEOCDSize + 0xFFFF))
        var offset = archiveData.count - 4

        while offset >= scanStart {
            if archiveData[offset] == 0x50,
               archiveData[offset + 1] == 0x4B,
               archiveData[offset + 2] == 0x05,
               archiveData[offset + 3] == 0x06 {
                return offset
            }
            offset -= 1
        }

        throw GTFSArchivePreparationError.invalidZipStructure
    }

    private func normalizedPath(from rawPath: String) throws -> String {
        let normalized = rawPath.replacingOccurrences(of: "\\", with: "/")
        if normalized.hasPrefix("/") {
            throw GTFSArchivePreparationError.invalidEntryPath(rawPath)
        }

        let parts = normalized.split(separator: "/")
        var safeParts: [String] = []
        safeParts.reserveCapacity(parts.count)

        for part in parts {
            if part == "." || part.isEmpty {
                continue
            }
            if part == ".." {
                throw GTFSArchivePreparationError.invalidEntryPath(rawPath)
            }
            safeParts.append(String(part))
        }

        return safeParts.joined(separator: "/")
    }

    private func readUInt16(in data: Data, at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 1 < data.count else {
            throw GTFSArchivePreparationError.invalidZipStructure
        }

        let low = UInt16(data[offset])
        let high = UInt16(data[offset + 1]) << 8
        return low | high
    }

    private func readUInt32(in data: Data, at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 3 < data.count else {
            throw GTFSArchivePreparationError.invalidZipStructure
        }

        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1]) << 8
        let b2 = UInt32(data[offset + 2]) << 16
        let b3 = UInt32(data[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }
}
