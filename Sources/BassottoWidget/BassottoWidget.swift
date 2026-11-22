import SwiftUI
import WidgetKit

struct DogEntry: TimelineEntry {
    let date: Date
}

struct DogProvider: TimelineProvider {
    func placeholder(in context: Context) -> DogEntry { DogEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (DogEntry) -> Void) {
        completion(DogEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DogEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [DogEntry(date: .now)], policy: .after(next)))
    }
}

struct DogWidgetView: View {
    let entry: DogEntry

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "dog.fill")
                .font(.system(size: 34))
            Text("Hello from Bassotto")
                .font(.caption)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct DogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DogWidget", provider: DogProvider()) { entry in
            DogWidgetView(entry: entry)
        }
        .configurationDisplayName("Bassotto")
        .description("Your dog, on the desktop.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct BassottoWidgets: WidgetBundle {
    var body: some Widget {
        DogWidget()
    }
}
