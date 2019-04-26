//
//  DatabaseMock.swift
//  GoMapTests
//
//  Created by Wolfgang Timme on 4/26/19.
//  Copyright © 2019 Bryce. All rights reserved.
//

@testable import Go_Map__

class DatabaseMock: NSObject {
    
}

extension DatabaseMock: Database {
    
    func querySqliteNodes() -> NSDictionary? {
        return [:]
    }
    
    func querySqliteWays() -> NSDictionary? {
        return [:]
    }
    
    func querySqliteRelations() -> NSDictionary? {
        return [:]
    }
    
}
