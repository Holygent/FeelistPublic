//
//  FeelingsAppApp.swift
//  FeelingsApp
//
//  Created by Holygent on 12/03/2024.
//

import SwiftUI
import FirebaseCore
import Firebase
import FirebaseFirestore
import Network

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct WorkoutApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var defaults = Defaults()
    @State private var currentTest = CurrentTest()
    let monitor = NWPathMonitor()
    @State private var offline = false
    @State private var alertOffline = false
    func getNetwork() {
        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                defaults.offline = false
                alertOffline = false
            } else {
                defaults.offline = true
                alertOffline = true
            }
        }
        let queue = DispatchQueue(label: "Monitor")
        monitor.start(queue: queue)
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    getNetwork()
                }
                .alert("You're Offline", isPresented: $alertOffline) {
                    Button("OK") { }
                } message: {
                    Text("Some features that require an Internet connection may not be available.")
                }
                .environment(defaults)
                .environment(currentTest)
        }
    }
}
