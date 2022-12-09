//
//  File.swift
//  
//
//  Created by Tom Johnson on 09/12/2022.
//

import Foundation

public class Permission {
    
    public var valid: Bool
    public var qrRawString: String
    
    var info: String
    var dateCreated: String?
    var jobNumber: String?
    public var jobNumberAsInt: String?
    
    var authKeyIncluded: Bool
    var authKeyType: Int?
    var authKey: [UInt8]
    
    var nodeGlobBool: Int?
    var areaGlobBool: Int?
    
    var nodeKey0: [UInt8]?
    var nodeKey1: [UInt8]?
    var nodeKey2: [UInt8]?
    var nodeKey3: [UInt8]?
    
    var accessKey: Int?
    public var permissionNumber: String?
    var optBoolAxN: Int?
    var roleTitle: String?
    
    var areaName0: String?
    var areaName1: String?
    var areaName2: String?
    var areaName3: String?
    
    var permissionType: String?
    var dayBoolx7: String?
    var momentA: String?
    var momentB: String?
    
    var isGenuine: Bool
    
    init() {
        
        self.valid = false
        self.qrRawString = ""
        self.info = "info"
        
        self.authKeyIncluded = false
        self.authKey = []
        
        self.isGenuine = false
    }
    
}
