import SwiftUI
import Combine

struct CustomPicker: View {
    @Binding var selection: Int
    var items: [String]
    var themeColor: Color
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { i in
                Text(items[i])
                    .font(.system(size: 13, weight: selection == i ? .bold : .medium))
                    .foregroundColor(selection == i ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selection == i ? themeColor : Color.clear)
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        playHaptic()
                        withAnimation(.easeInOut(duration: 0.2)) { selection = i }
                    }
            }
        }
        .padding(4)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct ContentView: View {
    @StateObject var dataManager = DataManager()
    
    @Environment(\.scenePhase) var scenePhase
    
    // ZMIANA: Dodano zmienną do sprawdzania, czy onboarding został już ukończony
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    
    @State private var selectedDate = Date()
    @State private var showSettings = false
    @State private var showCalendar = false
    @State private var showAddEvent = false
    @State private var showAbsences = false
    @State private var showGrades = false
    @State private var showSyllabus = false
    @State private var isSharing = false
    @State private var planMode: Int = 0
    @State private var displayMode: Int = 0
    @State private var isSearching = false
    @State private var searchText = ""
    @AppStorage("enableLiveActivities") var enableLiveActivities: Bool = true
    
    var preferredScheme: ColorScheme? {
        if dataManager.colorSchemeSetting == 1 { return .light }
        else if dataManager.colorSchemeSetting == 2 { return .dark }
        else { return nil }
    }
    
    var body: some View {
        // ZMIANA: Logika decydująca, co pokazać użytkownikowi
        if hasSeenOnboarding {
            mainAppView
        } else {
            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding, manager: dataManager)
                .preferredColorScheme(preferredScheme)
        }
    }
    
    // ZMIANA: Wydzieliłem Twój stary ContentView do osobnej zmiennej "mainAppView", żeby było czyściej
    var mainAppView: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                if displayMode == 1 {
                                    Text("Tydzień Roboczy").font(.caption).bold().foregroundColor(.secondary)
                                    Text(formatWeekRange(selectedDate)).font(.title2).fontWeight(.black)
                                } else {
                                    Text(getSmartDateSubHeader(selectedDate)).font(.caption).bold().foregroundColor(.secondary)
                                    Text(getSmartDateHeader(selectedDate)).font(.title2).fontWeight(.black)
                                }
                            }
                            Spacer()
                            Button(action: { playHaptic(); isSharing = true }) {
                                Image(systemName: "square.and.arrow.up").frame(width: 34, height: 34).foregroundColor(dataManager.theme.mainColor).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(Circle())
                            }
                            Button(action: { playHaptic(); withAnimation { isSearching.toggle(); searchText = "" } }) {
                                Image(systemName: "magnifyingglass").frame(width: 34, height: 34).foregroundColor(isSearching ? .white : dataManager.theme.mainColor).background(isSearching ? dataManager.theme.mainColor : Color(UIColor.secondarySystemGroupedBackground)).clipShape(Circle())
                            }
                            Button(action: { playHaptic(); showSettings = true }) {
                                Image(systemName: "gearshape.fill").frame(width: 34, height: 34).foregroundColor(dataManager.theme.mainColor).background(Color(UIColor.secondarySystemGroupedBackground)).clipShape(Circle())
                            }
                        }
                        
                        if isSearching {
                            HStack {
                                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                                TextField("Szukaj...", text: $searchText)
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
                                }
                            }
                            .padding(10)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                        }
                        
                        HStack(spacing: 15) {
                            CustomPicker(selection: $planMode, items: ["Mój Plan", "Pełny Plan"], themeColor: dataManager.theme.mainColor)
                            CustomPicker(selection: $displayMode, items: ["Dzień", "Tydzień"], themeColor: dataManager.theme.mainColor)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                    .zIndex(100)
                    
                    if displayMode == 0 {
                        DailyScheduleView(selectedDate: $selectedDate, planMode: $planMode, searchText: $searchText, manager: dataManager, showCalendar: $showCalendar)
                    } else {
                        WeeklyScheduleView(selectedDate: $selectedDate, planMode: $planMode, searchText: $searchText, manager: dataManager)
                    }
                }
                
                VStack {
                    Spacer()
                    HStack(spacing: 15) {
                        Button(action: { playHaptic(); showAbsences = true }) {
                            Image(systemName: "figure.run").font(.title3.weight(.bold)).foregroundColor(.white).frame(width: 50, height: 50).background(dataManager.theme.secondaryColor).clipShape(Circle()).shadow(color: dataManager.theme.secondaryColor.opacity(0.4), radius: 6, x: 0, y: 3)
                        }
                        Button(action: { playHaptic(); showGrades = true }) {
                            Image(systemName: "graduationcap.fill").font(.title3.weight(.bold)).foregroundColor(.white).frame(width: 50, height: 50).background(dataManager.theme.mainColor.opacity(0.75)).clipShape(Circle()).shadow(color: dataManager.theme.mainColor.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        Button(action: { playHaptic(); showSyllabus = true }) {
                            Image(systemName: "book.pages.fill").font(.title3.weight(.bold)).foregroundColor(.white).frame(width: 50, height: 50).background(dataManager.theme.mainColor).clipShape(Circle()).shadow(color: dataManager.theme.mainColor.opacity(0.4), radius: 6, x: 0, y: 3)
                        }
                        Spacer()
                        Button(action: { playHaptic(style: .rigid); showAddEvent.toggle() }) {
                            Image(systemName: "plus").font(.title.weight(.bold)).foregroundColor(.white).frame(width: 60, height: 60).background(dataManager.theme.mainColor).clipShape(Circle()).shadow(color: dataManager.theme.mainColor.opacity(0.5), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                    .background(Color(UIColor.systemBackground).shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -4))
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) { SettingsView(manager: dataManager) }
            .sheet(isPresented: $showAddEvent) { AddEventView(manager: dataManager, defaultDate: selectedDate) }
            .sheet(isPresented: $showAbsences) { AbsencesView(manager: dataManager) }
            .sheet(isPresented: $showGrades) { GradesView(manager: dataManager) }
            .sheet(isPresented: $showSyllabus) { SyllabusView(manager: dataManager) }
            .sheet(isPresented: $showCalendar) { DatePicker("Wybierz datę", selection: $selectedDate, displayedComponents: [.date]).datePickerStyle(.graphical).presentationDetents([.medium]).environment(\.locale, Locale(identifier: "pl_PL")) }
            .sheet(isPresented: $isSharing) {
                if let image = renderShareImage() { ShareSheet(items: [image]) } else { Text("Błąd generowania zdjęcia.") }
            }
        }
        .onAppear {
            dataManager.requestNotificationPermission()
            let now = Date()
            let todaysEvents = dataManager.filteredEvents(forDate: now, mode: .myPlan, searchText: "")
            if !todaysEvents.isEmpty && todaysEvents.allSatisfy({ $0.endTime < now }) {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            }
            dataManager.activityTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect().sink { _ in dataManager.manageLiveActivity() }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                dataManager.manageLiveActivity()
            }
        }
        .accentColor(dataManager.theme.mainColor)
        .preferredColorScheme(preferredScheme)
    }
    
    func getSmartDateHeader(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "DZISIAJ" }
        if cal.isDateInTomorrow(date) { return "JUTRO" }
        let f = DateFormatter(); f.dateFormat = "d MMMM"; f.locale = Locale(identifier: "pl_PL")
        return f.string(from: date).uppercased()
    }
    
    func getSmartDateSubHeader(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) || cal.isDateInTomorrow(date) {
            let f = DateFormatter(); f.dateFormat = "d MMMM, EEEE"; f.locale = Locale(identifier: "pl_PL")
            return f.string(from: date)
        }
        return date.formatted(.dateTime.year())
    }
    
    func formatWeekRange(_ date: Date) -> String {
        let monday = date.getMonday()
        let friday = Calendar.current.date(byAdding: .day, value: 4, to: monday)!
        let fMonth = DateFormatter(); fMonth.locale = Locale(identifier: "pl_PL"); fMonth.dateFormat = "MMMM"
        let fDay = DateFormatter(); fDay.locale = Locale(identifier: "pl_PL"); fDay.dateFormat = "d"
        let mMonth = fMonth.string(from: monday).uppercased()
        let sMonth = fMonth.string(from: friday).uppercased()
        if mMonth == sMonth { return "\(fDay.string(from: monday)) - \(fDay.string(from: friday)) \(mMonth)" }
        else { return "\(fDay.string(from: monday)) \(mMonth) - \(fDay.string(from: friday)) \(sMonth)" }
    }
    
    @MainActor func renderShareImage() -> UIImage? {
            if displayMode == 0 {
                let events = dataManager.filteredEvents(forDate: selectedDate, mode: (planMode == 0) ? .myPlan : .fullPlan, searchText: "")
                let view = ShareablePlanView(date: selectedDate, events: events, themeColor: dataManager.theme.mainColor)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 3.0
                return renderer.uiImage
            } else {
                let mode: DataManager.ViewMode = (planMode == 0) ? .myPlan : .fullPlan
                let weekEvents = dataManager.getWeekEvents(for: selectedDate, mode: mode, searchText: "")
                let view = ShareableWeeklyPlanView(date: selectedDate, weekEvents: weekEvents, themeColor: dataManager.theme.mainColor, weekRangeText: formatWeekRange(selectedDate))
                let renderer = ImageRenderer(content: view)
                renderer.scale = 3.0
                return renderer.uiImage
            }
        }
}

