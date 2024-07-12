//
//  Lists.swift
//  FeelingsApp
//
//  Created by Holygent on 6/27/24.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import Network

struct TestDetailsL: View {
    @Binding var test: [String: [String: Any]]
    @Binding var isOwner: Bool
    let forList: String
    @State private var alertDelete = false
    @State private var sheetHelp = false
    @State private var sheetFeedback = false
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var hideResults = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Test Results")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Taken on \(DateFormatter.localizedString(from: (test.first.map({ $0.value })?.first(where: { $0.key == "DATE_UPDTAKEN" })?.value as? Timestamp ?? Timestamp()).dateValue(), dateStyle: .medium, timeStyle: .short))")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .padding(.bottom,10)
                    if !hideResults {
                        ForEach((test.first.flatMap({ $0.value })?.filter({ $0.key != "DATE_UPDTAKEN" }) as? [String: Any] ?? [:]).sorted(by: { $0.value as? Double ?? 0.0 > $1.value as? Double ?? 0.0 }), id: \.key) { result in
                            NavigationLink(destination: AppreciationDetails(id: forList, list: true, listMetaKey: result.key, listMetaV: result.value as? Double ?? 0.0, listTestIndex: Int((test.keys.first ?? "").replacingOccurrences(of: "data", with: "")) ?? 0)) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(colors: colorScheme == .light ? [.gray.opacity(0.5), .gray.opacity(0.85)] : [.white.opacity(0.75), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                            .frame(width: 50, height: 50)
                                        Text("\(result.key.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").compactMap({ String($0.first ?? Character("")) }).joined().uppercased())")
                                            .font(.system(size: 20))
                                            .fontDesign(.rounded)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                    }
                                    Text(result.key)
                                        .lineLimit(3)
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                    Text("\(Int((result.value as? Double ?? 0.0)*100))%")
                                        .foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                }
                            }
                            Divider()
                                .padding(.vertical,2)
                                .padding(.horizontal,5)
                        }
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Test #\((Int((test.keys.first ?? "").replacingOccurrences(of: "data", with: "")) ?? 0)+1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        if isOwner {
                            Button(role: .destructive, action: {
                                alertDelete = true
                            }) {
                                Label("Delete test", systemImage: "trash")
                            }
                            Divider()
                        }
                        Button(action: {
                            sheetHelp = true
                        }) {
                            Label("Help", systemImage: "questionmark.circle")
                        }
                        Button(action: {
                            sheetFeedback = true
                        }) {
                            Label("Send Feedback", systemImage: "exclamationmark.bubble")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $sheetHelp) {
                Help(suggestedSection: "Lists")
                    .presentationCornerRadius(40)
            }
            .sheet(isPresented: $sheetFeedback) {
                ReportView()
                    .presentationCornerRadius(40)
            }
            .alert("Delete this test?", isPresented: $alertDelete) {
                Button("Delete", role: .destructive) {
                    Firestore.firestore().collection("Workout").document(forList).getDocument { document, error in
                        if error == nil {
                            let tests = (document?.data()?["tests"] as? [String: [String: Any]] ?? [:])
                            Firestore.firestore().collection("Workout").document(forList).updateData(["tests":tests.filter({ $0.key != test.keys.first })])
                            if document?.data()?["nowTesting"] as? Bool ?? false && test.keys.first == tests.sorted(by: { Int($0.key.replacingOccurrences(of: "data", with: "")) ?? 0 > Int($1.key.replacingOccurrences(of: "data", with: "")) ?? 0 }).first?.key {
                                Firestore.firestore().collection("Workout").document(forList).updateData(["nowTesting":false, "proposedNames":[], "currentTesters":[], "testCreator":FieldValue.delete()])
                            }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Deleting this test will also delete it for everyone in the List.\nIf the test is running, it will be stopped for everyone testing.\n\nThis action cannot be undone.")
            }
        }
    }
}

