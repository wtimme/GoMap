//
//  CLLocationCoordinate2D+MakeCoordinate.swift
//  GoMapTests
//
//  Created by Wolfgang Timme on 4/26/19.
//  Copyright © 2019 Bryce. All rights reserved.
//

import CoreLocation

/// Extension that allows for easier creation of `CLLocationCoordinate2D` instances for testing.
extension CLLocationCoordinate2D {
    
    /// - Returns: A `CLLocationCoordinate2D` instance that is in Berlin, Germany.
    static func makeBerlinCoordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.3927)
    }
    
}
