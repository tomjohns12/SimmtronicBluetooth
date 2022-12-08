//
//  File.swift
//
//
//  Created by Tom Johnson on 01/12/2022.
//


import Foundation
import CoreBluetooth
import CommonCrypto
import CryptoKit


public class SimtronicBluetooth: NSObject {
    
    
    // MARK: - Variables
    
    public typealias Device = CBPeripheral
    
    public let delegate: DeviceDelegate
    private let serviceIDs: [CBUUID]
    private let characteristicIDs: [CBUUID]
    private let queue = DispatchQueue(label: "uk.co.appoly.BluetoothDevice.CBCentralManager", qos: .background)
    
    public var isScanning: Bool { return manager.isScanning }
    private var devices: [Device] = []
    public var connectedDevice: Device?
    private lazy var manager = CBCentralManager(delegate: self, queue: queue)
    
    
    
    private var dataController: DataController
    var accesspoints: [Accesspoint] = []
    
    var getMessage: GetMessage = .queryDeviceInfo
    var state: State = .awaitingInfoReply
    
    var keyNoToTry: Int = 0
    var authChallengeMessage: [UInt8] = []
    var deviceFirmwareBuildNumber: UInt8 = 0x00
    
    var expectedMiscDataStoreIntegrityNumber: UInt8?
    var expectedMiscDataStoreBlockNo: Int = 0
    var miscDataStoreString = ""
    
    var expectedAreaNameIntegrityNumber: UInt8?
    var expectedAreaNameBlockNo: Int = 0
    var areaNameString = ""
    
    var expectedAccessKeyIntegrityNumber: UInt8?
    var expectedAccessKeysBlockNo: Int = 0
    var accessKeysString = ""
    
    var expectedAccessMapIntegrityNumber: UInt8?
    var expectedAccessMapBlockNo: Int = 0
    var accessMapString = ""
    
    var accessPoint: APdata?
    
    
    // MARK: - Initialiser
    
    public init(delegate: DeviceDelegate, serviceID: [CBUUID], characteristicID: [CBUUID]) {
        self.delegate = delegate
        self.serviceIDs = serviceID
        self.characteristicIDs = characteristicID
        self.dataController = DataController()
        super.init()
        self.manager.retrieveConnectedPeripherals(withServices: serviceIDs)
    }
    
    // MARK: - Utilities
    
    public func scan() {
        manager.scanForPeripherals(withServices: serviceIDs, options: nil)
    }
    
    public func cancelScan() {
        guard manager.isScanning else { return }
        manager.stopScan()
    }
    
    public func connect(to device: Device) {
        manager.connect(device, options: nil)
        connectedDevice = nil
    }
    
    public func disconnect() {
        guard connectedDevice != nil else {
            return
        }
        manager.cancelPeripheralConnection(connectedDevice!)
    }
    
    func service(withUUID uuid: CBUUID) -> CBService? {
        
        guard let peripharel = connectedDevice else {
            return nil
        }
        
        guard let services = peripharel.services else {
            return nil
        }
        
        for service in services {
            if service.uuid == uuid {
                return service
            }
        }
        
        return nil
    }
    
    func characteristic(forService service: CBService, withCharacteristicUUID uuid: CBUUID) -> CBCharacteristic? {
        guard let characteristics = service.characteristics,
            characteristics.count > 0 else {
                return nil
        }
        
        for characteristic in characteristics {
            if characteristic.uuid == uuid {
                return characteristic
            }
        }
       
        return nil
    }
    
    
    
    // MARK: - Functions
    
    func connected(_ peripheral: CBPeripheral) {
        
        state = .connected
        
        
        
        accessPoint = APdata(id: peripheral.identifier)
        
        state = .awaitingInfoReply
        getMessage = .queryDeviceInfo
        sendGetMessage()
        
    }
    
