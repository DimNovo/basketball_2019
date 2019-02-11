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
        case none = 0
        case ball = 1
        case start = 2
        case end = 4
    }
    var collisionBall = false
    var collisionResult = false
    var score = 0
    var hoopAdded = false
    
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
        
        let ball = SCNSphere(radius: 0.35)
        let ballNode = SCNNode(geometry: ball)
        ballNode.name = "ball"
        ballNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named:
            "art.scnassets/ballTexture.png")
        
        guard let frame = sceneView.session.currentFrame else { return }
        
        ballNode.simdTransform = frame.camera.transform
        
        let ballBody = SCNPhysicsBody(type:
            .dynamic,shape:
            SCNPhysicsShape(node:
                ballNode,options:
                [SCNPhysicsShape.Option.collisionMargin:0.01]))
        
        ballNode.physicsBody = ballBody
        
        let power = Float(10)
        let transform = SCNMatrix4(frame.camera.transform)
        let force = SCNVector3(-transform.m31 * power,
                               -transform.m32 * power,
                               -transform.m33 * power)
        
        ballBody.applyForce(force, asImpulse: true)
        
        ballBody.categoryBitMask = BodyType.ball.rawValue
        
        ballBody.collisionBitMask = BodyType.start.rawValue | BodyType.end.rawValue
        ballBody.contactTestBitMask = BodyType.start.rawValue | BodyType.end.rawValue
        
        sceneView.scene.rootNode.addChildNode(ballNode)
    }
    
    func createHoop(result: ARHitTestResult) {
        
        let hoop = SCNBox(width: 1.8, height: 1.1, length: 0.1, chamferRadius: 0)
        let ballTorus = SCNTorus(ringRadius: 0.44, pipeRadius: 0.01)
        let resultTorus = SCNTorus(ringRadius: 0.41, pipeRadius: 0.01)
        
        let hoopNode = SCNNode(geometry: hoop)
        let ballTorusNode = SCNNode(geometry: ballTorus)
        let resultTorusNode = SCNNode(geometry: resultTorus)
        
        hoopNode.name = "hoopNode"
        ballTorusNode.name = "ballTorusNode"
        resultTorusNode.name = "resultTorusNode"
        
        hoopNode.simdTransform = result.worldTransform
        hoopNode.eulerAngles.x -= .pi / 2
        hoopNode.opacity = 0.77
        
        ballTorusNode.position = SCNVector3(x: hoopNode.position.x,
                                            y: (hoopNode.position.y - 0.55),
                                            z: (hoopNode.position.z - 0.5))
        resultTorusNode.position = SCNVector3(x: hoopNode.position.x,
                                              y: (hoopNode.position.y - 0.75),
                                              z: (hoopNode.position.z - 0.5))
        
        
        hoopNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named:
            "art.scnassets/hoopTexture.png")
        ballTorusNode.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
        resultTorusNode.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        
        hoopAdded = true
        stopPlaneDetection()
        removeWalls()
        
        hoopNode.physicsBody = SCNPhysicsBody(
            type:.static,shape:
            SCNPhysicsShape(node:
                hoopNode,options:
                [SCNPhysicsShape
                    .Option.type:
                    SCNPhysicsShape
                        .ShapeType
                        .concavePolyhedron]))
        ballTorusNode.physicsBody = SCNPhysicsBody(
            type:.static,shape:
            SCNPhysicsShape(node:
                ballTorusNode,options:
                [SCNPhysicsShape
                    .Option.type:
                    SCNPhysicsShape
                        .ShapeType
                        .concavePolyhedron]))
        resultTorusNode.physicsBody = SCNPhysicsBody(
            type:.static,shape:
            SCNPhysicsShape(node:
                resultTorusNode,options:
                [SCNPhysicsShape
                    .Option.type:
                    SCNPhysicsShape
                        .ShapeType
                        .concavePolyhedron]))
        
        resultTorusNode.physicsBody?.categoryBitMask = BodyType.end.rawValue
        resultTorusNode.physicsBody?.collisionBitMask = BodyType.ball.rawValue
        resultTorusNode.physicsBody?.contactTestBitMask = BodyType.ball.rawValue
        ballTorusNode.physicsBody?.categoryBitMask = BodyType.start.rawValue
        ballTorusNode.physicsBody?.collisionBitMask = BodyType.ball.rawValue
        ballTorusNode.physicsBody?.contactTestBitMask = BodyType.ball.rawValue
        
        sceneView.scene.rootNode.addChildNode(hoopNode)
        sceneView.scene.rootNode.addChildNode(ballTorusNode)
        sceneView.scene.rootNode.addChildNode(resultTorusNode)
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
    
    // MARK: - ... @IBAction
    @IBAction func screenTapped(_ sender: UITapGestureRecognizer) {
        if hoopAdded {
            createBasketBall()
            collisionBall = false
            collisionResult = false
            resultLabel.textColor = UIColor.blue
        } else {
            let location = sender.location(in: sceneView)
            guard let result = sceneView.hitTest(location, types: [.existingPlaneUsingExtent]).first else { return }
            createHoop(result: result)
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
        
        if (collisionBall == false) {
            if (contact.nodeA.name! == "ball" && contact.nodeB.name! == "ballTorusNode") ||
                (contact.nodeB.name! == "ball" && contact.nodeA.name! == "ballTorusNode") {
                
                collisionBall = true
            }
        }
        if (collisionBall == true) && (collisionResult == false) {
            if (contact.nodeA.name! == "ball" && contact.nodeB.name! == "resultTorusNode") ||
                (contact.nodeA.name! == "ball" && contact.nodeB.name! == "resultTorusNode") {
                
                collisionResult = true
                collisionBall = false
                
                score += 1
                DispatchQueue.main.async {
                    self.resultLabel.textColor = UIColor.red
                    self.resultLabel.text = String("Goals: \(self.score)")
                }
            }
        }
    }
}
// MARK: - ... Свойство categoryBitMask - это число, определяющее тип объекта, который предназначен для рассмотрения коллизий.
//Свойство collisionBitMask - это число, определяющее, с какими категориями объектов должен сталкиваться этот узел,
//Свойство contactTestBitMask - это число, определяющее, о каких коллизиях мы хотим получать уведомления.
