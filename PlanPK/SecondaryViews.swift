import SwiftUI
import UIKit
import WidgetKit
import Combine
import UniformTypeIdentifiers

func playHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            self.data = data
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

struct EnhancedEventCard: View {
    let event: AppEvent
    let currentTime: Date
    var note: String?
    var isCancelled: Bool = false
    
    @ObservedObject var manager: DataManager
    @Environment(\.colorScheme) var colorScheme
    
    var cardColor: Color {
        if let cat = event.category { return cat.color }
        return event.classType?.color ?? .gray
    }
    
    var iconName: String {
        if event.isUserCreated { return "star.fill" }
        return event.classType?.icon ?? "calendar"
    }
    
    var isNow: Bool {
        !isCancelled && event.isHappeningNow(at: currentTime)
    }
    
    var isExam: Bool {
        manager.markedExams.contains(event.id) || event.category == .exam
    }
    
    var isImportant: Bool {
        manager.markedImportant.contains(event.id)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(event.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isCancelled ? .gray : (isNow ? .red : .primary))
                Text(event.endTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(isCancelled ? .gray.opacity(0.5) : .secondary)
                if !isCancelled {
                    Text(event.durationString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
            }
            .frame(width: 55)
            .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .strikethrough(isCancelled)
                        .lineLimit(2)
                    Spacer()
                    if isCancelled {
                        Text("ODWOŁANE")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    } else if isExam {
                        Text("🚨 KOLOKWIUM")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .shadow(color: .red.opacity(0.4), radius: 3)
                    } else if isImportant {
                        Text("⭐ WAŻNE")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.9))
                            .foregroundColor(.black)
                            .cornerRadius(6)
                            .shadow(color: .yellow.opacity(0.4), radius: 3)
                    } else if isNow {
                        Text("TERAZ")
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .shadow(color: .red.opacity(0.4), radius: 3)
                    } else {
                        Image(systemName: iconName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(cardColor)
                            .clipShape(Circle())
                    }
                }
                
                HStack {
                    Label(event.room, systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let gr = event.group {
                        Text(gr)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(6)
                    } else if event.isUserCreated {
                        let catText = event.customCategory ?? event.category?.rawValue ?? "Inne"
                        Text(catText.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(cardColor.opacity(0.15))
                            .foregroundColor(cardColor)
                            .cornerRadius(6)
                    }
                }
                
                HStack {
                    Image(systemName: "person.fill").font(.caption2)
                    Text(event.lecturer).font(.caption).lineLimit(1)
                }
                .foregroundColor(.secondary)
                
                if !isCancelled {
                    if let n = note, !n.isEmpty {
                        HStack(alignment: .top) {
                            Image(systemName: "pencil.line")
                                .font(.caption)
                                .foregroundColor(cardColor)
                            Text(n)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .italic()
                        }
                        .padding(8)
                        .background(cardColor.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.top, 4)
                    }
                    if isNow {
                        VStack(alignment: .trailing, spacing: 4) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.red.opacity(0.15))
                                    Capsule().fill(Color.red).frame(width: geo.size.width * CGFloat(event.progress(at: currentTime)))
                                }
                            }
                            .frame(height: 6)
                            
                            Text(event.timeLeftString(at: currentTime))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : (isNow ? 0.15 : 0.08)), radius: isNow ? 8 : 4, x: 0, y: isNow ? 4 : 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isExam ? Color.red : (isImportant ? Color.yellow.opacity(0.8) : (isNow ? Color.red.opacity(0.8) : (isCancelled ? Color.gray.opacity(0.4) : Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.05)))), lineWidth: isExam || isImportant ? 3 : (isNow ? 2 : 1))
            )
            .opacity(isCancelled ? 0.6 : 1.0)
        }
        .contextMenu {
            if !event.isUserCreated {
                Button(action: {
                    playHaptic(style: .medium)
                    manager.toggleCancel(for: event.id)
                }) {
                    Label(isCancelled ? "Przywróć zajęcia" : "Odwołaj zajęcia", systemImage: isCancelled ? "arrow.uturn.backward" : "nosign")
                }
            }
            if event.isUserCreated {
                Button(role: .destructive, action: {
                    playHaptic(style: .heavy)
                    manager.deleteUserEvent(id: event.id)
                }) {
                    Label("Usuń wydarzenie", systemImage: "trash")
                }
            }
        }
        .id(event.id)
    }
}

struct CalendarStrip: View {
    @Binding var selectedDate: Date
    var themeColor: Color
    @ObservedObject var manager: DataManager
    @Environment(\.colorScheme) var colorScheme
    
