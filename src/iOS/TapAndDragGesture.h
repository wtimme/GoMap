//
//  TapAndDragGesture.h
//  Go Map!!
//
//  Created by Bryce Cogswell on 10/13/15.
//  Copyright © 2015 Bryce Cogswell. All rights reserved.
//

#import <UIKit/UIGestureRecognizerSubclass.h>
#import <UIKit/UIKit.h>

@interface TapAndDragGesture : UIGestureRecognizer {
    NSInteger _tapState;
    CGPoint _tapPoint;

    CGPoint _lastTouchLocation;
    CGPoint _lastTouchTranslation;
    NSTimeInterval _lastTouchTimestamp;
}
- (void)reset;
- (void)touchesBegan:(NSSet *_Nonnull)touches withEvent:(UIEvent *_Nonnull)event;
- (void)touchesMoved:(NSSet *_Nonnull)touches withEvent:(UIEvent *_Nonnull)event;
- (void)touchesEnded:(NSSet *_Nonnull)touches withEvent:(UIEvent *_Nonnull)event;
- (void)touchesCancelled:(NSSet *_Nonnull)touches withEvent:(UIEvent *_Nonnull)event;

- (CGPoint)translationInView:(nullable UIView *)view; // translation in the coordinate system of the specified view
@end
