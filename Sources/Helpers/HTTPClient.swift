//
//  File.swift
//  
//
//  Created by Thomas Visser on 05/07/2023.
//

import Foundation

public protocol HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {

}
