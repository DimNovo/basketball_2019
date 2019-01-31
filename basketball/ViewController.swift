//
//  ViewController.swift
//  basketball
//
//  Created by Dmitry Novosyolov on 31/01/2019.
//  Copyright © 2019 Dmitry Novosyolov. All rights reserved.
//

import ARKit

class ViewController: UIViewController {
    
    // MARK: - ... Properties
    var hoopAdded = false
    
    // MARK: - ... @IBOutlet
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - ... UIViewController Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Switch on lighting
        sceneView.autoenablesDefaultLighting = true
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ... Custom Methods
    func createBasketBall() {
        
        guard let ballNode = createNode(from: "Ball.scn") else { return }
        guard let frame = sceneView.session.currentFrame else { return }
        ballNode.simdTransform = frame.camera.transform
        
        sceneView.scene.rootNode.addChildNode(ballNode)
    }
    
    func createHoop(result: ARHitTestResult) {
        
        guard let hoopNode = createNode(from: "Hoop.scn") else { return }
        hoopNode.simdTransform = result.worldTransform
        hoopNode.eulerAngles.x -= .pi / 2
        
        hoopAdded = true
        stopPlaneDetection()
        removeWalls()
        
        sceneView.scene.rootNode.addChildNode(hoopNode)
    }
    
    func createNode(from sceneName: String) -> SCNNode? {
        
        guard let scene = SCNScene(named: "art.scnassets/\(sceneName)") else
        {
            print(#function, "ERROR: Can't create node from scene \(sceneName)")
            return nil
        }
        
        let node = scene.rootNode.clone()
        
        return node
    }
    
    func createWall(anchor: ARPlaneAnchor) -> SCNNode {
        
        let extent = anchor.extent
        let width = CGFloat(extent.x)
        let height = CGFloat(extent.z)
        
        let node = SCNNode(geometry: SCNPlane(width: width, height: height))
        
        node.eulerAngles.x -= .pi / 2
        node.geometry?.firstMaterial?.diffuse.contents = #colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1)
        node.name = "Wall"
        node.opacity = 0.25
        
        return node
    }
    
    func removeWalls() {
        
        sceneView.scene.rootNode.enumerateChildNodes { node,_ in
            guard node.name != "Wall" else {
                removeFromParent()
                return
            }
        }
    }
    
    func stopPlaneDetection() {
        
        guard let configuration = sceneView.session.configuration as? ARWorldTrackingConfiguration else { return }
        
        configuration.planeDetection = []
        sceneView.session.run(configuration)
    }
    
    // MARK: - ... @IBAction
    @IBAction func screenTapped(_ sender: UITapGestureRecognizer) {
        
        guard !hoopAdded else {
            createBasketBall()
            return
        }
        
        let location = sender.location(in: sceneView)
        guard let result = sceneView.hitTest(location, types: [.existingPlaneUsingExtent]).first else { return }
        createHoop(result: result)
    }
}

// MARK: - ... ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        guard let anchor = anchor as? ARPlaneAnchor else { return }
        let wall = createWall(anchor: anchor)
        
        node.addChildNode(wall)
    }
}
