//
//  StorageGateway.swift
//  FinalChallenge
//
//  Created by Matheus Oliveira Costa on 10/09/19.
//  Copyright © 2019 The Rest of Us. All rights reserved.
//

import Foundation
import CloudKit
import PromiseKit

class SessionManager {

    static let current = SessionManager()

    private let cloudKitGateway: CloudKitGateway
    private let coreDataGateway: CoreDataGateway

    init() {
        self.cloudKitGateway = CloudKitGateway(container:
            CKContainer(identifier: "iCloud.academy.the-rest-of-us.Splay"))
        self.coreDataGateway = CoreDataGateway(viewContext: CoreDataStore.context)
    }

    // MARK: - User management
    func loginUser() -> Promise<Bool> {
        return userIsLogged().then { _ in
            self.cloudKitGateway.fetchInitialData().then { records -> Promise<Bool> in
                let (userRecord, teamRecord) = records
                let user = UserManager.createUser(with: userRecord.recordKeysAndValues())

                if let teamRecord = teamRecord {
                    let team = TeamManager.createTeam(with: teamRecord.recordKeysAndValues())
                    team.addToMembers(user)
                }

                UserDefaults.standard.loggedUserUUID = user.id?.uuidString

                return self.coreDataGateway.save(user)
            }
        }
    }

    func updateRegister(of user: User) -> Promise<Bool> {
        let userRecord = user.ckRecord()
        return cloudKitGateway.update(userRecord: userRecord).then { updatedRecord -> Promise<Bool> in
            let recordMetadata = updatedRecord.recordMetadata()
            UserManager.update(recordMetadata: recordMetadata, of: user)

            return self.coreDataGateway.save(user)
        }
    }

    /// Retorna o status da conta do iCloud do usuário no dispositivo. Se retornar
    /// `true` quer dizer que está logado e pode continuar, no contrário, o usuário não
    /// está mais logado no dispositivo.
    func userIsLogged() -> Promise<Bool> {
        cloudKitGateway.userAccountAvailable()
    }

    // MARK: - Teams management
    func updateLocallyTeam(of user: User) -> Promise<Bool> {
        guard let userTeam = user.team else { return Promise(error: SessionError.userDontHaveTeam) }
        let userRecord = user.ckRecord()
        return cloudKitGateway.team(of: userRecord).then { (teamRecord) -> Promise<Bool> in
            let teamRecordInfo = teamRecord.recordKeysAndValues()
            TeamManager.update(team: userTeam, with: teamRecordInfo)
            return self.coreDataGateway.save(userTeam)
        }
    }

    // TODO: Colocar para adicionar o usuário no time do cloudkit
    func add(user: User, to team: Team) -> Promise<Bool> {
        user.team = team

        return self.cloudKitGateway.add(userRecord: user.ckRecord(), to: team.ckRecord()).then {
                results -> Promise<Bool> in
                let (updatedUserRecord, updatedTeamRecord) = results
                UserManager.update(recordMetadata: updatedUserRecord.recordMetadata(), of: user)
                TeamManager.update(recordMetadata: updatedTeamRecord.recordMetadata(), of: team)

                return self.coreDataGateway.save(user)
        }.then { _ in
            self.addSubscriptions(for: user)
        }
    }

    func remove(user: User, from team: Team) -> Promise<Bool> {
        let userRecord = user.ckRecord()
        let teamRecord = team.ckRecord()

        return cloudKitGateway.remove(userRecord: userRecord, from: teamRecord).then {
            updatedUserRecord -> Promise<Bool> in
            team.removeFromMembers(user)
            UserManager.update(recordMetadata: updatedUserRecord.recordMetadata(), of: user)
            return self.coreDataGateway.save(user)
        }.then { _ in self.removeSubscriptions() }
    }

    func listTeams() -> Promise<[Team]> {
        return cloudKitGateway.listTeams().map({ $0.1 }).thenMap { teamRecord in
            self.cloudKitGateway.users(from: teamRecord).map({ (teamRecord, $0) })
        }.thenMap { results -> Promise<Team> in
            let (teamRecord, usersRecords) = results
            let team = TeamManager.createTeam(with: teamRecord.recordKeysAndValues())
            for userRecord in usersRecords {
                let user = UserManager.createUser(with: userRecord.recordKeysAndValues())
                team.addToMembers(user)
            }

            return Promise.value(team)
        }
    }

    func create(team: Team, with user: User) -> Promise<Bool> {
        let teamRecord = team.ckRecord()
        let userRecord = user.ckRecord()

        return cloudKitGateway.create(teamRecord: teamRecord, withCreator: userRecord).then {
            updatedRecords -> Promise<Bool> in

            let (updatedTeamRecord, updatedUserRecord) = updatedRecords
            TeamManager.update(recordMetadata: updatedTeamRecord.recordMetadata(), of: team)
            UserManager.update(recordMetadata: updatedUserRecord.recordMetadata(), of: user)
            user.team = team

            return self.addSubscriptions(for: user)
        }
    }

    // MARK: - Subscriptions
    private func addSubscriptions(for user: User) -> Promise<Bool> {
        guard let teamUUID = user.team?.id?.uuidString else {
            return Promise(error: SessionError.missingTeamIdentifier)
        }
        print("Adicionando subscriptions para time: \(teamUUID)")
        let subscription = cloudKitGateway.subscriptionForUpdates(recordType: "Teams", objectUUID: teamUUID)

        return cloudKitGateway.save([subscription])
    }

    func removeSubscriptions() -> Promise<Bool> {
        cloudKitGateway.removeSubscriptions()
    }
}