    public func writeToNode(index: Int, configRotate: Int, cmd: Int) {
        
//        var bytes: [UInt8] = [0x0a,0x00,0x00]
        var bytes: [UInt8] = Array(repeating: 0x00, count: 20)
//         should be an array of nil??
        
        bytes[0] = 0x04
        bytes[1] = 0x00
        bytes[2] = 0x01

        bytes[3] = UInt8((index >> 8) & 0xff)
        bytes[4] = UInt8(index & 0xff)

        bytes[5] = UInt8(configRotate)

        bytes[6] = UInt8((cmd >> 8) & 0xff)
        bytes[7] = UInt8(cmd & 0xff)
        
        writeToCharacteristic(data: Data(bytes))
    }
    
    func writeToCharacteristic(data: Data) {
        
        guard let service = service(withUUID: SimtronicBluetooth.serviceUUID), let characterisitc = characteristic(forService: service, withCharacteristicUUID: SimtronicBluetooth.outBoundCharacteristic.uuid) else {
            return
        }
        
        guard let peripheral = connectedDevice else {
            return
        }
        
        peripheral.writeValue(data, for: characterisitc, type: .withResponse)
    }
    
    func readFromNode(data: Data) {
        
        let bytes: [UInt8] = [UInt8](data)
        
        print(bytes)
        
//        dataController.readDeviceInfo(bytes: bytes)
        
        
        switch state {
        case .connected:
            break
        case .awaitingInfoReply:
            readInfoReply(bytes: bytes)
        case .awaitingCompatReply:
            readCompatReply(bytes: bytes)
        case .awaitingAuthChallenge:
            readAuthChallenge(bytes: bytes)
        case .awaitingAuthResult:
            readAuthResult(bytes: bytes)
        case .awaitingSpxSystemTime:
            readSPXSystemTime(bytes: bytes)
        case .awaitingIdentifyAck:
            break
        case .awaitingMiscDataStartIntegReply:
            readMiscDataStartIntegReply(bytes: bytes)
        case .awaitingMiscDataBlock:
            readMiscDataBlockReply(bytes: bytes)
        case .awaitingMiscDataEndIntegReply:
            readMiscDataEndIntegReply(bytes: bytes)
        case .awaitingAreaNameStartIntegReply:
            readAreaNameStartIntegReply(bytes: bytes)
        case .awaitingAreaNameBlock:
            readAreaNameBlockReply(bytes: bytes)
        case .awaitingAreaNameEndIntegReply:
            readAreaNameEndIntegReply(bytes: bytes)
        case .awaitingKeysStartIntegReply:
            readKeysStartIntegReply(bytes: bytes)
        case .awaitingAccesKeysBlock:
            readAccessKeysBlockReply(bytes: bytes)
        case .awaitingKeysEndIntegReply:
            readKeysEndIntegReply(bytes: bytes)
        case .awaitingMapStartIntegReply:
            readMapsStartIntegReply(bytes: bytes)
        case .awaitingAccessMapBlock:
            readAccessMapsBlockReply(bytes: bytes)
        case .awaitingMapEndIntegReply:
            readMapsEndIntegReply(bytes: bytes)
        }
        
    }
    
