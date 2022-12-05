//
//  File.swift
//  
//
//  Created by Tom Johnson on 02/12/2022.
//

import Foundation

class DataController {
    
    func readDeviceInfo(bytes: [UInt8]) {
        
        if bytes[0] == 0x0a {
            
            let deviceType = bytes[1]
            print(deviceType)
            
            if deviceType == 0x01 {
                var deviceFirmwareBuildNumber = bytes[2] << 24
                deviceFirmwareBuildNumber += bytes[3] << 16
                deviceFirmwareBuildNumber += bytes[4] << 8
                deviceFirmwareBuildNumber += bytes[5]
                
                print(deviceFirmwareBuildNumber)
            }
        }
        
    }
    
    
}