    var days: [Date] {
        (-2...2).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: selectedDate) }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { date in
                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                Button(action: {
                    playHaptic()
                    withAnimation { selectedDate = date }
                }) {
                    VStack(spacing: 2) {
                        Text(formatDay(date))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isSelected ? .white : .secondary)
                        Text(date.formatted(.dateTime.day()))
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(isSelected ? .white : .primary)
                        
                        HStack(spacing: 3) {
                            if manager.hasExam(on: date) {
                                Circle().fill(isSelected ? .white : .red).frame(width: 4, height: 4)
                            } else if manager.hasImportant(on: date) {
                                Circle().fill(isSelected ? .white : .yellow).frame(width: 4, height: 4)
                            }
                            if manager.hasNote(on: date) {
                                Circle().fill(isSelected ? .white.opacity(0.7) : themeColor).frame(width: 4, height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 2)
                    }
                    .frame(width: 50, height: 70)
                    .background(isSelected ? themeColor : Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                    .shadow(color: isSelected ? themeColor.opacity(0.3) : Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 4, x: 0, y: 2)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                }
            }
        }
    }
    
    func formatDay(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.locale = Locale(identifier: "pl_PL")
        return f.string(from: d).uppercased()
    }
}

struct EmptyStateView: View {
    let mode: Int
    let isSearching: Bool
    let themeColor: Color
    
    let randomTexts = ["Odpłyń. Masz wolne.", "Czas na CS'a.", "Idź na piwo 🍻", "Odpalaj Netflixa.", "Śpij spokojnie."]
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: isSearching ? "magnifyingglass" : "cup.and.saucer.fill")
                .font(.system(size: 70))
                .foregroundColor(themeColor.opacity(0.5))
                .padding(.bottom, 10)
            
            Text(isSearching ? "Brak wyników" : "Wolne!")
                .font(.title2)
                .fontWeight(.bold)
            
            if isSearching {
                Text("Nic tu nie pasuje.").foregroundColor(.secondary)
            } else if mode == 0 {
                Text(randomTexts.randomElement()!).foregroundColor(.secondary)
            } else {
                Text("Brak zajęć na uczelni.").foregroundColor(.secondary)
            }
        }
    }
}

struct EventDetailView: View {
    @State private var showEditTime = false
    @ObservedObject var manager: DataManager
    let event: AppEvent
    @State private var noteText: String = ""
    @State private var roomText: String = ""
    @Environment(\.dismiss) var dismiss
    
    var isCancelled: Bool { manager.cancelledEvents.contains(event.id) }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Zajęcia 🎓")) {
                    Text(event.title).font(.headline)
                    Text(event.startTime.formatted(date: .abbreviated, time: .shortened)).foregroundColor(.secondary)
                }
                
                Section(header: Text("Zmień salę (opcjonalnie) 📍")) {
                    TextField("Wpisz nową salę...", text: $roomText)
                }
                Button(action: { showEditTime = true }) {
                    HStack {
                        Image(systemName: "clock.arrow.2.circlepath")
                        Text("Zmień godziny zajęć")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .sheet(isPresented: $showEditTime) {
                    EditTimeView(manager: manager, event: event)
                }
                
                Section(header: Text("Oznaczenia specjalne 🏷️")) {
                    Toggle(isOn: Binding(
                        get: { manager.markedExams.contains(event.id) },
                        set: { _ in playHaptic(); manager.toggleExam(for: event.id, event: event) }
                    )) {
                        Text("🚨 Kolokwium").bold()
                    }
                    
                    Toggle(isOn: Binding(
                        get: { manager.markedImportant.contains(event.id) },
                        set: { _ in playHaptic(); manager.toggleImportant(for: event.id, event: event) }
                    )) {
                        Text("⭐ Ważne").bold()
                    }
                }
                
                Section(header: Text("Twoja Notatka 📝")) {
                    TextEditor(text: $noteText).frame(height: 100)
                }
            }
            .navigationTitle("Szczegóły")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zapisz") {
                        manager.saveNote(for: event.id, note: noteText)
                        manager.saveRoom(for: event.id, room: roomText)
                        dismiss()
                    }.bold()
                }
            }
            .onAppear {
                noteText = manager.customNotes[event.id] ?? ""
                roomText = manager.customRooms[event.id] ?? event.room
            }
        }
    }
}

struct AddEventView: View {
    @ObservedObject var manager: DataManager
    var defaultDate: Date
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var lecturer = ""
    @State private var room = ""
    @State private var category: EventCategory = .other
    @State private var customCategoryName = ""
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var specialTag: Int = 0
    @State private var reminderPreset: Int = 30
    