    func readInfoReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x0a {
            
            let deviceType = bytes[1]
            print(deviceType)
            
            accessPoint?.deviceType = Int(deviceType)
            
            if deviceType == 0x01 {
                
                deviceFirmwareBuildNumber = bytes[2] << 24
                deviceFirmwareBuildNumber += bytes[3] << 16
                deviceFirmwareBuildNumber += bytes[4] << 8
                deviceFirmwareBuildNumber += bytes[5]
                
                accessPoint?.firmware = Int(deviceFirmwareBuildNumber)
                print(deviceFirmwareBuildNumber)
                
                if deviceFirmwareBuildNumber < 19 {
                    
                } else {
                    state = .awaitingCompatReply
                    getMessage = .compatibilityCode17Plus
                    sendGetMessage()
                }
                
            } else {
                // disconnect
            }
            
        }
        
    }
    
    func readCompatReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x63 {
            
            if (bytes[1] & 0x01) == 0x00 {
                // disconnect
            } else {
                
                accessPoint?.compatible = true
                
                // Keys.getInstance().keyCount() > 0
                if true {
                    
                    keyNoToTry = 0
                    state = .awaitingAuthChallenge
                    getMessage = .authRequestChallenge
                    sendGetMessage()
                    
                } else {
                    // disconnect
                }
                
            }
        }
    }
    
    func readAuthChallenge(bytes: [UInt8]) {
        
        if bytes[0] == 0x65 {
            if bytes[1] == 0x02 {
                
                authChallengeMessage = bytes
                state = .awaitingAuthResult
                getMessage = .authSolvedChallenge(ba: bytes, keyNumToTry: keyNoToTry)
                sendGetMessage()
                
            }
        }
    }
    
    func readAuthResult(bytes: [UInt8]) {
        
        if bytes[0] == 0x65 {
            
            if bytes[1] == 0x00 {
                
                keyNoToTry += 1
                
                // Keys.getInstance().keyCount()
                if keyNoToTry < 2 {
                    getMessage = .authSolvedChallenge(ba: authChallengeMessage, keyNumToTry: keyNoToTry)
                    sendGetMessage()
                } else {
                    // disconnect
                }
                
            } else if bytes[1] == 0x01 {
                
                print("Authenticated!!")
                
                if (bytes[1] & 0x02) == 0x02 {
//                    KeyRolloverLog.log(deviceJobNum, Utils.byteArrayToHexString(latestKeyUsedForAuth) )
                } else {
//                    KeyRolloverLog.unlog(deviceJobNum, Utils.byteArrayToHexString(latestKeyUsedForAuth) )
                }
                
                accessPoint?.accessible = true
                
                // connectingForUser
                if false {
                    state = .awaitingSpxSystemTime
                    getMessage = .spxSystemTime
                    sendGetMessage()
                } else {
                    
                    state = .awaitingMiscDataStartIntegReply
                    getMessage = .miscDataStoreIntegrityNoAtStart
                    sendGetMessage()
//                    nodesStatusCountAccessible++;
//                    buildDeviceInfoString();
//                    info_text_accessible_nodes += deviceInfo;
//                    info_text_accessible_nodes += "\n";
                }
            }
        }
    }
    
    func readSPXSystemTime(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x0a {
//                refreshControlDetails();
//                completedIniti0alTimeCheck = true;
                state = .awaitingMiscDataStartIntegReply
                getMessage = .miscDataStoreIntegrityNoAtStart
                sendGetMessage()
            }
            
        }
        
    }
    
    
    // MARK: Misc Data
    
    func readMiscDataStartIntegReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x08 {
                
                var integrityNumber = bytes[3]
                integrityNumber = integrityNumber & 0xff
                let echoedByte = bytes[2]
                
                if integrityNumber == 0xff {
                    // diconnect
                    print("disconnect data start")
                } else if echoedByte == 0x01 {
                    expectedMiscDataStoreIntegrityNumber = integrityNumber
                    expectedMiscDataStoreBlockNo = 0
                    miscDataStoreString = ""
                    state = .awaitingMiscDataBlock
                    getMessage = .miscDataStoreBlock(echoedByte: (expectedMiscDataStoreBlockNo & 0xff), blockNo: expectedMiscDataStoreBlockNo)
                    sendGetMessage()
                }
                
            }
        }
    }
    
    func readMiscDataBlockReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x09 {
                
                let echoedByte = bytes[2]
                let blockLength = bytes[3]
                
                if echoedByte == UInt8(expectedMiscDataStoreBlockNo & 0xff) {
                    
                    for i in 0..<blockLength {
                        miscDataStoreString += [Character(UnicodeScalar(bytes[4 + Int(i)]))]
                        print(miscDataStoreString)
                    }
                    
                    if blockLength < 16 {
                        state = .awaitingMiscDataEndIntegReply
                        getMessage = .miscDataStoreIntegrityNoAtEnd
                        sendGetMessage()
                    } else {
                        expectedMiscDataStoreBlockNo += 1
                        getMessage = .miscDataStoreBlock(echoedByte: (expectedMiscDataStoreBlockNo & 0xff), blockNo: expectedMiscDataStoreBlockNo)
                        sendGetMessage()
                    }
                }
            }
        }
    }
    
    func readMiscDataEndIntegReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x09 {
                
                var integrityNumber = bytes[3]
                integrityNumber = (integrityNumber & 0xff)
                
                let echoedByte = bytes[2]
                
                if integrityNumber == 0xff {
                    // disconnect
                    print("disconnect data end")
                } else if echoedByte == 0x02 {
                    if integrityNumber == expectedMiscDataStoreIntegrityNumber {
                        print("MiscData transfer Complete")
                        accessPoint?.miscData = miscDataStoreString
                        state = .awaitingAreaNameStartIntegReply
                        getMessage = .areaNameIntegrityNoAtStart
                        sendGetMessage()
                    } else {
                        state = .awaitingMiscDataStartIntegReply
                        getMessage = .miscDataStoreIntegrityNoAtStart
                        sendGetMessage()
                    }
                }
            }
        }
    }
    
    
    // MARK: Area Name
    
    func readAreaNameStartIntegReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x04 {
                
                var integrityNumber = bytes[3]
                let echoedByte = bytes[2]
                
                if integrityNumber == 0xff {
                    getMessage = .areaNameIntegrityNoAtStart
                    sendGetMessage()
                } else if echoedByte == 0x01 {
                    expectedAreaNameIntegrityNumber = integrityNumber
                    expectedAreaNameBlockNo = 0
                    areaNameString = ""
                    state = .awaitingAreaNameBlock
                    getMessage = .areaNameBlock(echoedByte: (expectedAreaNameBlockNo & 0xff), byteOffset: expectedAreaNameBlockNo)
                    sendGetMessage()
                }
            }
        }
    }
    
    func readAreaNameBlockReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x05 {
                
                let echoedByte = bytes[2]
                let blockLength = bytes[3]
                
                if echoedByte == UInt8(expectedAreaNameBlockNo & 0xff) {
                    
                    for i in 0..<blockLength {
                        areaNameString += [Character(UnicodeScalar(bytes[4 + Int(i)]))]
                    }
                    
                    if blockLength < 16 {
                        state = .awaitingAreaNameEndIntegReply
                        getMessage = .areaNameIntegrityNoAtEnd
                        sendGetMessage()
                    } else {
                        expectedMiscDataStoreBlockNo += 16
                        getMessage = .areaNameBlock(echoedByte: (expectedAreaNameBlockNo & 0xff), byteOffset: expectedAreaNameBlockNo)
                        sendGetMessage()
                    }
                }
            }
        }
    }
    
    func readAreaNameEndIntegReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x04 {
                
                var integrityNumber = bytes[3]
                let echoedByte = bytes[2]
                
                if integrityNumber == 0xff {
                    state = .awaitingAreaNameStartIntegReply
                    getMessage = .areaNameIntegrityNoAtStart
                } else if echoedByte == 0x02 {
                    if integrityNumber == expectedAreaNameIntegrityNumber {
                        print("Area Name transfer Complete: \(areaNameString)")
                        accessPoint?.areaName = areaNameString
                        if deviceFirmwareBuildNumber < 16 {
                            state = .awaitingAreaNameStartIntegReply
                            getMessage = .accessMapIntegrityNoAtStart
                        } else {
                            state = .awaitingAreaNameStartIntegReply
                            getMessage = .accessKeysIntegrityNoAtStart
                        }
                    } else {
                        state = .awaitingAreaNameStartIntegReply
                        getMessage = .areaNameIntegrityNoAtStart
                    }
                }
                
                sendGetMessage()
            }
        }
    }
    
    
    // MARK: Keys
    
    func readKeysStartIntegReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x06 {
                
                var integrityNumber = bytes[3]
                integrityNumber = integrityNumber & 0xff
                let echoedByte = bytes[2]
                
                if integrityNumber == 0xff {
                    // disconnect
                } else if echoedByte == 0x01 {
                    expectedAccessKeyIntegrityNumber = integrityNumber
                    expectedAccessKeysBlockNo = 0
                    accessKeysString = ""
                    state = .awaitingAccesKeysBlock
                    getMessage = .accessKeysBlock(echoedByte: (expectedAccessKeysBlockNo & 0xff), blockNo: expectedAccessKeysBlockNo)
                    sendGetMessage()
                }
            }
        }
    }
    
    func readAccessKeysBlockReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x07 {
                
                let echoedByte = bytes[2]
                let blockLength = bytes[3]
                
                if echoedByte == UInt8(expectedAccessKeysBlockNo & 0xff) {
                    
                    for i in 0..<blockLength {
                        accessKeysString += [Character(UnicodeScalar(bytes[4 + Int(i)]))]
                    }
                    
                    if blockLength < 16 {
                        state = .awaitingKeysEndIntegReply
                        getMessage = .accessKeysIntegrityNoAtEnd
                    } else {
                        expectedMiscDataStoreBlockNo += 1
                        getMessage = .accessKeysBlock(echoedByte: (expectedAccessKeysBlockNo & 0xff), blockNo: expectedAccessKeysBlockNo)
                    }
                    
                    sendGetMessage()
                }
            }
        }
    }
    
    func readKeysEndIntegReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x06 {
                
                var integrityNumber = bytes[3]
                integrityNumber = integrityNumber & 0xff
                let echoedByte = bytes[2]
                
                if integrityNumber == 0xff {
                    // disconnect
                } else if echoedByte == 0x02 {
                    
                    if integrityNumber == expectedAccessKeyIntegrityNumber {
                        
                        print("AccessKeys transfer Complete")
                        accessPoint?.accessKeys = accessKeysString
                        
                        if deviceFirmwareBuildNumber < 16 {
                            state = .awaitingMapStartIntegReply
                            getMessage = .accessMapIntegrityNoAtStart
                        } else {
                            state = .awaitingKeysStartIntegReply
                            getMessage = .accessKeysIntegrityNoAtStart
                        }
                        
                    } else {
                        state = .awaitingAreaNameStartIntegReply
                        getMessage = .areaNameIntegrityNoAtStart
                    }
                }
                
                sendGetMessage()
            }
        }
    }
    
    
    // MARK: Maps
    
    func readMapsStartIntegReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x02 {
                
                var integrityNumber = bytes[3]
                integrityNumber = integrityNumber & 0xff
                let echoedByte = bytes[2]
                
                if integrityNumber == 0xff {
                    // disconnect
                } else if echoedByte == 0x01 {
                    expectedAccessMapIntegrityNumber = integrityNumber
                    expectedAccessMapBlockNo = 0
                    accessMapString = ""
                    state = .awaitingAccessMapBlock
                    getMessage = .accessMapBlock(echoedByte: (expectedAccessMapBlockNo & 0xff), blockNo: expectedAccessMapBlockNo)
                    sendGetMessage()
                }
            }
        }
    }
    
    func readAccessMapsBlockReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x03 {
                
                let echoedByte = bytes[2]
                let blockLength = bytes[3]
                
                if echoedByte == UInt8(expectedAreaNameBlockNo & 0xff) {
                    
                    for i in 0..<blockLength {
                        accessMapString += [Character(UnicodeScalar(bytes[4 + Int(i)]))]
                    }
                    
                    if blockLength < 16 {
                        state = .awaitingMapEndIntegReply
                        getMessage = .accessMapIntegrityNoAtEnd
                    } else {
                        expectedMiscDataStoreBlockNo += 1
                        getMessage = .accessMapBlock(echoedByte: (expectedAccessMapBlockNo & 0xff), blockNo: expectedAccessMapBlockNo)
                    }
                    
                    sendGetMessage()
                }
            }
        }
    }
    
    func readMapsEndIntegReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x02 {
                
                var integrityNumber = bytes[3]
                integrityNumber = integrityNumber & 0xff
                let echoedByte = bytes[2]
                
                if integrityNumber == 0xff {
                    // disconnect
                } else if echoedByte == 0x02 {
                    
                    if integrityNumber == expectedAccessMapIntegrityNumber {
                        
                        print("Access Map transfer complete")
                        accessPoint?.accessMap = accessMapString
//                        accessPoint.writetoCache
//                        nodeCacheTriggerNumberOnPrevCache = nodeCacheTriggerNumber
                        
                        // connectingforuser
                        if false {
                            
//                            Lighting.voidAllData()
//                            final SimmBLE2.reportedAccessPoint[] aps
//                            aps = SimmBLE2.getInstance().reportAccessPoints();
//                            for( int apNum=0; apNum < aps.length; apNum++ ){
//                                if( aps[apNum].rssi > MIN_CONNECTABLE_RSSI ) {
//                                    Lighting.processRetrievedNodeData( apNum, aps[apNum].macString );
//                                }
//                            }
//
//                            state = STATE_CONNECTED_AND_WAITING;
//                            statusToReport = REPORTED_STATUS_CONNECTED;
//
//                            availableControlGroupArraysNeedRefreshing = true;
                            
                        } else {
                            disconnect()
                        }
                        
                        if deviceFirmwareBuildNumber < 16 {
                            state = .awaitingAreaNameStartIntegReply
                            getMessage = .accessMapIntegrityNoAtStart
                        } else {
                            state = .awaitingAreaNameStartIntegReply
                            getMessage = .accessKeysIntegrityNoAtStart
                        }
                        
                    } else {
                        state = .awaitingAreaNameStartIntegReply
                        getMessage = .areaNameIntegrityNoAtStart
                        sendGetMessage()
                    }
                }
                
            }
        }
    }
    
    
    
    
    func sendLightCommand(command: NodeCommand) {
        
        let index = 0x00
        let config = 0x00
        
        writeToNode(index: index, configRotate: config, cmd: command.rawValue)
    }
    
    public func sendGetMessage() {
        
        let data = Data(getMessage.pkt)
        
        writeToCharacteristic(data: data)
    }
    
    
}



