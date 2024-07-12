//
//  Details.swift
//  FeelingsApp
//
//  Created by Holygent on 6/27/24.
//

import Foundation
import SwiftUI
import FirebaseFirestore

struct ListDetails: View {
    @Binding var id: String
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var list: DocumentSnapshot? = nil
    @State private var loading = false
    @State private var showHelp = false
    @State private var sheetReport = false
    @State private var sheetTest = false
    @State private var firstCreator = ""
    @State private var loadingTest = false
    @State private var startTest = false
    @State private var sheetStats = false
    @State private var alertQuitOrLeave = false
    @State private var sheetSettings = false
    @State private var hideTests = false
    @State private var tests: [String: [String: Any]] = [:]
    @State private var navigateToTestDetails = false
    @State private var selectedTest: [String: [String: Any]] = [:]
    @State private var isOwner = false
    @Environment(Defaults.self) var defaults
    func getList() {
        withAnimation {
            loading = true
            loadingTest = true
        }
        var wasTesting = false
        Firestore.firestore().collection("Workout").whereField(FieldPath.documentID(), isEqualTo: id).addSnapshotListener { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    querySnapshot?.documentChanges.forEach { diff in
                        if ((document.data()["removedUsers"] as? [String] ?? []).contains(defaults.userID) || document.data()["deleted"] as? Bool ?? false || !(document.data()["users"] as? [String] ?? []).contains(defaults.userID)) {
                            presentationMode.wrappedValue.dismiss()
                        }
                        let orgTesters = list?.data()?["currentTesters"] as? [String] ?? []
                        if !(document.data()["nowTesting"] as? Bool ?? false) && orgTesters.contains(defaults.userID) && (document.data()["currentTesters"] as? [String] ?? []).count == 0 && (document.data()["testCreator"] as? String ?? "").isEmpty {
                            sheetTest = false
                        }
                        withAnimation {
                            loadingTest = true
                            list = document
                            tests = document.data()["tests"] as? [String: [String: Any]] ?? [:]
                        }
                        isOwner = list?.data()?["listOwner"] as? String ?? "" == defaults.userID
                        if diff.type == .modified {
                            if document.data()["nowTesting"] as? Bool ?? false && (document.data()["currentTesters"] as? [String] ?? []).contains(defaults.userID) {
                                if !wasTesting {
                                    startTest = true
                                }
                            } else {
                                startTest = false
                            }
                            wasTesting = document.data()["nowTesting"] as? Bool ?? false
                        }
                        withAnimation {
                            loadingTest = false
                        }
                    }
                }
                withAnimation {
                    loading = false
                }
            }
        }
    }
    let dateFormatter: DateFormatter = {
        let dF = DateFormatter()
        dF.dateFormat = "MMM d"
        return dF
    }()
    var body: some View {
        NavigationStack {
            let string = "See how much you love people with me by joining \(isOwner ? "my" : "the") “\(list?.data()?["name"] as? String ?? "")” List on Feelist!\n\nIf you have the app installed:\n➡️ feelingsApp:///joinList/\(list?.documentID ?? "")\n\nIf you don't have the app installed yet:\n➡️ https://testflight.apple.com/join/wRet2zme\n\n\nRequires Feelist v0.2 or later installed on iOS 17.0 or later or iPadOS 17.0 or later.\nThis is a Beta."
            ScrollView {
                VStack(alignment: .center) {
                    if loading {
                        ProgressView()
                            .padding(15)
                            .frame(maxWidth: .infinity)
                    }
                    Text(list?.data()?["icon"] as? String ?? "")
                        .font(.system(size: 60))
                        .frame(width: 0.35*UIScreen.main.bounds.width, height: 0.35*UIScreen.main.bounds.width)
                        .background(colorScheme == .light ? Color(red: 220/255, green: 220/255, blue: 220/255) : Color(red: 50/255, green: 50/255, blue: 50/255))
                        .cornerRadius(25)
                        .padding(30)
                    Text(list?.data()?["name"] as? String ?? "")
                        .font(.title.bold())
                        .padding(.bottom,(list?.data()?["description"] as? String ?? "").isEmpty ? 30 : 2)
                    if !(list?.data()?["description"] as? String ?? "").isEmpty {
                        Text(list?.data()?["description"] as? String ?? "")
                            .padding(.bottom,30)
                    }
                    HStack {
                        Button(action: {
                            sheetTest = true
                        }) {
                            Text((list?.data()?["currentTesters"] as? [String] ?? []).count > 0 ? "Join Test" : "Test")
                                .font(.headline)
                                .padding(.vertical,8)
                                .padding(.horizontal,20)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .disabled(!(list?.data()?["editable"] as? Bool ?? false) || defaults.offline)
                        ShareLink(item: string) {
                            Image(systemName: "square.and.arrow.up")
                                .padding(5)
                                .font(.title3)
                        }
                        .fontWeight(.medium)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .disabled(!(list?.data()?["isPublic"] as? Bool ?? false) && list?.data()?["listOwner"] as? String ?? "" != defaults.userID)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal,15)
                .padding(.bottom,20)
                Divider()
                    .padding(.vertical,15)
                if tests.count == 0 {
                    VStack {
                        Image(systemName: "person.fill.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.accentColor)
                            .padding(30)
                            .padding(.top,10)
                        Text("Let's test someone.")
                            .font(.title.bold())
                            .padding(.bottom,20)
                        Text("Test a friend, family member, or partner to see how much you love them.")
                            .font(.subheadline)
                            .padding(.bottom,20)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal,15)
                    .padding(.bottom,10)
                } else {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 0) {
                            Text("Tests")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(action: {
                                withAnimation {
                                    hideTests.toggle()
                                }
                            }) {
                                Image(systemName: "chevron.up")
                                    .font(.subheadline.bold())
                                    .rotationEffect(hideTests ? .degrees(180) : .degrees(0))
                                    .padding(2)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                        }
                        if !hideTests {
                            ForEach(tests.sorted(by: { Int($0.key.replacingOccurrences(of: "data", with: "")) ?? 0 > Int($1.key.replacingOccurrences(of: "data", with: "")) ?? 0 }), id: \.key) { test in
                                NavigationLink(destination: TestDetailsL(test: $selectedTest, isOwner: $isOwner, forList: list?.documentID ?? "")) {
                                    HStack {
                                        ZStack {
                                            let dividedIcons = test.value.filter({ $0.key != "DATE_UPDTAKEN" }).compactMap({ $0.key }).sorted(by: <)
                                            if dividedIcons.count == 1 {
                                                Circle()
                                                    .fill(LinearGradient(colors: colorScheme == .light ? [.gray.opacity(0.5), .gray.opacity(0.85)] : [.white.opacity(0.75), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                                    .frame(width: 50, height: 50)
                                                Text("\((test.value.filter({ $0.key != "DATE_UPDTAKEN" }).keys.first ?? "").trimmingCharacters(in: .whitespaces).components(separatedBy: " ").compactMap({ String($0.first ?? Character("")) }).joined().uppercased())")
                                                    .font(.system(size: 20))
                                                    .fontDesign(.rounded)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white)
                                            } else {
                                                let size = 50/(2.squareRoot())
                                                Circle()
                                                    .fill(colorScheme == .light ? .gray.opacity(0.125) : .white.opacity(0.125))
                                                    .frame(width: 50, height: 50)
                                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                                                    ForEach(dividedIcons.prefix(4), id: \.self) { icon in
                                                        ZStack {
                                                            Circle()
                                                                .fill(LinearGradient(colors: colorScheme == .light ? [.gray.opacity(0.5), .gray.opacity(0.85)] : [.white.opacity(0.75), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                                                .rotationEffect(.degrees(dividedIcons.count == 2 ? -30 : 0))
                                                            Text("\(icon.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").compactMap({ String($0.first ?? Character("")) }).joined().uppercased())")
                                                                .font(.system(size: 9))
                                                                .fontDesign(.rounded)
                                                                .fontWeight(.medium)
                                                                .foregroundColor(.white)
                                                                .rotationEffect(.degrees(dividedIcons.count == 2 ? -30 : 0))
                                                        }
                                                        .frame(width: 0.5*size, height: 0.5*size)
                                                        .padding(1)
                                                    }
                                                }
                                                .frame(width: size, height: size)
                                                .rotationEffect(.degrees(dividedIcons.count == 2 ? 30 : 0))
                                            }
                                        }
                                        Text("\(test.value.filter({ $0.key != "DATE_UPDTAKEN" }).compactMap({ $0.key }).sorted(by: <).joined(separator: ", "))")
                                            .lineLimit(3)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .multilineTextAlignment(.leading)
                                        Text("\(dateFormatter.string(from: (test.value.filter({ $0.key == "DATE_UPDTAKEN" }).values.first as? Timestamp ?? Timestamp()).dateValue()))")
                                            .foregroundColor(.secondary)
                                        Image(systemName: "chevron.right")
                                    }
                                }
                                .simultaneousGesture(TapGesture().onEnded({
                                    selectedTest[test.key] = test.value
                                }))
                                if test.key != tests.compactMap({ $0.key }).min(by: { Int($0.replacingOccurrences(of: "data", with: "")) ?? 0 < Int($1.replacingOccurrences(of: "data", with: "")) ?? 0 }) {
                                    Divider()
                                        .padding(.vertical,2)
                                        .padding(.horizontal,5)
                                }
                            }
                        }
                    }
                    .padding(.horizontal,15)
                    .frame(maxWidth: .infinity)
                }
                Divider()
                    .padding(.vertical,15)
                Button(role: .destructive, action: {
                    alertQuitOrLeave = true
                }) {
                    Text(isOwner ? "Delete List" : "Leave List")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: isOwner ? "trash" : "rectangle.portrait.and.arrow.forward")
                }
                .padding(.bottom,10)
                .padding(.horizontal,15)
                .disabled(defaults.offline)
            }
            .navigationTitle(list?.data()?["name"] as? String ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button(action: {
                            sheetStats = true
                        }) {
                            Label("Stats", systemImage: "chart.bar.xaxis")
                        }
                        if isOwner {
                            Button(action: {
                                sheetSettings = true
                            }) {
                                Label("Settings", systemImage: "gearshape.fill")
                            }
                            .disabled(defaults.offline)
                        }
                        Divider()
                        Button(role: .destructive, action: {
                            alertQuitOrLeave = true
                        }) {
                            Label(isOwner ? "Delete List" : "Leave List", systemImage: isOwner ? "trash" : "rectangle.portrait.and.arrow.forward")
                        }
                        .disabled(defaults.offline)
                        Divider()
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
                    ShareLink(item: string) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(!(list?.data()?["isPublic"] as? Bool ?? false) && list?.data()?["listOwner"] as? String ?? "" != defaults.userID)
                }
            }
            .onAppear {
                getList()
            }
            .alert("Are you sure you want to \(isOwner ? "delete the List" : "leave the List")?", isPresented: $alertQuitOrLeave) {
                Button(isOwner ? "Delete" : "Leave", role: .destructive) {
                    let updatedUsers = (list?.data()?["users"] as? [String] ?? []).filter({ $0 != defaults.userID })
                    Firestore.firestore().collection("Workout").document(id).updateData(isOwner ? ["deleted":true] : ["users":updatedUsers])
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(isOwner ? "Deleting your List will also delete it for everyone who joined it.\n\nThis action cannot be undone." : "You can join the List again by tapping its link.")
            }
            .sheet(isPresented: $showHelp) {
                Help(suggestedSection: "Lists")
                    .presentationCornerRadius(40)
            }
            .sheet(isPresented: $sheetReport) {
                ReportView()
                    .presentationCornerRadius(40)
            }
            .sheet(isPresented: self.$sheetStats) {
                StatsL(list: list)
                    .presentationCornerRadius(40)
            }
            .sheet(isPresented: self.$sheetSettings) {
                SettingsL(forList: id)
                    .presentationCornerRadius(40)
            }
            .sheet(isPresented: self.$sheetTest, onDismiss: {
                if list?.data()?["testCreator"] as? String ?? "" == defaults.userID || ((list?.data()?["currentTesters"] as? [String] ?? []).first == defaults.userID && (list?.data()?["currentTesters"] as? [String] ?? []).count == 1) {
                    Firestore.firestore().collection("Workout").document(id).updateData(["nowTesting":false, "currentTesters":[], "testCreator":FieldValue.delete(), "proposedNames":FieldValue.delete()])
                } else if (list?.data()?["currentTesters"] as? [String] ?? []).contains(defaults.userID) {
                    let updatedTesters = (list?.data()?["currentTesters"] as? [String] ?? []).filter({ $0 != defaults.userID })
                    let updatedNames = (list?.data()?["proposedNames"] as? [String: String] ?? [:]).filter({ $0.key != defaults.userID })
                    Firestore.firestore().collection("Workout").document(id).updateData(["currentTesters":updatedTesters, "proposedNames":updatedNames])
                }
            }) {
                MainL(list: $list, loading: $loadingTest, startTest: $startTest)
                    .presentationCornerRadius(40)
            }
        }
    }
}