struct SettingsL: View {
    let forList: String
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var pickAnIcon = false
    @State private var listName = ""
    @State private var listDesc = ""
    let icons = ["😀", "😊", "🧐", "🫨", "😮", "😵‍💫", "🥇", "🚫", "🤢", "😱", "🥳", "🤯", "🥰", "❤️", "🔥", "😎", "👀", "😭", "💣", "🧑‍💻", "🤞", "🤪", "🤬", "🥵", "🤌", "💪", "🍆", "🍒", "🍓", "🍑", "🏀", "🎯", "🥺", "💀", "📸", "🤤", "🫣", "💸", "💯", "💅", "👙", "💦", "🚨"]
    @State private var selectedIcon = "🔥"
    @State private var editable = false
    @State private var locked = false
    @FocusState private var focus: Bool
    @FocusState private var focus1: Bool
    @State private var loading = false
    @State private var document: DocumentSnapshot? = nil
    @State private var alertDelete = false
    @State private var alertRemoveUsers = false
    @State private var showUsers = false
    @State private var showBannedUsers = false
    @State private var removeUser = ""
    @State private var alertRemoveUser = false
    @State private var changeOwner = false
    @State private var makeOwner = ""
    @State private var alertMakeOwner = false
    @Environment(Defaults.self) var defaults
    func getList() {
        withAnimation {
            loading = true
        }
        Firestore.firestore().collection("Workout").document(forList).getDocument { document, error in
            if error == nil {
                withAnimation {
                    self.document = document
                    selectedIcon = document?.data()?["icon"] as? String ?? ""
                    listName = document?.data()?["name"] as? String ?? ""
                    listDesc = document?.data()?["description"] as? String ?? ""
                    editable = document?.data()?["editable"] as? Bool ?? false
                    locked = (document?.data()?["isPublic"] as? Bool ?? false) ? false : true
                    loading = false
                }
            }
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                if loading {
                    ProgressView()
                        .padding(15)
                }
                VStack(alignment: .leading) {
                    VStack {
                        Button(action: {
                            pickAnIcon = true
                        }) {
                            ZStack {
                                Text(selectedIcon)
                                    .font(.system(size: 72))
                                Image(systemName: "pencil")
                                    .font(.title3.bold())
                                    .padding(20)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            }
                            .frame(width: 0.45*UIScreen.main.bounds.width, height: 0.45*UIScreen.main.bounds.width)
                            .background(colorScheme == .light ? Color(red: 220/255, green: 220/255, blue: 220/255) : Color(red: 50/255, green: 50/255, blue: 50/255))
                            .cornerRadius(30)
                            .padding(20)
                        }
                        ZStack {
                            TextField("Name your List", text: $listName)
                                .focused($focus)
                                .submitLabel(.done)
                                .onSubmit {
                                    if !listName.trimmingCharacters(in: .whitespaces).isEmpty {
                                        Firestore.firestore().collection("Workout").document(forList).updateData(["name":listName.trimmingCharacters(in: .whitespaces)])
                                    }
                                }
                                .font(.title.bold())
                                .multilineTextAlignment(.center)
                            Button(action: {
                                focus = true
                            }) {
                                Image(systemName: "pencil")
                                    .font(.title3.bold())
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.top,10)
                        .padding(.bottom,5)
                        ZStack {
                            TextField("Add a description", text: $listDesc)
                                .focused($focus1)
                                .submitLabel(.done)
                                .onSubmit {
                                    if !listDesc.trimmingCharacters(in: .whitespaces).isEmpty {
                                        Firestore.firestore().collection("Workout").document(forList).updateData(["description":listDesc.trimmingCharacters(in: .whitespaces)])
                                    }
                                }
                                .multilineTextAlignment(.center)
                            Button(action: {
                                focus1 = true
                            }) {
                                Image(systemName: "pencil")
                                    .font(.title3.bold())
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.bottom,20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal,15)
                    Divider()
                        .padding(.vertical,10)
                    VStack(alignment: .leading) {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Color.accentColor)
                            Text("Sharing")
                        }
                        .font(.title3.bold())
                        .padding(.bottom,5)
                        Toggle("Lock List", isOn: $locked)
                            .tint(Color.accentColor)
                            .onChange(of: locked) { oldValue, newValue in
                                if newValue != oldValue {
                                    Firestore.firestore().collection("Workout").document(forList).updateData(["isPublic":locked ? false : true])
                                }
                            }
                        Text("Prevents anyone from joining the List.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal,15)
                    .multilineTextAlignment(.leading)
                    Divider()
                        .padding(.vertical,10)
                    VStack(alignment: .leading) {
                        HStack(spacing: 5) {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(Color.accentColor)
                            Text("Members")
                        }
                        .font(.title3.bold())
                        .padding(.bottom,5)
                        Toggle("Allow testing", isOn: $editable)
                            .tint(Color.accentColor)
                            .onChange(of: editable) { oldValue, newValue in
                                if newValue != oldValue {
                                    Firestore.firestore().collection("Workout").document(forList).updateData(["editable":editable])
                                }
                            }
                            .padding(.bottom,10)
                        Button(action: {
                            withAnimation {
                                showUsers.toggle()
                            }
                        }) {
                            Text("View Members")
                                .foregroundStyle(Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.up")
                                .rotationEffect(!showUsers ? .degrees(180) : .degrees(0))
                        }
                        .padding(.bottom,10)
                        if showUsers {
                            if (document?.data()?["users"] as? [String] ?? []).count == 0 {
                                let isOwner = document?.data()?["listOwner"] as? String ?? "" == defaults.userID
                                let string = "See how much you love people with me by joining \(isOwner ? "my" : "the") “\(listName)” List on Feelist!\n\nIf you have the app installed:\n➡️ feelingsApp:///joinList/\(forList)\n\nIf you don't have the app installed yet:\n➡️ https://testflight.apple.com/join/wRet2zme\n\n\nRequires Feelist v0.2 or later installed on iOS 17.0 or later or iPadOS 17.0 or later.\nThis is a Beta."
                                ShareLink(item: string) {
                                    Text("Invite people")
                                        .padding(.vertical,5)
                                }
                                .padding(.bottom,10)
                            }
                            VStack(alignment: .leading) {
                                ForEach((document?.data()?["users"] as? [String] ?? []).filter({ !(document?.data()?["removedUsers"] as? [String] ?? []).contains($0) }), id: \.self) { user in
                                    Button(role: .destructive, action: {
                                        if user != defaults.userID {
                                            removeUser = user
                                            alertRemoveUser = true
                                        }
                                    }) {
                                        Text(user)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .multilineTextAlignment(.leading)
                                            .foregroundStyle(Color.primary)
                                        if user != defaults.userID {
                                            Image(systemName: "rectangle.portrait.and.arrow.forward")
                                        }
                                    }
                                    .font(.subheadline)
                                    Divider()
                                        .padding(.vertical,5)
                                }
                                .padding(.horizontal,10)
                            }
                            .padding(.bottom,10)
                        }
                        Button(action: {
                            withAnimation {
                                showBannedUsers.toggle()
                            }
                        }) {
                            Text("View Banned Members")
                                .foregroundStyle(Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.up")
                                .rotationEffect(!showBannedUsers ? .degrees(180) : .degrees(0))
                        }
                        .padding(.bottom,showBannedUsers ? 10 : 0)
                        if showBannedUsers {
                            if (document?.data()?["removedUsers"] as? [String] ?? []).count == 0 {
                                Button(action: {
                                    withAnimation {
                                        showUsers = true
                                    }
                                }) {
                                    (Text("No one was banned.").foregroundStyle(Color.primary) + Text(" Ban someone"))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical,5)
                                }
                            }
                            ForEach(document?.data()?["removedUsers"] as? [String] ?? [], id: \.self) { user in
                                Button(action: {
                                    Firestore.firestore().collection("Workout").document(forList).updateData(["removedUsers":(document?.data()?["removedUsers"] as? [String] ?? []).filter({ $0 != user })])
                                    getList()
                                }) {
                                    Text(user)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                        .foregroundStyle(Color.primary)
                                    Image(systemName: "arrow.counterclockwise")
                                }
                                Divider()
                                    .padding(.vertical,5)
                            }
                            .padding(.horizontal,10)
                        }
                    }
                    .padding(.horizontal,15)
                    .multilineTextAlignment(.leading)
                    Divider()
                        .padding(.vertical,10)
                    VStack(alignment: .leading) {
                        HStack(spacing: 5) {
                            Image(systemName: "shield.fill")
                                .foregroundStyle(Color.accentColor)
                            Text("Ownership")
                        }
                        .font(.title3.bold())
                        .padding(.bottom,5)
                        Button(action: {
                            withAnimation {
                                changeOwner.toggle()
                            }
                        }) {
                            Text("Change List Owner")
                                .foregroundStyle(Color.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.up")
                                .rotationEffect(!changeOwner ? .degrees(180) : .degrees(0))
                        }
                        .padding(.bottom,changeOwner ? 10 : 0)
                        if changeOwner {
                            if (document?.data()?["users"] as? [String] ?? []).count == 0 {
                                let isOwner = document?.data()?["listOwner"] as? String ?? "" == defaults.userID
                                let string = "See how much you love people with me by joining \(isOwner ? "my" : "the") “\(listName)” List on Feelist!\n\nIf you have the app installed:\n➡️ feelingsApp:///joinList/\(forList)\n\nIf you don't have the app installed yet:\n➡️ https://testflight.apple.com/join/wRet2zme\n\n\nRequires Feelist v0.2 or later installed on iOS 17.0 or later or iPadOS 17.0 or later.\nThis is a Beta."
                                ShareLink(item: string) {
                                    Text("Invite people")
                                        .padding(.vertical,5)
                                }
                                .padding(.bottom,10)
                            }
                            VStack(alignment: .leading) {
                                ForEach((document?.data()?["users"] as? [String] ?? []).filter({ !(document?.data()?["removedUsers"] as? [String] ?? []).contains($0) && $0 != defaults.userID }), id: \.self) { user in
                                    Button(action: {
                                        makeOwner = user
                                        alertMakeOwner = true
                                    }) {
                                        Text(user)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .multilineTextAlignment(.leading)
                                            .foregroundStyle(Color.primary)
                                        Image(systemName: "checkmark.shield.fill")
                                    }
                                    .font(.subheadline)
                                    Divider()
                                        .padding(.vertical,5)
                                }
                                .padding(.horizontal,10)
                            }
                            .padding(.bottom,10)
                        }
                    }
                    .padding(.horizontal,15)
                    .multilineTextAlignment(.leading)
                    Divider()
                        .padding(.vertical,10)
                    VStack(alignment: .leading, spacing: 0) {
                        Button(role: .destructive, action: {
                            alertDelete = true
                        }) {
                            Text("Delete List")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "trash")
                        }
                        .padding(.bottom,10)
                        Button(role: .destructive, action: {
                            alertRemoveUsers = true
                        }) {
                            Text("Remove or Ban members")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "trash")
                        }
                    }
                    .padding(.horizontal,15)
                    .padding(.bottom,15)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                getList()
            }
            .toolbar {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .padding(1)
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
            .sheet(isPresented: $pickAnIcon) {
                iconPicker
                    .presentationCornerRadius(40)
                    .presentationDetents([.medium, .large])
            }
            .alert("Delete List?", isPresented: $alertDelete) {
                Button("Delete", role: .destructive) { Firestore.firestore().collection("Workout").document(forList).updateData(["deleted":true]) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Deleting your List will also delete it for everyone who joined it.\n\nThis action cannot be undone.")
            }
            .alert("What would you like to do?", isPresented: $alertRemoveUsers) {
                Button("Remove all members", role: .destructive) { Firestore.firestore().collection("Workout").document(forList).updateData(["users":[defaults.userID]]); getList() }
                Button("Ban all members", role: .destructive) { Firestore.firestore().collection("Workout").document(forList).updateData(["removedUsers":(document?.data()?["users"] as? [String] ?? []).filter({ $0 != defaults.userID })]); getList() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Removing all members of the List allows them to rejoin it whenever they want.\nThis action cannot be undone.\n\nBanning all members of the List prevents them to rejoin it. If you want them back, you'll have to unban them.")
            }
            .alert("Ban member?", isPresented: $alertRemoveUser) {
                Button("Ban", role: .destructive) {
                    Firestore.firestore().collection("Workout").document(forList).updateData(["removedUsers":([removeUser] + (document?.data()?["removedUsers"] as? [String] ?? []))])
                    if document?.data()?["nowTesting"] as? Bool ?? false == true && (document?.data()?["testCreator"] as? String ?? "" == removeUser || ((document?.data()?["testCreator"] as? String ?? "").isEmpty && (document?.data()?["currentTesters"] as? [String] ?? []).contains(removeUser))) {
                        Firestore.firestore().collection("Workout").document(forList).updateData(["nowTesting":false, "currentTesters":[], "testCreator":FieldValue.delete(), "proposedNames":FieldValue.delete()])
                    }
                    getList()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Banning “\(removeUser)” will prevent them from using the List.\nAt any time, you can unban them.")
            }
            .alert("Make List owner?", isPresented: $alertMakeOwner) {
                Button("Make owner") { Firestore.firestore().collection("Workout").document(forList).updateData(["listOwner":makeOwner]); presentationMode.wrappedValue.dismiss() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to make “\(makeOwner)” the List owner?\n\nYou'll lose ownership, thus all owner actions will be unavailable to you.\nThis action cannot be undone.")
            }
            .onChange(of: selectedIcon) { oldValue, newValue in
                if newValue != oldValue {
                    Firestore.firestore().collection("Workout").document(forList).updateData(["icon":selectedIcon])
                }
            }
        }
    }
    var iconPicker: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 40) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: {
                            withAnimation {
                                selectedIcon = icon
                            }
                            pickAnIcon = false
                        }) {
                            Text(icon)
                                .font(.largeTitle)
                        }
                    }
                }
                .padding(.horizontal,40)
                .padding(.vertical,10)
            }
            .navigationTitle("Pick an Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        pickAnIcon = false
                    }) {
                        Image(systemName: "xmark")
                            .padding(1)
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }
            }
        }
    }
}