public protocol DeviceDelegate {
    func didDetect(devices: [SimtronicBluetooth.Device])
    func failedToConnect(to device: SimtronicBluetooth.Device)
    func connected(to device: SimtronicBluetooth.Device)
    func availabilityUpdated(available: Bool)
    func disconnected(from device: SimtronicBluetooth.Device)
    func bluetoothDeviceUpdatedValues(_ bluetooth: SimtronicBluetooth)
}

extension SimtronicBluetooth {
    struct Characteristic {
        let uuid: CBUUID
        let descriptorUUID: CBUUID?
    }
}

extension SimtronicBluetooth: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        
        print("peripheral \(peripheral.description), \(peripheral.identifier)")
        
        for service in services {
            peripheral.discoverCharacteristics(characteristicIDs, for: service)
            print("service \(service.description)")
        }
    }
    
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            print("\(characteristic.description)")
            peripheral.setNotifyValue(true, for: characteristic)
            peripheral.discoverDescriptors(for: characteristic)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        
        guard let descriptors = characteristic.descriptors else {
            return
        }
        
        for descriptor in descriptors {
            print(descriptor)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
//        print("updated charac")
        
        guard let data = characteristic.value else {
            return
        }
        
        readFromNode(data: data)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
    
        print("updated descr")
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
//        print("didWrite")
    }
    
}

