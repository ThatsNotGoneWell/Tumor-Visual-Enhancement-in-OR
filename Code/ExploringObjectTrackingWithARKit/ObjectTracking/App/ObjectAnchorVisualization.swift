/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The visualization of an object anchor.
*/

import ARKit
import RealityKit
import SwiftUI

@MainActor
class ObjectAnchorVisualization {
    
    private let textBaseHeight: Float = 0.08
    private let alpha: CGFloat = 0.7
    private let axisScale: Float = 0.05
    
    var boundingBoxOutline: BoundingBoxOutline
    
    var entity: Entity

    init(for anchor: ObjectAnchor, withModel model: Entity? = nil) {
        boundingBoxOutline = BoundingBoxOutline(anchor: anchor, alpha: alpha)
        
        let entity = Entity()
        
        let originVisualization = Entity.createAxes(axisScale: axisScale, alpha: alpha)
        
        if let model {
                // Overwrite the model's appearance to a yellow wireframe.
                var wireframeMaterial = PhysicallyBasedMaterial()
                wireframeMaterial.triangleFillMode = .lines
                wireframeMaterial.faceCulling = .back
                wireframeMaterial.baseColor = .init(tint: .yellow)
                wireframeMaterial.blending = .transparent(opacity: 0.2)

                model.applyMaterialRecursively(wireframeMaterial)
                entity.addChild(model)
        
            }

            //In charge of disabling bounding box
            boundingBoxOutline.entity.isEnabled = model == nil

            entity.addChild(originVisualization)
            entity.addChild(boundingBoxOutline.entity)

            entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
            entity.isEnabled = anchor.isTracked

            let descriptionEntity = Entity.createText(anchor.referenceObject.name, height: textBaseHeight * axisScale)
            descriptionEntity.transform.translation.x = textBaseHeight * axisScale
            descriptionEntity.transform.translation.y = anchor.boundingBox.extent.y * 0.5
            entity.addChild(descriptionEntity)

    
            self.entity = entity
            // **New: Attach the 3D model**
            attach3DModel(to: entity, anchor: anchor)
    }
        
    // New function to attach the 3D model
    private func attach3DModel(to parentEntity: Entity, anchor: ObjectAnchor) {
        // Load the model from the Reference Objects folder
        //tumor
        if let modelEntity = try? Entity.loadModel(named: "YellowBallSegmentation.usdz") {
        
        //Tank cover
        //if let modelEntity = try? Entity.loadModel(named: "test1115.usdz") {
            
            // Tumor
            let XOffset: Float = 0.103
            let YOffset: Float = 0.0
            let ZOffset: Float = -0.003
            
            //Tank cover
//            let XOffset: Float = -0.02
//            let YOffset: Float = 0.0
//            let ZOffset: Float = 0
            
            // Position the model relative to the anchor
            modelEntity.transform.translation.x = anchor.boundingBox.center.x+XOffset
            modelEntity.transform.translation.y = anchor.boundingBox.center.y+YOffset
            modelEntity.transform.translation.z = anchor.boundingBox.center.z+ZOffset
            
            // Tumor
            let degreesX: Float = 267
            let degreesY: Float = 5
            let degreesZ: Float = 135
            
            //Tank Cover
//            let degreesX: Float = 260
//            let degreesY: Float = 240
//            let degreesZ: Float = -10
            
            let radiansX = degreesX * (Float.pi / 180)
            let radiansY = degreesY * (Float.pi / 180)
            let radiansZ = degreesZ * (Float.pi / 180)

            // Create a quaternion for the 45-degree rotation along any axis
            let rotationX = simd_quatf(angle: radiansX, axis: [1, 0, 0])  // Rotation along X axis
            let rotationY = simd_quatf(angle: radiansY, axis: [0, 1, 0])  // Rotation along Y axis
            let rotationZ = simd_quatf(angle: radiansZ, axis: [0, 0, 1])  // Rotation along Z axis

            // Combine rotations as needed (optional: multiply quaternions for combined rotation)
            let combinedRotation = rotationX * rotationY * rotationZ // Example of combining axes

            // Apply the combined rotation to the model
            modelEntity.transform.rotation = combinedRotation
            
            // **New: Apply scaling**
            let scaleFactor: Float = 1/960  // Change this to scale up or down
            modelEntity.transform.scale = [scaleFactor, scaleFactor, scaleFactor]  // Uniform scaling
            
            // Add colored markers to indicate rotation directions
            let markerLength: Float = 0.4
            let markerThickness: Float = 0.03

            func createAxisMarker(color: UIColor, direction: SIMD3<Float>) -> Entity {
                let material = SimpleMaterial(color: color, isMetallic: false)
                let mesh = MeshResource.generateBox(size: [markerThickness, markerThickness, markerLength])
                let marker = ModelEntity(mesh: mesh, materials: [material])

                // Align the marker along the direction vector
                let rotation = simd_quatf(from: [0, 0, 1], to: normalize(direction))
                marker.orientation = rotation

                // Offset so the base of the marker starts at origin
                marker.position = direction * (markerLength / 2.0)

                return marker
            }

            // Create and add X (red), Y (green), Z (blue) rotation direction markers
            let xDirection = simd_act(modelEntity.orientation, SIMD3<Float>(1, 0, 0))
            let yDirection = simd_act(modelEntity.orientation, SIMD3<Float>(0, 1, 0))
            let zDirection = simd_act(modelEntity.orientation, SIMD3<Float>(0, 0, 1))

            let xMarker = createAxisMarker(color: .red, direction: xDirection)
            let yMarker = createAxisMarker(color: .green, direction: yDirection)
            let zMarker = createAxisMarker(color: .blue, direction: zDirection)

//            parentEntity.addChild(xMarker)
//            parentEntity.addChild(yMarker)
//            parentEntity.addChild(zMarker)


            // Add the model as a child of the main entity
            parentEntity.addChild(modelEntity)
        } else {
            print("Failed to load the 3D model.")
        }
    }

    
    func update(with anchor: ObjectAnchor) {
        entity.isEnabled = anchor.isTracked
        guard anchor.isTracked else { return }
        
        entity.transform = Transform(matrix: anchor.originFromAnchorTransform)
        boundingBoxOutline.update(with: anchor)
    }

