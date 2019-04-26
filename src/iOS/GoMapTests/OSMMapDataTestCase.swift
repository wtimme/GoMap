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
    
    // MARK: NSCoding
    
    func testNSCodingShouldProperlyEncodeAndDecodeNodes() {
        // Given
        let node = mapData.createNode(atLocation: CLLocationCoordinate2D.makeBerlinCoordinate()).require()
        let encodingKey = "lorem-ipsum"
        
        // When
        let archiver = NSKeyedArchiver()
        archiver.encode(mapData, forKey: encodingKey)
        
        let unarchiver = NSKeyedUnarchiver(forReadingWith: archiver.encodedData)
        let unarchivedObject = unarchiver.decodeObject(forKey: encodingKey).require()
        
        // Then
        guard let unarchivedMapData = unarchivedObject as? OsmMapData else {
            XCTFail()
            return
        }
        
        XCTAssertNotNil(unarchivedMapData.node(forRef: node.ident),
                        "The unarchived map data should contain the previously created node.")
    }
    
    func testNSCodingShouldProperlyEncodeAndDecodeWays() {
        // Given
        let way = mapData.createWay().require()
        let encodingKey = "lorem-ipsum"
        
        // When
        let archiver = NSKeyedArchiver()
        archiver.encode(mapData, forKey: encodingKey)
        
        let unarchiver = NSKeyedUnarchiver(forReadingWith: archiver.encodedData)
        let unarchivedObject = unarchiver.decodeObject(forKey: encodingKey).require()
        
        // Then
        guard let unarchivedMapData = unarchivedObject as? OsmMapData else {
            XCTFail()
            return
        }
        
        XCTAssertNotNil(unarchivedMapData.way(forRef: way.ident),
                        "The unarchived map data should contain the previously created way.")
    }
    
    func testNSCodingShouldProperlyEncodeAndDecodeRelations() {
        // Given
        let relation = mapData.createRelation().require()
        let encodingKey = "lorem-ipsum"
        
        // When
        let archiver = NSKeyedArchiver()
        archiver.encode(mapData, forKey: encodingKey)
        
        let unarchiver = NSKeyedUnarchiver(forReadingWith: archiver.encodedData)
        let unarchivedObject = unarchiver.decodeObject(forKey: encodingKey).require()
        
        // Then
        guard let unarchivedMapData = unarchivedObject as? OsmMapData else {
            XCTFail()
            return
        }
        
        XCTAssertNotNil(unarchivedMapData.relation(forRef: relation.ident),
                        "The unarchived map data should contain the previously created relation.")
    }

}