    init(manager: DataManager, defaultDate: Date) {
        self.manager = manager
        self.defaultDate = defaultDate
        _date = State(initialValue: defaultDate)
        _startTime = State(initialValue: Date())
        _endTime = State(initialValue: Date().addingTimeInterval(5400))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Co dodajemy? 📝")) {
                    TextField("Nazwa", text: $title)
                    Picker("Kategoria", selection: $category) {
                        ForEach(EventCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    if category == .other {
                        TextField("Wpisz własną kategorię...", text: $customCategoryName)
                    }
                }
                Section(header: Text("Kiedy? ⏰")) {
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                    DatePicker("Rozpoczęcie", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Zakończenie", selection: $endTime, displayedComponents: .hourAndMinute)
                    TextField("Sala", text: $room)
                }
                Section(header: Text("Opcje ⚙️")) {
                    Picker("Oznaczenie", selection: $specialTag) {
                        Text("Brak").tag(0)
                        Text("⭐ Ważne").tag(1)
                        Text("🚨 Kolokwium").tag(2)
                    }.pickerStyle(.segmented)
                    
                    Picker("Powiadomienia", selection: $reminderPreset) {
                        Text("Brak").tag(0)
                        Text("Tylko 30 min przed").tag(30)
                        Text("Dzień wcześniej i 30 min przed").tag(1)
                        Text("Tydzień, dzień i 30 min przed").tag(2)
                    }
                }
                Section(header: Text("Info ℹ️")) {
                    TextField("Notatka", text: $lecturer)
                }
            }
            .navigationTitle("Nowe wydarzenie")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zapisz") {
                        playHaptic(style: .medium)
                        let finalStart = combineDateAndTime(date, startTime)
                        let finalEnd = combineDateAndTime(date, endTime)
                        
                        var customRemindersList: [Int] = []
                        switch reminderPreset {
                        case 30: customRemindersList = [30]
                        case 1: customRemindersList = [1440, 30]
                        case 2: customRemindersList = [10080, 1440, 30]
                        default: customRemindersList = []
                        }
                        
                        let newEvent = AppEvent(
                            id: UUID().uuidString,
                            title: title.isEmpty ? "Wydarzenie" : title,
                            lecturer: lecturer.isEmpty ? "Własne" : lecturer,
                            room: room.isEmpty ? "-" : room,
                            date: date,
                            startTime: finalStart,
                            endTime: finalEnd,
                            category: category,
                            classType: nil,
                            group: nil,
                            isUserCreated: true,
                            customCategory: category == .other && !customCategoryName.isEmpty ? customCategoryName : nil,
                            customReminders: customRemindersList
                        )
                        manager.addUserEvent(newEvent)
                        
                        if specialTag == 1 { manager.toggleImportant(for: newEvent.id, event: newEvent) }
                        else if specialTag == 2 { manager.toggleExam(for: newEvent.id, event: newEvent) }
                        
                        dismiss()
                    }.disabled(title.isEmpty)
                }
            }
        }
    }
    
    func combineDateAndTime(_ d: Date, _ t: Date) -> Date {
        let c = Calendar.current
        let tc = c.dateComponents([.hour, .minute], from: t)
        return c.date(bySettingHour: tc.hour!, minute: tc.minute!, second: 0, of: d) ?? d
    }
}

struct SyllabusView: View {
    @ObservedObject var manager: DataManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if manager.uniqueSubjects.isEmpty {
                    Text("Brak wczytanych przedmiotów z kalendarza.")
                }
                ForEach(manager.uniqueSubjects, id: \.self) { subject in
                    NavigationLink(destination: SyllabusDetailView(manager: manager, subject: subject, types: manager.subjectTypes.first(where: { $0.0 == subject })?.1 ?? [])) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(subject).font(.subheadline).bold()
                                Spacer()
                                if manager.syllabuses[subject] != nil && !manager.syllabuses[subject]!.isEmpty {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                }
                            }
                            let lects = manager.lecturers(for: subject)
                            if !lects.isEmpty {
                                Text("👨‍🏫 " + lects).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Zasady Zaliczenia 📖")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
        }
    }
}

struct SyllabusDetailView: View {
    @ObservedObject var manager: DataManager
    let subject: String
    let types: [ClassType]
    
