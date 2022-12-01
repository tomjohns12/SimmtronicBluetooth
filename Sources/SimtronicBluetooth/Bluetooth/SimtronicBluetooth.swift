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
    
    
    // MARK: - Initialiser
    
    public init(delegate: DeviceDelegate, serviceID: [CBUUID], characteristicID: [CBUUID]) {
        self.delegate = delegate
        self.serviceIDs = serviceID
        self.characteristicIDs = characteristicID
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
        
        for service in services {
            peripheral.discoverCharacteristics(characteristicIDs, for: service)
        }
    }
    
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
    }
    
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard let descriptors = characteristic.descriptors else {
            return
        }
        
        for descriptor in descriptors {
            peripheral.readValue(for: descriptor)
        }
    }
    
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        
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
            guard self?.devices.first(where: { $0.identifier == peripheral.identifier }) == nil else { return }
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
    static let inBoundCharacteristic = Characteristic(uuid: CBUUID(string: "424f00a7-c936-0250-32be-9d7ee4161a14"), descriptorUUID: nil)
    static let outBoundCharacteristic = Characteristic(uuid: CBUUID(string: "0fc84852-5785-4c94-ef7b-f6a055d94531"), descriptorUUID: nil)
}