struct DailyScheduleView: View {
    @Binding var selectedDate: Date
    @Binding var planMode: Int
    @Binding var searchText: String
    @ObservedObject var manager: DataManager
    @Binding var showCalendar: Bool
    
    @State private var currentTime = Date()
    @State private var eventToEdit: AppEvent? = nil
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var visibleEvents: [AppEvent] {
        manager.filteredEvents(forDate: selectedDate, mode: (planMode == 0) ? .myPlan : .fullPlan, searchText: searchText)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { playHaptic(); showCalendar.toggle() }) {
                    Image(systemName: "calendar").font(.title2).padding(8).foregroundColor(manager.theme.mainColor)
                }
                CalendarStrip(selectedDate: $selectedDate, themeColor: manager.theme.mainColor, manager: manager)
            }.padding(.vertical, 10)
            
            if !visibleEvents.isEmpty && searchText.isEmpty && planMode == 0 {
                let activeEvents = visibleEvents.filter { !manager.cancelledEvents.contains($0.id) }
                let totalMin = activeEvents.reduce(0) { $0 + $1.durationMinutes }
                Text("Dzisiaj: \(activeEvents.count) zajęć (\(totalMin/60)h \(totalMin%60)m)")
                    .font(.caption).bold().foregroundColor(.secondary).padding(.bottom, 5)
            }
            
            if visibleEvents.isEmpty {
                EmptyStateView(mode: planMode, isSearching: !searchText.isEmpty, themeColor: manager.theme.mainColor).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(visibleEvents) { event in
                            let isCancelled = manager.cancelledEvents.contains(event.id)
                            EnhancedEventCard(event: event, currentTime: currentTime, note: manager.customNotes[event.id], isCancelled: isCancelled, manager: manager)
                                .onTapGesture { playHaptic(); eventToEdit = event }
                        }
                    }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 120)
                }
            }
        }
        .onReceive(timer) { time in currentTime = time }
        .sheet(item: $eventToEdit) { event in EventDetailView(manager: manager, event: event) }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 40, coordinateSpace: .local).onEnded { value in
            if value.translation.width < 0 {
                playHaptic(); withAnimation { selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate }
            } else if value.translation.width > 0 {
                playHaptic(); withAnimation { selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate }
            }
        })
    }
}

