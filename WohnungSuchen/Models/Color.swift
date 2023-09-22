//
//  Color.swift
//  DetectChanges
//
//  Created by Yuriy Gudimov on 08.04.2023.
//

import UIKit

enum Color: String {
    case brandDark
    case brandBlue
    case brandGray
    case brandOlive
    case brandRed
    case brandContrast

    var setColor: UIColor? {
        switch self {
        case .brandDark: return UIColor(named: self.rawValue)
        case .brandBlue: return UIColor(named: self.rawValue)
        case .brandGray: return UIColor(named: self.rawValue)
        case .brandOlive: return UIColor(named: self.rawValue)
        case .brandRed: return UIColor(named: self.rawValue)
        case .brandContrast: return UIColor(named: self.rawValue)
        }
    }
}