    var body: some View {
        Form {
            ForEach(types, id: \.rawValue) { type in
                let lect = manager.lecturer(for: subject, type: type.rawValue)
                Section(header: Text("Warunki: \(type.fullName)"), footer: Text(lect.isEmpty ? "" : "👨‍🏫 Prowadzący: \(lect)")) {
                    TextField("Wpisz warunki...", text: Binding(
                        get: { manager.syllabuses[subject]?[type.rawValue] ?? "" },
                        set: { manager.saveSyllabus(for: subject, type: type.rawValue, text: $0) }
                    ), axis: .vertical)
                    .lineLimit(3...15)
                }
            }
        }.navigationTitle("Zasady Zaliczenia")
    }
}

struct AbsencesView: View {
    @ObservedObject var manager: DataManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Podsumowanie Semestru 📊")) {
                    let stats = manager.totalAttendanceStats
                    HStack {
                        Text("Ogólna frekwencja:").font(.headline)
                        Spacer()
                        Text("\(Int(stats.percentage))%").font(.title).bold()
                            .foregroundColor(stats.percentage < 50 ? .red : (stats.percentage < 75 ? .orange : .green))
                    }
                    Text("Wykorzystane losówki: \(stats.absences) z \(stats.total) wszystkich zajęć")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Twoje Przedmioty 📚")) {
                    if manager.uniqueSubjects.isEmpty {
                        Text("Brak wczytanych z kalendarza.")
                    } else {
                        ForEach(manager.uniqueSubjects, id: \.self) { item in
                            NavigationLink(destination: AbsenceDetailView(manager: manager, subject: item, types: manager.subjectTypes.first(where: { $0.0 == item })?.1 ?? [])) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item).font(.subheadline).bold().lineLimit(2)
                                    HStack {
                                        let activeTypes = (manager.subjectTypes.first(where: { $0.0 == item })?.1 ?? []).filter { (manager.absencesDates[item]?[$0.rawValue]?.count ?? 0) > 0 }
                                        
                                        if activeTypes.isEmpty {
                                            Text("Wzorowa frekwencja 🌟").font(.caption).foregroundColor(.secondary)
                                        } else {
                                            ForEach(activeTypes, id: \.rawValue) { type in
                                                let dates = manager.absencesDates[item]?[type.rawValue] ?? []
                                                let limit = manager.absenceLimits[item]?[type.rawValue] ?? 0
                                                let limitStr = limit > 0 ? "/\(limit)" : ""
                                                let total = manager.totalClassesCount(for: item, type: type.rawValue)
                                                let ratio = total > 0 ? Int((Double(total - dates.count) / Double(total)) * 100) : 100
                                                
                                                Text("\(type.rawValue): \(dates.count)\(limitStr)")
                                                    .font(.caption).bold()
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background((ratio < 50 ? Color.red : (ratio < 75 ? Color.orange : Color.green)).opacity(0.2))
                                                    .foregroundColor(ratio < 50 ? .red : (ratio < 75 ? .orange : .green))
                                                    .cornerRadius(4)
                                            }
                                        }
                                    }
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Losówki 🏃‍♂️")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Zamknij") { dismiss() } }
            }
        }
    }
}

struct AbsenceDetailView: View {
    @ObservedObject var manager: DataManager
    let subject: String
    let types: [ClassType]
    
    @State private var selectedDate = Date()
    @State private var selectedType: ClassType? = nil
    @State private var withNote = false
    @State private var noteText = ""
    
    var body: some View {
        Form {
            Section(header: Text("Wykorzystaj Losówkę 🏃‍♂️")) {
                Picker("Typ zajęć", selection: $selectedType) {
                    Text("Wybierz...").tag(ClassType?.none)
                    ForEach(types, id: \.self) { t in Text(t.fullName).tag(ClassType?.some(t)) }
                }
                DatePicker("Data", selection: $selectedDate, displayedComponents: .date)
                Toggle("Dodaj notatkę (opcjonalnie)", isOn: $withNote)
                if withNote { TextField("Powód (np. zaspałem)", text: $noteText) }
                Button("Wykorzystaj") {
                    if let t = selectedType {
                        playHaptic()
                        manager.addAbsence(for: subject, type: t.rawValue, date: selectedDate, note: withNote ? noteText : "")
                        noteText = ""
                        withNote = false
                    }
                }
                .disabled(selectedType == nil)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .center)
                .bold()
            }
            
            ForEach(types, id: \.rawValue) { type in
                let records = manager.absencesDates[subject]?[type.rawValue] ?? []
                let total = manager.totalClassesCount(for: subject, type: type.rawValue)
                let attendance = total > 0 ? Double(total - records.count) / Double(total) * 100 : 100.0
                
                Section(header: Text("\(type.fullName) - Frekwencja: \(Int(attendance))%")) {
                    if records.isEmpty {
                        Text("Wzorowy uczeń! 0 nieobecności.")
                    } else {
                        ForEach(0..<records.count, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Losówka - \(records[i].date.formatted(date: .long, time: .omitted))")
                                if !records[i].note.isEmpty {
                                    Text("📝 \(records[i].note)").font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }.onDelete { idx in
                            for i in idx { manager.removeAbsence(for: subject, type: type.rawValue, at: i) }
                        }
                    }
                }
            }
            
            Section(header: Text("Limity losówek 🛡️"), footer: Text("Ustaw ile maksymalnie możesz opuścić zajęć, aby apka pokazywała np. L: 1/2.")) {
                ForEach(types, id: \.rawValue) { type in
                    HStack {
                        Text(type.fullName)
                        Spacer()
                        let currentLimit = manager.absenceLimits[subject]?[type.rawValue] ?? 0
                        Stepper(currentLimit == 0 ? "Brak limitu" : "Limit: \(currentLimit)", value: Binding(
                            get: { currentLimit },
                            set: { manager.updateAbsenceLimit(for: subject, type: type.rawValue, limit: $0) }
                        ), in: 0...10)
                    }
                }
            }
        }.navigationTitle("Detale Frekwencji")
    }
}

