//
//  BLEManager.swift
//  MiniComputer
//
//  Created by Niklas Mischke on 28.12.21.
//

import Foundation
import CoreBluetooth

protocol BluetoothSerialDelegate {
	func serialDidReceiveString(_ message: String)
	func serialDidReceiveBytes(_ message: [UInt8])
	func serialDidReceiveData(_message: Data)
	func serialDidConnect()
	func serialDidFailToConnect()
}

extension BluetoothSerialDelegate {
	func serialDidReceiveString(_ message: String) {}
	func serialDidReceiveBytes(_ message: [UInt8]) {}
	func serialDidReceiveData(_message: Data) {}
	func serialDidConnect() {}
	func serialDidFailToConnect() {}
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
	var delegate: BluetoothSerialDelegate?
	var myCentral: CBCentralManager!
	public var isConnected: Bool {
		get {
			return connectedDevice != nil
		}
	}
	
	@Published var isSwitchedOn = false
	@Published var peripherals = [CBPeripheral]()
	@Published var connectedDevice: CBPeripheral?
	
	private var writeCharacteristics: CBCharacteristic?
	private var writeType: CBCharacteristicWriteType = .withoutResponse
	private var reconnect: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "BLEManagerReconnectBool")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "BLEManagerReconnectBool")
		}
	}
	private var reconnectID: UUID {
		get {
			return UserDefaults.standard.object(forKey: "BLEManagerReconnectUUID") as? UUID ?? UUID()
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "BLEManagerReconnectUUID")
		}
	}
	private var isReady: Bool {
		get {
			return 	myCentral.state == .poweredOn &&
			connectedDevice != nil &&
			writeCharacteristics != nil
		}
	}
	
	override init() {
		super.init()
		
		self.reconnect = reconnect
		
		myCentral = CBCentralManager(delegate: self, queue: nil)
		myCentral.delegate = self
	}
	
	func enableReconnect() {
		reconnect = true
	}
	
	func disableReconnect() {
		reconnect = false
	}
	
	func startScanning() {
		myCentral.scanForPeripherals(withServices: nil, options: nil)
	}
	
	func stopScanning() {
		myCentral.stopScan()
	}
	
	func connect(peripheral: CBPeripheral) {
		myCentral.connect(peripheral, options: nil)
	}
	
	func disconnect() {
		if (connectedDevice != nil) {
			myCentral.cancelPeripheralConnection(connectedDevice!)
		}
	}
	
	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		if central.state == .poweredOn {
			isSwitchedOn = true
			startScanning()
		} else {
			isSwitchedOn = false
		}
	}
	
	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
		if (peripheral.name == nil) {
			return
		}
		
		for peripheral_old in peripherals {
			if(peripheral_old.identifier == peripheral.identifier) {
				return
			}
		}
		
		peripherals.append(peripheral)
		
		if reconnect && connectedDevice == nil && peripheral.identifier == reconnectID {
			connect(peripheral: peripheral)
		}
	}
	
	func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
		delegate?.serialDidFailToConnect()
	}
	
	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		stopScanning()
		connectedDevice = peripheral
		reconnectID = peripheral.identifier
		peripheral.delegate = self
		discoverServices(peripheral: peripheral)
		delegate?.serialDidConnect()
	}
	
	func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
		connectedDevice = nil
	}
	
	func discoverServices(peripheral: CBPeripheral) {
		peripheral.discoverServices([CBUUID(string: "FFE0")])
	}
	
	func discoverCharacteristics(peripheral: CBPeripheral) {
		guard let services = peripheral.services else {
			return
		}
		for service in services {
			peripheral.discoverCharacteristics(nil, for: service)
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		guard peripheral.services != nil else {
			return
		}
		discoverCharacteristics(peripheral: peripheral)
	}
	
	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
		for characteristic in service.characteristics! {
			if characteristic.uuid == CBUUID(string: "FFE1") {
				peripheral.setNotifyValue(true, for: characteristic)
				
				writeCharacteristics = characteristic
				
				writeType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
			}
		}
	}
	
	func readValue(characteristic: CBCharacteristic) {
		self.connectedDevice?.readValue(for: characteristic)
	}
	
	func sendMessageToDevice(_ message: String) {
		guard isReady else { return }
		if let data = message.data(using: String.Encoding.utf8) {
			connectedDevice!.writeValue(data, for: writeCharacteristics!, type: writeType)
		}
	}
	
	func sendBytesToDevice(_ bytes: [UInt8]) {
		guard isReady else { return }
		let data = Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
		connectedDevice!.writeValue(data, for: writeCharacteristics!, type: writeType)
	}
	
	func sendDataToDevice(_ data: Data) {
		guard isReady else { return }
		connectedDevice!.writeValue(data, for: writeCharacteristics!, type: writeType)
	}
	
	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
		if error != nil {
			return
		}
		
		guard let value = characteristic.value else { return }
		
		delegate?.serialDidReceiveData(_message: value)
		
		if let string = String(bytes: value, encoding: .utf8) {
			delegate?.serialDidReceiveString(string)
		} else {
		}
		
		var bytes = [UInt8](repeating: 0, count: value.count / MemoryLayout<UInt8>.size)
		(value as NSData).getBytes(&bytes, length: value.count)
		delegate?.serialDidReceiveBytes(bytes)
	}
}
