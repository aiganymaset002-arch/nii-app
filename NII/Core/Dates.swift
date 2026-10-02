//
//  Dates.swift
//  NII App
//
//  Parsing and formatting of Supabase dates (timestamptz and date columns).
//

import Foundation

enum NIIDate {
    /// Kazakhstan has used a single zone, UTC+5, since March 2024 (no daylight saving).
    /// Fixed offset so old time-zone data on a device cannot shift times by an hour.
    static let timeZone = TimeZone(secondsFromGMT: 5 * 3600) ?? .current

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = timeZone
        f.dateFormat = format
        return f
    }

    private static let dayFormatter = formatter("yyyy-MM-dd")
    private static let shortFormatter = formatter("dd.MM.yyyy")
    private static let dateTimeFormatter = formatter("dd.MM.yyyy HH:mm")
    private static let timeFormatter = formatter("HH:mm")

    /// "2026-10-02T22:30:07.123456+00:00", "2026-10-02T22:30:07Z", "2026-10-02"
    static func parse(_ text: String) -> Date? {
        if text.count == 10 {
            return dayFormatter.date(from: text)
        }
        var value = text.replacingOccurrences(of: " ", with: "T")
        // Postgres sends up to 6 fractional digits; the ISO formatter wants 3
        if let dot = value.firstIndex(of: ".") {
            let fractionEnd = value[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) ?? value.endIndex
            let digits = value[value.index(after: dot)..<fractionEnd]
            let ms = String((digits + "000").prefix(3))
            value = String(value[..<dot]) + "." + ms + String(value[fractionEnd...])
        }
        return isoFractional.date(from: value) ?? iso.date(from: value)
    }

    static func iso8601(_ date: Date) -> String { iso.string(from: date) }

    /// "yyyy-MM-dd" for date columns
    static func day(_ date: Date) -> String { dayFormatter.string(from: date) }
    static func dayDate(_ text: String?) -> Date? { text.flatMap { dayFormatter.date(from: $0) } }

    static func short(_ date: Date) -> String { shortFormatter.string(from: date) }
    static func short(day text: String?) -> String { dayDate(text).map(short) ?? "—" }
    static func dateTime(_ date: Date) -> String { dateTimeFormatter.string(from: date) }
    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }

    static var today: String { day(Date()) }
}

extension JSONDecoder {
    static let nii: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = NIIDate.parse(text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(text)"))
            }
            return date
        }
        return d
    }()
}

extension JSONEncoder {
    static let nii: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(NIIDate.iso8601(date))
        }
        return e
    }()
}
