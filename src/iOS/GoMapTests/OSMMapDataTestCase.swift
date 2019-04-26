//
//  OSMMapDataTestCase.swift
//  GoMapTests
//
//  Created by Wolfgang Timme on 4/15/19.
//  Copyright © 2019 Bryce. All rights reserved.
//

import XCTest
@testable import Go_Map__

class OSMMapDataTestCase: XCTestCase {
    
    var mapData: OsmMapData!
    var databaseMock: DatabaseMock!
    var userDefaults: UserDefaults!

    override func setUp() {
        databaseMock = DatabaseMock()
        userDefaults = createDedicatedUserDefaults()
        mapData = OsmMapData(database: databaseMock,
                             userDefaults: userDefaults)
        
        // Setup the `undoContext` closure. This is necessary, as `OsmMapData` relies on it being present.
        // Otherwise, the app crashes.
        mapData.undoContextForComment = { _ in
            return [:]
        }
    }

    override func tearDown() {
        mapData = nil
        databaseMock = nil
        userDefaults = nil
    }
    
    // MARK: setServer
    
    func testSetServerShouldAddThePathSeparatorSuffixIfItDoesNotExist() {
        let hostname = "https://example.com"
        mapData.setServer(hostname)
        
        let hostnameWithPathSeparatorSuffix = "\(hostname)/"
        XCTAssertEqual(OSM_API_URL, hostnameWithPathSeparatorSuffix)
    }
    
    func testSetServerShouldNotAddThePathSeparatorSuffixIfItAlreadyExists() {
        let hostname = "https://example.com/"
        mapData.setServer(hostname)
        
        XCTAssertEqual(OSM_API_URL, hostname)
    }

}
