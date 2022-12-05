//
//  File.swift
//  
//
//  Created by Tom Johnson on 02/12/2022.
//

import Foundation

class LightManager {
    
//    func sendLightCommad(command: NodeCommand)
    
}

enum NodeCommand: Int {
    
    case preset01 = 0x0820
    case preset02 = 0x0824
    case preset03 = 0x0828
    case preset04 = 0x082C
    
    case rampUp = 0x0b01
    case rampDown = 0x0a21
    case rampUpWithRepeat = 0x0b04
    case rampDownWithRepeat = 0x0a24
}
