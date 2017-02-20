//
//  GameScene.swift
//  Project17
//
//  Created by Xiaoheng Pan on 11/5/16.
//  Copyright © 2016 Xiaoheng Pan. All rights reserved.
//

import SpriteKit
import AVFoundation // needed for AVAudioPlayer

enum ForceBomb {
    case never, always, random
}

enum SequenceType: Int {
    // Note that it says enum SequenceType: Int. We didn't have that for the ForceBomb enum – it's new here, and it means "I want this enum to be mapped to integer values," and means we can reference each of the sequence type options using so-called "raw values" from 0 to 7.
    // For example, to create a twoWithOneBomb sequence type we could use SequenceType(rawValue: 2). Swift doesn't know whether that number exists or not (we could have written 77), so it returns an optional type that you need to unwrap.
    case oneNoBomb, one, twoWithOneBomb, two, three, four, chain, fastChain
}

class GameScene: SKScene {
    var gameScore: SKLabelNode!
    var score: Int = 0 {
        didSet {
            gameScore.text = "Score: \(score)"
        }
    }
    
    var livesImages = [SKSpriteNode]()
    var lives = 3
    var activeEnemies = [SKSpriteNode]() // Used to track enemies that are currently active in the scene.
    
    var activeSliceBG: SKShapeNode!
    var activeSliceFG: SKShapeNode!
    var activeSlicePoints = [CGPoint]()
    var isSwooshSoundActive = false // You see, if we just played a swoosh every time the player moved, there would be 100 sounds playing at any given time – one for every small movement they made. Instead, we want only one swoosh to play at once, so we're going to set to true a property called isSwooshSoundActive, make the waitForCompletion of our SKAction true, then use a completion closure for runAction() so that isSwooshSoundActive is set to false. So, when the player first swipes we set isSwooshSoundActive to be true, and only when the swoosh sound has finished playing do we set it back to false again. This will allow us to ensure only one swoosh sound is playing at a time.
    var bombSoundEffect: AVAudioPlayer!
    
    var popupTime = 0.9 //amount of time to wait between the last enemy being destroyed and a new one being created.
    var sequence: [SequenceType]! // an array of our SequenceType enum that defines what enemies to create.
    var sequencePosition = 0 // this property is where we are right now in the game
    var chainDelay = 3.0 // property is how long to wait before creating a new enemy when the sequence type is .chain or .fastChain. Enemy chains don't wait until the previous enemy is offscreen before creating a new one, so it's like throwing five enemies quickly but with a small delay between each one.
    var nextSequenceQueued = true // this property is used so we know when all the enemies are destroyed and we're ready to create more.
    
    var gameEnded = false
    
    override func didMove(to view: SKView) {
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace // Blend modes determine how a node is drawn, and SpriteKit gives you many options. The .replace option means "just draw it, ignoring any alpha values," which makes it fast for things without gaps such as our background
        background.zPosition = -1
        addChild(background)
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -6) // gravity is -9.8, setting dy = -6 allows object to stay a bit longer in the air.
        physicsWorld.speed = 0.85
        
        createScore()
        createLives()
        createSlices()
        