struct StatsL: View {
    let list: DocumentSnapshot?
    @Environment(\.presentationMode) var presentationMode
    @Environment(Defaults.self) var defaults
    func stats(isOwner: Bool) -> [(icon: String, name: String, description: String, id: String)] {
        var stats2: [(icon: String, name: String, description: String, id: String)] = []
        if isOwner {
            stats2.append(("person.badge.shield.checkmark.fill", "Owner", "\(defaults.userID) (You)", UUID().uuidString))
        }
        let creationDate = DateFormatter.localizedString(from: (list?.data()?["creationDate"] as? Timestamp ?? Timestamp()).dateValue(), dateStyle: .medium, timeStyle: .short)
        let users = list?.data()?["users"] as? [String] ?? []
        let tests = (list?.data()?["tests"] as? [String: [String: Any]] ?? [:])
        let lastDate = ((list?.data()?["tests"] as? [String: [String: Any]] ?? [:]).filter({ $0.key.replacingOccurrences(of: "data", with: "") == "\((list?.data()?["tests"] as? [String: [String: Any]] ?? [:]).count-1)" }).values.first?.first(where: { $0.key == "DATE_UPDTAKEN" })?.value as? Timestamp ?? Timestamp()).dateValue()
        let testsDescription = "\(tests.count) taken\(tests.count > 0 ? " — Last taken on \(DateFormatter.localizedString(from: lastDate, dateStyle: .medium, timeStyle: .short))" : "")"
        stats2.append(("plus.app.fill", "Created", creationDate, UUID().uuidString))
        stats2.append(("checklist.checked", "Tests", testsDescription, UUID().uuidString))
        stats2.append(("person.3.fill", "\(users.count) Members", users.joined(separator: ", "), UUID().uuidString))
        let isPublic = list?.data()?["isPublic"] as? Bool ?? false
        stats2.append(("lock.\(isPublic ? "open." : "")fill", "List \(isPublic ? "Not " : "")Locked", "\(isPublic ? "Anyone can join the List with its link. Anyone in the List can invite others." : "No one can join the List, but current members can still interact with it.")", UUID().uuidString))
        let editable = list?.data()?["editable"] as? Bool ?? false
        stats2.append(("pencil\(!editable ? ".slash" : "")", "Can\(!editable ? "not" : "") be Edited", "When the List cannot be edited, no one can test. Note: Anyone can still join the List if it's not locked.", UUID().uuidString))
        return stats2
    }
    var body: some View {
        NavigationStack {
            let isOwner = list?.data()?["listOwner"] as? String ?? "" == defaults.userID
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(stats(isOwner: isOwner), id: \.id) { stat in
                        VStack(alignment: .leading, spacing: 0) {
                            Image(systemName: stat.icon)
                                .font(.system(size: 40))
                                .foregroundStyle(Color.accentColor)
                                .padding(.bottom,10)
                            Text(stat.name)
                                .font(.title3.bold())
                                .padding(.bottom,2)
                            Text(stat.description)
                                .font(.subheadline)
                            Divider()
                                .padding(.vertical,25)
                        }
                        .padding(.horizontal,10)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal,15)
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .padding(1)
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
        }
    }
}

