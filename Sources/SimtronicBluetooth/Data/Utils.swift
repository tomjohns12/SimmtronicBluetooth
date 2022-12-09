//
//  File 2.swift
//  
//
//  Created by Tom Johnson on 08/12/2022.
//

import Foundation

class Utils {
    
    private var hexArray: [Character] = Array("0123456789ABCDEF")
    
    init() {
        
    }
    
    func byteArrayToHexString(bytes: [UInt8]) -> String {
        
        var hexChars: [Character] = []
        
        for i in 0..<bytes.count {
            
            let v = (bytes[i] & 0xFF)
            hexChars[i*2] = hexArray[Int(v>>4)]
            hexChars[i*2+1] = hexArray[Int(v & 0x0F)]
        }
        
        return String(hexChars)
    }
    
    func hexStringToByteArray(string: String) -> [UInt8] {
        
        let halfLength = string.count / 2
        
        var bytes: [UInt8] = Array(repeating: 0x00, count: halfLength)
        
        for i in 0..<halfLength {
            
            let index = i * 2
            
            let start = string.index(string.startIndex, offsetBy: index)
            let end = string.index(string.startIndex, offsetBy: (index + 2))
            let range = start..<end
            
            let sub =  String(string[range])
            
            if let val = Int(sub, radix: 16) {
                bytes[i] = UInt8(val)
            }
        }
        
        return bytes
    }
    
}
