//
//  ContentView.swift
//  FeelingsApp
//
//  Created by Holygent on 10/03/2024.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import LocalAuthentication
import Charts
import Foundation

@Observable class Defaults {
    var loggedIn = false
    var password = ""
    var ignoreRecommendation = false
    var userID = ""
    var deviceID = ""
    var acceptedNew = false
    var lockWithLocalAuth = false
    var showLastPrefTime = false
    var showRelation = false
    var offline = false
    var acceptedWelcome = false
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var sheetNew = false
    @State private var lockData = false
    @State private var loadedFirst = false
    @Environment(Defaults.self) var defaults
    func getDefaults(forKey: String) -> Any {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let path = documentDirectory?.appendingPathComponent("Defaults.plist", conformingTo: .xml)
        if !FileManager.default.fileExists(atPath: path?.path() ?? "") {
            let emptyDict: [String: Any] = [:]
            let data = try? PropertyListSerialization.data(fromPropertyList: emptyDict, format: .xml, options: 0)
            try? data?.write(to: path!)
        }
        do {
            let readData = try Data(contentsOf: path!)
            let plist = try PropertyListSerialization.propertyList(from: readData, options: [], format: nil) as? [String: Any] ?? [:]
            return plist.first(where: { $0.key == forKey })?.value as Any
        } catch {
            return error
        }
    }
    func saveDefaults(forKey: String, value: Any) {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let path = documentDirectory?.appendingPathComponent("Defaults.plist", conformingTo: .xml)
        do {
            let readData = try Data(contentsOf: path!)
            var plist = try PropertyListSerialization.propertyList(from: readData, options: [], format: nil) as? [String: Any] ?? [:]
            plist[forKey] = value
            let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try plistData.write(to: path!)
            setupSession()
        } catch {
            print("Feelist-ThrownError=An error occured while saving to PLIST file “Defaults.plist”. { \(error.localizedDescription) }")
        }
    }
    func setupSession() {
        defaults.loggedIn = getDefaults(forKey: "loggedIn") as? Bool ?? false
        defaults.password = getDefaults(forKey: "password") as? String ?? ""
        defaults.ignoreRecommendation = getDefaults(forKey: "ignoreRecommendation") as? Bool ?? false
        defaults.userID = getDefaults(forKey: "userID") as? String ?? ""
        defaults.deviceID = getDefaults(forKey: "deviceID") as? String ?? ""
        defaults.acceptedNew = getDefaults(forKey: "acceptedNew") as? Bool ?? false
        defaults.lockWithLocalAuth = getDefaults(forKey: "lockWithLocalAuth") as? Bool ?? false
        defaults.showLastPrefTime = getDefaults(forKey: "showLastPrefTime") as? Bool ?? false
        defaults.showRelation = getDefaults(forKey: "showRelation") as? Bool ?? false
        defaults.acceptedWelcome = getDefaults(forKey: "acceptedWelcome") as? Bool ?? false
    }
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        if lockData {
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: !defaults.loggedIn ? "Sign up" : "Unlock data") { success, authenticationError in
                    if success {
                        lockData.toggle()
                        if !defaults.loggedIn {
                            saveDefaults(forKey: "loggedIn", value: true)
                            sheetCreateAccount = false
                            let userID = UUID().uuidString
                            let deviceID = UUID().uuidString
                            saveDefaults(forKey: "userID", value: userID)
                            saveDefaults(forKey: "deviceID", value: deviceID)
                            Firestore.firestore().collection("Workout").addDocument(data: ["forPart":"Users", "userID":userID, "devices":["device-\(deviceID)":["dName":machineName(), "dType":UIDevice.current.model, "osName":UIDevice.current.systemName, "osVersion":UIDevice.current.systemVersion, "deviceID":deviceID]]])
                        }
                    }
                }
            }
        } else {
            lockData.toggle()
        }
    }
    @State private var people: [(DocumentSnapshot, String)] = []
    @State private var preferences: [(name: String, preference: Double, id: String, initials: String, relation: String, lastDate: Date)] = []
    @State private var reportResponses: [(String, String, String, Bool)] = []
    @State private var lists: [(name: String, isPublic: Bool, userCount: Int, owner: String, icon: String, id: String)] = []
    @State private var announcements: [(id: String, title: String, desc: String, link: String, linkTitle: String)] = []
    @State private var loadings = ["people":false, "preferences":false, "average1":false, "average2":false, "lists":false]
    func machineName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
    func getData() {
        withAnimation {
            loadings.updateValue(true, forKey: "people")
            people.removeAll()
            reportResponses.removeAll()
        }
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Users").whereField("userID", isEqualTo: defaults.userID).getDocuments { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    let password = document.data()["password"] as? String ?? ""
                    if password != defaults.password {
                        logOut()
                    }
                }
            }
        }
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Appreciation").getDocuments { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    if !(document.data()["deleted"] as? Bool ?? false) && document.data()["userID"] as? String ?? "" == defaults.userID {
                        let stepTwo = (document.data()["name"] as? String ?? "").trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                        var final = ""
                        for string in stepTwo {
                            if final.count < 2 {
                                final += String(string.first!)
                            }
                        }
                        withAnimation {
                            people.append((document, final))
                        }
                    }
                }
                withAnimation {
                    loadings.updateValue(false, forKey: "people")
                }
            }
        }
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "UCC").getDocuments { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    if document.data()["userID"] as? String ?? "" == defaults.userID && !(document.data()["readResponse"] as? Bool ?? false) && document.data()["response"] as? String ?? "" != "" {
                        withAnimation {
                            if reportResponses.contains(where: { $0.0 == document.documentID }) {
                                reportResponses.removeAll(where: { $0.0 == document.documentID })
                            }
                            reportResponses.append((document.documentID, document.data()["responseTitle"] as? String ?? "", document.data()["response"] as? String ?? "", document.data()["resolved"] as? Bool ?? false))
                        }
                    }
                }
            }
        }
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Announcements").getDocuments { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    if !(document.data()["readBy"] as? [String] ?? []).contains(defaults.userID) {
                        withAnimation {
                            if announcements.contains(where: { $0.id == document.documentID }) {
                                announcements.removeAll(where: { $0.id == document.documentID })
                            }
                            announcements.append((document.documentID, document.data()["title"] as? String ?? "", document.data()["desc"] as? String ?? "", document.data()["link"] as? String ?? "", document.data()["linkTitle"] as? String ?? ""))
                        }
                    }
                }
            }
        }
        getHistoryAverage()
    }
    func addSnapshot() {
        withAnimation {
            loadings.updateValue(true, forKey: "preferences")
            loadings.updateValue(true, forKey: "lists")
            preferences.removeAll()
            lists.removeAll()
        }
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Appreciation").addSnapshotListener { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    querySnapshot?.documentChanges.forEach { _ in
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
                        let relation = document.data()["relation"] as? String ?? ""
                        let components = (document.data()["name"] as? String ?? "").trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                        var initials = ""
                        for string in components {
                            if initials.count < 2 {
                                initials += String(string.first!)
                            }
                        }
                        if !(document.data()["deleted"] as? Bool ?? false) && document.data()["userID"] as? String ?? "" == defaults.userID {
                            withAnimation {
                                preferences.removeAll(where: { $0.id == document.documentID })
                                preferences.append((document.data()["name"] as? String ?? "", greatestDouble, document.documentID, initials, relation, greatestTmsp.dateValue()))
                            }
                        } else {
                            withAnimation {
                                preferences.removeAll(where: { $0.id == document.documentID })
                            }
                        }
                    }
                }
            }
            withAnimation {
                loadings.updateValue(false, forKey: "preferences")
            }
        }
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Lists").addSnapshotListener { querySnapshot, error in
            if error == nil {
                let userID = defaults.userID
                for document in querySnapshot!.documents {
                    querySnapshot?.documentChanges.forEach { diff in
                        if (document.data()["users"] as? [String] ?? []).contains(userID) && !(document.data()["deleted"] as? Bool ?? false) && !(document.data()["removedUsers"] as? [String] ?? []).contains(userID) {
                            if diff.type == .added {
                                if document.data()["createdFromDeviceID"] as? String ?? "" == defaults.deviceID && !(loadings.first(where: { $0.key == "lists" })?.value as? Bool ?? false) {
                                    sheetAddList = false
                                    URLListID = document.documentID
                                    navigateToListDetails = true
                                }
                            }
                            withAnimation {
                                lists.removeAll(where: { $0.id == document.documentID })
                                lists.append((document.data()["name"] as? String ?? "", document.data()["isPublic"] as? Bool ?? false, (document.data()["users"] as? [String] ?? []).count-1, document.data()["listOwner"] as? String ?? "", document.data()["icon"] as? String ?? "", document.documentID))
                            }
                        } else {
                            withAnimation {
                                lists.removeAll(where: { $0.id == document.documentID })
                            }
                        }
                    }
                }
                withAnimation {
                    loadings.updateValue(false, forKey: "lists")
                }
            }
        }
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Users").addSnapshotListener { querySnapshot, error in
            if error == nil {
                var deviceIDs: [String] = []
                for document in querySnapshot!.documents {
                    if document.data()["userID"] as? String ?? "" == defaults.userID {
                        for device in document.data()["devices"] as? [String: [String: String]] ?? [:] {
                            deviceIDs.append(device.value.first(where: { $0.key == "deviceID" })?.value as? String ?? "")
                        }
                        if !deviceIDs.contains(defaults.deviceID) {
                            logOut()
                        }
                    }
                }
            }
        }
    }
    @State private var sheetAddData = false
    @State private var sheetAddList = false
    @State private var navigateToPreferenceDetails = false
    @State private var navigateToListDetails = false
    @State private var preferenceID = ""
    @State private var filters = ["Friend", "Family Member", "Partner", "Other"]
    @State private var lockWithLocalAuthUntiNextSession = false
    @State private var hideCharts = false
    @State private var showDialog = false
    @State private var hidePreferences = false
    @State private var sheetCreateAccount = false
    @State private var sheetLogin = false
    @State private var sheetLogin3 = false
    @State private var loginSheet = false
    @State private var alertLogOut = false
    @State private var sheetAccount = false
    @State private var sheetHelp = false
    @State private var sheetReport = false
    @State private var sheetLoginWithPassword = false
    @State private var URLJoinList = false
    @State private var URLListID = ""
    @State private var hideLists = false
    @State private var alertMustLogIn = false
    @State private var alertRemovedFromList = false
    @State private var initiatedLink = false
    var body: some View {
        NavigationStack {
            Group {
                if !defaults.loggedIn {
                    if !defaults.acceptedWelcome {
                        loginWelcome
                    } else {
                        loginBody
                    }
                } else {
                    mainBody
                }
            }
            .onAppear {
                setupSession()
                if !defaults.acceptedNew {
                    sheetNew = true
                }
            }
            .alert("Please sign up or log in first", isPresented: $alertMustLogIn) {
                Button("OK") { }
            } message: {
                Text("To join this List, please first sign up or log in.")
            }
            .alert("You were banned from this List", isPresented: $alertRemovedFromList) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The owner of this List banned you. To join back, ask them to unban you from their List settings.")
            }
            .sheet(isPresented: $sheetNew, onDismiss: { saveDefaults(forKey: "acceptedNew", value: true) }) {
                New()
                    .presentationCornerRadius(40)
            }
            .onOpenURL { url in
                initiatedLink = false
                navigateToListDetails = false
                URLJoinList = false
                if url.deletingLastPathComponent() == URL(string: "feelingsApp:///joinList/") && url.lastPathComponent != "joinList" && url.lastPathComponent != "" {
                    if !defaults.loggedIn {
                        alertMustLogIn = true
                    } else {
                        URLListID = url.lastPathComponent
                        Firestore.firestore().collection("Workout").whereField(FieldPath.documentID(), isEqualTo: URLListID).getDocuments { querySnapshot, error in
                            if error == nil {
                                for document in querySnapshot!.documents {
                                    if (document.data()["removedUsers"] as? [String] ?? []).contains(defaults.userID) {
                                        alertRemovedFromList = true
                                    } else {
                                        Firestore.firestore().collection("Workout").whereField(FieldPath.documentID(), isEqualTo: URLListID).addSnapshotListener { querySnapshot, error in
                                            if error == nil {
                                                for document in querySnapshot!.documents {
                                                    if !initiatedLink {
                                                        initiatedLink = true
                                                        sheetHelp = false
                                                        sheetReport = false
                                                        sheetAccount = false
                                                        sheetAddData = false
                                                        if (document.data()["users"] as? [String] ?? []).contains(defaults.userID) {
                                                            navigateToListDetails = true
                                                        } else {
                                                            querySnapshot?.documentChanges.forEach { diff in
                                                                if diff.type == .modified {
                                                                    navigateToListDetails = true
                                                                } else {
                                                                    URLJoinList = true
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    @State private var selectedPage = 0
    let welcomePages: [(tag: Int, title: String, desc: String, image: String)] = [(1, "Testing", "See who you prefer people by answering a 3-step questionnaire.\n\nTest friends, family members, and anyone in-between.", "FeelistWelcomePageIndex1Light"), (2, "Lists", "You can also test anyone with friends in Lists! Simply create a List and share its link.\n\nResults are automatically shared and accessible from the List.", "FeelistWelcomePageIndex2Light"), (3, "Sharing", "Share test results with a link, so easy.\n\nWhen your friend taps the link, they can save the results, test for themselves, and more.", "FeelistWelcomePageIndex3Light"), (4, "Security", "Breakthrough yet super-simple se••••ty. No more usernames and passwords, just you.\n\nYou'll see how straightforward it is when signing up or logging in.", "FeelistWelcomePageIndex4Light"), (5, "Send Feedback", "Thanks for testing Feelist. If something goes wrong or you feel like something's missing, please reach out directly from the app.", "FeelistWelcomePageIndexLastLight")]
    var loginWelcome: some View {
        TabView(selection: $selectedPage) {
            lWOne
                .tag(0)
            ForEach(welcomePages, id: \.tag) { page in
                VStack(spacing: 0) {
                    LazyVStack {
                        Text(page.title)
                            .font(.title.bold())
                            .padding(20)
                        Image(colorScheme == .dark ? page.image.replacingOccurrences(of: "Light", with: "Dark") : page.image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 0.4*UIScreen.main.bounds.height)
                            .cornerRadius(20)
                            .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 10, y: colorScheme == .light ? 5 : 10)
                    }
                    .padding(.horizontal,50)
                    LazyVStack {
                        Text(page.desc)
                            .padding(.bottom,40)
                        Button(action: {
                            withAnimation {
                                if page.tag == 5 {
                                    saveDefaults(forKey: "acceptedWelcome", value: true)
                                } else {
                                    selectedPage += 1
                                }
                            }
                        }) {
                            Text(page.tag == 5 ? "Done" : "Next")
                                .font(.headline)
                                .padding(.vertical,8)
                                .padding(.horizontal,30)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    }
                    .padding(50)
                }
                .tag(page.tag)
            }
        }
        .multilineTextAlignment(.center)
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
    var lWOne: some View {
        VStack {
            Image("FeelistAppLogo")
                .resizable()
                .frame(width: 0.35*UIScreen.main.bounds.width, height: 0.35*UIScreen.main.bounds.width)
                .cornerRadius(35)
                .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 5, y: colorScheme == .light ? 5 : 10)
                .padding(60)
            Text("Welcome to Feelist")
                .font(.title.bold())
                .padding(.bottom,20)
            Text("Let's take a quick look around.")
                .font(.system(size: 20))
                .padding(.bottom,80)
                .padding(.horizontal,20)
            Button(action: {
                withAnimation {
                    selectedPage += 1
                }
            }) {
                Text("Get Started")
                    .font(.headline)
                    .padding(.vertical,8)
                    .frame(maxWidth: UIScreen.main.bounds.width/2.25)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            Button("Skip") {
                withAnimation {
                    saveDefaults(forKey: "acceptedWelcome", value: true)
                }
            }
            .padding(10)
        }
        .padding(50)
    }
    var loginBody: some View {
        VStack {
            Image("FeelistAppLogo")
                .resizable()
                .frame(width: 0.3*UIScreen.main.bounds.width, height: 0.3*UIScreen.main.bounds.width)
                .cornerRadius(30)
                .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 5, y: colorScheme == .light ? 5 : 10)
                .padding(60)
            Text("Welcome to Feelist")
                .font(.headline)
                .padding(.bottom,2)
            Text("See how much you love people")
                .font(.title.bold())
                .padding(.bottom,40)
            Group {
                Button(action: {
                    sheetCreateAccount = true
                }) {
                    Text("Create an Account")
                        .font(.headline)
                        .padding(.vertical,8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                Button(action: {
                    sheetLogin = true
                }) {
                    Text("Log In")
                        .font(.headline)
                        .padding(.vertical,8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(defaults.offline)
            }
            .disabled(defaults.offline)
            .padding(.horizontal,75)
            .padding(5)
            .fullScreenCover(isPresented: $sheetCreateAccount) {
                createAccount
            }
            .fullScreenCover(isPresented: $sheetLogin) {
                login2
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal,15)
    }
    var createAccount: some View {
        NavigationStack {
            VStack {
                HStack {
                    Image(systemName: "faceid")
                    Image(systemName: "touchid")
                }
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 72))
                .padding(30)
                Text("No more passwords. Just you.")
                    .font(.title.bold())
                    .padding(.bottom,20)
                Text("Create an account with Face ID, Touch ID, or passcode, and that's it.\n\nThis data is only saved on-device.")
                    .font(.subheadline)
                    .padding(.bottom,40)
                Button(action: {
                    lockData = true
                    authenticate()
                }) {
                    Text("Sign Up")
                        .font(.headline)
                        .padding(.vertical,8)
                        .padding(.horizontal,30)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(defaults.offline)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal,40)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        sheetCreateAccount = false
                    }
                    .font(.headline)
                }
            }
        }
    }
    var login2: some View {
        NavigationStack {
            VStack {
                Image(systemName: "arrow.turn.up.forward.iphone")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 72))
                    .padding(30)
                Text("Generate a code from a logged-in device.")
                    .font(.title.bold())
                    .padding(.bottom,20)
                (Text("From a device that's logged into your account, go to ").font(.headline) + Text(Image(systemName: "ellipsis.circle")).foregroundStyle(Color.accentColor) + Text(" > ").font(.headline) + Text("Log in on another device ") + Text(Image(systemName: "iphone.and.arrow.forward")))
                    .padding(.bottom,40)
                Button(action: {
                    sheetLogin3 = true
                }) {
                    Text("Next")
                        .font(.headline)
                        .padding(.vertical,8)
                        .padding(.horizontal,30)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .padding(.bottom,60)
                Button("Log in with password instead") {
                    sheetLoginWithPassword = true
                }
            }
            .disabled(defaults.offline)
            .multilineTextAlignment(.center)
            .padding(.horizontal,40)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        sheetLogin = false
                    }
                    .font(.headline)
                }
            }
            .fullScreenCover(isPresented: $sheetLogin3) {
                login3
            }
            .fullScreenCover(isPresented: $sheetLoginWithPassword) {
                loginWithPassword
            }
        }
    }
    @State private var codeUser = 0
    @State private var codeIncorrect = false
    let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .none
        nf.zeroSymbol = ""
        return nf
    }()
    func login() {
        Firestore.firestore().collection("Workout").whereField(sheetLogin3 ? "loginCode" : "password", isEqualTo: sheetLogin3 ? codeUser : passwordUser).getDocuments { querySnapshot, error in
            if error == nil {
                if querySnapshot!.documents.count == 0 {
                    codeIncorrect = true
                } else {
                    for document in querySnapshot!.documents {
                        let password = document.data()["password"] as? String ?? ""
                        let userID = document.data()["userID"] as? String ?? ""
                        let deviceID = UUID().uuidString
                        withAnimation {
                            saveDefaults(forKey: "loggedIn", value: true)
                            sheetLogin = false
                            sheetLogin3 = false
                            saveDefaults(forKey: "userID", value: userID)
                            saveDefaults(forKey: "deviceID", value: deviceID)
                            saveDefaults(forKey: "password", value: password)
                        }
                        Firestore.firestore().collection("Workout").document(document.documentID).updateData(["loginCode":FieldValue.delete(), "devices.device-\(deviceID)":["dName":machineName(), "dType":UIDevice.current.model, "osName":UIDevice.current.systemName, "osVersion":UIDevice.current.systemVersion, "deviceID":deviceID]])
                        addSnapshot()
                        codeUser = 0
                        passwordUser = ""
                    }
                }
            }
        }
    }
    var login3: some View {
        NavigationStack {
            VStack {
                Image(systemName: "123.rectangle")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 72))
                    .padding(30)
                Text("What's the code?")
                    .font(.title.bold())
                    .padding(.bottom,20)
                TextField("Code", value: $codeUser, formatter: numberFormatter)
                    .keyboardType(.numberPad)
                    .font(.largeTitle.bold())
                    .fontDesign(.monospaced)
                    .padding(.vertical,15)
                    .padding(.bottom,25)
                Button(action: {
                    login()
                }) {
                    Text("Log In")
                        .font(.headline)
                        .padding(.vertical,8)
                        .padding(.horizontal,30)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(defaults.offline)
                .alert("Incorrect code", isPresented: $codeIncorrect) {
                    Button("OK") { }
                } message: {
                    Text("The code you provided does not match any user.")
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal,40)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        sheetLogin = false
                    }
                    .font(.headline)
                }
            }
        }
    }
    @State private var passwordUser = ""
    var loginWithPassword: some View {
        NavigationStack {
            VStack {
                Image(systemName: "key.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 72))
                    .padding(30)
                Text("Enter your account password.")
                    .font(.title.bold())
                    .padding(.bottom,20)
                Text("Make sure your account has a password.")
                    .font(.subheadline)
                    .padding(.bottom,40)
                TextField("Password", text: $passwordUser)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.vertical,15)
                    .padding(.bottom,25)
                Button(action: {
                    login()
                }) {
                    Text("Log In")
                        .font(.headline)
                        .padding(.vertical,8)
                        .padding(.horizontal,30)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(defaults.offline)
                .alert("Incorrect password", isPresented: $codeIncorrect) {
                    Button("OK") { }
                } message: {
                    Text("The password you provided does not match any user.")
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal,40)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        sheetLogin = false
                    }
                    .font(.headline)
                }
            }
        }
    }
    @State private var code = 0
    @State private var documentIDForUserID = ""
    @State private var loadingCode = false
    func generateCode() {
        withAnimation {
            loadingCode = true
        }
        var existingCodes = [1]
        var orgDevices: [String: [String: String]] = [:]
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Users").getDocuments { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    if document.data()["userID"] as? String ?? "" != defaults.userID {
                        existingCodes.append(document.data()["loginCode"] as? Int ?? 0)
                    } else {
                        if orgDevices.count == 0 {
                            orgDevices = document.data()["devices"] as? [String: [String: String]] ?? [:]
                        }
                        documentIDForUserID = document.documentID
                        var someCode = 1
                        repeat {
                            someCode = Int.random(in: 1..<1000)
                        } while existingCodes.contains(someCode)
                        Firestore.firestore().collection("Workout").document(documentIDForUserID).updateData(["loginCode":someCode])
                        code = someCode
                    }
                    withAnimation {
                        loadingCode = false
                    }
                }
            }
        }
        Firestore.firestore().collection("Workout").whereField("userID", isEqualTo: defaults.userID).addSnapshotListener { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    for diff in querySnapshot!.documentChanges {
                        if diff.type == .modified && orgDevices.count < (document.data()["devices"] as? [String: [String: String]] ?? [:]).count {
                            loginSheet = false
                        }
                    }
                }
            }
        }
    }
    let steps: [(index: Int, title: String, desc: String)] = [(0, "Bring your other device", "Bring the device you want to log into your account."), (1, "Tap “Log In”", "On your other device, tap “Log In” from Welcome to Feelist and follow the instructions."), (2, "Insert the code above", "When asked, insert the code above and tap “Log In”.")]
    var loginOnOtherDevice: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    if loadingCode {
                        ProgressView()
                            .padding(15)
                            .frame(maxWidth: .infinity)
                    }
                    Text(loadingCode ? "Loading..." : "\(code)")
                        .font(.system(size: 72, weight: .semibold, design: .monospaced))
                        .padding(.vertical,75)
                    Divider()
                        .padding(.bottom,10)
                    ForEach(steps, id: \.index) { step in
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(step.index+1)")
                                .font(.title2.bold())
                                .foregroundStyle(.blue)
                                .frame(width: 25)
                            VStack(alignment: .leading) {
                                Text(step.title)
                                    .font(.headline)
                                Text(step.desc)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondary)
                                Divider()
                                    .padding(.vertical,10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal,15)
            }
            .navigationTitle("Log in on another device")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                generateCode()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        loginSheet = false
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
    func logOut() {
        Firestore.firestore().collection("Workout").whereField("userID", isEqualTo: defaults.userID).getDocuments { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    if document.data()["userID"] as? String ?? "" == defaults.userID {
                        for device in document.data()["devices"] as? [String: [String: String]] ?? [:] {
                            if device.value.first(where: { $0.key == "deviceID" })?.value as? String ?? "" == defaults.deviceID {
                                Firestore.firestore().collection("Workout").document(document.documentID).updateData(["devices.\(device.key)":FieldValue.delete()])
                            }
                        }
                    }
                }
                withAnimation {
                    people.removeAll()
                    average1.removeAll()
                    average2.removeAll()
                    preferences.removeAll()
                    lists.removeAll()
                    hidePreferences = false
                    hideLists = false
                    hideCharts = false
                    filters = ["Friend", "Family Member", "Partner", "Other"]
                    saveDefaults(forKey: "loggedIn", value: false)
                    saveDefaults(forKey: "userID", value: "")
                    saveDefaults(forKey: "deviceID", value: "")
                    saveDefaults(forKey: "password", value: "")
                    saveDefaults(forKey: "ignoreRecommendation", value: false)
                }
            }
        }
    }
    var mainBody: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if !defaults.lockWithLocalAuth && !defaults.ignoreRecommendation && people.count > 3 {
                    VStack(alignment: .leading) {
                        Text("Recommended")
                            .textCase(.uppercase)
                            .fontDesign(.rounded)
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        HStack(spacing: 5) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.accentColor)
                                .font(.title3)
                            Text("Auto-Lock")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Divider()
                            .padding(.vertical,5)
                        Text("Automatically locks your data when you leave the app. It's back when you're back, too.")
                            .font(.subheadline)
                            .padding(.bottom,10)
                        Button(action: {
                            withAnimation {
                                saveDefaults(forKey: "lockWithLocalAuth", value: true)
                            }
                            lockData = true
                            authenticate()
                            if !defaults.offline {
                                getData()
                            }
                        }) {
                            Text("Enable")
                                .font(.headline)
                                .padding(.vertical,8)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .cornerRadius(15)
                        Button("Not Now") {
                            withAnimation {
                                saveDefaults(forKey: "ignoreRecommendation", value: true)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .font(.subheadline)
                        .padding(.top,5)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .light ? .white : Color(red: 20/255, green: 20/255, blue: 20/255))
                    .cornerRadius(25)
                    .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 10, y: colorScheme == .light ? 5 : 10)
                    .padding(.horizontal,15)
                    .padding(.bottom,20)
                    Divider()
                        .padding(.bottom,reportResponses.count > 0 ? 20 : 0)
                }
                overClosure
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 2) {
                        Button(action: {
                            sheetAddData = true
                        }) {
                            VStack(alignment: .center) {
                                ZStack {
                                    Circle()
                                        .fill(.blue.opacity(0.2))
                                    Image(systemName: "plus")
                                        .font(.title)
                                        .fontDesign(.rounded)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.accentColor)
                                }
                                Text("Add Person")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 0.18*UIScreen.main.bounds.width)
                            .padding(.trailing,12)
                        }
                        if loadings.first(where: { $0.key == "people" })?.value as? Bool ?? false {
                            ProgressView()
                                .frame(width: 0.18*UIScreen.main.bounds.width)
                                .frame(maxHeight: .infinity)
                                .padding(.trailing,12)
                        } else if people.count == 0 {
                            Text("Test people to view them here.")
                                .padding(.horizontal,(0.18*UIScreen.main.bounds.width-CGFloat(24))/CGFloat(2))
                                .frame(maxHeight: .infinity)
                                .font(.headline)
                        }
                        ForEach(people.sorted(by: { item1, item2 in
                            (item1.0.data()?["testDate"] as? [Timestamp] ?? []).last?.dateValue() ?? Date() > (item2.0.data()?["testDate"] as? [Timestamp] ?? []).last?.dateValue() ?? Date()
                        }), id: \.0.documentID) { ppl in
                            Button(action: {
                                preferenceID = ppl.0.documentID
                                navigateToPreferenceDetails = true
                            }) {
                                VStack(alignment: .center) {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(colors: colorScheme == .light ? [.gray.opacity(0.5), .gray.opacity(0.85)] : [.white.opacity(0.75), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                            .frame(height: 0.18*UIScreen.main.bounds.width)
                                        Text(ppl.1)
                                            .font(.title)
                                            .fontDesign(.rounded)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                    }
                                    Text(ppl.0.data()?["name"] as? String ?? "")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(width: 0.18*UIScreen.main.bounds.width)
                                .padding(.trailing,12)
                                .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.leading,15)
                }
                .padding(.top,15)
                Divider()
                    .padding(.vertical,15)
                if loadings.first(where: { $0.key == "lists" })?.value as? Bool ?? false {
                    ProgressView()
                        .frame(height: 0.25*UIScreen.main.bounds.height)
                        .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 0) {
                            Text("Lists")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(action: {
                                sheetAddList = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.subheadline.bold())
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                            .disabled(defaults.offline)
                            Button(action: {
                                if preferences.count > 0 {
                                    withAnimation {
                                        hideLists.toggle()
                                    }
                                } else {
                                    sheetHelp = true
                                }
                            }) {
                                Image(systemName: preferences.count > 0 ? "chevron.up" : "questionmark")
                                    .font(.subheadline.bold())
                                    .rotationEffect(hideLists ? .degrees(180) : .degrees(0))
                                    .padding(preferences.count > 0 ? 2 : 0)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                        }
                        .padding(.horizontal,15)
                        if !hideLists {
                            if lists.count > 0 {
                                ScrollView(.horizontal) {
                                    HStack(alignment: .top) {
                                        ForEach(lists, id: \.id) { list in
                                            Button(action: {
                                                URLListID = list.id
                                                navigateToListDetails = true
                                            }) {
                                                HStack {
                                                    Text(list.icon)
                                                        .font(.title2)
                                                        .frame(width: 0.125*UIScreen.main.bounds.width, height: 0.125*UIScreen.main.bounds.width)
                                                        .background(colorScheme == .light ? Color(red: 220/255, green: 220/255, blue: 220/255) : Color(red: 50/255, green: 50/255, blue: 50/255))
                                                        .cornerRadius(10)
                                                    VStack(alignment: .leading) {
                                                        Text(list.name)
                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                        (Text(Image(systemName: list.isPublic ? "lock.open.fill" : "lock.fill")) + (list.isPublic ? (Text(" Shared • ") + Text(Image(systemName: "person.2.fill")) + Text(" \(list.userCount)")) : Text(" Private")))
                                                            .font(.caption)
                                                            .foregroundStyle(Color.secondary)
                                                    }
                                                    .multilineTextAlignment(.leading)
                                                }
                                                .foregroundStyle(Color.primary)
                                                .padding(.trailing,15)
                                            }
                                        }
                                    }
                                    .padding(.leading,15)
                                }
                            } else if preferences.count > 0 {
                                VStack {
                                    HStack {
                                        Image(systemName: "folder.fill.badge.plus")
                                            .foregroundStyle(Color.accentColor)
                                        Text("Test with friends!")
                                    }
                                    .font(.headline)
                                    .padding(.bottom,10)
                                    Text("Lists allow you to test people with your friends in real time, show them who you really love, and more.")
                                        .font(.caption)
                                        .padding(.bottom,20)
                                    Button(action: {
                                        sheetAddList = true
                                    }) {
                                        Text("Create a List")
                                            .font(.headline)
                                            .padding(.vertical,5)
                                            .padding(.horizontal,10)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .buttonBorderShape(.capsule)
                                }
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal,35)
                                .padding(.vertical,10)
                            }
                        }
                    }
                    Divider()
                        .padding(.vertical,15)
                }
                if loadings.first(where: { $0.key == "average1" })?.value as? Bool ?? false || loadings.first(where: { $0.key == "average1" })?.value as? Bool ?? false {
                    ProgressView()
                        .frame(height: 0.25*UIScreen.main.bounds.height)
                        .frame(maxWidth: .infinity)
                } else if preferences.count > 0 {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 0) {
                            Text("Highlights")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(action: {
                                withAnimation {
                                    hideCharts.toggle()
                                }
                            }) {
                                Image(systemName: "chevron.up")
                                    .font(.subheadline.bold())
                                    .rotationEffect(hideCharts ? .degrees(180) : .degrees(0))
                                    .padding(2)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                        }
                        if !hideCharts {
                            if average1.count > 1 && average2.count >= 4 {
                                charts
                                    .padding(.top,5)
                                    .padding(.bottom,10)
                            } else {
                                VStack {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundStyle(Color.accentColor)
                                        Text("Keep Testing")
                                    }
                                    .font(.headline)
                                    .padding(.bottom,10)
                                    Text("Test more people today and tomorrow for insights on your preferences.")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal,20)
                                .padding(.vertical,10)
                            }
                        }
                    }
                    .padding(.horizontal,15)
                    Divider()
                        .padding(.vertical,15)
                }
                if loadings.first(where: { $0.key == "preferences" })?.value as? Bool ?? false {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal,15)
                } else if preferences.count == 0 {
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
                            .padding(.bottom,40)
                        Button(action: {
                            sheetAddData = true
                        }) {
                            Text("Test Someone")
                                .font(.headline)
                                .padding(.vertical,8)
                                .padding(.horizontal,30)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal,15)
                    .padding(.bottom,10)
                } else if preferences.count > 0 {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center, spacing: 0) {
                            Text("Preferences")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Menu {
                                Button(action: {
                                    withAnimation {
                                        if filters.contains("Friend") {
                                            filters.removeAll(where: { $0 == "Friend" })
                                        } else {
                                            filters.append("Friend")
                                        }
                                    }
                                }) {
                                    Label("Friends (\(preferences.filter({ $0.relation == "Friend" }).count))", systemImage: filters.contains("Friend") ? "checkmark" : "")
                                }
                                Button(action: {
                                    withAnimation {
                                        if filters.contains("Family Member") {
                                            filters.removeAll(where: { $0 == "Family Member" })
                                        } else {
                                            filters.append("Family Member")
                                        }
                                    }
                                }) {
                                    Label("Family Members (\(preferences.filter({ $0.relation == "Family Member" }).count))", systemImage: filters.contains("Family Member") ? "checkmark" : "")
                                }
                                Button(action: {
                                    withAnimation {
                                        if filters.contains("Partner") {
                                            filters.removeAll(where: { $0 == "Partner" })
                                        } else {
                                            filters.append("Partner")
                                        }
                                    }
                                }) {
                                    Label("Partners (\(preferences.filter({ $0.relation == "Partner" }).count))", systemImage: filters.contains("Partner") ? "checkmark" : "")
                                }
                                Button(action: {
                                    withAnimation {
                                        if filters.contains("Other") {
                                            filters.removeAll(where: { $0 == "Other" })
                                        } else {
                                            filters.append("Other")
                                        }
                                    }
                                }) {
                                    Label("Other (\(preferences.filter({ $0.relation == "Other" }).count))", systemImage: filters.contains("Other") ? "checkmark" : "")
                                }
                            } label: {
                                Button(action: {
                                    showDialog = true
                                }) {
                                    Image(systemName: "line.3.horizontal.decrease")
                                        .font(.subheadline.bold())
                                        .padding(2)
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.circle)
                                .badge(-1*(filters.count-3))
                            }
                            Button(action: {
                                withAnimation {
                                    hidePreferences.toggle()
                                }
                            }) {
                                Image(systemName: "chevron.up")
                                    .font(.subheadline.bold())
                                    .rotationEffect(hidePreferences ? .degrees(180) : .degrees(0))
                                    .padding(2)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)
                        }
                        if !hidePreferences {
                            if preferences.count <= 3 {
                                Button(action: {
                                    sheetAddData = true
                                }) {
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(.blue.opacity(0.2))
                                                .frame(height: 0.125*UIScreen.main.bounds.width)
                                            Image(systemName: "plus")
                                                .font(.title2)
                                                .fontDesign(.rounded)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        Text("Add Someone Else")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                Divider()
                                    .padding(.vertical,2)
                                    .padding(.horizontal,5)
                            }
                            ForEach(preferences.sorted(by: { item1, item2 in
                                item1.preference > item2.preference
                            }).filter({ filters.contains($0.relation) }), id: \.id) { preference in
                                Button(action: {
                                    preferenceID = preference.id
                                    navigateToPreferenceDetails = true
                                }) {
                                    HStack(alignment: .center) {
                                        ZStack {
                                            Circle()
                                                .fill(LinearGradient(colors: colorScheme == .light ? [.gray.opacity(0.5), .gray.opacity(0.85)] : [.white.opacity(0.75), .white.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                                .frame(height: 0.125*UIScreen.main.bounds.width)
                                            Text(preference.initials)
                                                .font(.title3)
                                                .fontDesign(.rounded)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                        }
                                        VStack(alignment: .leading) {
                                            Text(preference.name)
                                                .foregroundColor(.primary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            let bothOn = defaults.showLastPrefTime && defaults.showRelation
                                            if defaults.showLastPrefTime || defaults.showRelation {
                                                Text("\(defaults.showLastPrefTime ? DateFormatter.localizedString(from: preference.lastDate, dateStyle: .medium, timeStyle: .none) : "")\(bothOn ? " • " : "")\(defaults.showRelation ? preference.relation : "")")
                                                    .foregroundStyle(Color.secondary)
                                                    .font(.caption)
                                            }
                                        }
                                        .multilineTextAlignment(.leading)
                                        Text("\(Int(preference.preference*100))%")
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
                    .padding(.horizontal,15)
                }
            }
        }
        .navigationTitle("Feelist")
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Menu {
                    Button(action: {
                        sheetAccount = true
                    }) {
                        Label("Account", systemImage: "person.crop.circle.fill")
                    }
                    Button(action: {
                        sheetHelp = true
                    }) {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                    Divider()
                    Button(action: {
                        loginSheet = true
                    }) {
                        Label("Log in on another device", systemImage: "iphone.and.arrow.forward")
                    }
                    .disabled(defaults.offline)
                    Button(role: .destructive, action: {
                        if defaults.password.count == 0 {
                            alertLogOut = true
                        } else {
                            logOut()
                        }
                    }) {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.forward")
                    }
                    .disabled(defaults.offline)
                } label: {
                    Label("More Actions", systemImage: "ellipsis.circle")
                }
                .alert("Hold up! Make sure you can log back in", isPresented: $alertLogOut) {
                    Button("Log out", role: .destructive) { logOut() }
                    Button("Set Password") { sheetAccount = true }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("If this is your only device, make sure you've set a password to log back in. Otherwise, you won't be able to access your data back.")
                }
                if defaults.offline {
                    Label("You're Offline", systemImage: "wifi.slash")
                        .foregroundStyle(.red)
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: {
                    sheetReport = true
                }) {
                    Label("Send Feedback", systemImage: "exclamationmark.bubble")
                }
                .tint(.red)
                Button(action: {
                    authenticate()
                }) {
                    Label("Quick Lock", systemImage: "lock.fill")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)) { _ in
            if defaults.lockWithLocalAuth {
                showChart1Details = false
                showChart2Details = false
                lockData = true
                authenticate()
                getData()
            }
        }
        .onAppear {
            getData()
            if !loadedFirst {
                addSnapshot()
                if defaults.lockWithLocalAuth {
                    lockData = true
                    authenticate()
                }
                loadedFirst = true
            }
        }
        .refreshable {
            getData()
        }
        .navigationDestination(isPresented: $navigateToPreferenceDetails) {
            AppreciationDetails(id: preferenceID, list: false, listMetaKey: "", listMetaV: 0.0, listTestIndex: 0)
        }
        .navigationDestination(isPresented: $navigateToListDetails) {
            ListDetails(id: $URLListID)
        }
        .sheet(isPresented: $sheetAddData, onDismiss: { getData() }) {
            AddAppreciation(nameTest: CurrentTest())
                .presentationCornerRadius(40)
        }
        .sheet(isPresented: $showChart1Details) {
            chart1Details
                .presentationCornerRadius(40)
        }
        .sheet(isPresented: $showChart2Details) {
            chart2Details
                .presentationCornerRadius(40)
        }
        .sheet(isPresented: $loginSheet, onDismiss: { Firestore.firestore().collection("Workout").document(documentIDForUserID).updateData(["loginCode":FieldValue.delete()]) }) {
            loginOnOtherDevice
                .presentationCornerRadius(40)
        }
        .sheet(isPresented: $sheetAccount, onDismiss: { getData(); saveDefaults(forKey: "password", value: defaults.password) }) {
            Account()
                .presentationCornerRadius(40)
        }
        .sheet(isPresented: $sheetHelp) {
            Help(suggestedSection: "General questions")
                .presentationCornerRadius(40)
        }
        .sheet(isPresented: $sheetReport) {
            ReportView()
                .presentationCornerRadius(40)
        }
        .sheet(isPresented: $sheetAddList) {
            AddList()
                .presentationCornerRadius(40)
        }
        .sheet(isPresented: self.$URLJoinList) {
            JoinList(urlListID: self.$URLListID)
                .presentationCornerRadius(40)
        }
        .fullScreenCover(isPresented: $lockData) {
            dataLocked
        }
    }
    var overClosure: some View {
        VStack {
            if announcements.count > 0 {
                ForEach(announcements, id: \.id) { announcement in
                    VStack(alignment: .leading) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("From the Developer")
                                    .textCase(.uppercase)
                                    .fontDesign(.rounded)
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                Text(announcement.title)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Button("Dismiss") {
                                Firestore.firestore().collection("Workout").document(announcement.id).getDocument { document, error in
                                    if error == nil {
                                        let read = document?.data()?["readBy"] as? [String] ?? []
                                        Firestore.firestore().collection("Workout").document(announcement.id).updateData(["readBy":read + [defaults.userID]])
                                    }
                                }
                                withAnimation {
                                    announcements.removeAll(where: { $0.id == announcement.id })
                                }
                            }
                        }
                        Divider()
                            .padding(.vertical,5)
                        Text(announcement.desc)
                            .font(.subheadline)
                            .padding(.bottom,5)
                        if !announcement.link.isEmpty {
                            Link(destination: URL(string: announcement.link)!) {
                                (Text("\(announcement.linkTitle.isEmpty ? announcement.link : announcement.linkTitle) ") + Text(Image(systemName: "arrow.up.forward")))
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .light ? .white : Color(red: 20/255, green: 20/255, blue: 20/255))
                    .cornerRadius(25)
                    .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 10, y: colorScheme == .light ? 5 : 10)
                    .padding(.horizontal,15)
                    .padding(.bottom,20)
                }
            }
            if reportResponses.count > 0 {
                ForEach(reportResponses, id: \.0) { reportResponse in
                    VStack(alignment: .leading) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("From the Developer")
                                    .textCase(.uppercase)
                                    .fontDesign(.rounded)
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                HStack(spacing: 5) {
                                    Image(systemName: "arrowshape.turn.up.left.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.title3)
                                    Text(reportResponse.1)
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Button("Dismiss") {
                                Firestore.firestore().collection("Workout").document(reportResponse.0).updateData(["readResponse":true])
                                withAnimation {
                                    reportResponses.removeAll(where: { $0.0 == reportResponse.0 })
                                }
                            }
                        }
                        Divider()
                            .padding(.vertical,5)
                        Text(reportResponse.2)
                            .font(.subheadline)
                            .padding(.bottom,5)
                        (Text(Image(systemName: !reportResponse.3 ? "xmark.circle.fill" : "checkmark.circle.fill")).foregroundStyle(!reportResponse.3 ? .red : .green) + Text(" The problem you reported was \(!reportResponse.3 ? "not yet " : "")resolved."))
                            .font(.caption)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .light ? .white : Color(red: 20/255, green: 20/255, blue: 20/255))
                    .cornerRadius(25)
                    .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 10, y: colorScheme == .light ? 5 : 10)
                    .padding(.horizontal,15)
                    .padding(.bottom,20)
                }
                Divider()
            }
        }
    }
    var dataLocked: some View {
        VStack {
            Image(systemName: "lock.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)
                .padding(15)
            Text("Feelist is Locked.")
                .font(.title.bold())
                .padding(.bottom,15)
            Text("The app is locked so others cannot view your data. Please unlock to use Feelist again.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom,40)
            Button(action: {
                withAnimation {
                    authenticate()
                }
            }) {
                Text("Unlock")
                    .font(.headline)
                    .padding(.vertical,8)
                    .padding(.horizontal,30)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal,40)
    }
    @State private var average1: [(Double, Date)] = []
    @State private var average2: [(Double, Date)] = []
    let dateFormatter = DateFormatter()
    let dateFormatter2 = DateFormatter()
    func getHistoryAverage() {
        withAnimation {
            average1.removeAll()
            average2.removeAll()
            loadings.updateValue(true, forKey: "average1")
            loadings.updateValue(true, forKey: "average2")
        }
        dateFormatter.dateFormat = "E"
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Appreciation").getDocuments { querySnapshot, error in
            if error == nil {
                var allTmsps: [Date] = []
                var allDoubles: [Double] = []
                for document in querySnapshot!.documents {
                    if !(document.data()["deleted"] as? Bool ?? false) && document.data()["userID"] as? String ?? "" == defaults.userID {
                        for tests in document.data()["tests"] as? [String: [String: Any]] ?? [:] {
                            var tmsp = (tests.value.first(where: { $0.key == "date" })?.value as? Timestamp ?? Timestamp()).dateValue()
                            tmsp = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: tmsp)!
                            if !allTmsps.contains(where: { Calendar.current.isDate(tmsp, inSameDayAs: $0) }) {
                                allTmsps.append(tmsp)
                            }
                            for allTmsp in allTmsps {
                                if Calendar.current.isDate(allTmsp, inSameDayAs: tmsp) && !average1.contains(where: { $0.1 == allTmsp }) && allTmsp >= Calendar.current.date(byAdding: .day, value: -7, to: Date())! {
                                    allDoubles.append(tests.value.first(where: { $0.key == "double" })?.value as? Double ?? 0.0)
                                    var totalCount = 0.0
                                    for allDouble in allDoubles {
                                        totalCount += allDouble
                                    }
                                    let avg = totalCount/(Double(allDoubles.count) == 0 ? 1.0 : Double(allDoubles.count))
                                    withAnimation {
                                        average1.append((avg, allTmsp))
                                    }
                                }
                                allDoubles.removeAll()
                            }
                        }
                    }
                }
                withAnimation {
                    loadings.updateValue(false, forKey: "average1")
                }
            }
        }
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Appreciation").getDocuments { querySnapshot, error in
            if error == nil {
                var allValues: [Date: [Double]] = [:]
                for document in querySnapshot!.documents {
                    if !(document.data()["deleted"] as? Bool ?? false) && document.data()["userID"] as? String ?? "" == defaults.userID {
                        for tests in (document.data()["tests"] as? [String: [String: Any]] ?? [:]) {
                            var tmsp = (tests.value.first(where: { $0.key == "date" })?.value as? Timestamp ?? Timestamp()).dateValue()
                            tmsp = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: tmsp)!
                            let value = tests.value.first(where: { $0.key == "double" })?.value as? Double ?? 0.0
                            if allValues.contains(where: { Calendar.current.isDate(tmsp, inSameDayAs: $0.key) }) {
                                allValues[tmsp]?.append(value)
                            } else {
                                allValues[tmsp] = [value]
                            }
                        }
                    }
                }
                var totalDouble = 0.0
                var totalCount = 0.0
                for allValue in allValues.sorted(by: { item1, item2 in
                    item1.key < item2.key
                }) {
                    for value in allValue.value {
                        totalDouble += value
                        totalCount += 1
                    }
                    withAnimation {
                        average2.append(((totalDouble/(totalCount == 0 ? 1 : totalCount)), allValue.key))
                    }
                }
                withAnimation {
                    if average2.count >= 50 {
                        dateFormatter2.dateFormat = "M/d/yy"
                    } else if average2.count >= 25 {
                        dateFormatter2.dateFormat = "MMM d, yy"
                    } else {
                        dateFormatter2.dateFormat = "MMMM d, yyyy"
                    }
                    loadings.updateValue(false, forKey: "average2")
                }
            }
        }
    }
    @State private var showChart1Details = false
    @State private var showChart2Details = false
    @State private var showLastXValue = false
    var charts: some View {
        VStack(alignment: .leading) {
            if !(loadings.first(where: { $0.key == "average1" })?.value as? Bool ?? false) && average1.count > 1 {
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("This Week")
                            .font(.title3.bold())
                            .fontDesign(.rounded)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button(action: {
                            showChart1Details = true
                        }) {
                            Image(systemName: "info")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                    }
                    .padding(.bottom,10)
                    Chart {
                        ForEach(average1.sorted(by: { item1, item2 in
                            item1.1 < item2.1
                        }), id: \.1) { avg in
                            BarMark(x: .value("Date", dateFormatter.string(from: avg.1)), y: .value("Average", avg.0*100))
                                .cornerRadius(12)
                            
                        }
                    }
                    .chartYScale(domain: [Int((average1.min(by: { item1, item2 in
                        item1.0 < item2.0
                    })?.0 ?? 0.0)*100) < 0 ? Int((average1.min(by: { item1, item2 in
                        item1.0 < item2.0
                    })?.0 ?? 0.0)*100) : 0, 100])
                    .chartYAxis {
                        AxisMarks(format: Decimal.FormatStyle.Percent.percent.scale(1), position: .leading, values: [0, 50, 100])
                    }
                    .frame(height: 0.25*UIScreen.main.bounds.height)
                    if average1.count <= 4 {
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.accentColor)
                                .font(.subheadline.bold())
                            Text("Test more people for more insight!")
                                .font(.subheadline)
                        }
                        .padding(.top,5)
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colorScheme == .light ? .white : Color(red: 20/255, green: 20/255, blue: 20/255))
                .cornerRadius(25)
                .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 10, y: colorScheme == .light ? 5 : 10)
                .padding(.bottom,20)
            }
            if !(loadings.first(where: { $0.key == "average2" })?.value as? Bool ?? false) && average2.count >= 4 {
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("All-Time")
                            .font(.title3.bold())
                            .fontDesign(.rounded)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button(action: {
                            showChart2Details = true
                        }) {
                            Image(systemName: "info")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                    }
                    .padding(.bottom,10)
                    ZStack {
                        Text("\(DateFormatter.localizedString(from: average2.sorted(by: { item1, item2 in item1.1 < item1.1 }).last?.1 as? Date ?? Date(), dateStyle: dateFormatter2.dateFormat == "MMMM d, yyyy" ? .long : dateFormatter2.dateFormat == "MMM d, yy" ? .medium : .short, timeStyle: .none))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(.trailing,5)
                        Chart {
                            ForEach(average2.sorted(by: { item1, item2 in
                                item1.1 < item2.1
                            }), id: \.1) { avg in
                                LineMark(x: .value("Date", avg.1), y: .value("Average", avg.0*100))
                                    .interpolationMethod(.catmullRom)
                                    .lineStyle(StrokeStyle(lineWidth: 4, lineJoin: .round))
                            }
                        }
                        .chartYScale(domain: [Int((average2.min(by: { item1, item2 in
                            item1.0 < item2.0
                        })?.0 ?? 0.0)*100) < 0 ? Int((average2.min(by: { item1, item2 in
                            item1.0 < item2.0
                        })?.0 ?? 0.0)*100) : 0, 100])
                        .chartYAxis {
                            AxisMarks(format: Decimal.FormatStyle.Percent.percent.scale(1), position: .leading, values: [0, 50, 100])
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: average2.count)) { value in
                                let dateValue = Calendar.current.component(.day, from: value.as(Date.self) ?? Date())
                                AxisValueLabel {
                                    VStack(alignment: .leading) {
                                        if dateValue == 1 || value.index == 0 {
                                            Text(dateFormatter2.string(from: value.as(Date.self) ?? Date()))
                                                .onAppear {
                                                    withAnimation {
                                                        if value.index >= value.count-4 {
                                                            showLastXValue = false
                                                        } else {
                                                            showLastXValue = true
                                                        }
                                                    }
                                                }
                                        }
                                    }
                                }
                                if dateValue == 1 || value.index == 0 || value.index+1 == value.count {
                                    AxisGridLine()
                                    AxisTick()
                                }
                            }
                        }
                        .frame(height: 0.25*UIScreen.main.bounds.height)
                    }
                    let valuesCompared = ((average2.sorted(by: { item1, item2 in item1.1 < item2.1 }).last?.0 as? Double ?? 0.0)-(average2.sorted(by: { item1, item2 in item1.1 < item2.1 }).first?.0 as? Double ?? 0.0))*100
                    let aroundZero = (valuesCompared >= -5 && valuesCompared <= 5)
                    let moreThanZero = (valuesCompared > 5)
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: aroundZero || moreThanZero ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(aroundZero || moreThanZero ? Color.green : Color.orange)
                            .font(.subheadline.bold())
                        Text(aroundZero ? "You happen to be preferring people as much as you used to." : moreThanZero ? "You happen to be preferring more people than you used to." : "You happen to be preferring less people than you used to.")
                            .font(.subheadline)
                    }
                    .padding(.top,5)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(colorScheme == .light ? .white : Color(red: 20/255, green: 20/255, blue: 20/255))
                .cornerRadius(25)
                .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 10, y: colorScheme == .light ? 5 : 10)
            }
        }
    }
    @Environment(\.presentationMode) var presentationMode
    let rectangles: [CGFloat] = [25, 70, 35, 80, 60, 30]
    var chart1Details: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title.bold())
                            .foregroundColor(.accentColor)
                        Text("About the Chart")
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom,20)
                    Text("“This Week” presents the **daily preference percentage average**.")
                        .padding(.bottom,10)
                    HStack {
                        Text("Preference %")
                            .font(.subheadline)
                        VStack {
                            HStack(alignment: .bottom) {
                                Divider()
                                ForEach(rectangles, id: \.self) { size in
                                    ZStack {
                                        Rectangle()
                                            .foregroundStyle(Color.accentColor)
                                            .cornerRadius(12)
                                            .frame(height: size)
                                            .frame(maxHeight: .infinity, alignment: .bottom)
                                        Rectangle()
                                            .foregroundStyle(Color.accentColor)
                                            .frame(height: size/2)
                                            .frame(maxHeight: .infinity, alignment: .bottom)
                                    }
                                }
                            }
                            Divider()
                            Text("Time")
                                .font(.subheadline)
                        }
                        .padding(10)
                    }
                    Text("The chart presents your daily preference percentage average for this week. This means that it presents the average of the results you've had for each day within the current week.\n\nIn order for the chart to be shown in “Highlights”, you must test at least one person this week.\n\nReviewing your daily average can help better understand how you most recently enjoy moments with certain people, as well as understand who you prefer the most and strengthen moments with them, and the opposite. Limiting the chart to only the current week allows you to reflect and what's most recent, that is, thought to be more accurate than earlier averages or results.")
                }
                .padding(.horizontal,15)
                .padding(.bottom,10)
            }
            .navigationTitle("More about “This Week”")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showChart1Details = false
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
    var chart2Details: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.title.bold())
                            .foregroundColor(.accentColor)
                        Text("About the Chart")
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom,20)
                    Text("“All-Time” presents the **evolution of your preference percentages** over time.")
                        .padding(.bottom,10)
                    HStack {
                        Text("Preference %")
                            .font(.subheadline)
                        VStack {
                            HStack(alignment: .bottom, spacing: 0) {
                                Divider()
                                Rectangle()
                                    .foregroundStyle(Color.accentColor)
                                    .cornerRadius(12)
                                    .rotationEffect(.degrees(-15), anchor: .top)
                                    .frame(height: 7)
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(height: 0.125*UIScreen.main.bounds.height)
                            Divider()
                            Text("Time")
                                .font(.subheadline)
                        }
                        .padding(10)
                    }
                    Text("The chart presents the evolution of your preference percentages over time. This means that it presents the average of the results you've had since the first day you've tested someone until the last which may be today. The more people you test, the more accurate.\n\nIn order for this chart to be shown in “Highlights”, you must test people on at least four different days.\n\nReviewing the evolution of your preference percentages over time allows you to monitor how you prefer people over time and how you live life moments with these people. For example, if the chart line appears to be increasing, it might mean that you prefer more people or that you enjoy more moments with them than you used to.")
                }
                .padding(.horizontal,15)
                .padding(.bottom,10)
            }
            .navigationTitle("More about “All-Time”")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showChart2Details = false
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

#Preview {
    ContentView()
}
