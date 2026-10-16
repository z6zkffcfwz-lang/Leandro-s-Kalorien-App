import SwiftUI
import PhotosUI

@main
struct LeandrosKalorienAppApp: App {
    @StateObject private var store = NutritionStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct FoodEntry: Identifiable, Codable {
    var id = UUID()
    var name: String
    var meal: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var date: Date = .now
}

struct WeightEntry: Identifiable, Codable {
    var id = UUID()
    var kilograms: Double
    var date: Date = .now
}

@MainActor
final class NutritionStore: ObservableObject {
    @Published var foods: [FoodEntry] = [] { didSet { save() } }
    @Published var weights: [WeightEntry] = [] { didSet { save() } }
    @Published var calorieGoal: Int = 2000 { didSet { save() } }

    private let foodsKey = "leandro.foods.v1"
    private let weightsKey = "leandro.weights.v1"
    private let goalKey = "leandro.goal.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: foodsKey),
           let decoded = try? JSONDecoder().decode([FoodEntry].self, from: data) {
            foods = decoded
        }
        if let data = UserDefaults.standard.data(forKey: weightsKey),
           let decoded = try? JSONDecoder().decode([WeightEntry].self, from: data) {
            weights = decoded
        }
        let savedGoal = UserDefaults.standard.integer(forKey: goalKey)
        if savedGoal > 0 { calorieGoal = savedGoal }
    }

    var todayFoods: [FoodEntry] {
        foods.filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
    }
    var eaten: Int { todayFoods.reduce(0) { $0 + $1.calories } }
    var protein: Double { todayFoods.reduce(0) { $0 + $1.protein } }
    var carbs: Double { todayFoods.reduce(0) { $0 + $1.carbs } }
    var fat: Double { todayFoods.reduce(0) { $0 + $1.fat } }

    func addFood(_ entry: FoodEntry) { foods.append(entry) }
    func deleteFood(_ entry: FoodEntry) { foods.removeAll { $0.id == entry.id } }
    func addWeight(_ kg: Double) { weights.append(WeightEntry(kilograms: kg)) }

    private func save() {
        if let data = try? JSONEncoder().encode(foods) {
            UserDefaults.standard.set(data, forKey: foodsKey)
        }
        if let data = try? JSONEncoder().encode(weights) {
            UserDefaults.standard.set(data, forKey: weightsKey)
        }
        UserDefaults.standard.set(calorieGoal, forKey: goalKey)
    }
}

private let lime = Color(red: 0.78, green: 0.95, blue: 0.41)
private let panel = Color(red: 0.105, green: 0.13, blue: 0.11)

struct MainView: View {
    @EnvironmentObject private var store: NutritionStore
    @State private var selectedTab = 0
    @State private var showAddFood = false
    @State private var showWeight = false

    var body: some View {
        TabView(selection: $selectedTab) {
            dashboard
                .tabItem { Label("Heute", systemImage: "circle.grid.2x2.fill") }
                .tag(0)
            statistics
                .tabItem { Label("Statistik", systemImage: "chart.bar.fill") }
                .tag(1)
            weightView
                .tabItem { Label("Gewicht", systemImage: "scalemass.fill") }
                .tag(2)
        }
        .tint(lime)
        .sheet(isPresented: $showAddFood) { AddFoodView().environmentObject(store) }
        .sheet(isPresented: $showWeight) { AddWeightView().environmentObject(store) }
    }

