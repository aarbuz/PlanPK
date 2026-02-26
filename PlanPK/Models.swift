import SwiftUI
import ActivityKit

public struct LiveClassAttributes: ActivityAttributes {
    
    public struct ContentState: Codable, Hashable {
     
    }
    public var className: String
    public var room: String
    public var startTime: Date
    public var endTime: Date
    public var typeName: String 
}

extension Date {
    func getMonday() -> Date {
        let calendar = Calendar.current
        let comp = calendar.dateComponents([.year, .weekOfYear, .weekday], from: self)
        let weekday = comp.weekday ?? 2
        let daysToSubtract = (weekday == 1 ? 6 : weekday - 2)
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: self)!
    }
}

enum AppThemeConfig: String, CaseIterable {
    case blue = "Politechnika", green = "Hacker (Zielony)", red = "Czerwony", purple = "Fioletowy", orange = "Bursztyn", pink = "Malinowy"
    
    var mainColor: Color { switch self { case .blue: return .blue; case .green: return .green; case .red: return .red; case .purple: return .purple; case .orange: return .orange; case .pink: return .pink } }
    var secondaryColor: Color { switch self { case .blue: return .cyan; case .green: return .teal; case .red: return .orange; case .purple: return .pink; case .orange: return .yellow; case .pink: return .purple } }
    var gradient: [Color] { switch self { case .blue: return [.blue, .purple.opacity(0.8)]; case .green: return [.green, .mint]; case .red: return [.red, .orange]; case .purple: return [.purple, .pink]; case .orange: return [.orange, .yellow]; case .pink: return [.pink, .purple] } }
}

enum AppColorScheme: Int, CaseIterable {
    case auto = 0, light = 1, dark = 2
    var description: String { switch self { case .auto: return "Systemowy"; case .light: return "Jasny"; case .dark: return "Ciemny" } }
}

enum EventCategory: String, Codable, CaseIterable {
    case exam = "Kolokwium", project = "Projekt", homework = "Zadanie", other = "Inne"
    var color: Color { switch self { case .exam: return .red; case .project: return .orange; case .homework: return .green; case .other: return .gray } }
}

enum ClassType: String, CaseIterable, Codable {
    case wyklad = "W", lab = "L", proj = "P", lek = "Lek", labK = "Lk", unknown = "Inne"
    var color: Color { switch self { case .wyklad: return .orange; case .lab: return .blue; case .proj: return .green; case .lek: return .pink; case .labK: return .purple; case .unknown: return .gray } }
    var icon: String { switch self { case .wyklad: return "book.fill"; case .lab: return "flask.fill"; case .proj: return "hammer.fill"; case .lek: return "bubble.left.and.bubble.right.fill"; case .labK: return "desktopcomputer"; case .unknown: return "calendar" } }
    var fullName: String { switch self { case .wyklad: return "Wykład"; case .lab: return "Laboratorium"; case .proj: return "Projekt"; case .lek: return "Lektorat"; case .labK: return "Lab. Komputerowe"; case .unknown: return "Inne" } }
}

enum GradeType: String, Codable, CaseIterable { case kolokwium = "Kolokwium", egzamin = "Egzamin", wejsciowka = "Wejściówka", projekt = "Projekt", inna = "Inne" }
struct GradeEntry: Identifiable, Codable { var id = UUID(); var value: Double; var type: GradeType; var date: Date; var customName: String? }
struct AbsenceRecord: Identifiable, Codable { var id = UUID(); var date: Date; var note: String }
struct SemesterArchive: Identifiable, Codable { var id = UUID(); var name: String; var date: Date; var grades: [String: [GradeEntry]]; var absences: [String: [String: [AbsenceRecord]]]; var syllabuses: [String: [String: String]]; var average: Double }

struct AppEvent: Identifiable, Codable {
    var id: String; var title: String; var lecturer: String; var room: String; var date: Date; var startTime: Date; var endTime: Date; var category: EventCategory?; var classType: ClassType?; var group: String?; var isUserCreated: Bool = false; var customCategory: String? = nil
    
    func isHappeningNow(at currentTime: Date) -> Bool { return currentTime >= startTime && currentTime <= endTime }
    func progress(at currentTime: Date) -> Double { let total = endTime.timeIntervalSince(startTime); let elapsed = currentTime.timeIntervalSince(startTime); return max(0, min(1, elapsed / total)) }
    func timeLeftString(at currentTime: Date) -> String { let diff = Int(endTime.timeIntervalSince(currentTime)) / 60; if diff <= 0 { return "Koniec" }; let h = diff / 60; let m = diff % 60; if h > 0 { return "Koniec za \(h)h \(m)m" }; return "Koniec za \(m) min" }
    var durationMinutes: Int { return Int(endTime.timeIntervalSince(startTime)) / 60 }
    var durationString: String { let h = durationMinutes / 60; let m = durationMinutes % 60; if h > 0 && m > 0 { return "\(h)h \(m)m" } else if h > 0 { return "\(h)h" } else { return "\(m)m" } }
}
struct CustomTimeInfo: Codable, Hashable {
    var startTime: Date
    var endTime: Date
}
