//
//  OyeApp.swift
//  Oye
//
//  Created by Jberg on 2025-11-15.
//

import SwiftUI
import CoreData

@main
struct OyeApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
