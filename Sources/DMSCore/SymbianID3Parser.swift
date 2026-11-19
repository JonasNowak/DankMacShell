import Foundation

/// Fast pure-Swift ID3v2 and ID3v1 audio metadata parser.
public enum SymbianID3Parser {

    /// Parses an MP3, AAC, or audio file at URL and returns a `SymbianTrack`.
    public static func parse(url: URL) -> SymbianTrack {
        let fileName = url.lastPathComponent
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return fallbackTrack(url: url, fileName: fileName, fileSize: fileSize)
        }
        defer { try? handle.close() }

        var title = ""
        var artist = ""
        var album = ""
        var year = ""
        var genre = ""
        var trackNumber = 1
        var duration: TimeInterval = 0
        let bitrate = 320

        // Preserve the source audio extension instead of hardcoding .mp3
        let audioExt = normalizedAudioExtension(url.pathExtension)

        // 1. Try ID3v2 from file start
        if let headerData = try? handle.read(upToCount: 10), headerData.count == 10 {
            if headerData[0] == 0x49 && headerData[1] == 0x44 && headerData[2] == 0x33 { // "ID3"
                let versionMajor = headerData[3]
                let headerFlags = headerData[5]
                let tagSize = synchsafe(b0: headerData[6], b1: headerData[7], b2: headerData[8], b3: headerData[9])

                if tagSize > 0 && tagSize < 5_000_000 { // reasonable tag size bound
                    if let tagData = try? handle.read(upToCount: tagSize), tagData.count == tagSize {
                        var framesData = tagData
                        // Skip an extended header (flag 0x40, ID3v2.3/2.4 only) without
                        // ever slicing out of bounds.
                        if versionMajor >= 3 && headerFlags & 0x40 != 0 && framesData.count >= 4 {
                            let extSize: Int
                            if versionMajor == 4 {
                                // v2.4: synchsafe size, includes the 4 size bytes themselves
                                extSize = synchsafe(b0: framesData[0], b1: framesData[1], b2: framesData[2], b3: framesData[3])
                            } else {
                                // v2.3: plain big-endian size, excludes the 4 size bytes
                                extSize = ((Int(framesData[0]) << 24) | (Int(framesData[1]) << 16)
                                           | (Int(framesData[2]) << 8) | Int(framesData[3])) + 4
                            }
                            let skip = min(max(extSize, 0), framesData.count)
                            framesData = framesData.subdata(in: skip..<framesData.count)
                        }
                        let frames = parseID3v2Frames(data: framesData, version: versionMajor)
                        if let t = frames["TIT2"], !t.isEmpty { title = t }
                        if let a = frames["TPE1"], !a.isEmpty { artist = a }
                        if let al = frames["TALB"], !al.isEmpty { album = al }
                        if let yr = frames["TYER"] ?? frames["TDRC"], !yr.isEmpty { year = yr }
                        if let gn = frames["TCON"], !gn.isEmpty { genre = gn }
                        if let trk = frames["TRCK"], let num = Int(trk.components(separatedBy: "/").first ?? ""), num > 0 {
                            trackNumber = num
                        }
                    }
                }
            }
        }

        // 2. Try ID3v1 from end of file if title or artist still missing
        if (title.isEmpty || artist.isEmpty) && fileSize >= 128 {
            if (try? handle.seek(toOffset: UInt64(fileSize - 128))) != nil {
                if let v1Data = try? handle.read(upToCount: 128), v1Data.count == 128 {
                    if v1Data[0] == 0x54 && v1Data[1] == 0x41 && v1Data[2] == 0x47 { // "TAG"
                        if title.isEmpty {
                            title = readFixedString(data: v1Data, offset: 3, length: 30)
                        }
                        if artist.isEmpty {
                            artist = readFixedString(data: v1Data, offset: 33, length: 30)
                        }
                        if album.isEmpty {
                            album = readFixedString(data: v1Data, offset: 63, length: 30)
                        }
                        if year.isEmpty {
                            year = readFixedString(data: v1Data, offset: 93, length: 4)
                        }
                        // ID3v1.1 track byte only exists when byte 125 == 0; guard byte 126 > 0
                        // so plain ID3v1.0 files don't report trackNumber = 0.
                        if trackNumber == 1 && v1Data[125] == 0 && v1Data[126] > 0 {
                            trackNumber = Int(v1Data[126])
                        }
                    }
                }
            }
        }