    private var dashboard: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    VStack(alignment: .leading, spacing: 16) {
                        Text("KALORIENBILANZ").font(.caption.bold()).tracking(1.5).foregroundStyle(.secondary)
                        HStack(alignment: .center, spacing: 22) {
                            ZStack {
                                Circle().stroke(.white.opacity(0.08), lineWidth: 12)
                                Circle()
                                    .trim(from: 0, to: min(1, Double(store.eaten) / Double(max(1, store.calorieGoal))))
                                    .stroke(lime, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                VStack(spacing: 4) {
                                    Text("\(max(0, store.calorieGoal - store.eaten))")
                                        .font(.system(size: 27, weight: .bold, design: .rounded))
                                    Text("übrig").font(.caption).foregroundStyle(.secondary)
                                }
                            }.frame(width: 138, height: 138)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(store.eaten) kcal").font(.title2.bold())
                                Text("gegessen").foregroundStyle(.secondary)
                                Divider()
                                Text("Tagesziel").font(.caption).foregroundStyle(.secondary)
                                Stepper("\(store.calorieGoal) kcal", value: $store.calorieGoal, in: 1000...5000, step: 50)
                                    .font(.subheadline.bold())
                            }
                        }
                    }
                    .padding(18).background(panel, in: RoundedRectangle(cornerRadius: 24))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Makronährstoffe").font(.title3.bold())
                        MacroBar(title: "Eiweiß", value: store.protein, color: lime)
                        MacroBar(title: "Kohlenhydrate", value: store.carbs, color: .cyan)
                        MacroBar(title: "Fett", value: store.fat, color: .purple)
                    }.padding(18).background(panel, in: RoundedRectangle(cornerRadius: 24))

                    HStack {
                        Text("Ernährungstagebuch").font(.title3.bold())
                        Spacer()
                        Button { showAddFood = true } label: {
                            Label("Hinzufügen", systemImage: "plus")
                                .font(.subheadline.bold())
                        }.buttonStyle(.borderedProminent).tint(lime).foregroundStyle(.black)
                    }

                    if store.todayFoods.isEmpty {
                        ContentUnavailableView("Noch nichts eingetragen", systemImage: "fork.knife",
                            description: Text("Füge deine erste Mahlzeit hinzu."))
                            .padding(.vertical, 12)
                    } else {
                        ForEach(store.todayFoods) { item in
                            HStack(spacing: 12) {
                                Image(systemName: "leaf.fill")
                                    .foregroundStyle(lime)
                                    .frame(width: 42, height: 42)
                                    .background(lime.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name).fontWeight(.semibold)
                                    Text("\(item.meal) · P \(Int(item.protein)) g · KH \(Int(item.carbs)) g · F \(Int(item.fat)) g")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(item.calories) kcal").font(.subheadline.bold())
                            }
                            .padding(12).background(panel, in: RoundedRectangle(cornerRadius: 16))
                            .contextMenu {
                                Button("Eintrag löschen", role: .destructive) { store.deleteFood(item) }
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        featureCard("Foto-Analyse", icon: "camera", detail: "Vorbereitet") {
                            showPhotoInfo()
                        }
                        featureCard("Barcode", icon: "barcode.viewfinder", detail: "Vorbereitet") {
                            showBarcodeInfo()
                        }
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert("Funktion noch nicht verbunden", isPresented: $showInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(infoAlert)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.title2).foregroundStyle(.black)
                .frame(width: 48, height: 48).background(lime, in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 3) {
                Text("Leandro’s").font(.title2.bold())
                Text("KALORIEN APP").font(.caption2.bold()).tracking(2).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "moon.stars.fill").foregroundStyle(lime).font(.title3)
        }.padding(.vertical, 4)
    }

    private var statistics: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Deine Woche").font(.largeTitle.bold())
                    Text("Kalorien heute").foregroundStyle(.secondary)
                    Text("\(store.eaten) kcal").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(lime)
                    Text("Erfasste Mahlzeiten: \(store.todayFoods.count)")
                    Text("Makros heute").font(.title3.bold()).padding(.top, 8)
                    MacroBar(title: "Eiweiß", value: store.protein, color: lime)
                    MacroBar(title: "Kohlenhydrate", value: store.carbs, color: .cyan)
                    MacroBar(title: "Fett", value: store.fat, color: .purple)
                    Text("Tägliche Einträge werden lokal gespeichert. Die vollständige Wochenübersicht mit Verlaufsgrafik ist ein nächster Ausbauschritt.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
                }.padding()
            }.background(Color.black.ignoresSafeArea())
                .navigationTitle("Statistik")
        }
    }

    private var weightView: some View {
        NavigationStack {
            List {
                Section("Aktuelles Gewicht") {
                    if let latest = store.weights.sorted(by: { $0.date > $1.date }).first {
                        Text(String(format: "%.1f kg", latest.kilograms)).font(.largeTitle.bold()).foregroundStyle(lime)
                    } else {
                        Text("Noch kein Gewicht eingetragen").foregroundStyle(.secondary)
                    }
                    Button { showWeight = true } label: {
                        Label("Gewicht eintragen", systemImage: "plus.circle.fill")
                    }
                }
                Section("Verlauf") {
                    ForEach(store.weights.sorted(by: { $0.date > $1.date })) { entry in
                        HStack {
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(String(format: "%.1f kg", entry.kilograms)).bold()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Gewicht")
        }
    }

    private func featureCard(_ title: String, icon: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon).font(.title2).foregroundStyle(lime)
                Text(title).font(.headline).foregroundStyle(.white)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(panel, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }

    private func showPhotoInfo() {
        // Hook point for a photo-analysis service and user-confirmed nutrition estimates.
        infoAlert = "Fotoanalyse benötigt noch eine Bildanalyse-Anbindung. Schätzwerte sollten vor dem Speichern bestätigt werden."
        showInfo = true
    }
    private func showBarcodeInfo() {
        infoAlert = "Der Kamera-Barcodescanner und eine Produktdatenbank müssen noch integriert werden."
        showInfo = true
    }

    @State private var showInfo = false
    @State private var infoAlert = ""
}

struct MacroBar: View {
    let title: String
    let value: Double
    let color: Color
    var body: some View {
        VStack(spacing: 7) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text("\(Int(value.rounded())) g").font(.subheadline.bold()).foregroundStyle(color)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule().fill(color).frame(width: proxy.size.width * min(1, value / 120))
                }
            }.frame(height: 7)
        }
    }
}

