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
    enum BodyType:Int
    {
        case ball = 1
        case start = 2
        case end = 5
    }
    
    var ballNode: SCNNode?
    var hoopAdded = false
    var score: Int?
    
    // MARK: - ... @IBOutlet
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var resultLabel: UILabel!
    
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
        sceneView.scene.physicsWorld.contactDelegate = self
        result()
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
        
        guard let ballNode = ballNode?.clone() ?? createNode(from: "Ball") else { return }
        
        self.ballNode = ballNode
        
        guard let frame = sceneView.session.currentFrame else { return }
        
        ballNode.simdTransform = frame.camera.transform
        
        let body = SCNPhysicsBody(type:
            .dynamic,shape:
            SCNPhysicsShape(node:
                ballNode,options:
                [SCNPhysicsShape.Option.collisionMargin:0.01]))
        
        ballNode.physicsBody = body
        
        let power = Float(10)
        let transform = SCNMatrix4(frame.camera.transform)
        let force = SCNVector3(-transform.m31 * power,
                               -transform.m32 * power,
                               -transform.m33 * power)
        
        body.applyForce(force, asImpulse: true)
        
        body.categoryBitMask = BodyType.ball.rawValue
        body.collisionBitMask = BodyType.start.rawValue | BodyType.end.rawValue
        body.contactTestBitMask = BodyType.start.rawValue | BodyType.end.rawValue
        
        sceneView.scene.rootNode.addChildNode(ballNode)
    }
    
    func createHoop(result: ARHitTestResult) {
        
        guard let hoopNode = createNode(from: "Hoop") else { return }
        
        hoopNode.simdTransform = result.worldTransform
        hoopNode.eulerAngles.x -= .pi / 2
        hoopNode.opacity = 0.77
        
        hoopAdded = true
        stopPlaneDetection()
        removeWalls()
        
        let body = SCNPhysicsBody(
            type:.static,shape:
            SCNPhysicsShape(node:
                hoopNode,options:
                [SCNPhysicsShape
                    .Option.type:
                    SCNPhysicsShape
                        .ShapeType
                        .concavePolyhedron]))
        hoopNode.physicsBody = body
        
        sceneView.scene.rootNode.addChildNode(hoopNode)
    }
    
    func createResultNodes(result: ARHitTestResult) {
        
        let startTorus = SCNTorus(ringRadius: 0.44, pipeRadius: 0.01)
        let endTorus = SCNTorus(ringRadius: 0.4, pipeRadius: 0.01)
        
        let startNode = SCNNode(geometry: startTorus)
        let endNode = SCNNode(geometry: endTorus)
        
        startNode.simdTransform = result.worldTransform
        endNode.simdTransform = result.worldTransform
        
        startNode.simdPosition.x += 0.5
        endNode.simdPosition.x += 0.5
        startNode.simdPosition.y -= 0.5
        endNode.simdPosition.y -= 0.6
        startNode.simdPosition.z += 0.5
        endNode.simdPosition.z += 0.5
        

        startNode.eulerAngles.x -= .pi / 2
        endNode.eulerAngles.x -= .pi / 2
        
        startNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        endNode.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        
        let bodyStart = SCNPhysicsBody(
            type:.static,shape:
            SCNPhysicsShape(node:
                startNode,options:
                [SCNPhysicsShape
                    .Option.type:
                    SCNPhysicsShape
                        .ShapeType
                        .concavePolyhedron]))
        
        let bodyEnd = SCNPhysicsBody(
            type:.static,shape:
            SCNPhysicsShape(node:
                endNode,options:
                [SCNPhysicsShape
                    .Option.type:
                    SCNPhysicsShape
                        .ShapeType
                        .concavePolyhedron]))
        
        startNode.physicsBody = bodyStart
        endNode.physicsBody = bodyEnd
        
        bodyStart.categoryBitMask = BodyType.ball.rawValue
        bodyStart.collisionBitMask = BodyType.start.rawValue
        bodyStart.contactTestBitMask = BodyType.start.rawValue
        
        bodyEnd.categoryBitMask = BodyType.ball.rawValue
        bodyEnd.collisionBitMask = BodyType.end.rawValue
        bodyEnd.contactTestBitMask = BodyType.end.rawValue
        
        sceneView.scene.rootNode.addChildNode(startNode)
        sceneView.scene.rootNode.addChildNode(endNode)
        
    }
    
    func createNode(from name: String) -> SCNNode? {
        guard let scene = SCNScene(named: "art.scnassets/\(name).scn") else {
            print(#function, "ERROR: Can't create node from scene \(name).scn")
            
            return nil
        }
        
        let node = scene.rootNode.childNode(withName: name, recursively: false)
        
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
            if node.name == "Wall" {
                node.removeFromParentNode()
            }
        }
    }
    
    func stopPlaneDetection() {
        guard let configuration = sceneView.session.configuration as? ARWorldTrackingConfiguration else { return }
        
        configuration.planeDetection = []
        
        sceneView.session.run(configuration)
    }
    
    func result() {
        resultLabel.text = "Goals: \(score ?? 0)"
    }
    
    // MARK: - ... @IBAction
    @IBAction func screenTapped(_ sender: UITapGestureRecognizer) {
        if hoopAdded {
            createBasketBall()
        } else {
            let location = sender.location(in: sceneView)
            guard let result = sceneView.hitTest(location, types: [.existingPlaneUsingExtent]).first else { return }
            createHoop(result: result)
            createResultNodes(result: result)
        }
    }
}

// MARK: - ... ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        guard let anchor = anchor as? ARPlaneAnchor,
        anchor.alignment == .vertical else { return }
        
        let wall = createWall(anchor: anchor)
        
        node.addChildNode(wall)
    }
}

// MARK: - ... SKPhysicsContactDelegate
extension ViewController: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        print("NodeA: \(contact.nodeA.description)\nNodeB: \(contact.nodeB.description)")
    }
}
// MARK: - ... Свойство categoryBitMask - это число, определяющее тип объекта, который предназначен для рассмотрения коллизий.
//Свойство collisionBitMask - это число, определяющее, с какими категориями объектов должен сталкиваться этот узел,
//Свойство contactTestBitMask - это число, определяющее, о каких коллизиях мы хотим получать уведомления.
