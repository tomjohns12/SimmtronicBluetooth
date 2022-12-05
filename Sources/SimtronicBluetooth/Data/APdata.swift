//
//  File.swift
//  
//
//  Created by Tom Johnson on 02/12/2022.
//

import Foundation

class APdata {
    
    var id: UUID
    var deviceType: Int
    var firmware: Int
    
    var configId: Int
    
    var compatible: Bool
    var accessible: Bool
    
    var areaName: String
    var miscData: String
    var accessMap: String
    var accessKeys: String
    
    init(id: UUID) {
        self.id = id
        self.deviceType = 0
        self.firmware = 0
        
        self.configId = 0
        
        self.compatible = false
        self.accessible = false
        
        self.areaName = ""
        self.miscData = ""
        self.accessMap = ""
        self.accessKeys = ""
    }
}