    @MainActor
    class BoundingBoxOutline {
        private let thickness: Float = 0.0025
        
        private var extent: SIMD3<Float> = [0, 0, 0]
        
        private var wires: [Entity] = []
        
        var entity: Entity

        fileprivate init(anchor: ObjectAnchor, color: UIColor = .yellow, alpha: CGFloat = 1.0) {
            let entity = Entity()
            
            let materials = [UnlitMaterial(color: color.withAlphaComponent(alpha))]
            let mesh = MeshResource.generateBox(size: [1.0, 1.0, 1.0])

            for _ in 0...11 {
                let wire = ModelEntity(mesh: mesh, materials: materials)
                wires.append(wire)
                entity.addChild(wire)
            }
            
            self.entity = entity
            
            update(with: anchor)
        }
        
        fileprivate func update(with anchor: ObjectAnchor) {
            let yOffset: Float = extent.y / 2  // Move the box down by half its height
            entity.transform.translation = anchor.boundingBox.center - SIMD3<Float>(0, yOffset, 0)
//            entity.transform.translation = anchor.boundingBox.center
            
            // Update the outline only if the extent has changed.
            guard anchor.boundingBox.extent != extent else { return }
            extent = anchor.boundingBox.extent/2.0

            for index in 0...3 {
                wires[index].scale = SIMD3<Float>(extent.x, thickness, thickness)
                wires[index].position = [0, extent.y / 2 * (index % 2 == 0 ? -1 : 1), extent.z / 2 * (index < 2 ? -1 : 1)]
            }
            
            for index in 4...7 {
                wires[index].scale = SIMD3<Float>(thickness, extent.y, thickness)
                wires[index].position = [extent.x / 2 * (index % 2 == 0 ? -1 : 1), 0, extent.z / 2 * (index < 6 ? -1 : 1)]
            }
            
            for index in 8...11 {
                wires[index].scale = SIMD3<Float>(thickness, thickness, extent.z)
                wires[index].position = [extent.x / 2 * (index % 2 == 0 ? -1 : 1), extent.y / 2 * (index < 10 ? -1 : 1), 0]
            }
        }
    }
}