extension SimtronicBluetooth: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { [weak self] in
            switch central.state {
                case .poweredOff:
                    self?.delegate.availabilityUpdated(available: false)
                    self?.cancelScan()
                case .poweredOn:
                    self?.delegate.availabilityUpdated(available: true)
                    self?.scan()
                default:
                    return
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        DispatchQueue.main.async { [weak self] in
            
            guard self?.devices.first(where: { $0.identifier == peripheral.identifier }) == nil else {
                return
            }
            
            guard let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else {
                return
            }
            
            let manufactureID = UInt16(data[0]) + UInt16(data[1]) << 8
            
            let manufactureName = String(format: "%04X", manufactureID)
            
            guard manufactureName == "06C6" else {
                return
            }
            
            self?.devices.append(peripheral)
            self?.delegate.didDetect(devices: self?.devices ?? [])
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate.failedToConnect(to: peripheral)
            self?.connectedDevice = nil
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            peripheral.delegate = self
            self.delegate.connected(to: peripheral)
            self.connectedDevice = peripheral
            peripheral.discoverServices(self.serviceIDs)
            
            self.connected(peripheral)
        }

    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            peripheral.delegate = self
            self.delegate.disconnected(from: peripheral)
            self.connectedDevice = nil
        }
    }
}


extension SimtronicBluetooth {

