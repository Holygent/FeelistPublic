//
//  AddAppreciation.swift
//  FeelingsApp
//
//  Created by Holygent on 6/27/24.
//

import Foundation
import SwiftUI
import FirebaseFirestore

@Observable class CurrentTest {
    var name = ""
    var relation = "Friend"
    var pointsGiven = 0.0
    var totalPoints = 0.0
    var forList = ""
}

struct AddAppreciation: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @Environment(Defaults.self) var defaults
    @Environment(CurrentTest.self) var currentTest
    @State private var peopleWithMatchingNames: [(String, Double, String, String, Date, String)] = []
    @State private var proposedNames: [String: String] = [:]
    @State private var sheetReport = false
    @State private var currentTesters: [String] = []
    @FocusState private var focusKeyboard: Bool
    func lookForPeople() {
        withAnimation {
            peopleWithMatchingNames.removeAll()
        }
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Appreciation").getDocuments { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    if !(document.data()["deleted"] as? Bool ?? false) && document.data()["userID"] as? String ?? "" == defaults.userID {
                        if (document.data()["name"] as? String ?? "").localizedCaseInsensitiveContains(currentTest.name) {
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
                            var final = ""
                            for string in components {
                                if final.count < 2 {
                                    final += String(string.first!)
                                }
                            }
                            withAnimation {
                                peopleWithMatchingNames.append((document.data()["name"] as? String ?? "", greatestDouble, final, document.documentID, greatestTmsp.dateValue(), document.data()["relation"] as? String ?? ""))
                            }
                        } else {
                            withAnimation {
                                peopleWithMatchingNames.removeAll(where: { $0.0 == currentTest.name })
                            }
                        }
                    }
                }
            }
        }
    }
    func lookForProposals() {
        Firestore.firestore().collection("Workout").whereField(FieldPath.documentID(), isEqualTo: currentTest.forList).addSnapshotListener { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    let proposedNames = document.data()["proposedNames"] as? [String: String] ?? [:]
                    if (document.data()["currentTesters"] as? [String] ?? []).count > 1 {
                        withAnimation {
                            self.proposedNames = proposedNames
                        }
                    }
                    withAnimation {
                        currentTesters = document.data()["currentTesters"] as? [String] ?? []
                    }
                }
            }
        }
    }
    @State private var navigateToNextStep = false
    @Bindable var nameTest: CurrentTest
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .center) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(Color.accentColor)
                            .padding(30)
                        Text("Who are you testing?")
                            .font(.title.bold())
                            .padding(.bottom,20)
                        Text("Add their name so you can find them among other people.")
                            .font(.subheadline)
                            .padding(.bottom,40)
                        ZStack {
                            TextField("Name", text: $nameTest.name)
                                .font(.title3)
                                .focused($focusKeyboard)
                                .submitLabel(.next)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.words)
                                .onSubmit {
                                    if !currentTest.forList.isEmpty {
                                        Firestore.firestore().collection("Workout").document(currentTest.forList).updateData(["proposedNames":FieldValue.delete()])
                                    }
                                    if !currentTest.name.trimmingCharacters(in: .whitespaces).isEmpty && currentTest.name != "DATE_UPDTAKEN" && proposedNames.allSatisfy({ $0.value == currentTest.name }) && (proposedNames.count == currentTesters.count || currentTesters.count == 1) {
                                        navigateToNextStep = true
                                    }
                                }
                                .onChange(of: nameTest.name) { oldValue, newValue in
                                    if oldValue != newValue {
                                        currentTest.name = newValue.trimmingCharacters(in: .whitespaces)
                                        print("LOC124: \(currentTest.name), \(oldValue), \(newValue)")
                                        lookForPeople()
                                        if !currentTest.forList.isEmpty {
                                            Firestore.firestore().collection("Workout").document(currentTest.forList).getDocument { document, error in
                                                if error == nil && !(document?.data()?["testCreator"] as? String ?? "").isEmpty {
                                                    Firestore.firestore().collection("Workout").document(currentTest.forList).updateData(["proposedNames.\(defaults.userID)":currentTest.name.trimmingCharacters(in: .whitespaces).isEmpty ? FieldValue.delete() : currentTest.name.trimmingCharacters(in: .whitespaces)])
                                                }
                                            }
                                        }
                                    }
                                    if !newValue.isEmpty {
                                        withAnimation {
                                            proxy.scrollTo("TEXTFIELD", anchor: .top)
                                        }
                                    }
                                }
                            Button(action: {
                                withAnimation {
                                    currentTest.name = ""
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .opacity(!currentTest.name.isEmpty ? 1 : 0)
                        }
                        .padding(.bottom,20)
                        .id("TEXTFIELD")
                        if !currentTest.forList.isEmpty {
                            if currentTesters.count > 1 {
                                Text("You must test the same person at once.")
                                    .font(.subheadline)
                                    .padding(.bottom,10)
                            }
                            if proposedNames.filter({ $0.key != defaults.userID }).count > 0 {
                                Text("Your friends suggest")
                                    .font(.headline)
                                    .padding(.vertical,10)
                                    .padding(.bottom,10)
                                VStack(alignment: .leading) {
                                    ForEach(proposedNames.filter({ $0.key != defaults.userID }).sorted(by: <), id: \.key) { ppl in
                                        Button(action: {
                                            withAnimation {
                                                currentTest.name = ppl.value
                                            }
                                            focusKeyboard = false
                                        }) {
                                            HStack {
                                                ZStack {
                                                    Circle()
                                                        .fill(LinearGradient(colors: colorScheme == .light ? [.gray.opacity(0.5), .gray.opacity(0.85)] : [.white.opacity(0.75), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                                        .frame(height: 0.12*UIScreen.main.bounds.width)
                                                    Text(ppl.value.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").compactMap({ String($0.first ?? Character("")) }).prefix(2).joined().uppercased())
                                                        .fontDesign(.rounded)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.white)
                                                }
                                                Text(ppl.value.trimmingCharacters(in: .whitespaces))
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                    .multilineTextAlignment(.leading)
                                            }
                                            .padding(.bottom,ppl.key == proposedNames.filter({ $0.key != defaults.userID }).sorted(by: <).first?.key ?? "" ? 0 : 15)
                                        }
                                        if ppl.key == proposedNames.filter({ $0.key != defaults.userID }).sorted(by: <).first?.key ?? "" {
                                            Text("Tap someone to test them.")
                                                .padding(.bottom,15)
                                        }
                                    }
                                }
                                .padding(.bottom,10)
                            }
                            if peopleWithMatchingNames.count > 0 && proposedNames.count > 0 {
                                Text("From your Preferences")
                                    .font(.headline)
                                    .padding(.vertical,10)
                                    .padding(.bottom,10)
                            }
                        }
                        VStack(alignment: .leading) {
                            ForEach(peopleWithMatchingNames, id: \.3) { ppl in
                                Button(action: {
                                    withAnimation {
                                        currentTest.name = ppl.0
                                        currentTest.relation = ppl.5
                                    }
                                    focusKeyboard = false
                                    if currentTest.forList.isEmpty {
                                        navigateToNextStep = true
                                    }
                                }) {
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(colors: colorScheme == .light ? [.gray.opacity(0.5), .gray.opacity(0.85)] : [.white.opacity(0.75), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                                .frame(height: 0.12*UIScreen.main.bounds.width)
                                            Text(ppl.2)
                                                .fontDesign(.rounded)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                        }
                                        VStack(alignment: .leading) {
                                            Text(ppl.0)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text("\(Int(ppl.1*100))% • \(DateFormatter.localizedString(from: ppl.4, dateStyle: .medium, timeStyle: .none))")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .multilineTextAlignment(.leading)
                                    }
                                    .padding(.bottom,15)
                                }
                            }
                        }
                        if !currentTest.forList.isEmpty {
                            NavigationLink(destination: AddAppreciationThree()) {
                                Text("Next")
                                    .font(.headline)
                                    .padding(.vertical,8)
                                    .padding(.horizontal,30)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .padding(.top,60)
                            .padding(.bottom,10)
                            .disabled(currentTest.name.trimmingCharacters(in: .whitespaces).isEmpty || (proposedNames.count != currentTesters.count && currentTesters.count > 1) || !proposedNames.allSatisfy({ $0.value == currentTest.name }) || currentTest.name == "DATE_UPDTAKEN")
                        } else {
                            NavigationLink(destination: AddAppreciationTwo(relationTest: CurrentTest())) {
                                Text("Next")
                                    .font(.headline)
                                    .padding(.vertical,8)
                                    .padding(.horizontal,30)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .padding(.top,60)
                            .padding(.bottom,10)
                            .disabled(currentTest.name.trimmingCharacters(in: .whitespaces).isEmpty || currentTest.name == "DATE_UPDTAKEN")
                        }
                    }
                    .padding(.horizontal,40)
                }
                .onAppear {
                    currentTest.name = ""
                    if !currentTest.forList.isEmpty {
                        lookForProposals()
                        Firestore.firestore().collection("Workout").document(currentTest.forList).updateData(["proposedNames":FieldValue.delete()])
                    }
                }
                .multilineTextAlignment(.center)
                .navigationTitle("Step 1 of 3")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden()
                .scrollDismissesKeyboard(.interactively)
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
                .navigationDestination(isPresented: $navigateToNextStep) {
                    AddAppreciationTwo(relationTest: CurrentTest())
                }
            }
        }
    }
}

struct AddAppreciationTwo: View {
    @Environment(CurrentTest.self) var currentTest
    @Bindable var relationTest: CurrentTest
    @State private var relationships = ["Friend", "Family Member", "Partner", "Other"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .center) {
                    Image(systemName: "person.line.dotted.person.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.accentColor)
                        .padding(30)
                    Text("What's your current relationship?")
                        .font(.title.bold())
                        .padding(.bottom,20)
                    Text("Specifying a relationship allows the system to better determine how much you love \(currentTest.name).")
                        .font(.subheadline)
                        .padding(.bottom,40)
                    Menu {
                        Picker("Select a relationship", selection: $relationTest.relation) {
                            ForEach(relationships, id: \.self) { item in
                                Text(item)
                            }
                        }
                        .onChange(of: relationTest.relation) { _, newValue in
                            currentTest.relation = newValue
                        }
                    } label: {
                        HStack {
                            Text(currentTest.relation)
                                .font(.title3)
                            Image(systemName: "chevron.up.chevron.down")
                        }
                    }
                    .padding(.bottom,15)
                    NavigationLink(destination: AddAppreciationThree()) {
                        Text("Next")
                            .font(.headline)
                            .padding(.vertical,8)
                            .padding(.horizontal,30)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .padding(.top,60)
                }
                .padding(.horizontal,40)
            }
            .multilineTextAlignment(.center)
            .navigationTitle("Step 2 of 3")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AddAppreciationThree: View {
    @State private var questions: [(index: Int, questionName: String, pointsIfTrue: Double)] = []
    @State private var currentIndex = -1.0
    @State private var sendToCloud = true
    @State private var publishedDocumentID = ""
    @State private var lastQuestions: [Double] = []
    @State private var alertReset = false
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @Environment(Defaults.self) var defaults
    @Environment(CurrentTest.self) var currentTest
    @State private var loadingUpload = false
    func getQuestions() {
        switch currentTest.relation {
        case "Friend":
            questions = [(0, "Done something you didn't like becaue \(currentTest.name) asked you?", 3), (1, "Often thought about \(currentTest.name)?", 5), (2, "Told \(currentTest.name) any of your secrets?", 4), (3, "Felt better when \(currentTest.name) was around?", 3), (4, "Often agreed with \(currentTest.name)?", 2), (5, "Been attracted by \(currentTest.name) or felt close to them?", 3), (6, "Been happy for \(currentTest.name) successes?", 2), (7, "Done things that were important for \(currentTest.name), especially if it required you to make sacrifices?", 3), (8, "Been open and/or honest with \(currentTest.name)?", 2), (9, "Asked \(currentTest.name) for support?", 3)]
        case "Family Member":
            questions = [(0, "Enjoyed spending time with \(currentTest.name)?", 1), (1, "Been jealous if \(currentTest.name) rewarded someone for something you were good at?", 3), (2, "Been sensitive to \(currentTest.name)'s feelings?", 2), (3, "Been in the same mood — or wanted to help — when \(currentTest.name) was not feeling alright?", 2), (4, "Enjoyed holidays with \(currentTest.name)?", 5), (5, "During holidays, had more than 2 problems per week with \(currentTest.name)?", -5), (6, "Been aware of \(currentTest.name)'s tastes'?", 6), (7, "Done things that \(currentTest.name) disliked for your own interest?", -6), (8, "Received affection from \(currentTest.name)?", 4), (9, "Been able to stand \(currentTest.name)?", 4), (10, "Been happy to receive calls from \(currentTest.name)?", 4), (11, "Sometimes made \(currentTest.name) laugh?", 2)]
        case "Partner":
            questions = [(0, "Enjoyed \(currentTest.name)'s appearance?", 1), (1, "Been friends with your partner's friends?", 2), (2, "Enjoyed having sex with \(currentTest.name)?", 7), (3, "Considered your partner's feelings and emotions?", 6), (4, "Been proud when \(currentTest.name) congratulated you?", 5), (5, "Tried to do things, with or without \(currentTest.name), they liked?", 5), (6, "Helped your partner doing things they liked?", 1), (7, "Sometimes been proud of \(currentTest.name)?", 5), (8, "Regarded \(currentTest.name)'s appearance as important?", 1), (9, "Often got angry at each other?", -6), (10, "Enjoyed spending time with your partner?", 7), (11, "Believed your partner wasn't good at something they thought they were good at?", -5), (12, "Looked after \(currentTest.name)?", 6), (13, "Somtimes intentionally ignored \(currentTest.name) physically or via messages?", -6), (14, "Sometimes intentionally not helped your partner?", -4)]
        default:
            questions = [(0, "Liked \(currentTest.name)'s appearance?", 1), (1, "Enjoyed spending time with \(currentTest.name)?", 3), (2, "Been honest with \(currentTest.name)?", 1), (3, "Been sensitive to \(currentTest.name)'s feelings?", 3), (4, "Been attracted by \(currentTest.name)?", 4), (5, "Looked to make \(currentTest.name) happy or satisfy them?", 2), (6, "Often been annoyed by \(currentTest.name)?", -3), (7, "Declined \(currentTest.name)'s requests more than you accepted them?", -2), (8, "Blocked \(currentTest.name)?", -4), (9, "Missed \(currentTest.name) when they were absent?", 3), (10, "Been happy to receive calls from \(currentTest.name)?", 2), (11, "Been jealous if \(currentTest.name) rewarded someone else's work or acheivement, especially in a field where you rock?", 3), (12, "Regarded \(currentTest.name)'s messages as important?", 1)]
        }
    }
    func uploadResults() {
        withAnimation {
            loadingUpload = true
        }
        if !currentTest.forList.isEmpty {
            Firestore.firestore().collection("Workout").document(currentTest.forList).getDocument { document, error in
                if error == nil, let document = document, document.exists {
                    let tests = document.data()?["tests"] as? [String: [String: Any]] ?? [:]
                    var greatestTmsp: Date? = nil
                    var greatestDouble = 0.0
                    for test in tests {
                        let tmsp = (test.value.first(where: { $0.key == "DATE_UPDTAKEN" })?.value as? Timestamp ?? Timestamp()).dateValue()
                        let double = test.value.first(where: { $0.key == currentTest.name })?.value
                        if greatestTmsp == nil || tmsp > greatestTmsp ?? Date() {
                            if double == nil {
                                greatestDouble = currentTest.pointsGiven/currentTest.totalPoints
                            } else {
                                greatestDouble = ((double as? Double ?? 0.0)+(currentTest.pointsGiven/currentTest.totalPoints))/2
                            }
                            greatestTmsp = tmsp
                        }
                    }
                    let biggestTestIndex = Int(tests.sorted(by: { Int($0.key.replacingOccurrences(of: "data", with: "")) ?? 0 > Int($1.key.replacingOccurrences(of: "data", with: "")) ?? 0 }).first?.key.replacingOccurrences(of: "data", with: "") ?? "") ?? 0
                    if document.data()?["nowTesting"] as? Bool ?? false && Calendar.current.isDateInToday(greatestTmsp ?? Date()) && !(document.data()?["testCreator"] as? String ?? "").isEmpty {
                        Firestore.firestore().collection("Woƒrkout").document(currentTest.forList).updateData(["tests.data\(biggestTestIndex).\(currentTest.name)":greatestDouble, "tests.data\(biggestTestIndex).DATE_UPDTAKEN":Timestamp()])
                    } else {
                        Firestore.firestore().collection("Workout").document(currentTest.forList).updateData(["tests.data\(biggestTestIndex+1)":[currentTest.name:greatestDouble, "DATE_UPDTAKEN":Timestamp()]])
                    }
                }
            }
        } else {
            Firestore.firestore().collection("Workout").whereField("name", isEqualTo: currentTest.name).getDocuments { querySnapshot, error in
                if error == nil {
                    for document in querySnapshot!.documents {
                        if querySnapshot!.documents.count == 1 && document.data()["userID"] as? String ?? "" == defaults.userID {
                            var oldValues = document.data()["tests"] as? [String: [String: Any]] ?? [:]
                            let newKey = currentTest.pointsGiven/currentTest.totalPoints
                            let newValue = Timestamp()
                            let tests = ["data0":["double":(currentTest.pointsGiven/currentTest.totalPoints), "date":Timestamp(), "relation":currentTest.relation]]
                            if (document.data()["deleted"] as? Bool ?? false) {
                                Firestore.firestore().collection("Workout").document(document.documentID).updateData(["deleted":false, "tests":tests, "relation":currentTest.relation])
                            } else {
                                oldValues["data\(oldValues.count)"] = ["double":newKey, "date":newValue, "relation":currentTest.relation]
                                Firestore.firestore().collection("Workout").document(document.documentID).updateData(["tests":oldValues, "relation":currentTest.relation])
                            }
                        } else {
                            let tests = ["data0":["double":(currentTest.pointsGiven/currentTest.totalPoints), "date":Timestamp(), "relation":currentTest.relation]]
                            Firestore.firestore().collection("Workout").document(UUID().uuidString).setData(["forPart":"Appreciation", "tests":tests, "name":currentTest.name, "relation":currentTest.relation, "userID":defaults.userID])
                        }
                    }
                }
            }
        }
    }
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .center) {
                        Image(systemName: "questionmark.bubble.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(Color.accentColor)
                            .padding(30)
                        Text("\(questions.count) questions to see how much you love \(currentTest.name).")
                            .font(.title.bold())
                            .padding(.bottom,20)
                        Text("This shouldn't take more than 2 minutes.")
                            .font(.subheadline)
                            .padding(.bottom,40)
                        Button(action: {
                            withAnimation {
                                currentIndex = 0.0
                                proxy.scrollTo(currentIndex, anchor: .center)
                            }
                        }) {
                            Text("Let's Go")
                                .font(.headline)
                                .padding(.vertical,8)
                                .padding(.horizontal,30)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .padding(.top,60)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal,40)
                    .padding(.bottom,0.5*UIScreen.main.bounds.height)
                    ForEach(questions, id: \.index) { question in
                        VStack(alignment: .leading) {
                            Text("Question \(question.index+1) of \(questions.count)")
                                .textCase(.uppercase)
                                .fontDesign(.rounded)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(question.questionName)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Divider()
                                .padding(.vertical,5)
                                .padding(.bottom,5)
                            HStack {
                                Button(action: {
                                    currentTest.pointsGiven += question.pointsIfTrue
                                    lastQuestions.append(question.pointsIfTrue)
                                    withAnimation {
                                        currentIndex += 1
                                        proxy.scrollTo(question.index+1, anchor: .center)
                                    }
                                }) {
                                    Text("Yes")
                                        .font(.headline)
                                        .padding(.vertical,5)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .cornerRadius(15)
                                .padding(.trailing,2)
                                Button(action: {
                                    lastQuestions.append(0)
                                    withAnimation {
                                        currentIndex += 1
                                        proxy.scrollTo(question.index+1, anchor: .center)
                                    }
                                }) {
                                    Text("No")
                                        .font(.headline)
                                        .padding(.vertical,5)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .cornerRadius(15)
                            }
                            .padding(.bottom,2)
                            Button(action: {
                                currentTest.pointsGiven += question.pointsIfTrue/2
                                lastQuestions.append(question.pointsIfTrue/2)
                                withAnimation {
                                    currentIndex += 1
                                    proxy.scrollTo(question.index+1, anchor: .center)
                                }
                            }) {
                                Text("Sometimes")
                                    .font(.headline)
                                    .padding(.vertical,5)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .cornerRadius(15)
                            .padding(.bottom,2)
                            Button(action: {
                                currentTest.pointsGiven += question.pointsIfTrue*0.25
                                lastQuestions.append(question.pointsIfTrue*0.25)
                                withAnimation {
                                    currentIndex += 1
                                    proxy.scrollTo(question.index+1, anchor: .center)
                                }
                            }) {
                                Text("I don't know")
                                    .font(.headline)
                                    .padding(.vertical,5)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .cornerRadius(15)
                        }
                        .padding(15)
                        .background(colorScheme == .light ? .white : Color(red: 20/255, green: 20/255, blue: 20/255))
                        .cornerRadius(25)
                        .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 10, y: colorScheme == .light ? 5 : 10)
                        .padding(.horizontal,20)
                        .padding(.vertical,20)
                        .opacity(Int(currentIndex) != question.index ? 0.25 : 1)
                        .disabled(Int(currentIndex) != question.index)
                        .id(Double(question.index))
                    }
                    VStack {
                        Divider()
                            .padding(.vertical,10)
                        Toggle("Send Results to Cloud", isOn: $sendToCloud)
                            .tint(.blue)
                        Text(sendToCloud ? "Your answers will be erased and your results automatically sent to the Cloud after being calculated." : "Your answers and results will be immediately erased as soon as you tap “Done”. Doing this prevents you to share your results.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Divider()
                            .padding(.vertical,10)
                    }
                    .padding(.horizontal,20)
                    NavigationLink(destination: AddAppreciationFour()) {
                        Text("Done")
                            .font(.headline)
                            .padding(.vertical,8)
                            .padding(.horizontal,30)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(Int(currentIndex) != questions.count)
                    .padding(.vertical,10)
                    .id(questions.count)
                    .simultaneousGesture(TapGesture().onEnded({
                        for question in questions {
                            if question.pointsIfTrue > 0 {
                                currentTest.totalPoints += question.pointsIfTrue
                            }
                        }
                        if sendToCloud {
                            uploadResults()
                        }
                    }))
                }
                .overlay(
                    Group {
                        if currentIndex >= 0 {
                            VStack(alignment: .leading) {
                                Gauge(value: currentIndex+1, in: 0...Double(questions.count)) {
                                    HStack {
                                        Button(action: {
                                            if currentIndex == 0 || lastQuestions.count == 0 {
                                                presentationMode.wrappedValue.dismiss()
                                            } else {
                                                alertReset = true
                                            }
                                        }) {
                                            Image(systemName: "arrow.counterclockwise")
                                                .font(.title2)
                                                .fontWeight(.medium)
                                        }
                                        .tint(.red)
                                        Text("Step 3 of 3")
                                            .fontDesign(.rounded)
                                            .font(.headline)
                                            .frame(maxWidth: .infinity)
                                        Button(action: {
                                            currentTest.pointsGiven -= lastQuestions.last ?? 0.0
                                            let lastIndex = lastQuestions.lastIndex(where: { $0 == lastQuestions.last })
                                            lastQuestions.remove(at: lastIndex ?? 0)
                                            withAnimation {
                                                currentIndex -= 1
                                                proxy.scrollTo(currentIndex, anchor: .center)
                                            }
                                        }) {
                                            Image(systemName: "arrow.uturn.backward")
                                                .font(.title2)
                                                .fontWeight(.medium)
                                        }
                                        .disabled(currentIndex == 0 || lastQuestions.count == 0)
                                    }
                                    .padding(.bottom,5)
                                }
                                Text("Since the past three weeks, have you or would you have...")
                                    .font(.title2.bold())
                                    .padding(.top,10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(15)
                            .background(.bar)
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                    }
                )
                .navigationBarBackButtonHidden(currentIndex >= 0)
                .alert("Start Over?", isPresented: $alertReset) {
                    Button("Continue", role: .destructive) { presentationMode.wrappedValue.dismiss() }
                    Button("Undo Last Answer") {
                        currentTest.pointsGiven -= lastQuestions.last ?? 0.0
                        lastQuestions.removeAll(where: { $0 == lastQuestions.last })
                        withAnimation {
                            currentIndex -= 1
                            proxy.scrollTo(currentIndex, anchor: .center)
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("You're about to start over your test.\nAre you sure you want to do this?")
                }
                .onAppear {
                    getQuestions()
                }
            }
        }
    }
}

struct AddAppreciationFour: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(Defaults.self) var defaults
    @Environment(CurrentTest.self) var currentTest
    @State private var size: CGFloat = 1
    @State private var sizeCircle: CGFloat = 0
    @State private var preferenceOverOthers = 0.0
    @State private var preferences: [(name: String, preference: Double, id: String)] = []
    @State private var hasLoaded = false
    func getPreferences() {
        if !currentTest.forList.isEmpty {
            Firestore.firestore().collection("Workout").whereField(FieldPath.documentID(), isEqualTo: currentTest.forList).addSnapshotListener { querySnapshot, error in
                if error == nil {
                    for document in querySnapshot!.documents {
                        let tests = document.data()["tests"] as? [String: [String: Any]] ?? [:]
                        let biggestTestKey = tests.sorted(by: { Int($0.key.replacingOccurrences(of: "data", with: "")) ?? 0 > Int($1.key.replacingOccurrences(of: "data", with: "")) ?? 0 }).first?.key
                        for test in tests {
                            let testDate = test.value.sorted(by: { (Int($0.key.replacingOccurrences(of: "data", with: "")) ?? 0) > (Int($1.key.replacingOccurrences(of: "data", with: "")) ?? 0) }).filter({ $0.key == "DATE_UPDTAKEN" }).first?.value as? Timestamp ?? Timestamp()
                            if test.key == biggestTestKey && Calendar.current.isDateInToday(testDate.dateValue()) {
                                for data in test.value where data.key != "DATE_UPDTAKEN" {
                                    withAnimation {
                                        if preferences.contains(where: { $0.name == data.key }) {
                                            preferences.removeAll(where: { $0.name == data.key })
                                        }
                                        preferences.append((data.key, data.value as? Double ?? 0.0, UUID().uuidString))
                                    }
                                }
                            }
                        }
                        withAnimation {
                            hasLoaded = true
                        }
                    }
                }
            }
        } else {
            preferenceOverOthers = 0.0
            preferences.removeAll()
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
                            if document.data()["name"] as? String ?? "" != currentTest.name {
                                preferences.append((document.data()["name"] as? String ?? "", greatestDouble, document.documentID))
                            }
                        }
                    }
                    var totalDoubleNumerator = 0.0
                    for preference in preferences {
                        totalDoubleNumerator += preference.preference
                    }
                    let value = (currentTest.pointsGiven/currentTest.totalPoints)
                    let average = totalDoubleNumerator/Double(preferences.count)
                    preferenceOverOthers = ((value/average)-1)*100
                    withAnimation {
                        hasLoaded = true
                    }
                }
            }
        }
        print("LOC741: \(currentTest.name)")
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                if hasLoaded {
                    VStack(alignment: .center) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down")
                                .foregroundStyle(Color.accentColor)
                                .font(.title2)
                            Text("Swipe down to quit")
                                .font(.headline)
                            Image(systemName: "arrow.down")
                                .foregroundStyle(Color.accentColor)
                                .font(.title2)
                        }
                        if size > -0.5 {
                            Image(systemName: "person.fill.checkmark")
                                .font(.system(size: 47))
                                .foregroundStyle(Color.accentColor)
                                .padding(15)
                                .scaleEffect(size*1.5)
                                .frame(height: 0.22*UIScreen.main.bounds.width)
                                .padding(30)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: colorScheme == .light ? [.gray.opacity(0.5), .gray.opacity(0.85)] : [.white.opacity(0.75), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                    .frame(height: 0.22*UIScreen.main.bounds.width)
                                Text(currentTest.name.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").compactMap({ String($0.first ?? Character("")) }).joined().uppercased())
                                    .fontDesign(.rounded)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .font(.largeTitle.bold())
                            }
                            .padding(30)
                            .scaleEffect(sizeCircle)
                        }
                        Text(currentTest.relation == "Friend" ? currentTest.pointsGiven/currentTest.totalPoints < 0.15 ? "You Might Not Like Them" : currentTest.pointsGiven/currentTest.totalPoints < 0.3 ? "You Slightly Like Them" : currentTest.pointsGiven/currentTest.totalPoints < 0.5 ? "You Somewhat Like Them" : currentTest.pointsGiven/currentTest.totalPoints < 0.7 ? "You Quite Like Them" : currentTest.pointsGiven/currentTest.totalPoints < 0.9 ? "You Highly Like Them" : "You May Be In Love" : currentTest.relation == "Family Member" ? currentTest.pointsGiven/currentTest.totalPoints <= 0.2 ? "You're Not Close At All" : currentTest.pointsGiven/currentTest.totalPoints <= 0.4 ? "You're Not So Close" : currentTest.pointsGiven/currentTest.totalPoints <= 0.8 ? "You're Close" : currentTest.pointsGiven/currentTest.totalPoints <= 0.9 ? "You're Very Close" : "You May Be the Closest" : currentTest.relation == "Partner" ? currentTest.pointsGiven/currentTest.totalPoints <= 0.2 ? "You May Not Like Her" : currentTest.pointsGiven/currentTest.totalPoints <= 0.4 ? "You May Not Be Happy" : currentTest.pointsGiven/currentTest.totalPoints <= 0.6 ? "You May Not Like Being With Them That Much" : currentTest.pointsGiven/currentTest.totalPoints <= 0.8 ? "You Love Them Reasonably" : currentTest.pointsGiven/currentTest.totalPoints <= 0.9 ? "You're in True Love" : "You Found the Chosen One" : currentTest.relation == "Other" ? currentTest.pointsGiven/currentTest.totalPoints <= 0.1 ? "You May Dislike Them" : currentTest.pointsGiven/currentTest.totalPoints <= 0.2 ? "You May Slightly Love Them" : currentTest.pointsGiven/currentTest.totalPoints <= 0.5 ? "You Somewhat Love Them" : currentTest.pointsGiven/currentTest.totalPoints <= 0.73 ? "You Quite Love Them" : "You May be In Love" : "Your results do not meet the requirements (have: \(currentTest.pointsGiven) points out of \(currentTest.totalPoints) points; computed: \(currentTest.pointsGiven/currentTest.totalPoints); relationship: \(currentTest.relation)). Please report a bug.\n\nDismiss this sheet > Three dots (top-left or top-right corner) > Send Feedback.")
                            .font(.title.bold())
                            .padding(.bottom,2)
                        Text("Based on your answers, you love \(currentTest.name) \(currentTest.relation != "Other" ? "as a \(currentTest.relation) " : "")by \(Int(currentTest.pointsGiven/currentTest.totalPoints*100))%.")
                            .padding(.bottom,40)
                        NavigationLink(destination: AddAppreciation(nameTest: CurrentTest())) {
                            Text("Test Someone Else")
                                .font(.headline)
                                .padding(.vertical,8)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .padding(.horizontal,50)
                        .padding(.bottom,preferences.count > 0 ? 40 : 5)
                        if preferences.count == 0 && currentTest.forList.isEmpty {
                            Text("See who you prefer the most!")
                                .font(.subheadline.bold())
                                .padding(.bottom,40)
                        }
                        if preferences.count > 0 {
                            VStack {
                                if preferences.filter({ $0.preference > (currentTest.pointsGiven/currentTest.totalPoints) }).count-2 > 0 {
                                    Text("+\(preferences.filter({ $0.preference > (currentTest.pointsGiven/currentTest.totalPoints) }).count-2) more")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                ForEach(preferences.sorted(by: { item1, item2 in
                                    item1.preference > item2.preference
                                }).filter({ $0.preference > (currentTest.pointsGiven/currentTest.totalPoints) }).suffix(2), id: \.id) { preference in
                                    HStack(alignment: .center) {
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(colors: colorScheme == .light ? [.gray.opacity(0.5), .gray.opacity(0.85)] : [.white.opacity(0.75), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                                .frame(height: 0.1*UIScreen.main.bounds.width)
                                            Text(preference.name.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").compactMap({ String($0.first ?? Character("")) }).joined().uppercased())
                                                .fontDesign(.rounded)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                        }
                                        Text(preference.name)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .multilineTextAlignment(.leading)
                                        Text("\(Int(preference.preference*100))%")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top,5)
                                }
                                let pref = Int(preferenceOverOthers)
                                Text("\(!currentTest.forList.isEmpty ? "All together, y" : "Y")ou prefer \(currentTest.name) \(pref < 0 ? -1*pref : pref)% \(pref < 0 ? "less" : "more") than others.")
                                    .font(.headline)
                                    .padding(.top,5)
                                    .padding(.vertical,10)
                                ForEach(preferences.sorted(by: { item1, item2 in
                                    item1.preference > item2.preference
                                }).filter({ $0.preference <= (currentTest.pointsGiven/currentTest.totalPoints) }).prefix(2), id: \.id) { preference in
                                    HStack(alignment: .center) {
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(colors: colorScheme == .light ? [.gray.opacity(0.5), .gray.opacity(0.85)] : [.white.opacity(0.75), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                                .frame(height: 0.1*UIScreen.main.bounds.width)
                                            Text(preference.name.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").compactMap({ String($0.first ?? Character("")) }).joined().uppercased())
                                                .fontDesign(.rounded)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                        }
                                        Text(preference.name)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .multilineTextAlignment(.leading)
                                        Text("\(Int(preference.preference*100))%")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top,5)
                                }
                                if preferences.filter({ $0.preference <= (currentTest.pointsGiven/currentTest.totalPoints) }).count-2 > 0 {
                                    Text("+\(preferences.filter({ $0.preference <= (currentTest.pointsGiven/currentTest.totalPoints) }).count-2) more")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.top,5)
                                }
                            }
                            .padding(.horizontal,5)
                            .padding(.bottom,20)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal,40)
                    Divider()
                        .padding(.top,10)
                        .padding(.vertical,15)
                    VStack(alignment: .leading) {
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Please note")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom,5)
                        Text("**Results may not always be accurate**\nIf your way of loving people is very different from others' or that not enough questions could apply, your results may not represent reality. If so, you're invited to [send an email](mailto:holygent@outlook.com) and suggest better questions or give your comments.")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal,20)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Your Results")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .onAppear {
                getPreferences()
                Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer1 in
                    timer1.invalidate()
                    Timer.scheduledTimer(withTimeInterval: 0.03125, repeats: true) { timer2 in
                        withAnimation {
                            if size > -0.5 {
                                size -= 0.5
                            } else if size == -0.5 && sizeCircle < 1 {
                                sizeCircle += 0.5
                            } else if sizeCircle == 1 {
                                timer2.invalidate()
                            }
                        }
                    }
                }
            }
        }
    }
}
