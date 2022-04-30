# Swift-BLE-HM10

## USAGE

1. Add file to your Project
2. Add Bluetooth property to your PList
3. Add BluetoothSerialDelegate property to your view
    ```swift
    struct ContentView: View, BluetoothSerialDelegate {
    ```
3. Create new BLEManager() Object
4. Impliment neeeded functions (in View)
    * They will automaticly get called
    ```swift
    func serialDidReceiveString(_ message: String) {}
    func serialDidReceiveBytes(_ message: [UInt8]) {}
    func serialDidReceiveData(_message: Data) {}
    func serialDidConnect() {}
    func serialDidFailToConnect() {}
      ```
5. You can enable/disable auto reconnect with *xxx.enableReconnect() / xxx.disableReconnect()*
6. For Sending Data you can use (Called on manager Object e.g. *xxx.sendMessageToDevice()*)
    ```swift
    func sendMessageToDevice(_ message: String) {}
    func sendBytesToDevice(_ bytes: [UInt8]) {}
    func sendDataToDevice(_ data: Data) {}
    ```