    static let maxAccessPoints = 10
    
    enum msgBLECode: Int {
        case advPkt = 1
        case connected = 2
        case disconnected = 3
        case gattFail = 4
        case servicesDiscovered = 5
        case descriptorWrite = 6
        case charactesticChanged = 7
    }
    
    enum msgUserCode: Int {
        case requestConnect = 100
        case writeRequest = 101
        case requestScan = 102
        case requestDisconnect = 103
        case requestResumeScan = 104
        case requestStopScan = 105
    }
    
    enum myStateCode: Int {
        case begin = 0
        case scanning = 1
        case error = 2
        case connectingAwaitingServer = 4
        case discoveringServices = 5
        case settingNotification = 6
        case connected = 7
    }
    
}

extension SimtronicBluetooth {
    
    static let serviceUUID = CBUUID(string: "3f298ab4-20e3-91c6-8dd8-2903cc2fa70b")
    static let inBoundCharacteristic = Characteristic(uuid: CBUUID(string: "0fc84852-5785-4c94-ef7b-f6a055d94531"), descriptorUUID: nil)
    static let outBoundCharacteristic = Characteristic(uuid: CBUUID(string: "424f00a7-c936-0250-32be-9d7ee4161a14"), descriptorUUID: nil)
}

extension Data {
    var stringEncoding: String.Encoding? {
        var nsString: NSString?
        guard case let rawValue = NSString.stringEncoding(for: self, encodingOptions: nil, convertedString: &nsString, usedLossyConversion: nil), rawValue != 0 else { return nil }
        return .init(rawValue: rawValue)
    }
}

