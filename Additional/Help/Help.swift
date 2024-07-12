//
//  Help.swift
//  FeelingsApp
//
//  Created by Holygent on 6/27/24.
//

import Foundation
import SwiftUI
import FirebaseFirestore

struct Help: View {
    let suggestedSection: String
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var helpSubjects: [DocumentSnapshot] = []
    @State private var selectedSection = ""
    func getHelp() {
        helpSubjects.removeAll()
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Help2").whereField("section", isEqualTo: "TOP_SECTION").getDocuments { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    helpSubjects.append(document)
                }
            }
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text("How can we help?")
                        .font(.largeTitle.bold())
                        .padding(.top,10)
                    Text("Select a section to get the help you need.")
                        .font(.headline)
                        .foregroundStyle(Color.secondary)
                        .padding(.bottom,20)
                        NavigationLink(destination: SubHelp(section: selectedSection)) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Suggested")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.secondary)
                                Text(suggestedSection)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fontDesign(.rounded)
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.primary)
                            }
                            Image(systemName: "chevron.right")
                        }
                        .padding(15)
                        .background(colorScheme == .light ? .white : Color(red: 20/255, green: 20/255, blue: 20/255))
                        .cornerRadius(25)
                        .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 10, y: colorScheme == .light ? 5 : 10)
                        .simultaneousGesture(TapGesture().onEnded({
                            selectedSection = suggestedSection
                        }))
                        .padding(.bottom,25)
                    ForEach(helpSubjects.sorted(by: { item1, item2 in
                            item1.data()?["index"] as? Int ?? 0 < item2.data()?["index"] as? Int ?? 0
                        }), id: \.documentID) { section in
                            NavigationLink(destination: SubHelp(section: selectedSection)) {
                                Text(section.data()?["title"] as? String ?? "")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fontDesign(.rounded)
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.primary)
                                Image(systemName: "chevron.right")
                            }
                            .padding(15)
                            .background(colorScheme == .light ? .white : Color(red: 20/255, green: 20/255, blue: 20/255))
                            .cornerRadius(25)
                            .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 10, y: colorScheme == .light ? 5 : 10)
                            .padding(.bottom,15)
                            .simultaneousGesture(TapGesture().onEnded({
                                selectedSection = section.data()?["title"] as? String ?? ""
                            }))
                        }
                    }
                .frame(maxWidth: .infinity)
                .padding(.horizontal,15)
                .onAppear {
                    getHelp()
                }
            }
            .navigationTitle("Help Center")
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
                    .buttonBorderShape(.circle)
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

struct SubHelp: View {
    let section: String
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var loading = true
    @State private var subjects: [DocumentSnapshot] = []
    @State private var selectedSubject: DocumentSnapshot? = nil
    func getData() {
        subjects.removeAll()
        Firestore.firestore().collection("Workout").whereField("forPart", isEqualTo: "Help2").whereField("section", isEqualTo: section).getDocuments { querySnapshot, error in
            if error == nil {
                for document in querySnapshot!.documents {
                    subjects.append(document)
                }
                withAnimation {
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
                        .frame(maxWidth: .infinity)
                }
                VStack(alignment: .leading) {
                    Text(section)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.title.bold())
                        .padding(.top,10)
                    Text("Get help about \(section).")
                        .font(.headline)
                        .foregroundStyle(Color.secondary)
                        .padding(.bottom,20)
                    ForEach(subjects.sorted(by: { $0.data()?["index"] as? Int ?? 0 < $1.data()?["index"] as? Int ?? 0 }), id: \.documentID) { subject in
                        NavigationLink(destination: SubHelpTwo(subject: selectedSubject)) {
                            Text(subject.data()?["title"] as? String ?? "")
                                .font(.title3.bold())
                                .foregroundStyle(Color.primary)
                                .fontDesign(.rounded)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                            Image(systemName: "chevron.right")
                        }
                        .simultaneousGesture(TapGesture().onEnded({
                            selectedSubject = subject
                        }))
                        .padding(15)
                        .background(colorScheme == .light ? .white : Color(red: 20/255, green: 20/255, blue: 20/255))
                        .cornerRadius(25)
                        .shadow(color: colorScheme == .light ? Color(red: 230/255, green: 230/255, blue: 230/255) : Color(red: 30/255, green: 30/255, blue: 30/255), radius: 10, y: colorScheme == .light ? 5 : 10)
                        .padding(.bottom,20)
                    }
                }
                .padding(.horizontal,15)
                .padding(.bottom,10)
            }
            .navigationTitle(section)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                getData()
            }
        }
    }
}

struct SubHelpTwo: View {
    let subject: DocumentSnapshot?
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @State private var loading = false
    let feedbackIcons = ["😠", "☹️", "😀", "🤩"]
    var body: some View {
        NavigationStack {
            ScrollView {
                if loading {
                    ProgressView()
                        .padding(15)
                }
                VStack(alignment: .leading) {
                    Text(subject?.data()?["title"] as? String ?? "")
                        .font(.title.bold())
                        .padding(.top,10)
                    Text("\(DateFormatter.localizedString(from: (subject?.data()?["published"] as? Timestamp ?? Timestamp()).dateValue(), dateStyle: .medium, timeStyle: .short))")
                        .font(.headline)
                        .foregroundStyle(Color.secondary)
                        .padding(.bottom,20)
                    Text((subject?.data()?["desc"] as? String ?? "").replacingOccurrences(of: "<br>", with: "\n"))
                    Divider()
                        .padding(.top,10)
                        .padding(.vertical,20)
                    Text("Was this helpful?")
                        .font(.headline)
                        .padding(.top,50)
                        .padding(.bottom,2)
                        .padding(.horizontal,20)
                        .frame(maxWidth: .infinity)
                    HStack(spacing: 20) {
                        ForEach(feedbackIcons, id: \.self) { icon in
                            Button(action: {
                                Firestore.firestore().collection("Workout").document(subject?.documentID ?? "").getDocument { document, error in
                                    if error == nil {
                                        let feedback = document?.data()?["helpful"] as? [String] ?? []
                                        Firestore.firestore().collection("Workout").document(subject?.documentID ?? "").updateData(["helpful":feedback + [icon]])
                                    }
                                }
                            }) {
                                Text(icon)
                                    .font(.title.bold())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom,50)
                }
                .padding(.horizontal,15)
                .padding(.bottom,10)
            }
            .multilineTextAlignment(.leading)
            .navigationTitle(subject?.data()?["title"] as? String ?? "")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
