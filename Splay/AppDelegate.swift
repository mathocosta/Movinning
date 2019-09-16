//
//  AppDelegate.swift
//  FinalChallenge
//
//  Created by Matheus Oliveira Costa on 02/09/19.
//  Copyright © 2019 The Rest of Us. All rights reserved.
//

import UIKit
import CoreData
import HealthKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private var appCoordinator: AppCoordinator?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Checa se o usuário não está logado, por agora, isso quer dizer que é
        // o primeiro acesso ao app
        UserDefaults.standard.isFirstLogin = UserManager.getLoggedUser() == nil

        appCoordinator = AppCoordinator(tabBarController: UITabBarController())

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.makeKeyAndVisible()
        window?.rootViewController = appCoordinator?.rootViewController
        window?.backgroundColor = .white
        appCoordinator?.start()

        // TODO: Remover isso depois, foi feito rápido para colocar no testflight :P
        if UserDefaults.standard.value(forKey: "SeedTeams") == nil {
            seedCoreData()
            UserDefaults.standard.set(true, forKey: "SeedTeams")
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        CoreStataStore.saveContext()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        guard let user = UserManager.current.loggedUser else { return }

        guard let lastUpdateTime = UserDefaults.standard.goalUpdateTime,
            let nextUpdateTime = calendar.getNextUpdateTime(from: lastUpdateTime) else {
                UserManager.changeGoals(for: user)
                return
        }

        if nextUpdateTime.compare(now) == .orderedAscending {
            UserManager.changeGoals(for: user, at: now)
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        CoreStataStore.saveContext()
    }

    // TODO: Remover isso depois, foi feito rápido para colocar no testflight :P
    func seedCoreData() {
        let team1 = Team(context: CoreStataStore.context)
        team1.id = UUID()
        team1.name = "Fortaleza"
        team1.points = 0
        team1.members = []

        let team2 = Team(context: CoreStataStore.context)
        team2.id = UUID()
        team2.name = "Ceará"
        team2.points = 0
        team2.members = []

        let team3 = Team(context: CoreStataStore.context)
        team3.id = UUID()
        team3.name = "Ferroviário"
        team3.points = 0
        team3.members = []

        CoreStataStore.saveContext()
    }

}