enum State {
    
    case connected
    
    case awaitingInfoReply
    case awaitingCompatReply
    case awaitingAuthChallenge
    case awaitingAuthResult
    
    case awaitingSpxSystemTime
    case awaitingIdentifyAck
    
    case awaitingMiscDataStartIntegReply
    case awaitingMiscDataBlock
    case awaitingMiscDataEndIntegReply
    
    case awaitingAreaNameStartIntegReply
    case awaitingAreaNameBlock
    case awaitingAreaNameEndIntegReply
    
    case awaitingKeysStartIntegReply
    case awaitingAccesKeysBlock
    case awaitingKeysEndIntegReply
    
    case awaitingMapStartIntegReply
    case awaitingAccessMapBlock
    case awaitingMapEndIntegReply
}

enum GetMessage {
    
    case queryDeviceInfo
    case compatibilityCode17Plus
    case authRequestChallenge
    case authSolvedChallenge(ba: [UInt8], keyNumToTry: Int)
    case identifyDevice
    
    case areaNameIntegrityNoAtStart
    case areaNameIntegrityNoAtEnd
    case areaNameBlock(echoedByte: Int, byteOffset: Int)
    
    case accessMapIntegrityNoAtStart
    case accessMapIntegrityNoAtEnd
    case accessMapBlock(echoedByte: Int, blockNo: Int)
    
