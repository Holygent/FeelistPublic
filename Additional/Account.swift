//
//  Account.swift
//  FeelingsApp
//
//  Created by Holygent on 6/27/24.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import LocalAuthentication

struct Account: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var devices: [(dName: String, osName: String, thisDevice: Bool, id: String)] = []
    @State private var loading = false
    @State private var showPassword = false
    @Environment(Defaults.self) var defaults
    @State private var accountPassword = ""
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
            defaults.password = getDefaults(forKey: "password") as? String ?? ""
            defaults.lockWithLocalAuth = getDefaults(forKey: "lockWithLocalAuth") as? Bool ?? false
            defaults.showLastPrefTime = getDefaults(forKey: "showLastPrefTime") as? Bool ?? false
            defaults.showRelation = getDefaults(forKey: "showRelation") as? Bool ?? false
            defaults.ignoreRecommendation = getDefaults(forKey: "ignoreRecommendation") as? Bool ?? false
        } catch {
            print("Feelist-ThrownError=An error occured while saving to PLIST file “Defaults.plist”. { \(error.localizedDescription) }")
        }
    }
    func getDevices() {
        withAnimation {
            loading = true
            devices.removeAll()
        }
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Users").getDocuments { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    if document.data()["userID"] as? String ?? "" == defaults.userID {
                        accountPassword = document.data()["password"] as? String ?? ""
                        for device in document.data()["devices"] as? [String: [String: String]] ?? [:] {
                            let dName = device.value.first(where: { $0.key == "dName" })?.value as? String ?? ""
                            let osName = device.value.first(where: { $0.key == "osName" })?.value as? String ?? ""
                            let thisDevice = device.value.first(where: { $0.key == "deviceID" })?.value as? String ?? "" == defaults.deviceID
                            let id = device.value.first(where: { $0.key == "deviceID" })?.value as? String ?? ""
                            devices.append((dName, osName, thisDevice, id))
                        }
                    }
                }
                withAnimation {
                    loading = false
                }
            }
        }
    }
    func savePassword() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Save password") { success, authenticationError in
                if success {
                    defaults.password = accountPassword
                    Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Users").getDocuments { querySnapshot, error in
                        for document in querySnapshot!.documents {
                            if document.data()["userID"] as? String ?? "" == defaults.userID {
                                Firestore.firestore().collection("Workout").document(document.documentID).updateData(["password":accountPassword])
                            }
                        }
                    }
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    func revealPassword() {
        let context = LAContext()
        var error: NSError?
        if !showPassword {
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Reveal account password") { success, authenticationError in
                    if success {
                        showPassword = true
                    }
                }
            }
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                HStack {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 36))
                        .fontWeight(.medium)
                        .padding(5)
                    VStack(alignment: .leading) {
                        Text("Me")
                            .font(.title2.bold())
                        Button(action: {
                            UIPasteboard.general.string = defaults.userID
                        }) {
                            (Text("ID: \(defaults.userID)").foregroundStyle(Color.secondary) + Text(" Copy"))
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .padding(.horizontal,15)
                .padding(.top,10)
                Divider()
                    .padding(.vertical,15)
                VStack(alignment: .leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("Security")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.title3.bold())
                    .padding(.bottom,10)
                    Text("Account password")
                        .font(.caption.bold())
                    HStack {
                        if !showPassword && accountPassword.count > 0 {
                            Button(action: {
                                revealPassword()
                            }) {
                                Text("Reveal")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                                Image(systemName: "eye")
                            }
                        } else {
                            TextField("Set a password", text: $accountPassword)
                                .textContentType(.newPassword)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onSubmit {
                                    if accountPassword.count >= 8 && accountPassword != defaults.password && accountPassword.contains(" ") {
                                        savePassword()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            Button("Save") {
                                savePassword()
                            }
                            .disabled(accountPassword.count < 8 || accountPassword == defaults.password || accountPassword.contains(" "))
                        }
                    }
                    .disabled(defaults.offline)
                    if accountPassword.count != 0 && (accountPassword.count < 8 || accountPassword.contains(" ")) {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(accountPassword.count < 8 ? "Password is too short." : "Password cannot contain spaces (“ ”).")
                        }
                        .font(.caption)
                    }
                    if showPassword {
                        Text("This can be useful when you log in and you don't have your other devices with you.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal,15)
                Divider()
                    .padding(.vertical,15)
                VStack(alignment: .leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("Privacy")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.title3.bold())
                    .padding(.bottom,10)
                    Link(destination: URL(string: "mailto:holygent@outlook.com")!) {
                        Text("Request to get all data uploaded about me")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "envelope")
                    }
                    .padding(.bottom,5)
                    Link(destination: URL(string: "https://docs.google.com/document/d/1Kr68Ty3DQXHv4DqCMFR4aKlSpo1AwCS2fwrVprYLQV0/edit?usp=sharing")!) {
                        Text("Privacy Policy")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "person.fill.viewfinder")
                    }
                }
                .padding(.horizontal,15)
                Divider()
                    .padding(.vertical,15)
                VStack(alignment: .leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("Settings")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.title3.bold())
                    .padding(.bottom,10)
                    Button(role: .destructive, action: {
                        saveDefaults(forKey: "lockWithLocalAuth", value: false)
                        saveDefaults(forKey: "ignoreRecommendation", value: false)
                        saveDefaults(forKey: "showLastPrefTime", value: false)
                        saveDefaults(forKey: "showRelation", value: false)
                    }) {
                        Text("Reset all settings")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "arrow.circlepath")
                    }
                    .disabled(!defaults.lockWithLocalAuth && !defaults.ignoreRecommendation && !defaults.showRelation && !defaults.showLastPrefTime)
                    Text("Resets:\nAuto-Lock\nAuto-Lock message\nShow last test date below person name\nShow relationships")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top,2)
                        .padding(.bottom,5)
                    Button(action: {
                        let bool = (getDefaults(forKey: "lockWithLocalAuth") as? Bool ?? false) ? false : true
                        saveDefaults(forKey: "lockWithLocalAuth", value: bool)
                    }) {
                        Text(defaults.lockWithLocalAuth ? "Disable Auto-Lock" : "Enable Auto-Lock")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "lock.fill")
                    }
                    Text("Automatically locks your data when you leave the app. It's back when you're back, too.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top,2)
                        .padding(.bottom,5)
                    Button(action: {
                        let bool = (getDefaults(forKey: "showLastPrefTime") as? Bool ?? false) ? false : true
                        saveDefaults(forKey: "showLastPrefTime", value: bool)
                    }) {
                        Text(!defaults.showLastPrefTime ? "Show last test date below person name" : "Hide last test date below person name")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        Image(systemName: !defaults.showLastPrefTime ? "eye.fill" : "eye.slash.fill")
                    }
                    Text("In “Preferences”, show the last time you tested someone below their name.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top,2)
                        .padding(.bottom,5)
                    Button(action: {
                        let bool = (getDefaults(forKey: "showRelation") as? Bool ?? false) ? false : true
                        saveDefaults(forKey: "showRelation", value: bool)
                    }) {
                        Text(!defaults.showRelation ? "Show relationships" : "Hide relationships")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        Image(systemName: !defaults.showRelation ? "eye.fill" : "eye.slash.fill")
                    }
                    Text("In “Preferences”, show the relationships you have for each person.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top,2)
                }
                .padding(.horizontal,15)
                Divider()
                    .padding(.vertical,15)
                VStack(alignment: .leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "display")
                            .foregroundStyle(Color.accentColor)
                        Text("Devices")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.title3.bold())
                    .padding(.bottom,10)
                    if loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(devices, id: \.id) { device in
                        HStack {
                            Image(systemName: device.osName == "iOS" ? "iphone" : "ipad")
                                .padding(5)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(device.dName)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(device.osName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if device.thisDevice {
                                    HStack(spacing: 5) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("This Device")
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                        .padding(.bottom,5)
                    }
                    if loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Divider()
                            .padding(.bottom,5)
                        Button(role: .destructive, action: {
                            withAnimation {
                                loading = true
                            }
                            Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Users").getDocuments { querySnapshot, error in
                                if error == nil {
                                    for document in querySnapshot!.documents {
                                        if document.data()["userID"] as? String ?? "" == defaults.userID {
                                            for device in document.data()["devices"] as? [String: [String: String]] ?? [:] {
                                                if device.value.first(where: { $0.key == "deviceID" })?.value as? String ?? "" != defaults.deviceID {
                                                    Firestore.firestore().collection("Workout").document(document.documentID).updateData(["devices.\(device.key)":FieldValue.delete()])
                                                }
                                            }
                                        }
                                    }
                                    getDevices()
                                }
                            }
                        }) {
                            Text("Log out my other devices")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                            Image(systemName: "rectangle.portrait.and.arrow.forward")
                        }
                        .disabled(devices.count <= 1)
                        .disabled(defaults.offline)
                        .padding(.bottom,10)
                    }
                }
                .padding(.horizontal,15)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                getDevices()
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
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