        // The following code fills the sequence array with seven pre-written sequences to help players warm up to how the game works, then adds 1001 (the ... operator means "up to and including") random sequence types to fill up the game. Finally, it triggers the initial enemy toss after two seconds.
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]
        for _ in 0 ... 1000 {
            let nextSequence = SequenceType(rawValue: RandomInt(min: 2, max: 7))! // Use the rawValue property to access the raw value of an enumeration case.
            sequence.append(nextSequence)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [unowned self] in
            self.tossEnemies()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        activeSlicePoints.removeAll(keepingCapacity: true)
        if let touch = touches.first {
            let location = touch.location(in: self)
            activeSlicePoints.append(location)
            
            redrawActiveSlice()
            
            activeSliceFG.removeAllActions()
            activeSliceBG.removeAllActions()
            
            activeSliceBG.alpha = 1
            activeSliceFG.alpha = 1
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if gameEnded {
            return
        }
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        activeSlicePoints.append(location)
        redrawActiveSlice()
        
        if !isSwooshSoundActive {
            playSwooshSound()
        }
        
        let nodesAtPoint = nodes(at: location)
        
        for node in nodesAtPoint {
            if node.name == "enemy" {
            // destroy penguin shoudld do the following ...
                // 1. Create a particle effect over the penguin.
                // 2. Clear its node name so that it can't be swiped repeatedly.
                // 3. Disable the isDynamic of its physics body so that it doesn't carry on falling.
                // 4. Make the penguin scale out and fade out at the same time.
                // 5. After making the penguin scale out and fade out, we should remove it from the scene.
                // 6. Add one to the player's score.
                // 7. Remove the enemy from our activeEnemies array.
                // 8. Play a sound so the player knows they hit the penguin.
                
                //1
                let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy")!
                emitter.position = node.position
                addChild(emitter)
                
                //2
                node.name = ""
                
                //3
//                node.physicsBody?.isDynamic = false
                
                //4 
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([scaleOut, fadeOut]) // SKAction.group specifies all actions to happen simultaneously.
                
                //5
                let seq = SKAction.sequence([group, SKAction.removeFromParent()])
                node.run(seq)
                
                //6
                score += 1
                
                //7
                let index = activeEnemies.index(of: node as! SKSpriteNode)! // why is SKSpriteNode needed?
                activeEnemies.remove(at: index)
                
                //8
                run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
                
            } else if node.name == "bomb" {
                // destroy bomb - If the player swipes a bomb by accident, they lose the game immediately. This uses much the same code as destroying a penguin, but with a few differences. The node called "bomb" is the bomb image, which is inside the bomb container. So, we need to reference the node's parent when looking up our position, changing the physics body, removing the node from the scene, and removing the node from our activeEnemies array..
                
                let emitter = SKEmitterNode(fileNamed: "sliceHitBomb")!
                emitter.position = node.parent!.position
                addChild(emitter)
                
                node.name = ""
                node.parent!.physicsBody!.isDynamic = false
                
                let scaleOut = SKAction.scale(to: 0.001, duration:0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([scaleOut, fadeOut])
                
                let seq = SKAction.sequence([group, SKAction.removeFromParent()])
                
                node.parent!.run(seq)
                
                let index = activeEnemies.index(of: node.parent as! SKSpriteNode)!
                activeEnemies.remove(at: index)
                
                run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
                endGame(triggeredByBomb: true)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        if let touches = touches {
            touchesEnded(touches, with: event)
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // We're using AVAudioPlayer so that we can stop the bomb fuse when bombs are no longer on the screen. We need to modify the update() method. This method is called every frame before it's drawn, and gives you a chance to update your game state as you want. We're going to use this method to count the number of bomb containers that exist in our game, and stop the fuse sound if the answer is 0.
        
        // The second change we're going to make is to remove enemies from the game when they fall off the screen. This is required, because our game mechanic means that new enemies aren't created until the previous ones have been removed. The exception to this rule are enemy chains, where multiple enemies are created in a batch, but even then the game won't continue until all enemies from the chain have been removed.
        // 1. If we have active enemies, we loop through each of them.
        // 2. If any enemy is at or lower than Y position -140, we remove it from the game and our activeEnemies array.
        // 3. If we don't have any active enemies and we haven't already queued the next enemy sequence, we schedule the next enemy sequence and set nextSequenceQueued to be true.
        
        // 1 & 2
        if activeEnemies.count > 0 {
            for node in activeEnemies {
                if node.position.y < -140 {
                    node.removeAllActions()
                    
                    // if the player misses slicing a penguin, they lose a life. We're also going to delete the node's name just in case any further checks for enemies or bombs happen – clearing the node name will avoid any problems.
                    if node.name == "enemy" {
                        node.name = ""
                        subtractLife()
                        
                        node.removeFromParent()
                        
                        if let index = activeEnemies.index(of: node) {
                            activeEnemies.remove(at: index)
                        }
                        
                    } else if node.name == "bombContainer" {
                        node.name = ""
                        node.removeFromParent()
                        
                        if let index = activeEnemies.index(of: node) {
                            activeEnemies.remove(at: index)
                        }
                    }
                }
            }
        // 3
        } else {
            if !nextSequenceQueued {
                DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) { [unowned self] in
                    self.tossEnemies()
                }
            }
            nextSequenceQueued = true
        }
        
        var bombCount = 0
        
        for node in activeEnemies {
            if node.name == "bombContainer" {
                bombCount += 0
                break // try without break
            }
        }
        
        if bombCount == 0 {
            //bombSoundEffect.stop() // try with just this code
            if bombSoundEffect != nil {
                bombSoundEffect.stop()
                bombSoundEffect = nil
            }
        }
    }
    
    func createScore() {
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.text = "Score: 0"
        gameScore.horizontalAlignmentMode = .left
        gameScore.fontSize = 48
        
        addChild(gameScore)
        
        gameScore.position = CGPoint(x: 8, y: 8)
    }
    
    func createLives() {
        for i in 0 ..< 3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
            addChild(spriteNode)
            
            livesImages.append(spriteNode)
        }
    }
    
    func createSlices() {
        activeSliceBG = SKShapeNode()
        activeSliceFG = SKShapeNode()
        
        activeSliceBG.lineWidth = 9
        activeSliceFG.lineWidth = 5
        
        activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
        activeSliceFG.strokeColor = UIColor.white
        
        activeSliceBG.zPosition = 2
        activeSliceFG.zPosition = 2
        
        addChild(activeSliceBG)
        addChild(activeSliceFG)
        
    }
    
    func redrawActiveSlice() {
        // This method needs to do:
        // 1. If we have fewer than two points in our array, we don't have enough data to draw a line so it needs to clear the shapes and exit the method.
        // 2. If we have more than 12 slice points in our array, we need to remove the oldest ones until we have at most 12 – this stops the swipe shapes from becoming too long.
        // 3. It needs to start its line at the position of the first swipe point, then go through each of the others drawing lines to each point.
        // 4. Finally, it needs to update the slice shape paths so they get drawn using their designs – i.e., line width and color.
        // To make this work, you're going to need to know that an SKShapeNode object has a property called path which describes the shape we want to draw. When it's nil, there's nothing to draw; when it's set to a valid path, that gets drawn with the SKShapeNode's settings. SKShapeNode expects you to use a data type called CGPath, but we can easily create that from a UIBezierPath. Drawing a path using UIBezierPath is a cinch: we'll use its move(to:) method to position the start of our lines, then loop through our activeSlicePoints array and call the path's addLine(to:) method for each point. To stop the array storing more than 12 slice points, we're going to use a new loop type called a while loop. This loop will continue executing until its condition stops being true, so we'll just give the condition that activeSlicePoints has more than 12 items, then ask it to remove the first item until the condition fails.
        
        //1
        if activeSlicePoints.count < 2 {
            activeSliceBG.path = nil
            activeSliceFG.path = nil
            return
        }
        //2
        while activeSlicePoints.count > 12 {
            activeSlicePoints.remove(at: 0)
        }
        
        //3
        let path = UIBezierPath()
        path.move(to: activeSlicePoints[0])
        for i in 1..<activeSlicePoints.count {
            path.addLine(to: activeSlicePoints[i])
            path.miterLimit = 100 // The limiting value that helps avoid spikes at junctions between connected line segments.
        }
        //4
        activeSliceFG.path = path.cgPath
        activeSliceBG.path = path.cgPath
    }
    
    func playSwooshSound() {
        isSwooshSoundActive = true
        let randomNumber = RandomInt(min: 1, max: 3)
        let soundName = "swoosh\(randomNumber).caf"
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        // By playing our sound with waitForCompletion set to true, SpriteKit automatically ensures the completion closure given to runAction() isn't called until the sound has finished, so this solution is perfect.
        
        run(swooshSound) { [unowned self] in
            self.isSwooshSoundActive = false
        }

    }
    
    func createEnemy(forceBomb: ForceBomb = .random) {
        var enemy: SKSpriteNode
        var enemyType = RandomInt(min: 0, max: 6)
        
        if forceBomb == .never {
            enemyType = 1
        } else if forceBomb == .always {
            enemyType = 0
        }
        
        if enemyType == 0 {
            //BOMB CODE goes here and needs to do the following ...
            // 1. Create a new SKSpriteNode that will hold the fuse and the bomb image as children, setting its Z position to be 1.
            // 2. Create the bomb image, name it "bomb", and add it to the container.
            // 3. If the bomb fuse sound effect is playing, stop it and destroy it.
            // 4. Create a new bomb fuse sound effect, then play it.
            // 5. Create a particle emitter node, position it so that it's at the end of the bomb image's fuse, and add it to the container.
            
            //1 
            enemy = SKSpriteNode()
            enemy.zPosition = 1
            enemy.name = "bombContainer" // why is this needed?
            
            //2
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb" // why is this needed?
            enemy.addChild(bombImage)
            
            //3 
            if bombSoundEffect != nil {
                bombSoundEffect.stop() // what will happen if I remove this line?
                bombSoundEffect = nil
            }
            
            //4
            // bombSoundEffect = run(SKAction.playSoundFileNamed("sliceBombFuse.caf", waitForCompletion: false)) // try this instead!
            let path = Bundle.main.path(forResource: "sliceBombFuse.caf", ofType: nil)!
            let url = URL(fileURLWithPath: path)
            let sound = try!AVAudioPlayer(contentsOf: url)
            bombSoundEffect = sound
            sound.play()
            // bombSoundEffect.play() // try this instead
            
            //5
            let emitter = SKEmitterNode(fileNamed: "sliceFuse")!
            emitter.position = CGPoint(x: 76, y: 64) // why this particular location?
            enemy.addChild(emitter)
            
        } else {
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemy"
        }
        
        // POSITION CODE goes here and it needs to do the following...
        // 1. Give the enemy a random position off the bottom edge of the screen.
        // 2. Create a random angular velocity, which is how fast something should spin.
        // 3. Create a random X velocity (how far to move horizontally) that takes into account the enemy's position.
        // 4. Create a random Y velocity just to make things fly at different speeds.
        // 5. Give all enemies a circular physics body where the collisionBitMask is set to 0 so they don't collide.
        
        //1 
        let xPosition = CGPoint(x: RandomInt(min: 64, max: 960), y: -128)
        enemy.position = xPosition
        
        //2 
        let randomAngularVelocity = CGFloat(RandomInt(min: -6, max: 6))/2.0
        
        //3
        var randomXVelocity = 0
        if xPosition.x < 256 {
            randomXVelocity = RandomInt(min: 8, max: 15)
        } else if xPosition.x < 512 {
            randomXVelocity = RandomInt(min: 3, max: 5)
        } else if xPosition.x < 768 {
            randomXVelocity = -RandomInt(min: 3, max: 5)
        } else {
            randomXVelocity = -RandomInt(min: 8, max: 15)
        }
        
        //4
        let randomYVelocity = RandomInt(min: 24, max: 32)
        
        //5
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
        //enemy.physicsBody.isDynamic = true // why is this line not required?
        enemy.physicsBody!.collisionBitMask = 0
        enemy.physicsBody!.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody!.angularVelocity = randomAngularVelocity
        
        addChild(enemy)
        activeEnemies.append(enemy)
    }
    
    func tossEnemies() {
        // Each sequence in our array creates one or more enemies, then waits for them to be destroyed before continuing. Enemy chains are different: they create five enemies with a short break between, and don't wait for each one to be destroyed before continuing. To handle these chains, we have calls to asyncAfter() with a timer value. If we assume for a moment that chainDelay is 10 seconds, then:
            // That makes chainDelay / 10.0 equal to 1 second.
            // That makes chainDelay / 10.0 * 2 equal to 2 seconds.
            // That makes chainDelay / 10.0 * 3 equal to three seconds. So, it spreads out the createEnemy() calls quite neatly.
        
        if gameEnded {
            return
        }
        
        popupTime *= 0.991
        chainDelay *= 0.99
        physicsWorld.speed *= 1.02
        
        let sequenceType = sequence[sequencePosition]
        
        switch sequenceType {
        case .oneNoBomb:
            createEnemy(forceBomb: .never)
            
        case .one:
            createEnemy()
            
        case .twoWithOneBomb:
            createEnemy(forceBomb: .never)
            createEnemy(forceBomb: .always)
            
        case .two:
            createEnemy()
            createEnemy()
            
        case .three:
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .four:
            createEnemy()
            createEnemy()
            createEnemy()
            createEnemy()
            
        case .chain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) { [unowned self] in self.createEnemy() }
            
        case .fastChain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) { [unowned self] in self.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) { [unowned self] in self.createEnemy() }
        }
        
        sequencePosition += 1
        nextSequenceQueued = false
        
        // The nextSequenceQueued property is more complicated. If it's false, it means we don't have a call to tossEnemies() in the pipeline waiting to execute. It gets set to true only in the gap between the previous sequence item finishing and tossEnemies() being called. Think of it as meaning, "I know there aren't any enemies right now, but more will come shortly."
    }
    
    func subtractLife() {
        lives -= 1
        run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))
        var life: SKSpriteNode
        if lives == 2 {
            life = livesImages[0]
        } else if lives == 1 {
            life = livesImages[1]
        } else {
            life = livesImages[2]
            endGame(triggeredByBomb: false)
        }
        
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        // Changing the character node's texture like this is helpful because it means we don't need to keep adding and removing nodes. Instead, we can just change the texture to switch between sliceLifeGone vs sliceLife depending on the situation.
        
        life.xScale = 1.3
        life.yScale = 1.3
        life.run(SKAction.scale(to: 1, duration:0.1))
        
    }
    
    func endGame(triggeredByBomb: Bool) {
        if gameEnded {
            return
        }
        
        gameEnded = true
        physicsWorld.speed = 0
        isUserInteractionEnabled = false
        
        if bombSoundEffect != nil {
            bombSoundEffect.stop()
            bombSoundEffect = nil
        }
        
        if triggeredByBomb {
            livesImages[0].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[1].texture = SKTexture(imageNamed: "sliceLifeGone")
            livesImages[2].texture = SKTexture(imageNamed: "sliceLifeGone")
        }
        
    }
}
