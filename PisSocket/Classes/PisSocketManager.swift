//
//  PisSocketManager.swift
//  PisSocket
//
//  Created by cyj on 11/12/24.
//

import Network
import Foundation

@available(iOS 12.0, *)
protocol PisSocketManagerDelegate: AnyObject {
    func socketManagerDidConnect(manager: PisSocketManager, host: String)
    func socketManagerDidDisconnect(manager: PisSocketManager, error: Error?)
    func socketManagerDidReceiveData(manager: PisSocketManager, data: Data)
}

@available(iOS 12.0, *)
class PisSocketManager: NSObject {
    weak var delegate: PisSocketManagerDelegate?
    
    private var connection: NWConnection?
    private var serverIP: String
    private var serverPort: UInt16
    private var connectionTimeout: TimeInterval
    private var heartbeatInterval: TimeInterval
    private var heartbeatData: Data?
    
    private var buffer = Data()                      // 用于拆包的缓冲区
    private let messageHeaderLength: Int             // 消息头长度
    private let lengthFieldRange: Range<Int>         // 消息长度字段的字节范围
    private var timer: DispatchSourceTimer?          // 用于心跳的定时器

    // MARK: - Initialization
    init(ip: String,
         port: UInt16,
         delegate: PisSocketManagerDelegate? = nil,
         connectionTimeout: TimeInterval = 15,
         heartbeatInterval: TimeInterval = 10,
         messageHeaderLength: Int = 12,
         lengthFieldRange: Range<Int> = 8..<12) {
        self.serverIP = ip
        self.serverPort = port
        self.delegate = delegate
        self.connectionTimeout = connectionTimeout
        self.heartbeatInterval = heartbeatInterval
        self.messageHeaderLength = messageHeaderLength
        self.lengthFieldRange = lengthFieldRange
        super.init()
    }

    // MARK: - Connection Methods
    func connect() {
        let params = NWParameters.tcp
        self.connection = NWConnection(host: NWEndpoint.Host(serverIP),
                                       port: NWEndpoint.Port(integerLiteral: serverPort),
                                       using: params)
        connection?.stateUpdateHandler = handleConnectionState
        connection?.start(queue: .global())

        DispatchQueue.main.asyncAfter(deadline: .now() + connectionTimeout) { [weak self] in
            guard let self = self, self.connection?.state != .ready else { return }
            self.connection?.cancel()
            self.delegate?.socketManagerDidDisconnect(manager: self, error: NSError(domain: "Connection Timeout", code: -1001, userInfo: nil))
        }
    }

    private func handleConnectionState(state: NWConnection.State) {
        switch state {
        case .ready:
            delegate?.socketManagerDidConnect(manager: self, host: serverIP)
            receiveData()
            startHeartbeat()
        case .failed(let error):
            delegate?.socketManagerDidDisconnect(manager: self, error: error)
        case .cancelled:
            stopHeartbeat()
        default:
            break
        }
    }

    func disconnect() {
        connection?.cancel()
        stopHeartbeat()
    }

    // MARK: - Data Sending and Receiving
    func send(data: Data, successHandler: (() -> Void)? = nil) {
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Send failed with error: \(error)")
            } else {
                successHandler?()
            }
        })
    }

    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                print("Receive error: \(error)")
                self.delegate?.socketManagerDidDisconnect(manager: self, error: error)
                return
            }

            if let data = content {
                self.buffer.append(data)
                self.processBuffer()  // 处理缓冲区数据，进行拆包解包
            }

            if isComplete == false {
                self.receiveData()
            }
        }
    }

    // MARK: - 封装的消息长度解析方法
    private func parseMessageLength(from data: Data) -> Int? {
        // 检查数据长度，确保至少有消息头
        guard data.count >= messageHeaderLength else { return nil }

        // 使用配置的 `lengthFieldRange` 解析消息长度
        let lengthData = data.subdata(in: lengthFieldRange)
        let messageLength = Int(UInt32(bigEndian: lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }))
        return messageLength
    }

    private func processBuffer() {
        while buffer.count >= messageHeaderLength {
            // 使用封装的 parseMessageLength(from:) 方法解析消息长度
            guard let messageLength = parseMessageLength(from: buffer) else { break }

            let totalMessageLength = messageHeaderLength + messageLength
            guard buffer.count >= totalMessageLength else { break }

            let messageData = buffer.subdata(in: messageHeaderLength..<totalMessageLength)
            delegate?.socketManagerDidReceiveData(manager: self, data: messageData)

            buffer.removeSubrange(0..<totalMessageLength)
        }
    }

    // MARK: - Heartbeat Methods
    func setHeartbeat(data: Data, interval: TimeInterval) {
        self.heartbeatData = data
        self.heartbeatInterval = interval
    }

    private func startHeartbeat() {
        guard let heartbeatData = heartbeatData else { return }
        timer = DispatchSource.makeTimerSource()
        timer?.schedule(deadline: .now(), repeating: heartbeatInterval)
        timer?.setEventHandler { [weak self] in
            self?.send(data: heartbeatData)
        }
        timer?.resume()
    }

    private func stopHeartbeat() {
        timer?.cancel()
        timer = nil
    }
}