struct GradesView: View {
    @ObservedObject var manager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @State private var newGradeValue: Double = 3.0
    @State private var newGradeType: GradeType = .kolokwium
    @State private var newGradeDate: Date = Date()
    @State private var customGradeName = ""
    
    let possibleValues = [2.0, 3.0, 3.5, 4.0, 4.5, 5.0]

    var totalAverage: Double {
        let allGrades = manager.grades.values.flatMap { $0 }.map { $0.value }
        if allGrades.isEmpty { return 0.0 }
        return allGrades.reduce(0, +) / Double(allGrades.count)
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Podsumowanie Semestru 📊")) {
                    HStack {
                        Text("Średnia Ogólna:").font(.headline)
                        Spacer()
                        Text(String(format: "%.2f", totalAverage)).font(.title).bold()
                            .foregroundColor(totalAverage >= 4.5 ? .green : (totalAverage >= 3.0 ? .blue : .red))
                    }
                }
                Section(header: Text("Twoje Przedmioty 📚")) {
                    if manager.uniqueSubjects.isEmpty {
                        Text("Brak wczytanych przedmiotów.")
                    } else {
                        ForEach(manager.uniqueSubjects, id: \.self) { subject in
                            let subjectGrades = manager.grades[subject] ?? []
                            let avg = subjectGrades.isEmpty ? 0.0 : subjectGrades.map{$0.value}.reduce(0, +) / Double(subjectGrades.count)
                            NavigationLink(destination: subjectGradeDetail(for: subject)) {
                                HStack {
                                    Text(subject).font(.subheadline).lineLimit(2)
                                    Spacer()
                                    if !subjectGrades.isEmpty {
                                        Text(String(format: "%.2f", avg))
                                            .bold()
                                            .padding(6)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Oceny 🎓")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Zamknij") { dismiss() } } }
        }
    }
    
    @ViewBuilder func subjectGradeDetail(for subject: String) -> some View {
        Form {
            Section(header: Text("Dodaj Ocenę ➕")) {
                Picker("Typ Oceny", selection: $newGradeType) {
                    ForEach(GradeType.allCases, id: \.self) { t in Text(t.rawValue).tag(t) }
                }
                
                if newGradeType == .inna {
                    TextField("Wpisz nazwę (np. Aktywność)", text: $customGradeName)
                }
                
                Picker("Ocena", selection: $newGradeValue) {
                    ForEach(possibleValues, id: \.self) { g in Text(String(format: "%.1f", g)).tag(g) }
                }.pickerStyle(.segmented)
                
                DatePicker("Data", selection: $newGradeDate, displayedComponents: .date)
                
                Button(action: {
                    playHaptic()
                    let entry = GradeEntry(value: newGradeValue, type: newGradeType, date: newGradeDate, customName: newGradeType == .inna ? customGradeName : nil)
                    manager.addGrade(for: subject, entry: entry)
                }) {
                    HStack { Spacer(); Text("Zapisz Ocenę").bold(); Spacer() }
                }.foregroundColor(.blue).disabled(newGradeType == .inna && customGradeName.isEmpty)
            }
            
            Section(header: Text("Historia Ocen 📜")) {
                let sGrades = manager.grades[subject] ?? []
                if sGrades.isEmpty {
                    Text("Brak wpisanych ocen.")
                } else {
                    ForEach(0..<sGrades.count, id: \.self) { i in
                        let grade = sGrades[i]
                        HStack {
                            VStack(alignment: .leading) {
                                Text(grade.type == .inna ? (grade.customName?.isEmpty == false ? grade.customName! : "Inne") : grade.type.rawValue).font(.headline)
                                Text(grade.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%.1f", grade.value)).font(.title3).bold().foregroundColor(.blue)
                        }
                    }.onDelete { idxs in manager.deleteGrades(for: subject, at: idxs) }
                }
            }
        }.navigationTitle("Detale Ocen")
    }
}

struct SettingsView: View {
    @ObservedObject var manager: DataManager
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("selectedLabGroup") var selectedLabGroup: String = "L1"
    @AppStorage("selectedProjGroup") var selectedProjGroup: String = "P1"
    @AppStorage("selectedKompGroup") var selectedKompGroup: String = "Lk1"
    @AppStorage("selectedLangGroup") var selectedLangGroup: String = "Lek1"
    @AppStorage("selectedJavaGroup") var selectedJavaGroup: String = "1"
    @AppStorage("appTheme") var appThemeRaw: String = AppThemeConfig.blue.rawValue
    @AppStorage("enableLiveActivities") var enableLiveActivities: Bool = true
    @AppStorage("showLectures") var showLectures: Bool = true
    
    @State private var showArchivePrompt = false
    @State private var archiveName = "Semestr Zimowy 2025"
    
    @State private var showFileExporter = false
    @State private var backupDocument: BackupDocument = BackupDocument(data: Data())
    @State private var showFileImporter = false
    @State private var alertMessage = ""
    @State private var showAlertInfo = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Wygląd Aplikacji 🎨")) {
                    Picker("Tryb ekranu", selection: manager.$colorSchemeSetting) {
                        ForEach(AppColorScheme.allCases, id: \.rawValue) { sc in Text(sc.description).tag(sc.rawValue) }
                    }.pickerStyle(.segmented)
                    
                    Picker("Motyw", selection: $appThemeRaw) {
                        ForEach(AppThemeConfig.allCases, id: \.self) { theme in Text(theme.rawValue).tag(theme.rawValue) }
                    }.pickerStyle(.menu)
                }
                
                Section(header: Text("Wybierz swoje grupy 👥")) {
                    Picker("Laboratoria (L)", selection: $selectedLabGroup) { ForEach(["L1","L2","L3","L4","L5","L6"], id:\.self){t in Text(t).tag(t)} }
                    Picker("Projekty (P)", selection: $selectedProjGroup) { ForEach(["P1","P2","P3","P4"], id:\.self){t in Text(t).tag(t)} }
                    Picker("Komputery (Lk)", selection: $selectedKompGroup) { ForEach(["Lk1","Lk2","Lk3","Lk4"], id:\.self){t in Text(t).tag(t)} }
                    Picker("Angielski (Lek)", selection: $selectedLangGroup) { ForEach(["Lek1","Lek2","Lek3"], id:\.self){t in Text(t).tag(t)} }
                    
                    Toggle(isOn: $showLectures) {
                        HStack {
                            Image(systemName: "book.fill").foregroundColor(.orange)
                            Text("Pokazuj Wykłady (W)")
                        }
                    }
                    .tint(.orange)
                    .onChange(of: showLectures) { _ in
                        manager.objectWillChange.send()
                        manager.exportWidgetData()
                        manager.manageLiveActivity()
                    }
                }
                
                Section(header: Text("Wyjątek dla JAVA ☕️")) {
                    Picker("JAVA (Lk = P)", selection: $selectedJavaGroup) {
                        ForEach(["1","2","3","4"], id: \.self) { num in Text("Grupa \(num) (Lk\(num) / P\(num))").tag(num) }
                    }
                }
                
                Section(header: Text("Personalizacja i Bateria 🔋")) {
                    Toggle(isOn: $enableLiveActivities) {
                        HStack {
                            Image(systemName: "battery.100.bolt")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Live Activities")
                                    .font(.body)
                                Text("Dynamic Island i widget na ekranie blokady")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tint(.green)
                    .onChange(of: enableLiveActivities) { _ in
                        manager.manageLiveActivity()
                    }
                }
                
                Section(header: Text("Kalendarz Apple 📅"), footer: Text("Wyeksportuj swój nadchodzący plan lekcji do systemowego kalendarza.")) {
                    Button(action: {
                        playHaptic()
                        manager.exportToAppleCalendar()
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Aktualizuj w Kalendarzu iOS")
                        }
                    }.foregroundColor(.blue)
                    
                    Button(action: {
                        playHaptic(style: .heavy)
                        manager.removeFromAppleCalendar()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Usuń wyeksportowany plan")
                        }
                    }.foregroundColor(.red)
                    
                    if !manager.exportStatus.isEmpty {
                        Text(manager.exportStatus).font(.caption).bold().foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Zarządzanie Semestrem 📦"), footer: Text("Zakończenie semestru wyczyści obecne oceny i losówki, zapisując je w archiwum.")) {
                    NavigationLink("Archiwum Semestrów", destination: ArchivesListView(manager: manager))
                    Button("Zakończ obecny semestr") { showArchivePrompt = true }.foregroundColor(.red)
                }
                
                Section(header: Text("Kopia Zapasowa 💾"), footer: Text("Zapisz swoje oceny, notatki, ustawienia i dodane wydarzenia do pliku .json na swoim telefonie, iCloud lub wyślij znajomym.")) {
                    Button("Eksportuj dane do pliku") {
                        if let data = manager.generateBackupData() {
                            backupDocument = BackupDocument(data: data)
                            showFileExporter = true
                        }
                    }.foregroundColor(.blue)
                    
                    Button("Importuj dane z pliku") {
                        showFileImporter = true
                    }.foregroundColor(.orange)
                }
            }
            .navigationTitle("Ustawienia")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Gotowe") { manager.loadData(); dismiss() } }
            }
            .alert("Zakończ Semestr", isPresented: $showArchivePrompt) {
                TextField("Nazwa (np. Zimowy 25)", text: $archiveName)
                Button("Anuluj", role: .cancel) { }
                Button("Zarchiwizuj", role: .destructive) {
                    let allGrades = manager.grades.values.flatMap { $0 }.map { $0.value }
                    let avg = allGrades.isEmpty ? 0.0 : allGrades.reduce(0, +) / Double(allGrades.count)
                    manager.archiveSemester(name: archiveName, currentAverage: avg)
                }
            } message: { Text("Twoje oceny, nieobecności i notatki zostaną przeniesione do archiwum.") }
            .fileExporter(isPresented: $showFileExporter, document: backupDocument, contentType: .json, defaultFilename: "PlanPK_Backup") { result in
                switch result {
                case .success(_):
                    alertMessage = "Kopia zapasowa zapisana pomyślnie!"
                    showAlertInfo = true
                case .failure(let error):
                    alertMessage = "Błąd zapisu: \(error.localizedDescription)"
                    showAlertInfo = true
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    if url.startAccessingSecurityScopedResource() {
                        manager.restoreFromBackup(url: url)
                        url.stopAccessingSecurityScopedResource()
                        alertMessage = "Dane przywrócone pomyślnie!"
                        showAlertInfo = true
                    }
                case .failure(let error):
                    alertMessage = "Błąd importu: \(error.localizedDescription)"
                    showAlertInfo = true
                }
            }
            .alert("Informacja", isPresented: $showAlertInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

struct ArchivesListView: View {
    @ObservedObject var manager: DataManager
    var body: some View {
        List {
            if manager.archives.isEmpty { Text("Brak zarchiwizowanych semestrów.") }
            ForEach(manager.archives) { arch in
                NavigationLink(destination: ArchiveDetailView(archive: arch)) {
                    VStack(alignment: .leading) {
                        Text(arch.name).font(.headline)
                        Text("Średnia: \(String(format: "%.2f", arch.average))").font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }.onDelete { idx in manager.deleteArchive(at: idx) }
        }.navigationTitle("Archiwum 📦")
    }
}

struct ArchiveDetailView: View {
    let archive: SemesterArchive
    var body: some View {
        List {
            Section(header: Text("Średnia Ogólna 📊")) { Text(String(format: "%.2f", archive.average)).font(.title).bold() }
            Section(header: Text("Oceny z przedmiotów 📚")) {
                ForEach(Array(archive.grades.keys.sorted()), id: \.self) { subject in
                    let g = archive.grades[subject]!
                    let avg = g.isEmpty ? 0.0 : g.map{$0.value}.reduce(0,+) / Double(g.count)
                    VStack(alignment: .leading) {
                        HStack { Text(subject).bold(); Spacer(); Text(String(format: "%.2f", avg)).foregroundColor(.blue) }
                        Text("Ilość Ocen: \(g.count) | Użyte Losówki: \(archive.absences[subject]?.values.reduce(0, { $0 + $1.count }) ?? 0)").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }.navigationTitle(archive.name)
    }
}

struct ShareablePlanView: View {
    let date: Date; let events: [AppEvent]; let themeColor: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading) { Text("PlanPK").font(.title).bold().foregroundColor(themeColor); Text(date.formatted(date: .complete, time: .omitted)).font(.subheadline).foregroundColor(.gray) }
                Spacer()
            }.padding(.bottom, 10)
            if events.isEmpty { Text("Brak zajęć na dzisiaj. Czysty chill! 🍻").font(.headline) }
            else {
                ForEach(events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Text(event.startTime.formatted(date: .omitted, time: .shortened)).font(.headline).frame(width: 50, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title).font(.headline).lineLimit(2)
                            HStack(spacing: 6) { Text(event.classType?.rawValue ?? "Inne").font(.caption2).bold().padding(.horizontal, 6).padding(.vertical, 2).background((event.classType?.color ?? .gray).opacity(0.2)).foregroundColor(event.classType?.color ?? .gray).cornerRadius(4); Text("\(event.room) • \(event.lecturer)").font(.caption).foregroundColor(.gray) }
                        }
                    }
                    Divider()
                }
            }
        }.padding(20).background(Color.white).frame(width: 400)
    }
}

struct ShareableWeeklyPlanView: View {
    let date: Date; let weekEvents: [Date: [AppEvent]]; let themeColor: Color; let weekRangeText: String
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { VStack(alignment: .leading) { Text("PlanPK - Tydzień").font(.title).bold().foregroundColor(themeColor); Text(weekRangeText).font(.subheadline).foregroundColor(.gray) }; Spacer() }.padding(.bottom, 10)
            if weekEvents.isEmpty { Text("Brak zajęć w tym tygodniu! 🍻").font(.headline) }
            else {
                let sortedDays = weekEvents.keys.sorted()
                ForEach(sortedDays, id: \.self) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(formatDayHeader(day)).font(.headline).foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 4).background(themeColor).cornerRadius(6)
                        ForEach(weekEvents[day]!) { event in
                            HStack(alignment: .top, spacing: 10) {
                                Text(event.startTime.formatted(date: .omitted, time: .shortened)).font(.subheadline).bold().frame(width: 50, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title).font(.subheadline).bold().lineLimit(2)
                                    HStack(spacing: 6) { Text(event.classType?.rawValue ?? "Inne").font(.caption2).bold().padding(.horizontal, 6).padding(.vertical, 2).background((event.classType?.color ?? .gray).opacity(0.2)).foregroundColor(event.classType?.color ?? .gray).cornerRadius(4); Text("\(event.room) • \(event.lecturer)").font(.caption).foregroundColor(.gray) }
                                }
                            }
                        }
                        Divider()
                    }
                }
            }
        }.padding(20).background(Color.white).frame(width: 420)
    }
    
    func formatDayHeader(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "pl_PL"); f.dateFormat = "EEEE, d MMM"
        return f.string(from: date).uppercased()
    }
}

