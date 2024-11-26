# PisSocket

PisSocket 是一个 iOS 网络库，旨在提供基于 `NWConnection` 的高效 Socket 通信解决方案。它支持与服务器的连接、数据发送/接收以及心跳机制的管理，并提供了简单易用的 API 供开发者使用。

## 特性

- 支持 iOS 12 及以上版本。
- 基于 Apple 的 Network.framework，提供可靠的 TCP 连接和数据传输。
- 支持自定义心跳机制，防止连接超时。
- 支持消息拆包和解包，方便数据的解析。
- 提供代理方法，方便用户进行连接、断开连接和接收数据等操作。

## 安装

### 使用 CocoaPods

1. 在你的 `Podfile` 中添加 `PisSocket`：

   ```ruby
   pod 'PisSocket', :git => 'https://github.com/your-repo/PisSocket.git'
   ```

2. 运行 `pod install` 来安装依赖：

   ```bash
   pod install
   ```

### 使用 Carthage

1. 在你的 `Cartfile` 中添加以下内容：

   ```ruby
   github "your-repo/PisSocket"
   ```

2. 运行 `carthage update` 来安装依赖。

### 手动安装

1. 克隆该仓库：
   
   ```bash
   git clone https://github.com/your-repo/PisSocket.git
   ```

2. 将 `PisSocket` 文件夹添加到你的 Xcode 项目中。

## 使用方法

### 初始化 `PisSocketManager`

在你需要使用 Socket 的地方，初始化 `PisSocketManager`：

```swift
import PisSocket

let socketManager = PisSocketManager(ip: "192.168.1.1", port: 8080)
socketManager.delegate = self
```

### 连接服务器

```swift
socketManager.connect()
```

### 发送数据

```swift
let data = "Hello, Server!".data(using: .utf8)
socketManager.send(data: data!)
```

### 接收数据

通过实现 `PisSocketManagerDelegate` 协议来接收数据：

```swift
extension YourClass: PisSocketManagerDelegate {
    func socketManagerDidConnect(manager: PisSocketManager, host: String) {
        print("Connected to \(host)")
    }
    
    func socketManagerDidDisconnect(manager: PisSocketManager, error: Error?) {
        print("Disconnected: \(String(describing: error))")
    }

    func socketManagerDidReceiveData(manager: PisSocketManager, data: Data) {
        if let message = String(data: data, encoding: .utf8) {
            print("Received data: \(message)")
        }
    }
}
```

### 设置心跳

```swift
let heartbeatData = "ping".data(using: .utf8)
socketManager.setHeartbeat(data: heartbeatData!, interval: 10)
```

### 断开连接

```swift
socketManager.disconnect()
```

## 代理方法

### `PisSocketManagerDelegate` 协议

实现以下代理方法来接收连接状态和数据：

```swift
protocol PisSocketManagerDelegate: AnyObject {
    func socketManagerDidConnect(manager: PisSocketManager, host: String)
    func socketManagerDidDisconnect(manager: PisSocketManager, error: Error?)
    func socketManagerDidReceiveData(manager: PisSocketManager, data: Data)
}
```

## 项目结构

```
PisSocket
│
├── Classes
│   ├── PisSocketManager.swift      # 核心 Socket 管理类
│   ├── PisSocketDelegate.swift     # 代理协议定义
│   └── ...                        # 其他文件
│
└── Resources
    └── ...                        # 资源文件
```

## 常见问题

### 为什么我在连接时收到超时错误？

连接超时可能是因为目标服务器不可达，或者你的网络连接不稳定。请确保服务器地址和端口正确，并且你的设备可以访问目标服务器。

### 如何使用 `PisSocket` 发送自定义格式的数据？

你可以使用 `send(data:)` 方法发送任意格式的数据。只需确保数据已经序列化成 `Data` 类型。

## 贡献

如果你想为 `PisSocket` 做出贡献，欢迎提交 Pull Request！在提交 PR 之前，请确保你的代码已经过测试，并且通过了 `pod lib lint` 验证。