struct MainL: View {
    @Binding var list: DocumentSnapshot?
    @Binding var loading: Bool
    @Binding var startTest: Bool
    @Environment(\.presentationMode) var presentationMode
    @Environment(Defaults.self) var defaults
    @State private var alertConfirmForceStop = false
    @State private var alertForceStopped = false
    @State private var alertErrForceStopping = false
    @State private var alertErrForceStoppingDesc = ""
    @State private var orgCreator = ""
    @State private var alertQuit = false
    func getFirstCreator() {
        if orgCreator.isEmpty {
            let testCreator = (list?.data()?["testCreator"] as? String ?? "")
            let firstTester = (list?.data()?["currentTesters"] as? [String] ?? []).first ?? ""
            orgCreator = testCreator.isEmpty ? firstTester : testCreator
        }
    }
    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView()
                        .padding(15)
                } else {
                    if (list?.data()?["currentTesters"] as? [String] ?? []).contains(defaults.userID) {
                        userTesting
                        //if a user has selected `Test with Friends`, `Test Alone`, or `Join Test` or if test was force-stopped by another user
                        //can hv alert as soon as whole test logic is emptied for force-stopping
                    } else {
                        if list?.data()?["nowTesting"] as? Bool ?? false {
                            testRunning
                            //if a test is already running, can here be force-stopped by current tester who's listOwner
                        } else {
                            if (list?.data()?["currentTesters"] as? [String] ?? []).count == 0 {
                                testPicker
                                //if no test is running at the moment and there's no testCreator
                            } else if !(list?.data()?["testCreator"] as? String ?? "").isEmpty {
                                joinTest
                                //if no test is running but there's a testCreator
                            }
                        }
                    }
                }
            }
            .onAppear {
                getFirstCreator()
            }
            .multilineTextAlignment(.center)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        if (list?.data()?["currentTesters"] as? [String] ?? []).contains(defaults.userID) && (list?.data()?["currentTesters"] as? [String] ?? []).count > 1 {
                            alertQuit = true
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .padding(1)
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }
            }
            .alert("Are you sure you want to force-stop this test?", isPresented: $alertConfirmForceStop) {
                Button("Force-stop", role: .destructive) {
                    Firestore.firestore().collection("Workout").document(list?.documentID ?? "").updateData(["nowTesting":false, "currentTesters":[], "testCreator":FieldValue.delete(), "proposedNames":FieldValue.delete()]) { error in
                        if error == nil {
                            alertForceStopped = true
                        } else {
                            alertErrForceStoppingDesc = "“\(error?.localizedDescription ?? "")”"
                            alertErrForceStopping = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Force-stopping this test will reset everyone's progress and won't be saved.")
            }
            .alert("The test was force-stopped.\(orgCreator != defaults.userID ? " Ban its creator from the List?" : "")", isPresented: $alertForceStopped) {
                if orgCreator != defaults.userID {
                    Button("Ban") { Firestore.firestore().collection("Workout").document(list?.documentID ?? "").updateData(["users":(list?.data()?["users"] as? [String] ?? []).filter( { $0 != orgCreator })]) }
                }
                Button("Done", role: .cancel) { }
            } message: {
                Text("Would you like to ban the test creator from the List?\nThis is useful if they were abusing.\n\nYou can unban them anytime in the List Settings.")
            }
            .alert("An error occured", isPresented: $alertErrForceStopping) {
                Button("OK") { }
            } message: {
                Text("The test couldn't be force-stopped. This may be because it was stopped or finished.\n\nMore:\n\(alertErrForceStoppingDesc)")
            }
            .alert(list?.data()?["testCreator"] as? String ?? "" == defaults.userID || ((list?.data()?["currentTesters"] as? [String] ?? []).first == defaults.userID && (list?.data()?["currentTesters"] as? [String] ?? []).count == 1) ? "Stop test?" : "Quit test?", isPresented: $alertQuit) {
                Button(list?.data()?["testCreator"] as? String ?? "" == defaults.userID || ((list?.data()?["currentTesters"] as? [String] ?? []).first == defaults.userID && (list?.data()?["currentTesters"] as? [String] ?? []).count == 1) ? "Stop" : "Quit", role: .destructive) {
                    presentationMode.wrappedValue.dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(list?.data()?["testCreator"] as? String ?? "" == defaults.userID || ((list?.data()?["currentTesters"] as? [String] ?? []).first == defaults.userID && (list?.data()?["currentTesters"] as? [String] ?? []).count == 1) ? "If you stop this test, neither your nor others' progress will be saved and the test will be stopped for everyone." : "Your progress won't be saved.")
            }
            .navigationDestination(isPresented: $startTest) {
                AddAppreciation(nameTest: CurrentTest())
            }
        }
    }
    var userTesting: some View {
        ScrollView {
            let isCreator = list?.data()?["testCreator"] as? String ?? "" == defaults.userID
            let isOwner = list?.data()?["listOwner"] as? String ?? "" == defaults.userID
            let count = (list?.data()?["currentTesters"] as? [String] ?? []).count-(isCreator ? 1 : 2)
            let nowTesting = list?.data()?["nowTesting"] as? Bool ?? false
            let string = "See how much you love people with me by joining \(isOwner ? "my" : "the") “\(list?.data()?["name"] as? String ?? "")” List on Feelist!\n\nIf you have the app installed:\n➡️ feelingsApp:///joinList/\(list?.documentID ?? "")\n\nIf you don't have the app installed yet:\n➡️ https://testflight.apple.com/join/wRet2zme\n\n\nRequires Feelist v0.2 or later installed on iOS 17.0 or later or iPadOS 17.0 or later.\nThis is a Beta."
            VStack {
                Image(systemName: nowTesting ? "person.wave.2.fill" : "person.badge.clock.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)
                    .padding(30)
                Text(nowTesting ? "Test in progress" : isCreator ? (list?.data()?["currentTesters"] as? [String] ?? []).count > 1 ? "\(count) member\(count > 1 ? "s" :"") ha\(count > 1 ? "ve" : "s") joined" : "Waiting for members..." : "Waiting for creator action...")
                    .font(.title.bold())
                    .padding(.bottom,20)
                if !isCreator || nowTesting {
                    Text(nowTesting ? "The test is in progress. You are seeing this because you joined it and an error occured.\nPlease report a bug and include what happened before you saw this." : "\(count) other member\(count == 1 ? "" : "s") are waiting.")
                        .font(.subheadline)
                        .padding(.bottom,20)
                }
                if !nowTesting {
                    ShareLink(item: string) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Link...")
                        }
                        .padding(.horizontal,5)
                        .padding(.vertical,2)
                    }
                    .fontWeight(.medium)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .padding(.bottom,(list?.data()?["users"] as? [String] ?? []).count == 1 ? 0 : 80)
                }
                if (list?.data()?["users"] as? [String] ?? []).count == 1 && !nowTesting {
                    Text("You're the only one in your List. Invite people!")
                        .font(.subheadline)
                        .padding(.top,5)
                        .padding(.bottom,80)
                }
                if isCreator {
                    Button(action: {
                        withAnimation {
                            loading = true
                        }
                        Firestore.firestore().collection("Workout").document(list?.documentID ?? "").updateData(["nowTesting":true])
                    }) {
                        Text((list?.data()?["currentTesters"] as? [String] ?? []).count-1 > 0 ? "Start" : "Test Alone")
                            .font(.headline)
                            .padding(.vertical,8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .padding(.horizontal,50)
                    .disabled(nowTesting)
                }
            }
            .padding(.horizontal,40)
        }
        .navigationTitle(list?.data()?["nowTesting"] as? Bool ?? false ? "Test in progress" : list?.data()?["testCreator"] as? String ?? "" == defaults.userID ? (list?.data()?["currentTesters"] as? [String] ?? []).count > 1 ? "Start test?" : "Waiting for members" : "Waiting for creator action")
    }
    var testPicker: some View {
        ScrollView {
            VStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)
                    .padding(30)
                Text("Would you like to test with friends?")
                    .font(.title.bold())
                    .padding(.bottom,20)
                Text("The more, the merrier!\n\nInstantly see who you and your friends prefer the most and share results automatically.")
                    .font(.subheadline)
                    .padding(.bottom,60)
                VStack(spacing: 20) {
                    Button(action: {
                        withAnimation {
                            loading = true
                        }
                        Firestore.firestore().collection("Workout").document(list?.documentID ?? "").updateData(["currentTesters":[defaults.userID], "testCreator":(defaults.userID), "isPublic":true])
                    }) {
                        Text("Test with Friends")
                            .font(.headline)
                            .padding(.vertical,8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button(action: {
                        withAnimation {
                            loading = true
                        }
                        Firestore.firestore().collection("Workout").document(list?.documentID ?? "").updateData(["currentTesters":[defaults.userID], "nowTesting":true])
                    }) {
                        Text("Test Alone")
                            .font(.headline)
                            .padding(.vertical,8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal,40)
                .buttonBorderShape(.capsule)
            }
            .padding(.horizontal,40)
        }
        .navigationTitle("Create a Test")
    }
    var testRunning: some View {
        ScrollView {
            VStack {
                let testerCount = (list?.data()?["currentTesters"] as? [String] ?? []).count
                let isOwner = list?.data()?["listOwner"] as? String ?? "" == defaults.userID && orgCreator != defaults.userID
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)
                    .padding(30)
                Text("A test is already running.")
                    .font(.title.bold())
                    .padding(.bottom,20)
                Text("A test is already running with \(testerCount) member\(testerCount > 1 ? "s" : "") of the List.\(isOwner ? "\nIf you want, you can force-stop this test to create a new one." : "")")
                    .font(.subheadline)
                    .padding(.bottom,isOwner ? 60 : 0)
                if isOwner {
                    Button(action: {
                        alertConfirmForceStop = true
                    }) {
                        Text("Force-stop")
                            .font(.headline)
                            .padding(.vertical,8)
                            .padding(.horizontal,30)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
            }
            .padding(.horizontal,40)
        }
        .navigationTitle("A test is already running")
    }
    var joinTest: some View {
        ScrollView {
            VStack {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)
                    .padding(30)
                Text("Join the test?")
                    .font(.title.bold())
                    .padding(.bottom,20)
                Text("Tap to join the test and test people with other members of this List.")
                    .font(.subheadline)
                    .padding(.bottom,60)
                Button(action: {
                    withAnimation {
                        loading = true
                    }
                    let usersPlusCurrent = (list?.data()?["currentTesters"] as? [String] ?? []) + [defaults.userID]
                    Firestore.firestore().collection("Workout").document(list?.documentID ?? "").updateData(["currentTesters":usersPlusCurrent])
                }) {
                    Text("Join")
                        .font(.headline)
                        .padding(.vertical,8)
                        .padding(.horizontal,20)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
            .padding(.horizontal,40)
        }
        .navigationTitle("Join test?")
    }
}

struct AddList: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var listName = ""
    let icons = ["😀", "😊", "🧐", "🫨", "😮", "😵‍💫", "🥇", "🚫", "🤢", "😱", "🥳", "🤯", "🥰", "❤️", "🔥", "😎", "👀", "😭", "💣", "🧑‍💻", "🤞", "🤪", "🤬", "🥵", "🤌", "💪", "🍆", "🍒", "🍓", "🍑", "🏀", "🎯", "🥺", "💀", "📸", "🤤", "🫣", "💸", "💯", "💅", "👙", "💦", "🚨"]
    @State private var selectedIcon = "🔥"
    @State private var pickAnIcon = false
    @State private var addListTwo = false
    @State private var sheetReport = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Button(action: {
                        pickAnIcon = true
                    }) {
                        ZStack {
                            Text(selectedIcon)
                                .font(.system(size: 80))
                            Image(systemName: "pencil")
                                .font(.title3.bold())
                                .padding(20)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        }
                        .frame(width: 0.5*UIScreen.main.bounds.width, height: 0.5*UIScreen.main.bounds.width)
                        .background(colorScheme == .light ? Color(red: 220/255, green: 220/255, blue: 220/255) : Color(red: 50/255, green: 50/255, blue: 50/255))
                        .cornerRadius(30)
                        .padding(20)
                    }
                    .padding(.bottom,20)
                    TextField("Name your List", text: $listName)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .submitLabel(.next)
                        .onSubmit {
                            if !listName.trimmingCharacters(in: .whitespaces).isEmpty {
                                addListTwo = true
                            }
                        }
                        .padding(.bottom,40)
                    Button(action: {
                        addListTwo = true
                    }) {
                        Text("Next")
                            .font(.headline)
                            .padding(.vertical,8)
                            .padding(.horizontal,30)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(listName.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal,40)
                .padding(.top,10)
                Button(action: {
                    sheetReport = true
                }) {
                    (Text("This is a new feature.").foregroundStyle(Color.secondary) + Text(" Send Feedback"))
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom,10)
                        .padding(.horizontal,15)
                }
                .padding(.top,50)
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .multilineTextAlignment(.center)
            .navigationDestination(isPresented: $addListTwo) {
                AddListTwo(listName: listName, listIcon: selectedIcon)
            }
            .sheet(isPresented: $pickAnIcon) {
                iconPicker
                    .presentationCornerRadius(40)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $sheetReport) {
                ReportView()
                    .presentationCornerRadius(40)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .padding(1)
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }
            }
        }
    }
    var iconPicker: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 40) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: {
                            withAnimation {
                                selectedIcon = icon
                            }
                            pickAnIcon = false
                        }) {
                            Text(icon)
                                .font(.largeTitle)
                        }
                    }
                }
                .padding(.horizontal,40)
                .padding(.vertical,10)
            }
            .navigationTitle("Pick an Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        pickAnIcon = false
                    }) {
                        Image(systemName: "xmark")
                            .padding(1)
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }
            }
        }
    }
}

