import Foundation

enum DateFormatters {
    static func matchDate(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM HH:mm")
        return formatter.string(from: date)
    }

    static func euros(_ amount: Decimal, locale: Locale) -> String {
        amount.formatted(.currency(code: "EUR").locale(locale))
    }
}