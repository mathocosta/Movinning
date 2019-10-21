//
//  TeamEntranceViewController.swift
//  FinalChallenge
//
//  Created by Matheus Oliveira Costa on 04/09/19.
//  Copyright © 2019 The Rest of Us. All rights reserved.
//

import UIKit

class TeamEntranceViewController: UIViewController {

    // MARK: - Properties
    private let teamEntranceView: TeamEntranceView
    private let team: Team

    weak var coordinator: TeamTabCoordinator?

    // MARK: - Lifecycle
    init(team: Team) {
        self.team = team
        self.teamEntranceView = TeamEntranceView(frame: .zero, team: team)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = teamEntranceView
        teamEntranceView.onShowMembers = self.onShowMembers
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = team.name
        teamEntranceView.teamTitleLabel.text = team.name
        teamEntranceView.onJoinTeam = selectTeamForLoggedUser
    }

    // MARK: - Actions
    func selectTeamForLoggedUser() {
        // Adicionar time ao usuário
        if let loggedUser = UserManager.getLoggedUser() {
            SessionManager.current.add(user: loggedUser, to: team).done(on: .main) { _ in
                // Retorna para a tela de abertura do time
                self.coordinator?.showDetails(of: self.team)
            }.catch(on: .main) { error in
                print(error.localizedDescription)
            }
        }
    }
    
    func onShowMembers() {
        guard let coordinator = coordinator else { return }
        coordinator.showTeamMembers(of: team)
    }
}
