//
//  File.swift
//  
//
//  Created by Tom Johnson on 02/12/2022.
//

import Foundation
import CoreBluetooth

class Accesspoint {
    
    var rssi: Int?
    var timeTolive: Int?
    var mac: [UInt8] = Array(repeating: 0x00, count: 6)
    var macString = ""
    var connectionTarget: Bool?
    
    var jobNo: Int?
    var spxAddr: Int?
    var busAddr: Int?
    var deviceType: Int?
    
    var apScanResult: CBPeripheral?
}

class ReportedAccesspoint {
    
    var rssi: Int = 0
    var macString = ""
    var index = 0
    var jobNo: Int?
    var spxAddr: Int?
    var busAddr: Int?
    var deviceType: Int?
}
