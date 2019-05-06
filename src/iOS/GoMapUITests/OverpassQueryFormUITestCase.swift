//
//  OverpassQueryFormUITestCase.swift
//  GoMapUITests
//
//  Created by Wolfgang Timme on 5/6/19.
//  Copyright © 2019 Bryce. All rights reserved.
//

import XCTest

class OverpassQueryFormUITestCase: XCTestCase {

    var app: XCUIApplication!
    
    override func setUp() {
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDown() {
        app.terminate()
        app = nil
    }
    
    func testTapOnOverpassQueryMenuItemInDisplayOptionsShouldShowOverpassQueryFormViewController() {
        goToOverpassQueryViewController()
    }
    
    func testEnteringAnInvalidQueryShouldDisplayAnErrorMessage() {
        goToOverpassQueryViewController()
        
        let textField = app.textViews["query_text_view"]
        textField.tap()
        textField.typeText("**")
        
        let errorLabel = app.staticTexts["error_message"]
        XCTAssertTrue(errorLabel.isHittable)
    }
    
    func testTappingOnTheErrorLabelShouldDismissTheKeyboard() {
        goToOverpassQueryViewController()
        
        let textField = app.textViews["query_text_view"]
        textField.tap()
        textField.typeText("**")
        
        let errorLabel = app.staticTexts["error_message"]
        errorLabel.tap()
        
        XCTAssert(app.keyboards.count == 0, "The keyboard should be dismissed")
    }
    
    // MARK: Helper methods
    
    private func goToOverpassQueryViewController() {
        let button = app.buttons["display_options_button"]
        button.press(forDuration: 1.0)
        
        waitForViewController("Display")
        
        app.cells["overpass_query"].tap()
        
        waitForViewController("Overpass Query")
    }

}