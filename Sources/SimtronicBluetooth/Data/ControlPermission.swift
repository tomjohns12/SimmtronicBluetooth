//
//  File 2.swift
//  
//
//  Created by Tom Johnson on 08/12/2022.
//

import Foundation
import CommonCrypto

class ControlPermission {
    
    var qrText = ""
    var info = ""
    
    var valid = false
    
    private lazy var utils = Utils()
    
    init() {
        
    }
    
    func getDetails(qrText: String) {
        
        self.qrText = qrText
        
        let details = qrText.components(separatedBy: ",")
        let fieldCount = details.count
        
        if fieldCount >= 25 {
            
            if details[0] == "CP1" {
                
                if details.last?.count == 16 {
                    
                    valid = true
                    info = "Control permission"
                    
                    if !details[1].isEmpty {
                        info += "\nDate Created: \(details[1])"
                    }
                    
                    if !details[2].isEmpty {
                        info += "\nJob: \(details[2])"
                    }
                    
                    if !details[3].isEmpty {
                        info += "\nPermission number: \(details[3])"
                    }
                    
                    if !details[8].isEmpty {
                        info += "\nRole: \(details[8])"
                    }
                    
                    if !details[10].isEmpty {
                        info += "\nArea: \(details[10])"
                    }
                    
                    if !details[11].isEmpty {
                        info += "\nArea: \(details[11])"
                    }
                    
                    if !details[12].isEmpty {
                        info += "\nArea: \(details[12])"
                    }
                    
                    if !details[13].isEmpty {
                        info += "\nArea: \(details[13])"
                    }
                    
                    if !details[22].isEmpty {
                        info += "\nMoment A: \(details[22])"
                    }
                    
                    if !details[23].isEmpty {
                        info += "\nMoment B: \(details[23])"
                    }
                    
                }
            }
        }
        
        info = "Unrcognised code"
    }
    
    
    
    
    func conrolPermissionIsGenuine(bytes: [UInt8]) -> Bool {
        
        let details = qrText.components(separatedBy: ",")
        let fieldCount = details.count
        let commaCount = fieldCount - 1
        
        let qrSmallHashString = details[commaCount]
        var qrStringWithoutCommas = ""
        
        for i in 0..<fieldCount {
            qrStringWithoutCommas += details[i]
        }
        
        qrStringWithoutCommas += utils.byteArrayToHexString(bytes: bytes)
        
        let sumSmall = getHashedString(string: qrStringWithoutCommas)
        let hashByteArray: [UInt8] = utils.hexStringToByteArray(string: qrSmallHashString)
        
        return (hashByteArray == sumSmall)
    }
    
    func getHashedString(string: String) -> [UInt8] {
        
        let hash = sha256(string: string)
        
        var smallSum: [UInt8] = Array(repeating: 0x00, count: 8)
        
        var hp = 0
        var hsp = 0
        
        for _ in 0..<2 {
            
            for _ in 0..<4 {
                
                smallSum[hsp] = UInt8( UInt8(hash[hp]) ^ UInt8(hash[hp + 4]) ^ UInt8(hash[hp + 8]) ^ UInt8(hash[hp + 12]) )
                
                hp += 1
                hsp += 1
            }
            
            hp += 12
        }
        
        var byte: UInt8 = 0x00
        
        byte = smallSum[0]
        smallSum[0] = smallSum[4]
        smallSum[4] = byte
        
        byte = smallSum[1]
        smallSum[1] = smallSum[5]
        smallSum[5] = byte
        
        byte = smallSum[2]
        smallSum[2] = smallSum[6]
        smallSum[6] = byte
        
        byte = smallSum[3]
        smallSum[3] = smallSum[7]
        smallSum[7] = byte
        
        return smallSum
    }
    
    func sha256(string: String) -> [UInt8] {
        let data = Data(string.utf8)
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        print(hash)
        return hash
    }
    
}
