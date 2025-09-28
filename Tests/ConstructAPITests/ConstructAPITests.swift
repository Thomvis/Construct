#if os(macOS)

import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class ConstructAPITests: XCTestCase {
    private var serverProcess: Process?

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        if let process = serverProcess {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
            serverProcess = nil
        }
    }

    func testAdminPasswordGrant() async throws {
        let adminPassword = "integration-password"
        let jwtSecret = "integration-secret"
        let port = try Self.findFreePort()
        let baseURL = URL(string: "http://127.0.0.1:\(port)")!

        try launchServer(port: port, adminPassword: adminPassword, jwtSecret: jwtSecret)
        try await waitForServer(baseURL: baseURL)

        var request = URLRequest(url: baseURL.appendingPathComponent("token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let tokenRequest = TokenRequestPayload(password: adminPassword)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(tokenRequest)

        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Invalid response type \(type(of: response))")
            return
        }

        XCTAssertEqual(httpResponse.statusCode, 200, "Unexpected status code")

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let tokenResponse = try decoder.decode(TokenResponsePayload.self, from: data)

        XCTAssertFalse(tokenResponse.accessToken.isEmpty, "access_token should not be empty")
        XCTAssertEqual(tokenResponse.tokenType ?? "bearer", "bearer", "token_type should default to bearer")
    }

    private func launchServer(port: UInt16, adminPassword: String, jwtSecret: String) throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // ConstructAPITests.swift
            .deletingLastPathComponent() // ConstructAPITests
            .deletingLastPathComponent() // Tests
        let serverDirectory = packageRoot.appendingPathComponent("Server")

        precondition(FileManager.default.fileExists(atPath: serverDirectory.path), "Server directory not found at \(serverDirectory.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "uv",
            "run",
            "--project",
            "Server",
            "uvicorn",
            "main:app",
            "--host",
            "127.0.0.1",
            "--port",
            String(port)
        ]

        var environment = ProcessInfo.processInfo.environment
        environment["ADMIN_PASSWORD"] = adminPassword
        environment["JWT_SECRET"] = jwtSecret
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment
        process.currentDirectoryURL = serverDirectory

        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()

        serverProcess = process

        addTeardownBlock { [process] in
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }
    }

    private func waitForServer(baseURL: URL, timeout: TimeInterval = 15) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        let session = URLSession(configuration: .ephemeral)
        while Date() < deadline {
            var request = URLRequest(url: baseURL.appendingPathComponent("health"))
            request.httpMethod = "GET"
            do {
                let (_, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    return
                }
            } catch {
                // ignore and retry
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        throw ServerStartupError.timedOut
    }

    private static func findFreePort() throws -> UInt16 {
        let socketFd = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFd >= 0 else {
            throw ErrnoError()
        }
        defer { close(socketFd) }

        var address = sockaddr_in()
        #if canImport(Darwin)
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.stride)
        #endif
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: in_addr_t(0))

        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socketFd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw ErrnoError()
        }

        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.getsockname(socketFd, $0, &length)
            }
        }
        guard nameResult == 0 else {
            throw ErrnoError()
        }

        return UInt16(bigEndian: address.sin_port)
    }
}

private struct ErrnoError: Error, CustomStringConvertible {
    let code: Int32
    let message: String

    init(code: Int32 = errno) {
        self.code = code
        self.message = String(cString: strerror(code))
    }

    var description: String { "errno \(code): \(message)" }
}

private enum ServerStartupError: Error {
    case timedOut
}

private struct TokenRequestPayload: Encodable {
    var grantType: String? = nil
    var password: String?
    var transaction: String? = nil
}

private struct TokenResponsePayload: Decodable {
    var accessToken: String
    var tokenType: String?
}

#else

import XCTest

final class ConstructAPITests: XCTestCase {
    func testAdminPasswordGrant() throws {
        throw XCTSkip("ConstructAPI integration tests require macOS host execution.")
    }
}

#endif