struct AddFoodView: View {
    @EnvironmentObject private var store: NutritionStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var meal = "Mittagessen"
    @State private var calories = "350"
    @State private var protein = "25"
    @State private var carbs = "35"
    @State private var fat = "10"
    private let meals = ["Frühstück", "Mittagessen", "Abendessen", "Snack"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Lebensmittel") {
                    TextField("z. B. Haferflocken mit Joghurt", text: $name)
                    Picker("Mahlzeit", selection: $meal) {
                        ForEach(meals, id: \.self) { Text($0) }
                    }
                }
                Section("Nährwerte der Portion") {
                    numericField("Kalorien (kcal)", text: $calories)
                    numericField("Eiweiß (g)", text: $protein)
                    numericField("Kohlenhydrate (g)", text: $carbs)
                    numericField("Fett (g)", text: $fat)
                }
                Section {
                    Text("Bitte Werte von der Verpackung oder einer verlässlichen Nährwertquelle übernehmen.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Mahlzeit hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
                              let kcal = Int(calories), kcal >= 0,
                              let p = Double(protein), p >= 0,
                              let c = Double(carbs), c >= 0,
                              let f = Double(fat), f >= 0 else { return }
                        store.addFood(FoodEntry(name: name, meal: meal, calories: kcal, protein: p, carbs: c, fat: f))
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }.preferredColorScheme(.dark).tint(lime)
    }

    private func numericField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text).keyboardType(.decimalPad)
    }
}

struct AddWeightView: View {
    @EnvironmentObject private var store: NutritionStore
    @Environment(\.dismiss) private var dismiss
    @State private var kilograms = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Gewicht") {
                    TextField("Kilogramm, z. B. 82,5", text: $kilograms).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Gewicht eintragen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let normalized = kilograms.replacingOccurrences(of: ",", with: ".")
                        if let value = Double(normalized), value > 0, value < 500 {
                            store.addWeight(value)
                            dismiss()
                        }
                    }
                }
            }
        }.preferredColorScheme(.dark).tint(lime)
    }
}
