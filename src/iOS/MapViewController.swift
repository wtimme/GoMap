//
//  MapViewController.swift
//  Go Map!!
//
//  Created by Wolfgang Timme on 4/12/19.
//  Copyright © 2019 Bryce. All rights reserved.
//

import UIKit

extension MapViewController {
    @IBAction func didLongTapOnAddButton(_ sender: AnyObject) {
        let storyboard = UIStoryboard(name: "MainStoryboard", bundle: nil)
        
        let poiTabBarController = storyboard.instantiateViewController(withIdentifier: "poiTabBar")
        self.present(poiTabBarController, animated: true) {
            // TODO
        }
    }
}
