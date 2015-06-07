//
//  main.swift
//  RayTracer
//
//  Created by 张国晔 on 15/6/6.
//  Copyright (c) 2015年 Shandong University. All rights reserved.
//

import Cocoa

struct Vector {
    let x, y, z: Float
    
    var normalized: Vector {
        let scale = 1 / sqrt(x * x + y * y + z * z)
        return Vector(x: x * scale, y: y * scale, z: z * scale)
    }
    
    static var zero: Vector {
        return Vector(x: 0, y: 0, z: 0)
    }
}

prefix func -(vec: Vector) -> Vector {
    return Vector(x: -vec.x, y: -vec.y, z: -vec.z)
}

func +(lhs: Vector, rhs: Vector) -> Vector {
    return Vector(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
}

func -(lhs: Vector, rhs: Vector) -> Vector {
    return Vector(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
}

func *(lhs: Vector, rhs: Float) -> Vector {
    return Vector(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
}

func *(lhs: Vector, rhs: Vector) -> Float {
    return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
}

func *(lhs: Vector, rhs: Vector) -> Vector {
    let x = lhs.y * rhs.z - lhs.z * rhs.y
    let y = lhs.z * rhs.x - lhs.x * rhs.z
    let z = lhs.x * rhs.y - lhs.y * rhs.x
    return Vector(x: x, y: y, z: z)
}

func max(lhs: Vector, rhs: Vector) -> Vector {
    return Vector(x: max(lhs.x, rhs.x), y: max(lhs.y, rhs.y), z: max(lhs.z, rhs.z))
}

struct Ray {
    let origin, direction: Vector
}

struct Face {
    let x, y, z: Vector
    
    init(x: Vector, y: Vector, z: Vector) {
        self.x = x
        self.y = y - self.x
        self.z = z - self.x
    }
    
    func intersect(ray: Ray) -> Float? {
        let h: Vector = ray.direction * z
        let a: Float = h * y
        if a > -0.00001 && a < 0.00001 {
            return nil
        }
        let f = 1 / a
        let s = ray.origin - x
        let u = f * (s * h)
        if u < 0 || u > 1 {
            return nil
        }
        let q: Vector = s * y
        let v = f * (ray.direction * q)
        if v < 0 || u + v > 1 {
            return nil
        }
        let t = f * (z * q)
        return t > 0.00001 ? t : nil
    }
    
    var normal: Vector {
        return y * z
    }
}

extension Int {
    var f: Float {
        return Float(self)
    }
}

let width = 1024, height = 1024
let light = Vector(x: 1, y: 0, z: 0)
let lightColor = Vector(x: 0, y: 0, z: 1)

var v: [Vector] = []
var f: [Face] = []

let model = String(contentsOfFile: "1.obj", encoding: NSUTF8StringEncoding, error: nil)!
let lines = split(model) { $0 == "\n" }
let numberFormatter = NSNumberFormatter()
for line in lines {
    let items = split(line) { $0 == " " }
    if items.count < 4 {
        continue
    }
    if items[0] == "v" {
        let array = Array(items[1...3]).map { numberFormatter.numberFromString($0)!.floatValue }
        v.append(Vector(x: array[0], y: array[1], z: array[2]))
    } else if items[0] == "f" {
        let array = Array(items[1...3]).map { $0.toInt()! }
        f.append(Face(x: v[array[0] - 1], y: v[array[1] - 1], z: v[array[2] - 1]))
    }
}

var image = [[Vector]](count: height, repeatedValue: [Vector](count: width, repeatedValue: .zero))

dispatch_apply(height, dispatch_get_global_queue(0, 0)) { i in
    let fi = i.f / height.f * 2 - 1
    for j in 0..<width {
        let fj = j.f / width.f * 2 - 1
        var color = Vector(x: 0, y: 0, z: 0)
        var reflection: Float = 1
        var depth = 0
        var ray = Ray(origin: Vector(x: fj, y: 1, z: fi), direction: Vector(x: 0, y: -1, z: 0))
        do {
            var min: Float = .infinity, minFace: Face?
            for face in f {
                if let distance = face.intersect(ray) where distance < min {
                    min = distance
                    minFace = face
                }
            }
            if let face = minFace {
                color = lightColor * 0.2
                let intersection = ray.origin + ray.direction * min
                let direction = light - intersection
                let toLight = Ray(origin: intersection, direction: direction)
                var obstructed = false
                for face in f {
                    if face.intersect(toLight) != nil {
                        obstructed = true
                        break
                    }
                }
                let n = face.normal.normalized
                if !obstructed {
                    let l = direction.normalized
                    let e = -intersection.normalized
                    let h = (l + e).normalized
                    let kd = max(l * n, 0)
                    let ks = pow(max(n * h, 0), 5)
                    let newColor = lightColor * (kd * 0.8) + Vector(x: 0.3, y: 0.3, z: 0.3) * ks
                    color = max(color, newColor)
                }
                let newDirection = ray.direction - n * ((n * ray.direction) as Float) * 2
                ray = Ray(origin: intersection, direction: ray.direction)
            } else {
                break
            }
            reflection *= 0.8
            depth++
        } while reflection > 0.00001 && depth < 10
        image[height - i - 1][width - j - 1] = color
    }
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: NSCalibratedRGBColorSpace, bytesPerRow: 3 * width, bitsPerPixel: 24)!
for i in 0..<height {
    for j in 0..<width {
        let color = image[i][j]
        rep.setColor(NSColor(calibratedRed: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: 1), atX: j, y: i)
    }
}
rep.representationUsingType(.NSPNGFileType, properties: [:])!.writeToFile("1.png", atomically: false)

//var output = "P3\n\(height) \(width) 255\n"
//for i in 0..<height {
//    for j in 0..<width {
//        let color = image[i][j]
//        output += "\(Int(color.x * 255)) \(Int(color.y * 255)) \(Int(color.z * 255))\n"
//    }
//}
//output.writeToFile("1.pmm", atomically: false, encoding: NSUTF8StringEncoding, error: nil)
