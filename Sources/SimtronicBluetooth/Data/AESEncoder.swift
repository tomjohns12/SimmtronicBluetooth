//
//  File 2.swift
//  
//
//  Created by Tom Johnson on 06/12/2022.
//

import Foundation
import CommonCrypto
import CryptoSwift

struct AESEncoder {

    // MARK: - Value
    // MARK: Private
//    private let key: Data
//    private let iv: Data
//
//
//    // MARK: - Initialzier
//    init?(key: String, iv: String) {
//        guard key.count == kCCKeySizeAES128 || key.count == kCCKeySizeAES256, let keyData = key.data(using: .utf8) else {
//            debugPrint("Error: Failed to set a key.")
//            return nil
//        }
//
//        guard iv.count == kCCBlockSizeAES128, let ivData = iv.data(using: .utf8) else {
//            debugPrint("Error: Failed to set an initial vector.")
//            return nil
//        }
//
//
//        self.key = keyData
//        self.iv  = ivData
//    }
    
    
    func getHashedPassword(password: String) -> [UInt8] {
        
        let hash = sha256(string: password)
        
        var hashSmall: [UInt8] = Array(repeating: 0x00, count: 16)
//        var hashSmall: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        
        var hp = 0
        var hsp = 0
        
        for _ in 0..<4 {
            
            for _ in 0..<4 {
                
                hashSmall[hsp] = UInt8(hash[0 + hp] ^ hash[4 + hp])
                
                hp += 1
                hsp += 1
            }
            
            hp += 4
        }
        
        var hashSmallFixed: [UInt8] = Array(repeating: 0x00, count: 16)
//        var hashSmallFixed: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        
        hashSmallFixed[0] = hashSmall[12]
        hashSmallFixed[1] = hashSmall[13]
        hashSmallFixed[2] = hashSmall[14]
        hashSmallFixed[3] = hashSmall[15]

        hashSmallFixed[4] = hashSmall[8]
        hashSmallFixed[5] = hashSmall[9]
        hashSmallFixed[6] = hashSmall[10]
        hashSmallFixed[7] = hashSmall[11]

        hashSmallFixed[8] = hashSmall[4]
        hashSmallFixed[9] = hashSmall[5]
        hashSmallFixed[10] = hashSmall[6]
        hashSmallFixed[11] = hashSmall[7]

        hashSmallFixed[12] = hashSmall[0]
        hashSmallFixed[13] = hashSmall[1]
        hashSmallFixed[14] = hashSmall[2]
        hashSmallFixed[15] = hashSmall[3]

        print(hashSmallFixed)
        return hashSmallFixed
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
    
    

    func solveChallenge(challenge: [UInt8], key: [UInt8]) -> [UInt8] {
        
        guard let iv = "abcdefghijklmnop".data(using: .utf8) else {
            return []
        }
        
        guard let encryptedPassword = encrypt(key: Data(key), iv: iv, data: Data(challenge)) else {
            return []
        }
        
        return [UInt8](encryptedPassword)
    }
    
    
    func encrypt(key: Data, iv: Data, data: Data) -> Data? {
        return crypt(key: key, iv: iv, data: data, option: CCOperation(kCCEncrypt))
    }

    func decrypt(key: Data, iv: Data, data: Data?) -> String? {
        guard let decryptedData = crypt(key: key, iv: iv, data: data, option: CCOperation(kCCDecrypt)) else { return nil }
        return String(bytes: decryptedData, encoding: .utf8)
    }

    func crypt(key: Data, iv: Data, data: Data?, option: CCOperation) -> Data? {
        
        guard let data = data else {
            return nil
        }
    
        let cryptLength = data.count + key.count
        var cryptData   = Data(count: cryptLength)
    
        var bytesLength = Int(0)
    
        let status = cryptData.withUnsafeMutableBytes { cryptBytes in
            data.withUnsafeBytes { dataBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                    CCCrypt(option, CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding), keyBytes.baseAddress, key.count, ivBytes.baseAddress, dataBytes.baseAddress, data.count, cryptBytes.baseAddress, cryptLength, &bytesLength)
                    }
                }
            }
        }
    
        guard Int32(status) == Int32(kCCSuccess) else {
            debugPrint("Error: Failed to crypt data. Status \(status)")
            return nil
        }
    
        cryptData.removeSubrange(bytesLength..<cryptData.count)
        return cryptData
    }
    
//    func AESEncryption(key: Data) -> String? {
//
//            let keyData: NSData! = (key as NSString).data(using: String.Encoding.utf8.rawValue) as NSData!
//
//            let data: NSData! = (self as NSString).data(using: String.Encoding.utf8.rawValue) as NSData!
//
//            let cryptData    = NSMutableData(length: Int(data.length) + kCCBlockSizeAES128)!
//
//            let keyLength              = size_t(kCCKeySizeAES128)
//            let operation: CCOperation = UInt32(kCCEncrypt)
//            let algoritm:  CCAlgorithm = UInt32(kCCAlgorithmAES128)
//            let options:   CCOptions   = UInt32(kCCOptionECBMode + kCCOptionPKCS7Padding)
//
//            var numBytesEncrypted :size_t = 0
//
//
//            let cryptStatus = CCCrypt(operation,
//                                      algoritm,
//                                      options,
//                                      keyData.bytes, keyLength,
//                                      nil,
//                                      data.bytes, data.length,
//                                      cryptData.mutableBytes, cryptData.length,
//                                      &numBytesEncrypted)
//
//            if UInt32(cryptStatus) == UInt32(kCCSuccess) {
//                cryptData.length = Int(numBytesEncrypted)
//
//                var bytes = [UInt8](repeating: 0, count: cryptData.length)
//                cryptData.getBytes(&bytes, length: cryptData.length)
//
//                var hexString = ""
//                for byte in bytes {
//                    hexString += String(format:"%02x", UInt8(byte))
//                }
//
//                return hexString
//            }
//
//            return nil
//        }
    
//    func aesEncrypt(_ key: String, iv: String) throws -> String {
//        let data = self.data(using: String.Encoding.utf8)
//        let enc = try AES(key: key, iv: iv, blockMode: .CBC, padding: PKCS7()).encrypt(data!.bytes)
//        let encData = Data(bytes: UnsafePointer<UInt8>(enc), count: Int(enc.count))
//        let base64String: String = encData.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
//        let result = String(base64String)
//        return result!
//    }
    
    func encriptMessageWithAES(key: [UInt8], data: [UInt8]) -> String {
        
        do {
            let encrypted = try AES(key: key, iv: nil, blockMode: .ECB, padding: PKCS7())
            let ciphertext = try encrypted.encrypt(data)
        } catch {
            print(error)
            return "error"
        }
    }
    
}
