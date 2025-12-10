//
//  GameViewController.swift
//  Beat Kanji
//
//  Created for Beat Kanji project
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    // Keep the home indicator visible so deferred system gestures work (double-swipe to exit)
    // per Apple guidance, hiding the indicator cancels gesture deferral.
    override var prefersHomeIndicatorAutoHidden: Bool {
        false
    }

    // Defer edge system gestures (home indicator, control/notification center)
    // so exiting the game requires a second swipe, which matches how many iOS games
    // avoid accidental dismissals during play.
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        .all
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        guard let skView = self.view as? SKView else { return }
        skView.backgroundColor = .black

        // Show loading scene first - it will preload data and transition to StartScene
        let loadingScene = LoadingScene(size: skView.bounds.size)
        loadingScene.scaleMode = .aspectFill
        skView.presentScene(loadingScene)

        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Ensure the system updates gesture deferral once the view is visible.
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        true
    }
}
