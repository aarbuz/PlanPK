import SwiftUI
import Combine
import UserNotifications
import ActivityKit
import WidgetKit
import EventKit

class DataManager: ObservableObject {
    @Published var allEvents: [AppEvent] = []
    @Published var customNotes: [String: String] = [:]
    @Published var customRooms: [String: String] = [:]
    @Published var cancelledEvents: Set<String> = []
    @Published var absencesDates: [String: [String: [AbsenceRecord]]] = [:]
    @Published var absenceLimits: [String: [String: Int]] = [:]
    @Published var grades: [String: [GradeEntry]] = [:]
    @Published var archives: [SemesterArchive] = []
    @Published var markedExams: Set<String> = []
    @Published var markedImportant: Set<String> = []
    @Published var syllabuses: [String: [String: String]] = [:]
    @Published var exportStatus: String = ""
    
    @Published var currentActivity: Activity<LiveClassAttributes>? = nil
    var activityTimer: AnyCancellable? = nil
    
    @AppStorage("enableLiveActivities") var enableLiveActivities: Bool = true
    @AppStorage("showLectures") var showLectures: Bool = true
    
    @Published var customTimes: [String: CustomTimeInfo] = [:]
    @AppStorage("selectedLabGroup") var selectedLabGroup: String = "L1"
    @AppStorage("selectedProjGroup") var selectedProjGroup: String = "P1"
    @AppStorage("selectedKompGroup") var selectedKompGroup: String = "Lk1"
    @AppStorage("selectedLangGroup") var selectedLangGroup: String = "Lek1"
    @AppStorage("selectedJavaGroup") var selectedJavaGroup: String = "1"
    @AppStorage("appTheme") var appThemeRaw: String = AppThemeConfig.blue.rawValue
    @AppStorage("colorScheme") var colorSchemeSetting: Int = 0
  
    var theme: AppThemeConfig { AppThemeConfig(rawValue: appThemeRaw) ?? .blue }
    let store = NSUbiquitousKeyValueStore.default
    
    let userEventsKey = "user_saved_events_v10"
    let notesKey = "user_saved_notes_v2"
    let roomsKey = "user_custom_rooms_v1"
    let cancelledKey = "user_cancelled_events_v1"
    let absencesKey = "user_absences_v4"
    let limitsKey = "user_absence_limits_v1"
    let gradesKey = "user_grades_v2"
    let archivesKey = "user_archives_v3"
    let markedExamsKey = "user_marked_exams_v1"
    let markedImportantKey = "user_marked_important_v1"
    let syllabusesKey = "user_syllabuses_v2"
    let customTimesKey = "user_custom_times_v1"
    
    init() { loadData() }
    
    func loadData() {
        let classEvents = parseICS(fileName: "plan")
        let userEvents = loadUserEvents()
        
        self.customNotes = loadFromCloud(key: notesKey, type: [String: String].self) ?? [:]
        self.customRooms = loadFromCloud(key: roomsKey, type: [String: String].self) ?? [:]
        self.cancelledEvents = loadFromCloud(key: cancelledKey, type: Set<String>.self) ?? []
        self.absencesDates = loadFromCloud(key: absencesKey, type: [String: [String: [AbsenceRecord]]].self) ?? [:]
        self.absenceLimits = loadFromCloud(key: limitsKey, type: [String: [String: Int]].self) ?? [:]
        self.grades = loadFromCloud(key: gradesKey, type: [String: [GradeEntry]].self) ?? [:]
        self.archives = loadFromCloud(key: archivesKey, type: [SemesterArchive].self) ?? []
        self.markedExams = loadFromCloud(key: markedExamsKey, type: Set<String>.self) ?? []
        self.markedImportant = loadFromCloud(key: markedImportantKey, type: Set<String>.self) ?? []
        self.syllabuses = loadFromCloud(key: syllabusesKey, type: [String: [String: String]].self) ?? [:]
        self.customTimes = loadFromCloud(key: customTimesKey, type: [String: CustomTimeInfo].self) ?? [:]
        
        self.allEvents = (classEvents + userEvents).sorted { $0.startTime < $1.startTime }
        
        DispatchQueue.main.async { self.objectWillChange.send() }
        scheduleNotifications()
        scheduleMorningBriefings()
        exportWidgetData()
    }
    
