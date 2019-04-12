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
        
        guard let poiTabBarController = storyboard.instantiateViewController(withIdentifier: "poiTabBar") as? POITabBarController else {
            return
        }
        
        // Make sure that the "Common Tags" item is selected.
        poiTabBarController.selectedIndex = 0
        
        present(poiTabBarController, animated: true) {
            guard let navigationController = poiTabBarController.viewControllers?.first as? UINavigationController else {
                return
            }
            
            navigationController.viewControllers.last?.performSegue(withIdentifier: "POITypeSegue", sender: nil)
        }
    }
}