struct JoinList: View {
    @Binding var urlListID: String
    @State private var listInvited: DocumentSnapshot? = nil
    @State private var loading = false
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @Environment(Defaults.self) var defaults
    func getList() {
        withAnimation {
            loading = true
        }
        Firestore.firestore().collection("Workout").document(urlListID).getDocument { document, error in
            if error == nil, let document = document, document.exists {
                listInvited = document
                withAnimation {
                    loading = false
                }
            }
        }
    }
    var body: some View {
        NavigationStack {
            VStack {
                if loading {
                    ProgressView()
                        .padding(30)
                } else if !(listInvited?.data()?["isPublic"] as? Bool ?? false) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 90, weight: .medium))
                        .foregroundStyle(.blue)
                        .padding(30)
                    Text("This List is locked.")
                        .font(.title.bold())
                        .padding(.bottom,20)
                    (Text("To join this List, ask its owner to make it public by disabling “Lock List” in Lists > \(listInvited?.data()?["name"] as? String ?? "") > ") + Text(Image(systemName: "ellipsis.circle")).foregroundStyle(Color.accentColor) + Text(" > Settings."))
                        .font(.subheadline)
                        .padding(.bottom,80)
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("OK")
                            .font(.headline)
                            .padding(.vertical,8)
                            .padding(.horizontal,30)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                } else {
                    Text(listInvited?.data()?["icon"] as? String ?? "")
                        .font(.system(size: 90))
                        .frame(width: 0.5*UIScreen.main.bounds.width, height: 0.5*UIScreen.main.bounds.width)
                        .background(colorScheme == .light ? Color(red: 220/255, green: 220/255, blue: 220/255) : Color(red: 50/255, green: 50/255, blue: 50/255))
                        .cornerRadius(25)
                        .padding(30)
                    Text("Join “\(listInvited?.data()?["name"] as? String ?? "")”?")
                        .font(.title.bold())
                        .padding(.bottom,20)
                    Text("Lists allow you to test people with your friends. Create yours!")
                        .font(.subheadline)
                        .padding(.bottom,40)
                    (Text(Image(systemName: "person.2.fill")).foregroundStyle(Color.accentColor) + Text(" Shared with \((listInvited?.data()?["users"] as? [String] ?? []).count-1) other people"))
                        .font(.headline)
                        .padding(.bottom,10)
                    let testCount = (listInvited?.data()?["tests"] as? [String: [String: Any]] ?? [:]).count
                    (Text(Image(systemName: "checklist.checked")).foregroundStyle(Color.accentColor) + Text(" \(testCount) test\(testCount == 1 ? "" : "s") taken"))
                        .font(.headline)
                        .padding(.bottom,60)
                    Button(action: {
                        Firestore.firestore().collection("Workout").document(urlListID).updateData(["users":(listInvited?.data()?["users"] as? [String] ?? []) + [defaults.userID]])
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Join List")
                            .font(.headline)
                            .padding(.vertical,8)
                            .padding(.horizontal,30)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
            }
            .padding(.horizontal,40)
            .padding(.vertical,10)
            .navigationTitle("You've been invited to a List")
            .navigationBarTitleDisplayMode(.inline)
            .multilineTextAlignment(.center)
            .onAppear {
                getList()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .padding(1)
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }
            }
        }
    }
}

