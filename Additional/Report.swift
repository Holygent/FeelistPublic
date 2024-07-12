//
//  Report.swift
//  FeelingsApp
//
//  Created by Holygent on 6/27/24.
//

import Foundation
import SwiftUI
import FirebaseFirestore

struct ReportView: View {
    let menus = ["Select one", "Main menu", "Lists", "Details about someone", "Account", "Log in on another device", "Help", "Testing someone", "Send Feedback", "Welcome to Feelist", "Sign up", "Log in", "More about “This Week”", "More about “All-Time”", "App Locked.", "Other"]
    @State private var menuSelected = "Select one"
    let sectionsMainMenu = ["Select one", "Auto-Lock message", "People list", "Shared With Me", "Lists", "Highlights", "Preferences", "Other"]
    let sectionsDetails = ["Select one", "Preference description", "Test Again", "How do the results compare to reality?", "History", "View All Data", "Delete Person", "Other"]
    let sectionsTesting = ["Select one", "Step 1 of 3", "Step 2 of 3", "Step 3 of 3", "Your Results", "Other"]
    let sectionsAccount = ["Select one", "Me", "Security", "Privacy", "Settings", "Devices", "Other"]
    let sectionsLists = ["Select one", "New List", "Join List", "List details", "Other"]
    @State private var sectionSelected = "Select one"
    let reportTypes = ["Select one", "Bug", "Crash", "Suggestion", "Something I don't understand", "Other"]
    @State private var typeSelected = "Select one"
    @State private var userDesc = ""
    @State private var agreesToProvideID = true
    @Environment(\.presentationMode) var presentationMode
    @Environment(Defaults.self) var defaults
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.red)
                    Text("How can we improve?")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom,30)
                    Text("Which menu would you like to send feedback about?")
                        .font(.headline)
                    Picker("Select the menu that you want to send feedback for", selection: $menuSelected) {
                        ForEach(menus, id: \.self) {
                            Text($0)
                        }
                    }
                    Divider()
                        .padding(.top,5)
                        .padding(.bottom,10)
                    if menuSelected == "Main menu" || menuSelected == "Details about someone" || menuSelected == "Testing someone" || menuSelected == "Account" || menuSelected == "Lists" {
                        Text("Where in “\(menuSelected)”?")
                            .font(.headline)
                        Picker("Select the section", selection: $sectionSelected) {
                            ForEach(menuSelected == "Main menu" ? sectionsMainMenu : menuSelected == "Details about someone" ? sectionsDetails : menuSelected == "Testing someone" ? sectionsTesting : menuSelected == "Account" ? sectionsAccount : menuSelected == "Lists" ? sectionsLists : menus, id: \.self) {
                                Text($0)
                            }
                        }
                        Divider()
                            .padding(.top,5)
                            .padding(.bottom,10)
                    }
                    Text("What are you reporting?")
                        .font(.headline)
                    Picker("Select what you're reporting. It could be a bug, a suggestion, or something you don't understand.", selection: $typeSelected) {
                        ForEach(reportTypes, id: \.self) {
                            Text($0)
                        }
                    }
                    Divider()
                        .padding(.top,5)
                        .padding(.bottom,10)
                    Text(typeSelected == "Bug" ? "What's happening?" : typeSelected == "Crash" ? "What did you last do before the app crashed?" : typeSelected == "Suggestion" ? "What are you suggesting?" : "What's wrong?")
                        .font(.headline)
                    TextField("Please include how to reproduce the problem.", text: $userDesc, axis: .vertical)
                    Divider()
                        .padding(.top,5)
                        .padding(.bottom,10)
                    Toggle("I agree to provide my user ID for further resolution.", isOn: $agreesToProvideID)
                        .font(.headline)
                        .tint(.accentColor)
                    Text("Your user ID, \(defaults.userID), can never be used to identify you as it's made of random characters. It's useful to check if the problem arises from a conflict in the databases due to identifiers.")
                        .padding(.top,5)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button(action: {
                        Firestore.firestore().collection("Workout").addDocument(data: ["forPart":"UCC", "type":typeSelected, "menu":menuSelected, "section":sectionSelected, "userID":agreesToProvideID ? defaults.userID : "", "desc":userDesc, "agreedToProvideID":agreesToProvideID])
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Submit")
                            .font(.headline)
                            .padding(.vertical,8)
                            .padding(.horizontal,30)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .padding(.top,50)
                    .padding(.bottom,10)
                    .frame(maxWidth: .infinity)
                    .disabled(userDesc.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal,15)
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }
}
