//
//  GazeSide.swift
//  ComfyPrompter
//
//  Created by Aryan Rogye on 10/26/26.
//

enum GazeSide {
    case none
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public mutating func next() {
        switch self {
        case .none:
            self = .topLeft
        case .topLeft:
            self = .bottomLeft
        case .topRight:
            self = .bottomRight
        case .bottomLeft:
            self = .topRight
        case .bottomRight:
            self = .none
        }
    }
}