struct WeeklyScheduleView: View {
    @Binding var selectedDate: Date
    @Binding var planMode: Int
    @Binding var searchText: String
    @ObservedObject var manager: DataManager
    
    @State private var currentTime = Date()
    @State private var eventToEdit: AppEvent? = nil
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        let mode: DataManager.ViewMode = (planMode == 0) ? .myPlan : .fullPlan
        let weekEvents = manager.getWeekEvents(for: selectedDate, mode: mode, searchText: searchText)
        let sortedDays = weekEvents.keys.sorted()
        
        VStack(spacing: 0) {
            HStack {
                Button(action: { playHaptic(); withAnimation { selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate } }) {
                    HStack(spacing: 6) { Image(systemName: "chevron.left.circle.fill"); Text("Poprzedni") }
                        .font(.subheadline).bold().padding(.vertical, 10).padding(.horizontal, 16).background(manager.theme.mainColor.opacity(0.15)).foregroundColor(manager.theme.mainColor).clipShape(Capsule())
                }
                Spacer()
                Button(action: { playHaptic(); withAnimation { selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate } }) {
                    HStack(spacing: 6) { Text("Następny"); Image(systemName: "chevron.right.circle.fill") }
                        .font(.subheadline).bold().padding(.vertical, 10).padding(.horizontal, 16).background(manager.theme.mainColor.opacity(0.15)).foregroundColor(manager.theme.mainColor).clipShape(Capsule())
                }
            }.padding(.horizontal).padding(.vertical, 10)
            
            if sortedDays.isEmpty {
                EmptyStateView(mode: planMode, isSearching: !searchText.isEmpty, themeColor: manager.theme.mainColor).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(sortedDays, id: \.self) { day in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(formatDayHeader(day)).font(.subheadline).bold().foregroundColor(isToday(day) ? .white : .primary).padding(.horizontal, 12).padding(.vertical, 6).background(isToday(day) ? manager.theme.mainColor : Color(UIColor.tertiarySystemFill)).cornerRadius(8)
                                    Spacer()
                                }.padding(.horizontal, 16)
                                
                                VStack(spacing: 12) {
                                    ForEach(weekEvents[day]!) { event in
                                        let isCancelled = manager.cancelledEvents.contains(event.id)
                                        EnhancedEventCard(event: event, currentTime: currentTime, note: manager.customNotes[event.id], isCancelled: isCancelled, manager: manager)
                                            .onTapGesture { playHaptic(); eventToEdit = event }
                                    }
                                }
                            }
                        }
                    }.padding(.top, 10).padding(.bottom, 120)
                }
            }
        }
        .onReceive(timer) { time in currentTime = time }
        .sheet(item: $eventToEdit) { event in EventDetailView(manager: manager, event: event) }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 40, coordinateSpace: .local).onEnded { value in
            if value.translation.width < 0 {
                playHaptic(); withAnimation { selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate }
            } else if value.translation.width > 0 {
                playHaptic(); withAnimation { selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate }
            }
        })
    }
    
    func formatDayHeader(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "pl_PL"); f.dateFormat = "EEEE, d MMM"
        return f.string(from: date).uppercased()
    }
    
    func isToday(_ date: Date) -> Bool { Calendar.current.isDateInToday(date) }
}