    case accessKeysIntegrityNoAtStart
    case accessKeysIntegrityNoAtEnd
    case accessKeysBlock(echoedByte: Int, blockNo: Int)
    
    case miscDataStoreIntegrityNoAtStart
    case miscDataStoreIntegrityNoAtEnd
    case miscDataStoreBlock(echoedByte: Int, blockNo: Int)
    
    case spxSystemTime
    
    var pkt: [UInt8] {
        switch self {
        case .queryDeviceInfo:
            return [0x0a, 0x00, 0x00]
        case .compatibilityCode17Plus:
            return [0x63, 0x3a, 0xfd, 0x09, 0x3d, 0x67, 0x51, 0xc3, 0x46]
        case .authRequestChallenge:
            return [0x65, 0x02]
        case .authSolvedChallenge(let ba, let num):
            
//            byte [] keyPlusType = Keys.getInstance().key(keyNumToTry);
//            byte[] key = Arrays.copyOfRange(keyPlusType, 1, 17);
//            latestKeyUsedForAuth = key;
//            byte keyType = keyPlusType[0];
            
            let aes = AESEncoder()
            let key = aes.getHashedPassword(password: "Simmtronic")
            
            let challenge = Array(ba[3...19])
            let tester: [UInt8] = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]
            let result = aes.solveChallenge(challenge: challenge, key: key)
            let byteCipherText = Array(result[0...16])
            
            var array: [UInt8] = Array(repeating: 0x00, count: 19)
            array[0] = 0x65
            array[1] = 0x03
            array[2] = 0x00
            for i in 0..<16 {
                array[i + 3] = byteCipherText[i]
            }
            
            print("challenge: \(challenge)")
            print("answer: \(array)")
            return array
            
        case .identifyDevice:
            return [0x64, 0x00, 0x01, 0x02]
        case .areaNameIntegrityNoAtStart:
            return [0x03, 0x04, 0x01]
        case .areaNameIntegrityNoAtEnd:
            return [0x03, 0x04, 0x02]
        case .areaNameBlock(let echoed, let offset):
            return [0x03, 0x05, UInt8(echoed), UInt8(offset >> 8), UInt8(offset & 0xff)]
        case .accessMapIntegrityNoAtStart:
            return [0x03, 0x02, 0x01]
        case .accessMapIntegrityNoAtEnd:
            return [0x03, 0x02, 0x02]
        case .accessMapBlock(let echoed, let no):
            return [0x03, 0x03, UInt8(echoed), UInt8(no >> 8), UInt8(no & 0xff)]
        case .accessKeysIntegrityNoAtStart:
            return [0x03, 0x06, 0x01]
        case .accessKeysIntegrityNoAtEnd:
            return [0x03, 0x06, 0x02]
        case .accessKeysBlock(let echoed, let no):
            return [0x03, 0x07, UInt8(echoed), UInt8(no >> 8), UInt8(no & 0xff)]
        case .miscDataStoreIntegrityNoAtStart:
            return [0x03, 0x08, 0x01]
        case .miscDataStoreIntegrityNoAtEnd:
            return [0x03, 0x08, 0x02]
        case .miscDataStoreBlock(let echoed, let no):
            return [0x03, 0x09, UInt8(echoed), UInt8(no >> 8), UInt8(no & 0xff)]
        case .spxSystemTime:
            return [0x03, 0x0a, 0x01]
        }
    }
    
}


