//
//  File 2.swift
//  
//
//  Created by Tom Johnson on 08/12/2022.
//

import Foundation

class Utils {
    
    init() {
        
    }
    
    
    func hexStringToByteArray(string: String) -> [UInt8] {
        
        let halfLength = string.count / 2
        
        var bytes: [UInt8] = Array(repeating: 0x00, count: halfLength)
        
        for i in 0..<halfLength {
            
            let index = i * 2
            
//            int val = Integer.parseInt(str.substring(index, index + 2), 16);
            let val = Int(string) ?? 0
            bytes[i] = UInt8(val)
        }
        
        return bytes
    }
    
}
