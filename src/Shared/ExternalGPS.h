//
//  ExternalGPS.h
//  Go Map!!
//
//  Created by Bryce Cogswell on 11/19/16.
//  Copyright © 2016 Bryce Cogswell. All rights reserved.
//

#import <ExternalAccessory/ExternalAccessory.h>
#import <Foundation/Foundation.h>

@interface ExternalGPS : NSObject <NSStreamDelegate> {
    EASession *_session;
    NSMutableData *_readData;
    NSMutableData *_writeData;
}

@property(strong, nonatomic) EAAccessoryManager *accessoryManager;

@end
