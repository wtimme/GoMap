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
        guard nil == mapView.editorLayer.selectedPrimary else {
            // Ignore long-taps when an object is selected.
            return
        }
        
        let storyboard = UIStoryboard(name: "MainStoryboard", bundle: nil)
        
        guard let poiTabBarController = storyboard.instantiateViewController(withIdentifier: "poiTabBar") as? POITabBarController else {
            return
        }
        
        guard let navigationController = poiTabBarController.viewControllers?.first as? UINavigationController else {
            assertionFailure("The view controller hierarchy is not set up as expected.")
            return
        }
        
        // Present the "POIType" view controller
        navigationController.viewControllers.last?.performSegue(withIdentifier: "POITypeSegue", sender: nil)
        
        // Make sure that the "Common Tags" item is selected.
        poiTabBarController.selectedIndex = 0
        
        present(poiTabBarController, animated: true)
    }
}
