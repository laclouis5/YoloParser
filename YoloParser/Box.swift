//
//  Box.swift
//  YoloParser
//
//  Created by Louis Lac on 15/07/2019.
//  Copyright © 2019 Louis Lac. All rights reserved.
//

import Foundation

struct Box: CustomStringConvertible {
    // MARK: - Definitions
    enum CoordType {
        case XYWH
        case XYX2Y2
    }
    
    enum CoordinateSystem {
        case absolute
        case relative
    }
    
    enum DetectionMode {
        case groundTruth
        case detection
    }
    
    // MARK: - Properties
    let name: String
    let x, y, w, h: Double
    let label: String
    let imgSize: NSSize?
    let confidence: Double?
    let coordType: CoordType
    let coordSystem: CoordinateSystem
    let detectionMode: DetectionMode
    
    var description: String {
        var description = "\(self.label):"
        switch self.coordType {
        case .XYX2Y2:
            description += " (xMin: \(self.x), yMin: \(self.y), xMax: \(self.w), yMax: \(self.h))"
        default:
            description += " (x: \(self.x), y: \(self.y), w: \(self.w), h: \(self.h))"
        }
        
        switch self.coordSystem {
        case .absolute:
            description += " abs. coords"
        default:
            description += " rel. coords"
        }
        
        switch self.detectionMode {
        case .groundTruth:
            description += ", ground truth"
        case .detection:
            description += ", detection with confidence \(confidence!)"
        }
        
        return description
    }
    
    // MARK: - Initalizers
    init?(name: String, a: Double, b: Double, c: Double, d: Double, label: String, coordType: CoordType = .XYWH, coordSystem: CoordinateSystem = .absolute, imgSize: NSSize? = nil, detectionMode : DetectionMode = .groundTruth, confidence: Double? = nil) {
        //FIXME: Change data storage format
        // It would be smarter to store raw coordinates and only ask imgSize if absolute coordinates (or ask it every time). Only convert to absolute (or relative) XYWH for computations.
        self.name = name
        self.label = label
        self.coordType = coordType
        self.coordSystem = coordSystem
        self.detectionMode = detectionMode
        self.imgSize = imgSize
        self.confidence = confidence
        
        var xTemp, yTemp, wTemp, hTemp: Double
        
        switch coordType {
        case .XYWH:
            (xTemp, yTemp, wTemp, hTemp) = (a, b, c, d)
        case .XYX2Y2:
            (xTemp, yTemp, wTemp, hTemp) = Box.convertToXYWH(xMin: a, yMin: b, xMax: c, yMax: d)
        }
        
        switch coordSystem {
        case .relative:
            guard let imgSize = imgSize else {
                print("Error: must provide img size when using relative coordinates")
                return nil
            }
            (x, y, w, h) = Box.convertToAbsolute(a: xTemp, b: yTemp, c: wTemp, d: hTemp, imgSize: imgSize)
        default:
            (x, y, w, h) = (xTemp, yTemp, wTemp, hTemp)
        }
        
        switch detectionMode {
        case .detection:
            guard confidence != nil else {
                print("Error: must provide confidence when using Detection mode")
                return nil
            }
        default:
            break
        }
    }
    
    init?(name: String, rect: CGRect, label: String, coordSystem: CoordinateSystem = .absolute, imgSize: NSSize? = nil, detectionMode: DetectionMode = .groundTruth, confidence: Double? = nil) {
        let (x, y, w, h) = (Double(rect.midX), Double(rect.midY), Double(rect.width), Double(rect.height))
        self.init(name: name, a: x, b: y, c: w, d: h, label: label, coordType: .XYWH, coordSystem: coordSystem, imgSize: imgSize, detectionMode: detectionMode, confidence: confidence)
    }
    
    // MARK: - Methods
    func getRawBoundingBox(coordType: CoordType = .XYWH, coordSystem: CoordinateSystem = .absolute, imgSize: NSSize? = nil) -> (Double, Double, Double, Double)? {
        var a, b, c, d: Double
        
        switch coordType {
        case .XYWH:
            (a, b, c, d) = (x, y, w, h)
        case .XYX2Y2:
            (a, b, c, d) = Box.convertToXYX2Y2(x: x, y: y, w: w, h: h)
        }
        
        switch coordSystem {
        case .relative:
            guard let size = (imgSize ?? self.imgSize) else {
                print("Error: must provide img size when relative")
                return nil
            }
            (a, b, c, d) = Box.convertToRelative(a: x, b: y, c: w, d: h, imgSize: size)
        default:
            break
        }
        
        return (a, b, c, d)
    }
    
    func computeIoU(with box: Box) -> Double {
        let (xMin1, yMin1, xMax1, yMax1) = Box.convertToXYX2Y2(x: x, y: y, w: w, h: h)
        let (xMin2, yMin2, xMax2, yMax2) = Box.convertToXYX2Y2(x: box.x, y: box.y, w: box.w, h: box.h)
        
        let (xA, yA, xB, yB) = (max(xMin1, xMin2), max(yMin1, yMin2), min(xMax1, xMax2), min(yMax1, yMax2))
        
        let intersection = (xB - xA)*(yB - yA)
        
        if intersection > 0.0 {
            let union = (xMax1 - xMin1)*(yMax1 - yMin1) + (xMax2 - xMin2)*(yMax2 - yMin2) - intersection
            return intersection / (union + Double.leastNonzeroMagnitude)
        } else {
            return 0.0
        }
    }
    
    static private func convertToXYX2Y2(x: Double, y: Double, w: Double, h: Double) -> (xMin: Double, yMin: Double, xMax: Double, yMax: Double) {
        return (x - w/2.0, y - h/2.0, x + w/2.0, y + h/2.0)
    }
    
    static private func convertToXYWH(xMin: Double, yMin: Double, xMax: Double, yMax: Double) -> (x: Double, y: Double, w: Double, h: Double) {
        let w = xMax - xMin
        let h = yMax - yMin
        return (xMin + w/2.0, yMin + h/2.0, w, h)
    }
    
    static private func convertToRelative(a: Double, b: Double, c: Double, d: Double, imgSize: NSSize) -> (Double, Double, Double, Double) {
        return (a/Double(imgSize.width), b/Double(imgSize.height), c/Double(imgSize.width), d/Double(imgSize.height))
    }
    
    static private func convertToAbsolute(a: Double, b: Double, c: Double, d: Double, imgSize: NSSize) -> (Double, Double, Double, Double) {
        return (a*Double(imgSize.width), b*Double(imgSize.height), c*Double(imgSize.width), d*Double(imgSize.height))
    }
}