struct EditTimeView: View {
    @ObservedObject var manager: DataManager
    var event: AppEvent
    @Environment(\.dismiss) var dismiss
    
    @State private var newStartTime: Date
    @State private var newEndTime: Date
    
    init(manager: DataManager, event: AppEvent) {
        self.manager = manager
        self.event = event
        
        let currentStart = manager.customTimes[event.id]?.startTime ?? event.startTime
        let currentEnd = manager.customTimes[event.id]?.endTime ?? event.endTime
        
        _newStartTime = State(initialValue: currentStart)
        _newEndTime = State(initialValue: currentEnd)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Nowe godziny zajęć")) {
                    DatePicker("Rozpoczęcie", selection: $newStartTime, displayedComponents: .hourAndMinute)
                    DatePicker("Zakończenie", selection: $newEndTime, displayedComponents: .hourAndMinute)
                }
                
                Section(footer: Text("Zmiana godzin wpłynie tylko na te konkretne zajęcia w Twoim planie. Zaktualizuje również Widgety i Live Activities.")) {
                    Button(action: {
                        playHaptic(style: .medium)
                        manager.resetEventTime(for: event.id)
                        dismiss()
                    }) {
                        Text("Przywróć domyślne godziny")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Zmień czas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Anuluj") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zapisz") {
                        playHaptic(style: .medium)
                        let calendar = Calendar.current
                        let startComponents = calendar.dateComponents([.hour, .minute], from: newStartTime)
                        let endComponents = calendar.dateComponents([.hour, .minute], from: newEndTime)
                        
                        if let finalStart = calendar.date(bySettingHour: startComponents.hour!, minute: startComponents.minute!, second: 0, of: event.date),
                           let finalEnd = calendar.date(bySettingHour: endComponents.hour!, minute: endComponents.minute!, second: 0, of: event.date) {
                            
                            manager.updateEventTime(for: event.id, newStart: finalStart, newEnd: finalEnd)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