// ==========================================
// EKRAN POWITALNY (ONBOARDING)
// ==========================================
struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @ObservedObject var manager: DataManager
    @State private var currentPage = 0
    
    @AppStorage("selectedLabGroup") var selectedLabGroup: String = "L1"
    @AppStorage("selectedProjGroup") var selectedProjGroup: String = "P1"
    @AppStorage("selectedKompGroup") var selectedKompGroup: String = "Lk1"
    @AppStorage("selectedLangGroup") var selectedLangGroup: String = "Lek1"
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                // EKRAN 1: Powitanie
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "graduationcap.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundColor(manager.theme.mainColor)
                    
                    Text("Witaj w PlanPK")
                        .font(.system(size: 38, weight: .black))
                    
                    Text("Twój uczelniany plan zajęć na nowym poziomie. Widgety, Live Activities i pełna kontrola nad ocenami.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                        .lineSpacing(4)
                    
                    Spacer()
                    
                    Button(action: {
                        playHaptic()
                        withAnimation { currentPage = 1 }
                    }) {
                        Text("Dalej")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(manager.theme.mainColor)
                            .cornerRadius(16)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 60)
                }
                .tag(0)
                
                // EKRAN 2: Wybór grup
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "person.2.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .foregroundColor(manager.theme.mainColor)
                    
                    Text("Wybierz swoje grupy")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("Apka automatycznie ukryje zajęcia innych grup, zostawiając tylko Twój właściwy plan.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                    
                    VStack(spacing: 12) {
                        HStack { Text("Laboratoria"); Spacer(); Picker("", selection: $selectedLabGroup) { ForEach(["L1","L2","L3","L4","L5","L6"], id:\.self){ Text($0) } }.tint(manager.theme.mainColor) }
                        HStack { Text("Projekty"); Spacer(); Picker("", selection: $selectedProjGroup) { ForEach(["P1","P2","P3","P4"], id:\.self){ Text($0) } }.tint(manager.theme.mainColor) }
                        HStack { Text("Komputery"); Spacer(); Picker("", selection: $selectedKompGroup) { ForEach(["Lk1","Lk2","Lk3","Lk4"], id:\.self){ Text($0) } }.tint(manager.theme.mainColor) }
                        HStack { Text("Języki"); Spacer(); Picker("", selection: $selectedLangGroup) { ForEach(["Lek1","Lek2","Lek3"], id:\.self){ Text($0) } }.tint(manager.theme.mainColor) }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    
                    Button(action: {
                        playHaptic()
                        withAnimation { currentPage = 2 }
                    }) {
                        Text("Dalej")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(manager.theme.mainColor)
                            .cornerRadius(16)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 60)
                }
                .tag(1)
                
                // EKRAN 3: Powiadomienia i Live Activities
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "bell.badge.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .foregroundColor(manager.theme.mainColor)
                    
                    Text("Bądź na bieżąco")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("PlanPK przypomni Ci o zajęciach 30 minut przed startem i wyświetli piękne odliczanie na zablokowanym ekranie.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                        .lineSpacing(4)
                    
                    Spacer()
                    
                    Button(action: {
                        playHaptic(style: .heavy)
                        manager.requestNotificationPermission()
                        manager.objectWillChange.send()
                        withAnimation {
                            hasSeenOnboarding = true
                        }
                    }) {
                        Text("Zaczynamy!")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(manager.theme.mainColor)
                            .cornerRadius(16)
                            .shadow(color: manager.theme.mainColor.opacity(0.4), radius: 10, x: 0, y: 5)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 60)
                }
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
    }
}
