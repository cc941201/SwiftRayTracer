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

func +=(inout lhs: Vector, rhs: Vector) {
    lhs = lhs + rhs
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

typealias Vertex = (position: Vector, normal: Vector)

struct Ray {
    let origin, direction: Vector
}

struct Face {
    let v0, e0, e1, n0, nd0, nd1: Vector
    
    init(v0: Vector, v1: Vector, v2: Vector, n0: Vector, n1: Vector, n2: Vector) {
        let e0 = v1 - v0, e1 = v2 - v0, e2 = v2 - v1
        let sn1, sn2: Vector
        if abs(e0.x) > abs(e1.x) || abs(e0.x) > abs(e2.x) {
            if abs(e1.x) > abs(e2.x) {
                self.e0 = e0
                self.e1 = e1
                self.v0 = v0
                self.n0 = n0
                sn1 = n1
                sn2 = n2
            } else {
                self.e0 = e2
                self.e1 = -e0
                self.v0 = v1
                self.n0 = n1
                sn1 = n2
                sn2 = n0
            }
        } else {
            self.e0 = -e1
            self.e1 = -e2
            self.v0 = v2
            self.n0 = n2
            sn1 = n0
            sn2 = n1
        }
        nd0 = sn1 - self.n0
        nd1 = sn2 - self.n0
    }
    
    func intersect(ray: Ray) -> Float? {
        let h: Vector = ray.direction * e1
        let a: Float = h * e0
        if a > -0.00001 && a < 0.00001 {
            return nil
        }
        let f = 1 / a
        let s = ray.origin - v0
        let u = f * (s * h)
        if u < 0 || u > 1 {
            return nil
        }
        let q: Vector = s * e0
        let v = f * (ray.direction * q)
        if v < 0 || u + v > 1 {
            return nil
        }
        let t = f * (e1 * q)
        return t > 0.00001 ? t : nil
    }
    
    func normal(point: Vector) -> Vector {
        let ratio1 = (point.x - v0.x) / e0.x
        let p1 = e0.y * ratio1 + v0.y
        let normal1 = nd0 * ratio1 + n0
        let ratio2 = (point.x - v0.x) / e1.x
        let p2 = e1.y * ratio2 + v0.y
        let normal2 = nd1 * ratio2 + n0
        let ratio = (point.y - p1) / (p2 - p1)
        return (normal2 - normal1) * ratio + normal1
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

var v: [Vertex] = []
var f: [(Int, Int, Int)] = []

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
        v.append((Vector(x: array[0], y: array[1], z: array[2]), .zero))
    } else if items[0] == "f" {
        let array = Array(items[1...3]).map { $0.toInt()! - 1 }
        f.append(array[0], array[1], array[2])
        let v0 = v[array[0]].position
        let v1 = v[array[1]].position - v0
        let v2 = v[array[2]].position - v0
        let normal: Vector = v1 * v2
        v[array[0]].normal += normal
        v[array[1]].normal += normal
        v[array[2]].normal += normal
    }
}
v = v.map { ($0.position, $0.normal.normalized) }
let faces = f.map { Face(v0: v[$0.0].position, v1: v[$0.1].position, v2: v[$0.2].position, n0: v[$0.0].normal, n1: v[$0.1].normal, n2: v[$0.2].normal) }

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
            for face in faces {
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
                for face in faces {
                    if face.intersect(toLight) != nil {
                        obstructed = true
                        break
                    }
                }
                let n = face.normal(intersection).normalized
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