    func exportToAppleCalendar() {
        let store = EKEventStore()
        exportStatus = "Sprawdzam uprawnienia..."
        
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { granted, error in self.handleCalendarAccess(granted: granted, store: store) }
        } else {
            store.requestAccess(to: .event) { granted, error in self.handleCalendarAccess(granted: granted, store: store) }
        }
    }
    
    private func handleCalendarAccess(granted: Bool, store: EKEventStore) {
        guard granted else { DispatchQueue.main.async { self.exportStatus = "Brak pełnych uprawnień!" }; return }
        guard let calendar = store.defaultCalendarForNewEvents else { DispatchQueue.main.async { self.exportStatus = "Brak domyślnego kalendarza" }; return }
        
        DispatchQueue.main.async { self.exportStatus = "Eksportowanie..." }
        let now = Date()
        let myUpcomingEvents = filteredEvents(forDate: nil, mode: .myPlan, searchText: "").filter { $0.startTime > now && !cancelledEvents.contains($0.id) }
        var addedCount = 0
        
        for appEvent in myUpcomingEvents {
            let predicate = store.predicateForEvents(withStart: appEvent.startTime, end: appEvent.endTime, calendars: [calendar])
            let existingEvents = store.events(matching: predicate)
            if !existingEvents.contains(where: { $0.title == appEvent.title }) {
                let newEvent = EKEvent(eventStore: store)
                newEvent.title = appEvent.title
                let typeName = appEvent.classType?.fullName ?? "Inne"
                newEvent.location = "\(appEvent.room) • \(typeName) • \(appEvent.lecturer)"
                newEvent.startDate = appEvent.startTime; newEvent.endDate = appEvent.endTime
                newEvent.notes = "Prowadzący: \(appEvent.lecturer)\nTyp zajęć: \(typeName)\n\nDodano z aplikacji PlanPK."
                newEvent.calendar = calendar
                do { try store.save(newEvent, span: .thisEvent); addedCount += 1 } catch { print("Błąd zapisu: \(error)") }
            }
        }
        DispatchQueue.main.async {
            if addedCount > 0 { self.exportStatus = "Dodano \(addedCount) zajęć! ✅"; playHaptic(style: .medium) }
            else { self.exportStatus = "Kalendarz jest aktualny! ✅"; playHaptic(style: .light) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.exportStatus = "" }
        }
    }
    
    func removeFromAppleCalendar() {
        let store = EKEventStore(); exportStatus = "Usuwanie..."
        let deleteClosure = {
            guard let calendar = store.defaultCalendarForNewEvents else { DispatchQueue.main.async { self.exportStatus = "Błąd kalendarza" }; return }
            let start = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
            let end = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
            let existingEvents = store.events(matching: predicate)
            var deletedCount = 0
            for event in existingEvents {
                if let notes = event.notes, notes.contains("Dodano z aplikacji PlanPK.") {
                    do { try store.remove(event, span: .thisEvent); deletedCount += 1 } catch { print("Błąd: \(error)") }
                }
            }
            DispatchQueue.main.async {
                if deletedCount > 0 { self.exportStatus = "Usunięto \(deletedCount) zajęć! 🗑️"; playHaptic(style: .heavy) }
                else { self.exportStatus = "Brak zajęć do usunięcia." }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.exportStatus = "" }
            }
        }
        if #available(iOS 17.0, *) { store.requestFullAccessToEvents { granted, error in if granted { deleteClosure() } else { DispatchQueue.main.async { self.exportStatus = "Brak pełnych uprawnień" } } } }
        else { store.requestAccess(to: .event) { granted, error in if granted { deleteClosure() } else { DispatchQueue.main.async { self.exportStatus = "Brak pełnych uprawnień" } } } }
    }
    
    func exportWidgetData() {
        let now = Date()
        let myUpcomingEvents = filteredEvents(forDate: nil, mode: .myPlan, searchText: "").filter { $0.endTime > now && !cancelledEvents.contains($0.id) }
        if let sharedDefaults = UserDefaults(suiteName: "group.PlanPK") {
            if let encoded = try? JSONEncoder().encode(Array(myUpcomingEvents.prefix(20))) {
                sharedDefaults.set(encoded, forKey: "widgetEvents")
            }
            sharedDefaults.set(Array(markedExams), forKey: "widgetExams")
            sharedDefaults.set(Array(markedImportant), forKey: "widgetImportant")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func parseICS(fileName: String) -> [AppEvent] {
        guard let filepath = Bundle.main.path(forResource: fileName, ofType: "ics") else { return [] }
        do {
            let contents = try String(contentsOfFile: filepath, encoding: .utf8)
            let lines = contents.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: .newlines); var events: [AppEvent] = []; var currentSummary = "", currentDtStart = "", currentDtEnd = ""; var insideEvent = false; let f = DateFormatter(); f.dateFormat = "yyyyMMdd'T'HHmmss"; f.timeZone = TimeZone.current
            for line in lines {
                let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if clean == "BEGIN:VEVENT" { insideEvent = true; currentSummary = ""; currentDtStart = ""; currentDtEnd = "" }
                else if clean == "END:VEVENT" {
                    insideEvent = false; if let start = f.date(from: currentDtStart), let end = f.date(from: currentDtEnd) {
                        let parts = currentSummary.components(separatedBy: "\\,"); if parts.count >= 2 {
                            let name = parts[0].trimmingCharacters(in: .whitespaces); let groupRaw = parts[1].trimmingCharacters(in: .whitespaces); var lecturer = "Nieznany"; if parts.count > 2 { lecturer = parts[2].trimmingCharacters(in: .whitespaces) }
                            var room = "Brak sali"; for part in parts { let p = part.trimmingCharacters(in: .whitespaces); if p.starts(with: "s.") || ["A1", "A2", "A3", "A4", "201", "202", "06", "19", "10", "101B"].contains(p) { room = p.replacingOccurrences(of: "s.", with: "").trimmingCharacters(in: .whitespaces) } }
                            var type: ClassType = .unknown; if groupRaw == "W" { type = .wyklad } else if groupRaw.starts(with: "Lek") { type = .lek } else if groupRaw.starts(with: "Lk") { type = .labK } else if groupRaw.starts(with: "L") { type = .lab } else if groupRaw.starts(with: "P") { type = .proj }
                            let uniqueID = "\(name.replacingOccurrences(of: " ", with: ""))_\(start.timeIntervalSince1970)"
                            events.append(AppEvent(id: uniqueID, title: name, lecturer: lecturer, room: room, date: start, startTime: start, endTime: end, category: nil, classType: type, group: groupRaw, isUserCreated: false))
                        }
                    }
                } else if insideEvent { if clean.starts(with: "SUMMARY:") { currentSummary = String(clean.dropFirst(8)) } else if clean.starts(with: "DTSTART:") { currentDtStart = String(clean.dropFirst(8)) } else if clean.starts(with: "DTEND:") { currentDtEnd = String(clean.dropFirst(6)) } }
            }
            return events
        } catch { return [] }
    }
    
    func saveToCloud<T: Encodable>(data: T, key: String) { if let encoded = try? JSONEncoder().encode(data) { store.set(encoded, forKey: key); store.synchronize(); UserDefaults.standard.set(encoded, forKey: key) } }
    func loadFromCloud<T: Decodable>(key: String, type: T.Type) -> T? { let data = store.data(forKey: key) ?? UserDefaults.standard.data(forKey: key); if let data = data, let decoded = try? JSONDecoder().decode(T.self, from: data) { return decoded }; return nil }
    
    func toggleCancel(for id: String) { if cancelledEvents.contains(id) { cancelledEvents.remove(id) } else { cancelledEvents.insert(id) }; saveToCloud(data: cancelledEvents, key: cancelledKey); objectWillChange.send(); exportWidgetData() }
    func scheduleCustomNotif(id: String, title: String, body: String, date: Date) { if date > Date() { let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default; let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date); let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false); UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) } }
    func toggleExam(for id: String, event: AppEvent) { if markedExams.contains(id) { markedExams.remove(id); UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["exam_5d_\(id)"]) } else { markedExams.insert(id); markedImportant.remove(id); UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["important_7d_\(id)"]); scheduleCustomNotif(id: "exam_5d_\(id)", title: "🚨 Kolokwium za 5 dni!", body: "Czas zacząć naukę do: \(event.title)", date: event.startTime.addingTimeInterval(-5 * 24 * 3600)) }; saveToCloud(data: markedExams, key: markedExamsKey); saveToCloud(data: markedImportant, key: markedImportantKey); objectWillChange.send(); exportWidgetData() }
    func toggleImportant(for id: String, event: AppEvent) { if markedImportant.contains(id) { markedImportant.remove(id); UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["important_7d_\(id)"]) } else { markedImportant.insert(id); markedExams.remove(id); UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["exam_5d_\(id)"]); scheduleCustomNotif(id: "important_7d_\(id)", title: "⭐ Ważne zajęcia za tydzień!", body: "Przypomnienie: \(event.title)", date: event.startTime.addingTimeInterval(-7 * 24 * 3600)) }; saveToCloud(data: markedExams, key: markedExamsKey); saveToCloud(data: markedImportant, key: markedImportantKey); objectWillChange.send(); exportWidgetData() }
    
    func saveNote(for id: String, note: String) { if note.isEmpty { customNotes.removeValue(forKey: id) } else { customNotes[id] = note }; saveToCloud(data: customNotes, key: notesKey); objectWillChange.send() }
    func saveRoom(for id: String, room: String) { if room.isEmpty { customRooms.removeValue(forKey: id) } else { customRooms[id] = room }; saveToCloud(data: customRooms, key: roomsKey); objectWillChange.send(); exportWidgetData() }
    
    func addGrade(for subject: String, entry: GradeEntry) { grades[subject, default: []].append(entry); saveToCloud(data: grades, key: gradesKey); objectWillChange.send() }
    func deleteGrades(for subject: String, at offsets: IndexSet) { grades[subject]?.remove(atOffsets: offsets); if grades[subject]?.isEmpty == true { grades.removeValue(forKey: subject) }; saveToCloud(data: grades, key: gradesKey); objectWillChange.send() }
    
    func archiveSemester(name: String, currentAverage: Double) { let arch = SemesterArchive(name: name, date: Date(), grades: grades, absences: absencesDates, syllabuses: syllabuses, average: currentAverage); archives.append(arch); saveToCloud(data: archives, key: archivesKey); grades = [:]; absencesDates = [:]; customNotes = [:]; customRooms = [:]; cancelledEvents = []; markedExams = []; markedImportant = []; syllabuses = [:]; saveToCloud(data: grades, key: gradesKey); saveToCloud(data: absencesDates, key: absencesKey); saveToCloud(data: customNotes, key: notesKey); saveToCloud(data: customRooms, key: roomsKey); saveToCloud(data: cancelledEvents, key: cancelledKey); saveToCloud(data: markedExams, key: markedExamsKey); saveToCloud(data: markedImportant, key: markedImportantKey); saveToCloud(data: syllabuses, key: syllabusesKey); objectWillChange.send(); exportWidgetData() }
    func deleteArchive(at offsets: IndexSet) { archives.remove(atOffsets: offsets); saveToCloud(data: archives, key: archivesKey); objectWillChange.send() }
    
    func hasExam(on date: Date) -> Bool { return filteredEvents(forDate: date, mode: .myPlan, searchText: "").contains { markedExams.contains($0.id) || $0.category == .exam } }
    func hasImportant(on date: Date) -> Bool { return filteredEvents(forDate: date, mode: .myPlan, searchText: "").contains { markedImportant.contains($0.id) } }
    func hasNote(on date: Date) -> Bool { return filteredEvents(forDate: date, mode: .myPlan, searchText: "").contains { customNotes[$0.id] != nil && !customNotes[$0.id]!.isEmpty } }
    
    func lecturers(for subject: String) -> String { return Set(allEvents.filter { $0.title == subject && !$0.isUserCreated && $0.lecturer != "Nieznany" }.map { $0.lecturer }).joined(separator: ", ") }
    func lecturer(for subject: String, type: String) -> String { return Set(allEvents.filter { $0.title == subject && $0.classType?.rawValue == type && !$0.isUserCreated && $0.lecturer != "Nieznany" }.map { $0.lecturer }).joined(separator: ", ") }
    func saveSyllabus(for subject: String, type: String, text: String) { if syllabuses[subject] == nil { syllabuses[subject] = [:] }; if text.isEmpty { syllabuses[subject]?.removeValue(forKey: type) } else { syllabuses[subject]?[type] = text }; if syllabuses[subject]?.isEmpty == true { syllabuses.removeValue(forKey: subject) }; saveToCloud(data: syllabuses, key: syllabusesKey); objectWillChange.send() }
    var subjectTypes: [(String, [ClassType])] { var dict: [String: Set<ClassType>] = [:]; for event in allEvents where !event.isUserCreated { if let type = event.classType { dict[event.title, default: []].insert(type) } }; return dict.map { ($0.key, Array($0.value).sorted { $0.rawValue < $1.rawValue }) }.sorted { $0.0 < $1.0 } }
    var uniqueSubjects: [String] { Array(Set(allEvents.filter { !$0.isUserCreated }.map { $0.title })).sorted() }
    func totalClassesCount(for subject: String, type: String) -> Int { return allEvents.filter { event in guard event.title == subject, event.classType?.rawValue == type else { return false }; if let gr = event.group { if gr == "W" { return true }; let isJava = event.title.lowercased().contains("java"); if isJava { if event.classType == .labK && gr != "Lk\(selectedJavaGroup)" { return false }; if event.classType == .proj && gr != "P\(selectedJavaGroup)" { return false }; if event.classType == .lab && gr != selectedLabGroup { return false } } else { if event.classType == .lab && gr != selectedLabGroup { return false }; if event.classType == .proj && gr != selectedProjGroup { return false }; if event.classType == .labK && gr != selectedKompGroup { return false }; if event.classType == .lek && gr != selectedLangGroup { return false } } }; return true }.count }
    var totalAttendanceStats: (total: Int, absences: Int, percentage: Double) { var t = 0; var a = 0; for subject in uniqueSubjects { for type in subjectTypes.first(where: { $0.0 == subject })?.1 ?? [] { t += totalClassesCount(for: subject, type: type.rawValue); a += absencesDates[subject]?[type.rawValue]?.count ?? 0 } }; let pct = t > 0 ? Double(t - a) / Double(t) * 100.0 : 100.0; return (t, a, pct) }
    func addAbsence(for subject: String, type: String, date: Date, note: String) { if absencesDates[subject] == nil { absencesDates[subject] = [:] }; var currentDates = absencesDates[subject]?[type] ?? []; currentDates.append(AbsenceRecord(date: date, note: note)); currentDates.sort(by: { $0.date > $1.date }); absencesDates[subject]?[type] = currentDates; saveToCloud(data: absencesDates, key: absencesKey); objectWillChange.send() }
    func removeAbsence(for subject: String, type: String, at index: Int) { absencesDates[subject]?[type]?.remove(at: index); if absencesDates[subject]?[type]?.isEmpty == true { absencesDates[subject]?.removeValue(forKey: type) }; if absencesDates[subject]?.isEmpty == true { absencesDates.removeValue(forKey: subject) }; saveToCloud(data: absencesDates, key: absencesKey); objectWillChange.send() }
    func updateAbsenceLimit(for subject: String, type: String, limit: Int) { if absenceLimits[subject] == nil { absenceLimits[subject] = [:] }; if limit <= 0 { absenceLimits[subject]?.removeValue(forKey: type); if absenceLimits[subject]?.isEmpty == true { absenceLimits.removeValue(forKey: subject) } } else { absenceLimits[subject]?[type] = limit }; saveToCloud(data: absenceLimits, key: limitsKey); objectWillChange.send() }
    
    private func loadUserEvents() -> [AppEvent] { return loadFromCloud(key: userEventsKey, type: [AppEvent].self) ?? [] }
    func addUserEvent(_ event: AppEvent) { var current = loadFromCloud(key: userEventsKey, type: [AppEvent].self) ?? []; current.append(event); saveToCloud(data: current, key: userEventsKey); loadData() }
    func deleteUserEvent(id: String) { var current = loadFromCloud(key: userEventsKey, type: [AppEvent].self) ?? []; current.removeAll { $0.id == id }; saveToCloud(data: current, key: userEventsKey); loadData() }
    
    func requestNotificationPermission() { UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in if granted { DispatchQueue.main.async { self.scheduleNotifications(); self.scheduleMorningBriefings() } } } }
    
    private func scheduleNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allEvents.map { $0.id })
        let now = Date()
        let upcoming = filteredEvents(forDate: nil, mode: .myPlan, searchText: "").filter { $0.startTime > now && !cancelledEvents.contains($0.id) }
        
        for event in upcoming.prefix(50) {
            let content = UNMutableNotificationContent()
            if event.isUserCreated {
                let catName = event.customCategory?.uppercased() ?? event.category?.rawValue.uppercased() ?? "INNE"
                content.title = "WŁASNE | \(catName) | \(event.title.uppercased())"
            } else {
                let typeName = event.classType?.rawValue.uppercased() ?? "INNE"
                content.title = "ZAJĘCIA | \(typeName) | \(event.title.uppercased())"
            }
            content.body = "Zaczynają się za 30 min w sali \(event.room)"
            content.sound = .default
            
            let triggerDate = event.startTime.addingTimeInterval(-30 * 60)
            if triggerDate > now {
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: event.id, content: content, trigger: trigger))
            }
        }
    }
    
    private func scheduleMorningBriefings() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: (0..<7).map { "briefing_\($0)" }); let calendar = Calendar.current; let now = Date(); for i in 0..<7 { guard let date = calendar.date(byAdding: .day, value: i, to: now), let targetDate = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: date) else { continue }; if targetDate < now { continue }; let dayEvents = filteredEvents(forDate: date, mode: .myPlan, searchText: "").filter { !cancelledEvents.contains($0.id) }; let content = UNMutableNotificationContent(); content.sound = .default; if dayEvents.isEmpty { content.title = "Dzień Dobry! ☀️"; content.body = "Śpij spokojnie, dzisiaj masz całkowicie wolne." } else { let first = dayEvents.first!; let last = dayEvents.last!; let f = DateFormatter(); f.dateFormat = "HH:mm"; content.title = "Plan na dziś: \(dayEvents.count) zajęć 🎓"; content.body = "Zaczynasz o \(f.string(from: first.startTime)), a kończysz o \(f.string(from: last.endTime)). Powodzenia!" }; let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate); let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false); UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "briefing_\(i)", content: content, trigger: trigger)) } }
    
    enum ViewMode { case myPlan, fullPlan }
    
    func filteredEvents(forDate date: Date?, mode: ViewMode, searchText: String) -> [AppEvent] {
        let calendar = Calendar.current
        return allEvents.filter { event in
            if let targetDate = date, !calendar.isDate(event.date, inSameDayAs: targetDate) { return false }
            if !showLectures && (event.classType == .wyklad || event.group == "W") { return false }
            
            if !searchText.isEmpty { let search = searchText.lowercased(); if !event.title.lowercased().contains(search) && !event.lecturer.lowercased().contains(search) && !event.room.lowercased().contains(search) { return false } }
            if event.isUserCreated { return true }; if mode == .fullPlan { return true }
            if let type = event.classType, let gr = event.group {
                if gr == "W" { return true }; let isJava = event.title.lowercased().contains("java")
                if isJava { if type == .labK && gr != "Lk\(selectedJavaGroup)" { return false }; if type == .proj && gr != "P\(selectedJavaGroup)" { return false }; if type == .lab && gr != selectedLabGroup { return false } }
                else { if type == .lab && gr != selectedLabGroup { return false }; if type == .proj && gr != selectedProjGroup { return false }; if type == .labK && gr != selectedKompGroup { return false }; if type == .lek && gr != selectedLangGroup { return false } }
            }
            return true
        }.map { event in
            var updatedEvent = event
            if let customRoom = customRooms[event.id] { updatedEvent.room = customRoom }
            if let customTime = customTimes[event.id] {
                updatedEvent.startTime = customTime.startTime
                updatedEvent.endTime = customTime.endTime
            }
            return updatedEvent
        }
    }
    
    func getWeekEvents(for date: Date, mode: ViewMode, searchText: String) -> [Date: [AppEvent]] {
        let calendar = Calendar.current
        let monday = date.getMonday()
        var weekDict: [Date: [AppEvent]] = [:]
        
        for i in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: i, to: monday) {
                let dailyEvents = filteredEvents(forDate: day, mode: mode, searchText: searchText)
                if !dailyEvents.isEmpty {
                    let startOfDay = calendar.startOfDay(for: day)
                    weekDict[startOfDay] = dailyEvents
                }
            }
        }
        return weekDict
    }
  
    func manageLiveActivity() {
        if !enableLiveActivities {
            for activity in Activity<LiveClassAttributes>.activities {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }
        
        let now = Date()
        let myEvents = filteredEvents(forDate: now, mode: .myPlan, searchText: "")
        let currentEvent = myEvents.first(where: { $0.isHappeningNow(at: now) && !cancelledEvents.contains($0.id) })
        
        let contentState = LiveClassAttributes.ContentState()
        let activityContent = ActivityContent(state: contentState, staleDate: nil)
        
        for activity in Activity<LiveClassAttributes>.activities {
            if now >= activity.attributes.endTime {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
                continue
            }
            if currentEvent == nil || activity.attributes.className != currentEvent?.title {
                Task { await activity.end(activityContent, dismissalPolicy: .immediate) }
            }
        }
        
        if let event = currentEvent {
            if Activity<LiveClassAttributes>.activities.contains(where: { $0.attributes.className == event.title }) { return }
            let typeName = event.classType?.rawValue ?? "Inne"
            let attributes = LiveClassAttributes(className: event.title, room: event.room, startTime: event.startTime, endTime: event.endTime, typeName: typeName)
            do { _ = try Activity.request(attributes: attributes, content: activityContent, pushType: nil) }
            catch { print("Błąd Live Activity: \(error.localizedDescription)") }
        }
    }
        
    func updateEventTime(for eventId: String, newStart: Date, newEnd: Date) {
        customTimes[eventId] = CustomTimeInfo(startTime: newStart, endTime: newEnd)
        saveToCloud(data: customTimes, key: customTimesKey)
        WidgetCenter.shared.reloadAllTimelines()
        manageLiveActivity()
    }
    
    func resetEventTime(for eventId: String) {
        customTimes.removeValue(forKey: eventId)
        saveToCloud(data: customTimes, key: customTimesKey)
        WidgetCenter.shared.reloadAllTimelines()
        manageLiveActivity()
    }
}
