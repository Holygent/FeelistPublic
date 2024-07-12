//
//  Details.swift
//  FeelingsApp
//
//  Created by Holygent on 6/27/24.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import Charts

struct AppreciationDetails: View {
    let id: String
    let list: Bool
    let listMetaKey: String
    let listMetaV: Double
    let listTestIndex: Int
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var document: DocumentSnapshot? = nil
    @State private var relation = ""
    @State private var preferences: [(Double, Timestamp, String, String)] = []
    @State private var sheetTest = false
    @State private var loading = true
    @State private var showAllData = false
    @State private var showLastXValue = false
    @State private var alertConfirmDeletion = false
    @State private var biggestIndex = 0
    @State private var showHelp = false
    @State private var showComparison = true
    @State private var sheetReport = false
    let feedbackIcons = ["😠", "☹️", "😀", "🤩"]
    @State private var isOwner = false
    @Environment(Defaults.self) var defaults
    let dateFormatter: DateFormatter = {
        let dF = DateFormatter()
        dF.dateFormat = "MMM d"
        return dF
    }()
    func getDocument() {
        withAnimation {
            loading = true
            preferences.removeAll()
        }
        Firestore.firestore().collection("Workout").document(id).getDocument { document, error in
            if error == nil, let document = document, document.exists {
                self.document = document
                relation = "Other"
                if !list {
                    relation = document.data()?["relation"] as? String ?? ""
                    for tests in document.data()?["tests"] as? [String: [String: Any]] ?? [:] {
                        preferences.append((tests.value.first(where: { $0.key == "double" })?.value as? Double ?? 0.0, tests.value.first(where: { $0.key == "date" })?.value as? Timestamp ?? Timestamp(), tests.value.first(where: { $0.key == "relation" })?.value as? String ?? "", tests.value.first(where: { $0.key == "feedback" })?.value as? String ?? ""))
                    }
                } else {
                    isOwner = document.data()?["listOwner"] as? String ?? "" == defaults.userID
                }
                withAnimation {
                    loading = false
                }
            }
        }
    }
    func preferenceDescription(relation: String, lastPref: Double) -> String {
        switch relation {
        case "Friend":
            switch lastPref {
            case ..<0.15: return "You might Not Like Them"
            case ..<0.3: return "You Slightly Like Them"
            case ..<0.5: return "You Somewhat Like Them"
            case ..<0.7: return "You Quite Like Them"
            case ..<0.85: return "You Highly Like Them"
            case 0.85...: return "You may be In Love"
            default: return "Error: out of bounds or incorrectly initialized: \(lastPref).\n\nPlease report a bug."
            }
        case "Family Member":
            switch lastPref {
            case ..<0.2: return "You're Not Close At All"
            case ..<0.4: return "You're Not So Close"
            case ..<0.8: return "You're Close"
            case ..<0.9: return "You're Very Close"
            case 0.9...: return "You May Be their Closest Family Member"
            default: return "Error: out of bounds or incorrectly initialized: \(lastPref).\n\nPlease report a bug."
            }
        case "Partner":
            switch lastPref {
            case ..<0.2: return "You may Not Like Them"
            case ..<0.4: return "You may Not be Happy"
            case ..<0.6: return "You May Not Like Being with Them That Much"
            case ..<0.8: return "You Love Them Reasonably"
            case ..<0.9: return "You're in True Love"
            case 0.9...: return "You Found the Chosen One"
            default: return "Error: out of bounds or incorrectly initialized: \(lastPref).\n\nPlease report a bug."
            }
        case "Other":
            switch lastPref {
            case ..<0.1: return "You may Dislike Them"
            case ..<0.2: return "You may Slightly Like Them"
            case ..<0.5: return "You Somewhat Like Them"
            case ..<0.73: return "You Quite Like Them"
            case 0.73...:
                switch list {
                case false: return "You may be In Love"
                case true: return "You Highly Like Them"
                }
            default: return "Error: out of bounds or incorrectly initialized: \(lastPref).\n\nPlease report a bug."
            }
        default:
            return "Your results do not meet the requirements (have: \(relation); computed: \(lastPref)).\n\nPlease report a bug.\nThree dots (top-right corner) > Send Feedback."
        }
    }
    func prefMarker(value: Int) -> String {
        if value == 0 {
            return "No Pref."
        } else if value == 15 {
            return "Low Pref."
        } else if value == 30 {
            return "Slight Pref."
        } else if value == 50 {
            return "Mid Pref."
        } else if value == 70 {
            return "High Pref."
        } else if value == 90 {
            return "In Love"
        } else if value == 100 {
            return "100%"
        } else {
            return ""
        }
    }
    @Environment(CurrentTest.self) var currentTest
    var body: some View {
        NavigationStack {
            ScrollView {
                if loading {
                    ProgressView()
                        .padding(15)
                        .frame(maxWidth: .infinity)
                } else {
                    let lastPref = preferences.sorted(by: { item1, item2 in item1.1.dateValue() > item2.1.dateValue() }).first?.0 as? Double ?? 0.0
                    let lastTime = (preferences.sorted { item1, item2 in item1.1.dateValue() > item2.1.dateValue() }.first?.1 as? Timestamp ?? Timestamp()).dateValue()
                    VStack(alignment: .center) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: colorScheme == .light ? [.gray.opacity(0.5), .gray.opacity(0.85)] : [.white.opacity(0.75), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                .frame(height: 0.22*UIScreen.main.bounds.width)
                            Text((list ? listMetaKey : document?.data()?["name"] as? String ?? "").trimmingCharacters(in: .whitespaces).components(separatedBy: " ").compactMap({ String($0.first ?? Character("")) }).joined().uppercased())
                                .fontDesign(.rounded)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .font(.largeTitle.bold())
                        }
                        .padding(30)
                        Text(preferenceDescription(relation: relation, lastPref: list ? listMetaV : lastPref))
                            .font(.title.bold())
                            .padding(.bottom,2)
                        let relation = document?.data()?["relation"] as? String ?? ""
                        let users = document?.data()?["users"] as? [String] ?? []
                        Text(list ? "On average, you and \(users.count-1) other\(users.count-1 > 1 ? "s" : "") love \(listMetaKey) by \(Int(listMetaV*100))%." : "\(relation != "Other" ? "As a \(relation), y" : "Y")ou love \(document?.data()?["name"] as? String ?? "") by \(Int(lastPref*100))%.")
                            .padding(.bottom,30)
                        if lastTime <= Calendar.current.date(byAdding: .day, value: -7, to: Date())! && !list {
                            let days = (Calendar.current.dateComponents([.day], from: lastTime, to: Date()).day)!
                            let months = (Calendar.current.dateComponents([.month], from: lastTime, to: Date()).month)!
                            HStack(alignment: .center, spacing: 5) {
                                Image(systemName: "exclamationmark.arrow.circlepath")
                                    .foregroundStyle(.orange)
                                    .fontWeight(.medium)
                                Text("Last tested \(days > 30 ? months : days) \(days > 30 ? "month\(months > 1 ? "s" : "")" : "day\(days > 1 ? "s" : "")") ago")
                                    .font(.subheadline)
                            }
                            .padding(.bottom,5)
                        }
                        if !list {
                            Button(action: {
                                sheetTest = true
                            }) {
                                Text("Test Again")
                                    .font(.headline)
                                    .padding(.vertical,8)
                                    .padding(.horizontal,20)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .disabled(defaults.offline)
                            if preferences.sorted(by: { item1, item2 in item1.1.dateValue() < item2.1.dateValue() }).last?.3 == "" {
                                Text("How do the results compare to reality?")
                                    .font(.headline)
                                    .padding(.top,50)
                                    .padding(.bottom,2)
                                    .padding(.horizontal,20)
                                HStack(spacing: 20) {
                                    ForEach(feedbackIcons, id: \.self) { icon in
                                        Button(action: {
                                            Firestore.firestore().collection("Workout").document(id).updateData(["tests.data\(preferences.count-1).feedback":icon])
                                            withAnimation {
                                                preferences.append((preferences.sorted(by: { item1, item2 in item1.1.dateValue() < item2.1.dateValue() }).last?.0 ?? 0.0, preferences.sorted(by: { item1, item2 in item1.1.dateValue() < item2.1.dateValue() }).last?.1 ?? Timestamp(), preferences.sorted(by: { item1, item2 in item1.1.dateValue() < item2.1.dateValue() }).last?.2 ?? "", icon))
                                                preferences.remove(at: preferences.count-2)
                                            }
                                        }) {
                                            Text(icon)
                                                .font(.title.bold())
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal,15)
                    .padding(.bottom,15)
                    .sheet(isPresented: $sheetTest, onDismiss: { getDocument() }) {
                        AddAppreciationTwo(relationTest: CurrentTest())
                            .presentationCornerRadius(40)
                            .onAppear {
                                currentTest.name = document?.data()?["name"] as? String ?? ""
                                currentTest.relation = document?.data()?["relation"] as? String ?? ""
                            }
                    }
                    if !list || isOwner {
                        Divider()
                            .padding(.vertical,15)
                    }
                    if preferences.count > 1 {
                        VStack(alignment: .leading) {
                            HStack(alignment: .center) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.accentColor)
                                    .font(.title3)
                                Text("History")
                                    .font(.title3.bold())
                                    .fontDesign(.rounded)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.bottom,10)
                            .padding(.horizontal,15)
                            if preferences.filter({ $0.2 == relation }).count > 1 {
                                ScrollViewReader { proxy in
                                    ScrollView(.horizontal) {
                                        let prePreferences = preferences.filter({ $0.2 == relation }).sorted { item1, item2 in item1.1.dateValue() < item2.1.dateValue() }
                                        let preferences = prePreferences.count == 0 ? self.preferences : prePreferences
                                        let sequence = self.preferences.filter({ $0.2 == relation }).count > 1 ? preferences : self.preferences.sorted { item1, item2 in item1.1.dateValue() < item2.1.dateValue() }
                                        Chart {
                                            ForEach(sequence, id: \.1) { avg in
                                                LineMark(x: .value("Date", avg.1.dateValue()), y: .value("Preference percentage", Int(avg.0*100)))
                                                    .interpolationMethod(.catmullRom)
                                                    .lineStyle(StrokeStyle(lineWidth: 4))
                                            }
                                        }
                                        .frame(width: CGFloat(50*preferences.count) <= UIScreen.main.bounds.width ? UIScreen.main.bounds.width : CGFloat(50*preferences.count), height: 0.3*UIScreen.main.bounds.height)
                                        .padding(.bottom,15)
                                        .onAppear {
                                            proxy.scrollTo(biggestIndex)
                                        }
                                        .chartYScale(domain: [Int((preferences.min(by: { item1, item2 in
                                            item1.0 < item2.0
                                        })?.0 ?? 0.0)*100) < 0 ? Int((preferences.min(by: { item1, item2 in
                                            item1.0 < item2.0
                                        })?.0 ?? 0.0)*100) : 0, 100])
                                        .chartYAxis {
                                            let relation = relation
                                            AxisMarks(position: .trailing, values: relation == "Friend" ? [0, 15, 30, 50, 70, 90, 100] : relation == "Family Member" ? [0, 20, 40, 60, 80, 100] : relation == "Partner" ? [0, 20, 40, 60, 80, 100] : [0, 20, 50, 73, 100]) { value in
                                                AxisValueLabel {
                                                    let valueInt = value.as(Int.self) ?? 0
                                                    if relation == "Friend" {
                                                        Text(prefMarker(value: valueInt))
                                                            .padding(.top,valueInt == 100 ? 10 : 0)
                                                            .id(value.index)
                                                            .onAppear {
                                                                biggestIndex = value.count
                                                            }
                                                    } else if relation == "Family Member" {
                                                        Text(valueInt == 0 ? "Not Close" : valueInt == 20 ? "A Bit Close" : valueInt == 40 ? "Close" : valueInt == 80 ? "Very Close" : valueInt == 100 ? "100%" : "")
                                                            .padding(.top,valueInt == 100 ? 10 : 0)
                                                            .id(value.index)
                                                            .onAppear {
                                                                biggestIndex = value.count
                                                            }
                                                    } else if relation == "Partner" {
                                                        Text(valueInt == 0 ? "Not Loving" : valueInt == 20 ? "No Joy" : valueInt == 40 ? "Unhappy" : valueInt == 60 ? "Love" : valueInt == 80 ? "Deep Love" : valueInt == 100 ? "100%" : "")
                                                            .padding(.top,valueInt == 100 ? 10 : 0)
                                                            .id(value.index)
                                                            .onAppear {
                                                                biggestIndex = value.count
                                                            }
                                                    } else {
                                                        Text(valueInt == 0 ? "No Love" : valueInt == 20 ? "Slight Love" : valueInt == 50 ? "Close" : valueInt == 73 ? "In Love" : valueInt == 100 ? "100%" : "")
                                                            .padding(.top,valueInt == 100 ? 10 : 0)
                                                            .id(value.index)
                                                            .onAppear {
                                                                biggestIndex = value.count
                                                            }
                                                    }
                                                }
                                            }
                                            AxisMarks(values: relation == "Friend" ? [0, 15, 30, 50, 70, 90, 100] : relation == "Family Member" ? [0, 20, 40, 80, 100] : relation == "Partner" ? [0, 20, 40, 60, 80, 100] : [0, 20, 50, 73, 100]) {
                                                AxisGridLine()
                                            }
                                        }
                                        .chartXAxis {
                                            AxisMarks(values: .stride(by: .day)) { value in
                                                let dateValue = value.as(Date.self) ?? Date()
                                                let monthDay = Calendar.current.component(.day, from: dateValue)
                                                let firstValue = Calendar.current.component(.day, from: preferences.sorted(by: { item1, item2 in item1.1.dateValue() < item2.1.dateValue() }).first?.1.dateValue() as? Date ?? Date())
                                                let isEvenOrNot = (firstValue%2 == 0 && monthDay%2 == 0) || (firstValue%2 == 1 && monthDay%2 == 1)
                                                AxisValueLabel {
                                                    if (monthDay == 1 || value.index == 0 || isEvenOrNot) && value.count > 2 {
                                                        Text(dateFormatter.string(from: dateValue))
                                                    } else if value.count <= 2 {
                                                        Text("\(DateFormatter.localizedString(from: dateValue, dateStyle: .medium, timeStyle: .short))")
                                                    }
                                                }
                                                if monthDay == 1 || value.index == 0 {
                                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                                                } else if isEvenOrNot {
                                                    AxisGridLine()
                                                    AxisTick()
                                                }
                                            }
                                        }
                                    }
                                }
                            } else if preferences.filter({ $0.2 == relation }).count == 1 {
                                VStack {
                                    Text("Test Once More")
                                        .font(.headline)
                                        .padding(.bottom,10)
                                    Text("You just need to test \(document?.data()?["name"] as? String ?? "") one more time and your history will appear!")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal,30)
                                .padding(.bottom,30)
                                .padding(.top,10)
                            } else if preferences.filter({ $0.2 == relation }).count == 0 {
                                VStack {
                                    Text("Test Again")
                                        .font(.headline)
                                        .padding(.bottom,10)
                                    Text("The version of Feelist on which you tested \(document?.data()?["name"] as? String ?? "") is not supported on v0.2. Please test them again.")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal,30)
                                .padding(.bottom,30)
                                .padding(.top,10)
                            } else {
                                VStack {
                                    Text("Please report a bug")
                                        .font(.headline)
                                        .padding(.bottom,10)
                                    Text("This shouldn't be appearing, impressing. Please report a bug from the three dots (top-right corner) > Send Feedback.")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal,30)
                                .padding(.bottom,30)
                                .padding(.top,10)
                            }
                        }
                        .padding(.top,15)
                        .frame(maxWidth: .infinity)
                        .background(colorScheme == .light ? .white : Color(red: 20/255, green: 20/255, blue: 20/255))
                        .cornerRadius(25)
                        .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 10, y: colorScheme == .light ? 5 : 10)
                        .padding(.horizontal,15)
                        .padding(.bottom,25)
                        Divider()
                    }
                    if !list {
                        HStack {
                            Image(systemName: "text.line.last.and.arrowtriangle.forward")
                                .font(.title3)
                                .frame(width: 25)
                                .foregroundStyle(Color.accentColor)
                            Text("Last tested on \(DateFormatter.localizedString(from: lastTime, dateStyle: .medium, timeStyle: .short))")
                        }
                        .padding(.vertical,20)
                        .padding(.bottom,10)
                    }
                    VStack(alignment: .leading) {
                        if !list {
                            Button(action: {
                                showAllData = true
                            }) {
                                Image(systemName: "ellipsis")
                                    .font(.title3)
                                    .frame(width: 25)
                                Text("View All Data")
                                    .foregroundColor(.primary)
                            }
                            .sheet(isPresented: $showAllData) {
                                allData
                                    .presentationCornerRadius(40)
                            }
                            .padding(.bottom,10)
                        }
                        if !list || isOwner {
                            Button(role: .destructive, action: {
                                alertConfirmDeletion = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.title3)
                                    .frame(width: 25)
                                Text("Delete Person")
                                    .foregroundColor(.primary)
                            }
                            .disabled(defaults.offline)
                            .alert("Delete \(document?.data()?["name"] as? String ?? "")\(list ? " from the test" : "")?", isPresented: $alertConfirmDeletion) {
                                Button("Delete", role: .destructive) {
                                    if list {
                                        Firestore.firestore().collection("Workout").document(id).getDocument { document, error in
                                            if error == nil {
                                                let tests = document?.data()?["tests"] as? [String: [String: Any]] ?? [:]
                                                let test = tests.first(where: { $0.key == "data\(listTestIndex)" }).flatMap({ $0 })?.value ?? [:]
                                                if test.count-1 == 1 {
                                                    Firestore.firestore().collection("Workout").document(id).updateData(["tests.data\(listTestIndex)":FieldValue.delete()])
                                                } else {
                                                    Firestore.firestore().collection("Workout").document(id).updateData(["tests.data\(listTestIndex).\(listMetaKey)":FieldValue.delete()])
                                                }
                                            }
                                        }
                                    } else {
                                        Firestore.firestore().collection("Workout").document(id).updateData(["deleted":true])
                                    }
                                    presentationMode.wrappedValue.dismiss()
                                }
                                Button("Cancel", role: .cancel) { }
                            } message: {
                                Text(list ? "Deleting this person from the test will also delete them for everyone in the List.\n\nThis action cannot be undone." : "Are you sure you want to delete this person? This action cannot be undone.\n\n\(document?.data()?["name"] as? String ?? "") will also be deleted for people to who you've shared them.\nTest results you've had may still be included if \(document?.data()?["name"] as? String ?? "") asks to get data uploaded about them.")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal,15)
                    .padding(.bottom,10)
                }
            }
            .navigationTitle(document?.data()?["name"] as? String ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        if !list {
                            Button(action: {
                                showAllData = true
                            }) {
                                Label("View All Data", systemImage: "list.dash")
                            }
                        }
                        if !list || isOwner {
                            Button(role: .destructive, action: {
                                alertConfirmDeletion = true
                            }) {
                                Label("Delete Person", systemImage: "trash")
                            }
                        }
                        if !list || isOwner {
                            Divider()
                        }
                        Button(action: {
                            showHelp = true
                        }) {
                            Label("Help", systemImage: "questionmark.circle")
                        }
                        Button(action: {
                            sheetReport = true
                        }) {
                            Label("Send Feedback", systemImage: "exclamationmark.bubble")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    let lastPref = preferences.sorted { item1, item2 in
                        item1.1.dateValue() > item2.1.dateValue()
                    }.first?.0 as? Double ?? 0.0
                    let string = "I\(relation == "Friend" ? lastPref < 0.15 ? " don't like \(document?.data()?["name"] as? String ?? "")" : lastPref < 0.3 ? " slightly like \(document?.data()?["name"] as? String ?? "")" : lastPref < 0.5 ? " somewhat like \(document?.data()?["name"] as? String ?? "")" : lastPref < 0.7 ? " quite like \(document?.data()?["name"] as? String ?? "")" : lastPref < 0.9 ? " highly like \(document?.data()?["name"] as? String ?? "")" : "'m in love with \(document?.data()?["name"] as? String ?? "")" : relation == "Family Member" ? lastPref <= 0.2 ? "'m not close to \(document?.data()?["name"] as? String ?? "") at all" : lastPref <= 0.4 ? "'m not so close to \(document?.data()?["name"] as? String ?? "")" : lastPref <= 0.8 ? "'m close to \(document?.data()?["name"] as? String ?? "")" : lastPref <= 0.9 ? "'m very close to \(document?.data()?["name"] as? String ?? "")" : " may be the closest to \(document?.data()?["name"] as? String ?? "")" : relation == "Partner" ? lastPref <= 0.2 ? " may not like \(document?.data()?["name"] as? String ?? "")" : lastPref <= 0.4 ? " may not be happy being with \(document?.data()?["name"] as? String ?? "")" : lastPref <= 0.6 ? " may not like being with \(document?.data()?["name"] as? String ?? "") that much" : lastPref <= 0.8 ? " love \(document?.data()?["name"] as? String ?? "") reasonably" : lastPref <= 0.9 ? "'m in true love with \(document?.data()?["name"] as? String ?? "")" : " found the chosen one" : relation == "Other" ? lastPref <= 0.1 ? " \(document?.data()?["name"] as? String ?? "")" : lastPref <= 0.2 ? " slightly love \(document?.data()?["name"] as? String ?? "")" : lastPref <= 0.5 ? " somewhat love \(document?.data()?["name"] as? String ?? "")" : lastPref <= 0.73 ? " quite love \(document?.data()?["name"] as? String ?? "")" : "'m in love with \(document?.data()?["name"] as? String ?? "")'" : " encountered an error").\(relation != "Other" ? " They're my \(relation)." : "")\n\nI'm a tester of “Feelist” from which this was generated.\n\n➡️ Test “Feelist” now:\nhttps://testflight.apple.com/join/wRet2zme"
                    ShareLink(item: string) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(loading)
                }
            }
            .onAppear {
                getDocument()
            }
            .sheet(isPresented: $showHelp) {
                Help(suggestedSection: "Testing/Preferences")
                    .presentationCornerRadius(40)
            }
            .sheet(isPresented: $sheetReport) {
                ReportView()
                    .presentationCornerRadius(40)
            }
        }
    }
    var allData: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("You have tested \(document?.data()?["name"] as? String ?? "") \(preferences.count == 1 ? "once" : preferences.count == 2 ? "twice" : "\(preferences.count) times").")
                        .padding(.vertical,10)
                        .padding(.bottom,10)
                    ForEach(preferences.sorted(by: { item1, item2 in
                        item1.1.dateValue() > item2.1.dateValue()
                    }), id: \.1) { pref in
                        HStack {
                            Text("\(Int(pref.0*100))%")
                                .font(.headline)
                            Text("\(DateFormatter.localizedString(from: pref.1.dateValue(), dateStyle: .medium, timeStyle: .short))")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        Text(pref.2)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Divider()
                            .padding(.vertical,8)
                    }
                }
                .padding(.horizontal,15)
                .padding(.bottom,10)
            }
            .navigationTitle("All Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: {
                        showAllData = false
                    }) {
                        Image(systemName: "xmark")
                            .padding(1)
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                    }
                    .buttonBorderShape(.circle)
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
