import WidgetKit
import SwiftUI
import ActivityKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), events: [], title: "DZISIAJ", exams: [], important: [])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let sampleEvent = AppEvent(id: "1", title: "Inżynieria Oprogramowania", lecturer: "Kowalski", room: "A1", date: Date(), startTime: Date(), endTime: Date().addingTimeInterval(5400), category: nil, classType: .wyklad, group: nil, isUserCreated: false)
        completion(SimpleEntry(date: Date(), events: [sampleEvent], title: "DZISIAJ", exams: [], important: []))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let now = Date()
        var displayEvents: [AppEvent] = []
        var headerTitle = "WOLNE"
        
        var exams: [String] = []
        var important: [String] = []
        
        if let sharedDefaults = UserDefaults(suiteName: "group.PlanPK") {
            exams = sharedDefaults.stringArray(forKey: "widgetExams") ?? []
            important = sharedDefaults.stringArray(forKey: "widgetImportant") ?? []
            
            if let data = sharedDefaults.data(forKey: "widgetEvents"),
               let upcoming = try? JSONDecoder().decode([AppEvent].self, from: data) {
                
                let calendar = Calendar.current
                let todayEvents = upcoming.filter { calendar.isDate($0.startTime, inSameDayAs: now) && $0.endTime > now }
                
                if !todayEvents.isEmpty {
                    displayEvents = todayEvents
                    headerTitle = "DZISIAJ"
                } else {
                    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                        let tomorrowEvents = upcoming.filter { calendar.isDate($0.startTime, inSameDayAs: tomorrow) }
                        if !tomorrowEvents.isEmpty {
                            displayEvents = tomorrowEvents
                            headerTitle = "JUTRO"
                        } else {
                            headerTitle = "WOLNE"
                        }
                    }
                }
            }
        }
        
        let limitedEvents = Array(displayEvents.prefix(2))
        let entry = SimpleEntry(date: now, events: limitedEvents, title: headerTitle, exams: exams, important: important)
        
        let nextUpdate = limitedEvents.first?.endTime ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let events: [AppEvent]
    let title: String
    let exams: [String]
    let important: [String]
}

struct PlanPKWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("🎓")
                    .font(.system(size: 14))
                Text("| PLANPK |")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.secondary)
                Text(entry.title)
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.blue)
                    .tracking(1.0)
                Spacer()
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            .padding(.bottom, 12)
            
            if entry.events.isEmpty {
                Spacer()
                Text("Czysty chill! 🍻")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                let isSingleEvent = entry.events.count == 1
                if isSingleEvent { Spacer() }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.events) { event in
                        let isExam = entry.exams.contains(event.id) || event.category == .exam
                        let isImportant = entry.important.contains(event.id)
                        
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(event.startTime.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: isSingleEvent ? 16 : 13, weight: .bold))
                                    .foregroundColor(.primary)
                                Text(event.endTime.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: isSingleEvent ? 13 : 11, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: isSingleEvent ? 50 : 45, alignment: .trailing)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(event.classType?.color ?? Color.blue)
                                .frame(width: isSingleEvent ? 5 : 4)
                                .padding(.vertical, 2)
                            
                            VStack(alignment: .leading, spacing: isSingleEvent ? 8 : 4) {
                                Text(event.title)
                                    .font(.system(size: isSingleEvent ? 16 : 13, weight: .bold))
                                    .lineLimit(isSingleEvent ? 3 : 2)
                                    .minimumScaleFactor(0.65)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                HStack(spacing: isSingleEvent ? 8 : 6) {
                                    Text(event.classType?.rawValue ?? "Inne")
                                        .font(.system(size: isSingleEvent ? 12 : 10, weight: .black))
                                        .padding(.horizontal, isSingleEvent ? 8 : 5)
                                        .padding(.vertical, isSingleEvent ? 4 : 2)
                                        .background((event.classType?.color ?? .gray).opacity(0.2))
                                        .foregroundColor(event.classType?.color ?? .gray)
                                        .cornerRadius(isSingleEvent ? 6 : 4)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: isSingleEvent ? 12 : 10))
                                        Text(event.room)
                                            .font(.system(size: isSingleEvent ? 14 : 12, weight: .bold))
                                    }
                                    .foregroundColor(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(
                            Color(UIColor.secondarySystemGroupedBackground)
                                .opacity(isExam || isImportant ? 1.0 : 0.0)
                        )
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isExam ? Color.red : (isImportant ? Color.yellow.opacity(0.8) : Color.clear), lineWidth: isExam || isImportant ? 2 : 0)
                        )
                    }
                }
                
                if isSingleEvent { Spacer() } else { Spacer(minLength: 0) }
            }
        }
        .padding(16)
        .containerBackground(Color(UIColor.systemBackground), for: .widget)
    }
}

struct PlanPKWidget: Widget {
    let kind: String = "PlanPKWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PlanPKWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mój Plan")
        .description("Szybki podgląd planu na pulpicie.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct PlanPKWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveClassAttributes.self) { context in
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🎓 | PlanPK | Trwają zajęcia")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                            .textCase(.uppercase)
                        
                        Text(context.attributes.className)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack(spacing: 8) {
                            Text(context.attributes.typeName.uppercased())
                                .font(.system(size: 12, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.3))
                                .foregroundColor(.cyan)
                                .cornerRadius(4)
                            
                            Text("|")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(.gray.opacity(0.8))
                            
                            Text("koniec o \(context.attributes.endTime.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text("Sala \(context.attributes.room)")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.3))
                        .foregroundColor(.cyan)
                        .cornerRadius(6)
                        
                        Spacer(minLength: 8)
                        Text("KONIEC ZA:")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.gray)
                        Text(context.attributes.endTime, style: .relative)
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(.cyan)
                            .multilineTextAlignment(.trailing)
                    }
                }
                ProgressView(timerInterval: context.attributes.startTime...context.attributes.endTime)
                    .labelsHidden()
                    .tint(.cyan)
                    .frame(height: 8)
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.65))
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "graduationcap.fill").foregroundColor(.cyan)
                        Text(context.attributes.room).bold().foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.endTime, style: .relative)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.className)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(context.attributes.typeName.uppercased())
                            .font(.caption2)
                            .fontWeight(.black)
                            .foregroundColor(.gray)
                        
                        ProgressView(timerInterval: context.attributes.startTime...context.attributes.endTime)
                            .labelsHidden()
                            .tint(.cyan)
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "graduationcap.fill").foregroundColor(.cyan).font(.caption)
                    Text(context.attributes.room).bold().font(.caption)
                }
            } compactTrailing: {
                Text(context.attributes.endTime, style: .relative)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
            } minimal: {
                Image(systemName: "graduationcap.fill").foregroundColor(.cyan)
            }
        }
    }
}

@main
struct PlanPKWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlanPKWidget()
        PlanPKWidgetLiveActivity()
    }
}
