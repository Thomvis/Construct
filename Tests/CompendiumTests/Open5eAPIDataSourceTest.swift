//
//  Open5eAPIDataSourceTest.swift
//  
//
//  Created by Thomas Visser on 15/06/2023.
//

import Foundation
import Compendium
import XCTest

final class Open5eAPIDataSourceTest: XCTestCase {
    func testReadsV2Creatures() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "Construct iOS")
            XCTAssertEqual(request.url?.path, "/v2/creatures")
            XCTAssertTrue(request.url?.query?.contains("document__key=srd-2014") == true)

            let responseData = """
                {
                  "next": null,
                  "results": [
                    {
                      "name": "Test Creature",
                      "size": { "name": "Medium" },
                      "type": { "name": "Humanoid" },
                      "alignment": "neutral",
                      "armor_class": 12,
                      "hit_points": 9,
                      "hit_dice": "2d8",
                      "speed": { "walk": 30.0 },
                      "ability_scores": {
                        "strength": 10,
                        "dexterity": 12,
                        "constitution": 10,
                        "intelligence": 8,
                        "wisdom": 10,
                        "charisma": 8
                      },
                      "resistances_and_immunities": {
                        "damage_immunities_display": "",
                        "damage_resistances_display": "",
                        "damage_vulnerabilities_display": "",
                        "condition_immunities_display": ""
                      },
                      "languages": { "as_string": "Common" },
                      "challenge_rating_text": "1/4",
                      "traits": [{ "name": "Test Trait", "desc": "Trait description" }],
                      "actions": [{ "name": "Club", "desc": "Hit.", "action_type": "ACTION" }]
                    }
                  ]
                }
                """

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(responseData.utf8))
        }

        let sut = Open5eAPIDataSource(itemType: .monster, document: "srd-2014", urlSession: session)

        var didReceiveResults = false
        for try await page in try sut.read() {
            XCTAssertEqual(page.count, 1)
            guard case .left = page[0] else {
                XCTFail("Expected monster payload")
                continue
            }
            didReceiveResults = true
            break
        }
        XCTAssertTrue(didReceiveResults)
    }

    func testReadsV2Spells() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: config)

        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/v2/spells")
            XCTAssertTrue(request.url?.query?.contains("document__key=srd-2014") == true)

            let responseData = """
                {
                  "next": null,
                  "results": [
                    {
                      "name": "Acid Arrow",
                      "desc": "A shimmering green arrow streaks toward a target.",
                      "higher_level": "Damage increases by 1d4.",
                      "range_text": "90 feet",
                      "verbal": true,
                      "somatic": true,
                      "material": true,
                      "material_specified": "Powdered rhubarb leaf and an adder's stomach.",
                      "ritual": false,
                      "duration": "instantaneous",
                      "concentration": false,
                      "casting_time": "action",
                      "level": 2,
                      "school": { "name": "Evocation" },
                      "classes": [{ "name": "Wizard" }]
                    }
                  ]
                }
                """

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(responseData.utf8))
        }

        let sut = Open5eAPIDataSource(itemType: .spell, document: "srd-2014", urlSession: session)

        var didReceiveResults = false
        for try await page in try sut.read() {
            XCTAssertEqual(page.count, 1)
            guard case .right = page[0] else {
                XCTFail("Expected spell payload")
                continue
            }
            didReceiveResults = true
            break
        }
        XCTAssertTrue(didReceiveResults)
    }
}

private final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            fatalError("Missing request handler")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
