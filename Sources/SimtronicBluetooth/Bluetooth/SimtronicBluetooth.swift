//
//  File.swift
//
//
//  Created by Tom Johnson on 01/12/2022.
//


import Foundation
import CoreBluetooth

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
        case .awaitingMiscDataStartIntegReply:
            readMiscDataStartIntegReply(bytes: bytes)
        case .awaitingMiscDataBlock:
            readMiscDataBlockReply(bytes: bytes)
        }
        
    }
    
    func readInfoReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x0a {
            
            let deviceType = bytes[1]
            print(deviceType)
            
            accessPoint?.deviceType = Int(deviceType)
            
            if deviceType == 0x01 {
                
                var deviceFirmwareBuildNumber = bytes[2] << 24
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
                if keyNoToTry < 10 {
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
                if true {
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
    
    func readMiscDataStartIntegReply(bytes: [UInt8]) {
        
        if bytes[0] == 0x03 {
            
            if bytes[1] == 0x08 {
                
                var integrityNumber = bytes[3]
                integrityNumber = integrityNumber & 0xff
                let echoedByte = bytes[2]
                
                if integrityNumber == 0xff {
                    // diconnect
                } else if echoedByte == 0x01 {
                    let expectedMiscDataStoreIntegrityNumber = integrityNumber;
                    let expectedMiscDataStoreBlockNo = 0;
//                    miscDataStoreString = "";
                    state = .awaitingMiscDataBlock
                    getMessage = .miscDataStoreBlock(echoedByte: (expectedMiscDataStoreBlockNo & 0xff), blockNo: expectedMiscDataStoreBlockNo)
                    sendGetMessage()
                }
                
                
            }
            
        }
        
    }
    
    func readMiscDataBlockReply(bytes: [UInt8]) {
        
        
        
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
        
        print("updated charac")
        
        guard let data = characteristic.value else {
            return
        }
        
        readFromNode(data: data)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
    
        print("updated descr")
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
        print("didWrite")
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
    
    case awaitingInfoReply
    case awaitingCompatReply
    case awaitingAuthChallenge
    case awaitingAuthResult
    
    case awaitingSpxSystemTime
    
    case awaitingMiscDataStartIntegReply
    case awaitingMiscDataBlock
    
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
            // TODO: Create function with 'keys'
            return []
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