struct AddListTwo: View {
    let listName: String
    let listIcon: String
    @Environment(\.colorScheme) var colorScheme
    @Environment(Defaults.self) var defaults
    @State private var people: [(name: String, preference: Double, id: String, initials: String, lastDate: Date)] = []
    @State private var peopleToInclude: [String: Any] = [:]
    @State private var textSearch = ""
    @State private var creatingList = false
    func getPeople() {
        withAnimation {
            people.removeAll()
        }
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Appreciation").getDocuments { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    if !(document.data()["deleted"] as? Bool ?? false) && document.data()["userID"] as? String ?? "" == defaults.userID {
                        var greatestTmsp = Timestamp()
                        var greatestDouble = 0.0
                        var wasConsidered = false
                        for tests in document.data()["tests"] as? [String: [String: Any]] ?? [:] {
                            let tmsp = tests.value.first(where: { $0.key == "date" })?.value as? Timestamp ?? Timestamp()
                            if tmsp.dateValue() > greatestTmsp.dateValue() || !wasConsidered {
                                greatestTmsp = tmsp
                                wasConsidered = true
                            }
                            let double = tests.value.filter({ $0.key == "double" }).first?.value as? Double ?? 0.0
                            if tests.value.values.contains(where: { $0 as? Timestamp ?? Timestamp() == greatestTmsp }) {
                                greatestDouble = double
                            }
                        }
                        let components = (document.data()["name"] as? String ?? "").trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                        var initials = ""
                        for string in components {
                            if initials.count < 2 {
                                initials += String(string.first!)
                            }
                        }
                        if (!textSearch.isEmpty && ((document.data()["name"] as? String ?? "").localizedCaseInsensitiveContains(textSearch))) || (textSearch.isEmpty && greatestTmsp.dateValue() > Calendar.current.date(byAdding: .day, value: -7, to: Date())!) {
                            withAnimation {
                                people.append((document.data()["name"] as? String ?? "", greatestDouble, document.documentID, initials, greatestTmsp.dateValue()))
                            }
                        }
                    }
                }
                withAnimation {
                    if people.count == 0 && textSearch.isEmpty {
                        let id = UUID().uuidString
                        Firestore.firestore().collection("Workout").document(id).setData(["forPart":"Lists", "icon":listIcon, "isPublic":false, "listOwner":defaults.userID, "name":listName, "tests":[:], "users":[defaults.userID], "creationDate":Timestamp(), "createdFromDeviceID":defaults.deviceID])
                    }
                }
            }
        }
    }
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack {
                        Image(systemName: "person.fill.badge.plus")
                            .font(.system(size: 72))
                            .foregroundStyle(Color.accentColor)
                            .padding(30)
                        Text("Include tests?")
                            .font(.title.bold())
                            .padding(.bottom,20)
                        Text("Include people you want in the List without having to test them again.")
                            .font(.subheadline)
                            .padding(.bottom,40)
                        ZStack {
                            TextField("Search people", text: $textSearch)
                                .font(.title3)
                                .onChange(of: textSearch) { oldValue, newValue in
                                    if newValue != oldValue {
                                        getPeople()
                                    }
                                    if !newValue.isEmpty {
                                        withAnimation {
                                            proxy.scrollTo("TEXTFIELD", anchor: .top)
                                        }
                                    }
                                }
                            Button(action: {
                                withAnimation {
                                    textSearch = ""
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .opacity(!textSearch.isEmpty ? 1 : 0)
                        }
                        .padding(.bottom,15)
                        .id("TEXTFIELD")
                        ForEach(people.sorted(by: { item1, item2 in
                            item1.preference > item2.preference
                        }), id: \.id) { preference in
                            Button(action: {
                                withAnimation {
                                    if peopleToInclude.contains(where: { $0.key == preference.name }) {
                                        peopleToInclude.removeValue(forKey: preference.name)
                                    } else {
                                        peopleToInclude[preference.name] = preference.preference
                                    }
                                }
                            }) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(colors: colorScheme == .light ? [.gray.opacity(0.5), .gray.opacity(0.85)] : [.white.opacity(0.75), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                            .frame(height: 0.12*UIScreen.main.bounds.width)
                                        Text(preference.initials)
                                            .fontDesign(.rounded)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                    }
                                    VStack(alignment: .leading) {
                                        Text(preference.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("\(Int(preference.preference*100))% • \(DateFormatter.localizedString(from: preference.lastDate, dateStyle: .medium, timeStyle: .none))")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .multilineTextAlignment(.leading)
                                    Image(systemName: peopleToInclude.contains(where: { $0.key == preference.name }) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(Color.accentColor)
                                }
                                .padding(.bottom,15)
                            }
                        }
                    }
                    .padding(.horizontal,40)
                    .padding(.vertical,10)
                }
            }
            .navigationTitle("Include people to \(listName)")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .multilineTextAlignment(.center)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    if creatingList {
                        ProgressView()
                    } else {
                        Button(action: {
                            withAnimation {
                                creatingList = true
                            }
                            peopleToInclude["DATE_UPDTAKEN"] = Timestamp()
                            let id = UUID().uuidString
                            let tests = ["data0":peopleToInclude]
                            Firestore.firestore().collection("Workout").document(id).setData(["forPart":"Lists", "icon":listIcon, "isPublic":false, "listOwner":defaults.userID, "name":listName, "tests":!peopleToInclude.isEmpty ? tests : [:], "users":[defaults.userID], "creationDate":Timestamp(), "createdFromDeviceID":defaults.deviceID, "editable":true])
                        }) {
                            Text(peopleToInclude.isEmpty ? "Skip" : "Create List")
                                .font(.headline)
                                .padding(.vertical,8)
                                .padding(.horizontal,30)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    }
                }
            }
            .onAppear {
                getPeople()
            }
        }
    }
}