        // 3. Fallback from filename if still empty
        if title.isEmpty {
            let (guessedArtist, guessedTitle) = guessMetadataFromFilename(fileName)
            title = guessedTitle
            if artist.isEmpty && !guessedArtist.isEmpty {
                artist = guessedArtist
            }
        }
        if artist.isEmpty { artist = "Unknown Artist" }
        if album.isEmpty { album = "Unknown Album" }

        // Estimate duration based on bitrate and file size (assume standard 320 kbps if unknown)
        if duration <= 0 && fileSize > 0 {
            // duration = (fileSize * 8) / (bitrate * 1000)
            duration = max(10, Double(fileSize * 8) / Double(bitrate * 1000))
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines)

        let safeArtist = sanitizeFATPathComponent(cleanArtist)
        let safeAlbum = sanitizeFATPathComponent(cleanAlbum)
        let safeTitle = sanitizeFATPathComponent(cleanTitle)

        let relativePath = "Music/\(safeArtist)/\(safeAlbum)/\(String(format: "%02d", trackNumber)) - \(safeTitle).\(audioExt)"

        return SymbianTrack(
            title: cleanTitle,
            artist: cleanArtist,
            album: cleanAlbum,
            year: year,
            genre: genre,
            trackNumber: trackNumber,
            duration: duration,
            fileSize: fileSize,
            bitrate: bitrate,
            filePath: url.path,
            relativeDevicePath: relativePath,
            isSyncedToDevice: false
        )
    }

    // MARK: - Internal Helpers

    /// Sanitizes illegal FAT32/DOS characters (`\ / : * ? " < > |`) to ensure reliable Nokia Belle mass memory paths. Also rejects `.` / `..` traversal,
    /// strips trailing dots/spaces (invalid on FAT32), and guards reserved DOS device names.
    public static func sanitizeFATPathComponent(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "\\/:*?\"<>|\0")
        var replaced = name.components(separatedBy: illegal).joined(separator: "_")
        // Trailing dots and spaces are invalid on FAT32 — strip them.
        while let last = replaced.last, last == "." || last == " " {
            replaced.removeLast()
        }
        let trimmed = replaced.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "." || trimmed == ".." {
            return "Unknown"
        }
        // Reserved DOS device names are invalid as a filename base (with or without extension).
        let reserved: Set<String> = [
            "CON", "PRN", "AUX", "NUL",
            "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
            "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
        ]
        let base = trimmed.components(separatedBy: ".").first?.uppercased() ?? ""
        if reserved.contains(base) {
            return "Unknown"
        }
        return trimmed
    }

    /// Normalizes an audio file extension to one Symbian Belle can play,
    /// defaulting to `mp3` when empty or unrecognized.
    public static func normalizedAudioExtension(_ ext: String) -> String {
        let allowed: Set<String> = ["mp3", "m4a", "aac", "wav", "wma"]
        let lower = ext.lowercased()
        return allowed.contains(lower) ? lower : "mp3"
    }

    private static func synchsafe(b0: UInt8, b1: UInt8, b2: UInt8, b3: UInt8) -> Int {
        return (Int(b0 & 0x7F) << 21) | (Int(b1 & 0x7F) << 14) | (Int(b2 & 0x7F) << 7) | Int(b3 & 0x7F)
    }

    /// ID3v2.2 uses 3-character frame IDs; map the ones we care about to their v2.3/2.4 names.
    private static let v22FrameIDMap: [String: String] = [
        "TT2": "TIT2", "TP1": "TPE1", "TAL": "TALB", "TYE": "TYER",
        "TCO": "TCON", "TRK": "TRCK", "TPB": "TPUB", "TEN": "TENC",
        "TCR": "TCOP", "TDA": "TDAT", "TIM": "TIME", "TRD": "TRDA"
    ]

    private static func parseID3v2Frames(data: Data, version: UInt8) -> [String: String] {
        var results: [String: String] = [:]
        var offset = 0
        let count = data.count

        // ID3v2.2 frames have 6-byte headers (3-char ID + 3-byte big-endian size);
        // v2.3/v2.4 use 10-byte headers (4-char ID + 4-byte size + 2 flag bytes).
        let isV22 = (version == 2)
        let headerLen = isV22 ? 6 : 10
        let idLen = isV22 ? 3 : 4

        while offset + headerLen <= count {
            if data[offset] == 0 { break } // padding

            guard let rawID = String(data: data.subdata(in: offset..<(offset + idLen)), encoding: .ascii),
                  rawID.allSatisfy({ ($0 >= "A" && $0 <= "Z") || ($0 >= "0" && $0 <= "9") }) else {
                break
            }
            let frameID = isV22 ? (v22FrameIDMap[rawID] ?? rawID) : rawID

            let frameSize: Int
            if isV22 {
                frameSize = (Int(data[offset + 3]) << 16) | (Int(data[offset + 4]) << 8) | Int(data[offset + 5])
            } else {
                let b0 = data[offset + 4]
                let b1 = data[offset + 5]
                let b2 = data[offset + 6]
                let b3 = data[offset + 7]
                if version == 4 {
                    frameSize = synchsafe(b0: b0, b1: b1, b2: b2, b3: b3)
                } else {
                    frameSize = (Int(b0) << 24) | (Int(b1) << 16) | (Int(b2) << 8) | Int(b3)
                }
            }

            offset += headerLen
            if frameSize <= 0 || offset + frameSize > count {
                break
            }

            let bodyData = data.subdata(in: offset..<offset + frameSize)
            offset += frameSize

            if bodyData.count > 1 {
                let encoding = bodyData[0]
                let textBytes = bodyData.dropFirst()
                var text: String? = nil

                switch encoding {
                case 0: // ISO-8859-1
                    text = String(data: textBytes, encoding: .isoLatin1)
                case 1: // UTF-16 with BOM
                    text = String(data: textBytes, encoding: .utf16)
                case 2: // UTF-16BE
                    text = String(data: textBytes, encoding: .utf16BigEndian)
                case 3: // UTF-8
                    text = String(data: textBytes, encoding: .utf8)
                default:
                    text = String(data: textBytes, encoding: .utf8) ?? String(data: textBytes, encoding: .ascii)
                }

                if let text = text {
                    let cleaned = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(["\0"])))
                    if !cleaned.isEmpty {
                        results[frameID] = cleaned
                    }
                }
            }
        }

        return results
    }

    private static func readFixedString(data: Data, offset: Int, length: Int) -> String {
        guard offset + length <= data.count else { return "" }
        let slice = data.subdata(in: offset..<offset + length)
        let str = String(data: slice, encoding: .isoLatin1) ?? String(data: slice, encoding: .ascii) ?? ""
        return str.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(["\0"])))
    }

    private static func guessMetadataFromFilename(_ fileName: String) -> (artist: String, title: String) {
        let base = (fileName as NSString).deletingPathExtension
        let parts = base.components(separatedBy: " - ")
        if parts.count >= 2 {
            let artist = parts[0].trimmingCharacters(in: .whitespaces)
            let title = parts[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)
            return (artist, title)
        }
        return ("", base.trimmingCharacters(in: .whitespaces))
    }

    private static func fallbackTrack(url: URL, fileName: String, fileSize: Int64) -> SymbianTrack {
        let (rawArtist, rawTitle) = guessMetadataFromFilename(fileName)
        let artist = rawArtist.isEmpty ? "Unknown Artist" : rawArtist
        let title = rawTitle.isEmpty ? "Track" : rawTitle
        let ext = normalizedAudioExtension(url.pathExtension)
        // Sanitize path components here too — never build a device path from raw metadata.
        let safeArtist = sanitizeFATPathComponent(artist)
        let safeTitle = sanitizeFATPathComponent(title)
        return SymbianTrack(
            title: title,
            artist: artist,
            album: "Unknown Album",
            fileSize: fileSize,
            filePath: url.path,
            relativeDevicePath: "Music/\(safeArtist)/\(safeTitle).\(ext)",
            isSyncedToDevice: false
        )
    }
}
