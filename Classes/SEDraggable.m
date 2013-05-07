//
//  SEDraggable.m
//  SEDraggable
//
//  Created by bryn austin bellomy <bryn@signals.io> on 10/23/11.
//  Copyright (c) 2012 robot bubble bath LLC. All rights reserved.
//

#import "SEDraggable.h"
#import "SEDraggableLocation.h"

@implementation UIView (Helpr)
- (CGPoint) getCenterInWindowCoordinates {
  if (self.superview != nil)
    return [self.superview convertPoint:self.center toView:nil];
  else
    return self.center;
}
@end

@interface SEDraggable ()
- (void) handleDrag:(id)sender;
- (BOOL) askToEnterLocation:(SEDraggableLocation *)location entryMethod:(SEDraggableLocationEntryMethod)entryMethod animated:(BOOL)animated;
@property (nonatomic) CGPoint touchOrigin;
@end

@implementation SEDraggable

@synthesize shouldSnapBackToHomeLocation = _shouldSnapBackToHomeLocation;
@synthesize shouldSnapBackToDragOrigin = _shouldSnapBackToDragOrigin;
@synthesize currentLocation = _currentLocation;
@synthesize homeLocation = _homeLocation;
@synthesize previousLocation = _previousLocation;
@synthesize delegate = _delegate;
@synthesize droppableLocations = _droppableLocations;

#pragma mark- Lifecycle

- (id) init {
  if (self = [self initWithFrame:CGRectNull]) {
  }
  return self;
}

- (id) initWithImage:(UIImage *)image andSize:(CGSize)size {
  UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
  imageView.frame = CGRectMake(0, 0, size.width, size.height);
  
  self = [self initWithView:imageView];
  if (self) {
  }
  return self;
}

- (id) initWithView:(UIView *)view {
  self = [self initWithFrame:view.frame];
  if (self) {
    view.frame = CGRectMake(0, 0, view.frame.size.width, view.frame.size.height);
    [self addSubview:view];
  }
  return self;
}

#pragma mark -- Designated initializer

- (void) _SEDraggableInit {
    // pan gesture handling
    self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:
                                       self action:@selector(handleDrag:)];
    self.longPressGestureRecognizer.delegate = self;
    [self addGestureRecognizer:self.longPressGestureRecognizer];
    
    self.shouldSnapBackToHomeLocation = NO;
    self.shouldSnapBackToDragOrigin = YES;
    
    self.homeLocation = nil;
    self.currentLocation = nil;
    self.previousLocation = nil;
    
    self.droppableLocations = [NSMutableSet set];
}

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self _SEDraggableInit];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self _SEDraggableInit];
    }
    return self;
}

- (void) dealloc {
    _longPressGestureRecognizer.delegate = nil;
    [self removeGestureRecognizer:_longPressGestureRecognizer];
}

#pragma mark- Convenience methods

- (void) addAllowedDropLocation:(SEDraggableLocation *)location {
  [self.droppableLocations addObject:location];
}



#pragma mark- UI events

- (void) handleDrag:(id)sender {
    
    CGPoint myCoordinates = [self.longPressGestureRecognizer locationOfTouch:0 inView:self.superview];
    [self.superview bringSubviewToFront:self];
    
    // movement has just begun
    if (self.longPressGestureRecognizer.state == UIGestureRecognizerStateBegan) {
        if ([self.delegate respondsToSelector:@selector(draggableObjectDidStartMoving:)])
            [self.delegate draggableObjectDidStartMoving:self];

        // keep track of where the movement began
        myCoordinates = [self.longPressGestureRecognizer locationOfTouch:0 inView:self.superview];
        _touchOrigin = CGPointMake(myCoordinates.x - self.center.x, myCoordinates.y - self.center.y);
    }

    CGPoint translatedPoint = CGPointMake(myCoordinates.x - _touchOrigin.x, myCoordinates.y - _touchOrigin.y);
    [self setCenter:translatedPoint];
    
    // movement is currently in process
    if (self.longPressGestureRecognizer.state == UIGestureRecognizerStateChanged) {
        if ([self.delegate respondsToSelector:@selector(draggableObjectDidMove:)])
            [self.delegate draggableObjectDidMove:self];
        
        if (self.droppableLocations.count > 0) {
            for (SEDraggableLocation *location in self.droppableLocations) {
                CGPoint myWindowCoordinates = [self.superview convertPoint:myCoordinates toView:nil];
                if ([location pointIsInsideResponsiveBounds:myWindowCoordinates]) {
                    [location draggableObjectDidMoveWithinBounds:self];
                    if ([self.delegate respondsToSelector:@selector(draggableObject:didMoveWithinLocation:)]) {
                        [self.delegate draggableObject:self didMoveWithinLocation:location];
                    }
                }
                else {
                    [location draggableObjectDidMoveOutsideBounds:self];
                }
            }
        }
    }
    
    // movement has just ended
    if (self.longPressGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        BOOL didStopMovingWithinLocation = NO;
        SEDraggableLocation *dropLocation = nil;
        
        for (SEDraggableLocation *location in self.droppableLocations) {
            CGPoint myWindowCoordinates = [self.superview convertPoint:myCoordinates toView:nil];
            if ([location pointIsInsideResponsiveBounds:myWindowCoordinates]) {
                // the draggable will ask for entry into every draggable location whose bounds it is inside until the first YES, at which point the search stops
                BOOL allowedEntry = [self askToEnterLocation:location entryMethod:SEDraggableLocationEntryMethodWasDropped animated:YES];
                if (allowedEntry) {
                    didStopMovingWithinLocation = YES;
                    dropLocation = location;
                    break;
                }
            }
        }
        
        if ([self.delegate respondsToSelector:@selector(draggableObjectDidStopMoving:)])
            [self.delegate draggableObjectDidStopMoving:self];
        
        if (didStopMovingWithinLocation) {
            if ([self.delegate respondsToSelector:@selector(draggableObject:didStopMovingWithinLocation:)])
                [self.delegate draggableObject:self didStopMovingWithinLocation:dropLocation];
        }
        else {
            if (self.shouldSnapBackToHomeLocation) {
                // @@TODO: should not hard-code "yes" here
                [self askToSnapBackToLocation:self.homeLocation animated:YES];
            }
            else if (self.shouldSnapBackToDragOrigin) {
                [self askToSnapBackToLocation:self.currentLocation animated:YES];
            }
        }
    }
}

#pragma mark- SEDraggableLocationClient (notifications about the location's decision)

- (void) draggableLocation:(SEDraggableLocation *)location
            didAllowEntry:(SEDraggableLocationEntryMethod)entryMethod
                  animated:(BOOL)animated {

  if ([self.delegate respondsToSelector:@selector(draggableObject:finishedEnteringLocation:withEntryMethod:)])
    [self.delegate draggableObject:self finishedEnteringLocation:location withEntryMethod:entryMethod];
}

- (void) draggableLocation:(SEDraggableLocation *)location
            didRefuseEntry:(SEDraggableLocationEntryMethod)entryMethod
                  animated:(BOOL)animated {
  
  if ([self.delegate respondsToSelector:@selector(draggableObject:failedToEnterLocation:withEntryMethod:)])
    [self.delegate draggableObject:self failedToEnterLocation:location withEntryMethod:entryMethod];
  
  if (entryMethod == SEDraggableLocationEntryMethodWasDropped && self.shouldSnapBackToHomeLocation) {
    [self askToEnterLocation:self.homeLocation entryMethod:entryMethod animated:animated];
    // @@TODO: maybe also should handle snapping back to self.previousLocation rather than ONLY self.homeLocation
  }
  else if (entryMethod == SEDraggableLocationEntryMethodWantsToSnapBack) {
    // what's a girl to do? :(
  }
}

- (void) snapCenterToPoint:(CGPoint)point animated:(BOOL)animated completion:(void (^)(BOOL))completionBlock {
  if (animated) {
    __block SEDraggable *myself = self;
    [UIView animateWithDuration:0.35f delay:0 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                       [myself setCenter:point];
                     }
                     completion:completionBlock];
  }
  else {
    self.center = point;
    if (completionBlock != nil)
      completionBlock(YES);
  }
}

#pragma mark - Requesting entry

#pragma mark -- Main method

- (BOOL) askToEnterLocation:(SEDraggableLocation *)location entryMethod:(SEDraggableLocationEntryMethod)entryMethod animated:(BOOL)animated {
  
  BOOL shouldAsk = YES;
  if ([self.delegate respondsToSelector:@selector(draggableObject:shouldAskToEnterLocation:withEntryMethod:)]) {
    shouldAsk = [self.delegate draggableObject:self shouldAskToEnterLocation:location withEntryMethod:entryMethod];
  }
  
  if (shouldAsk == YES) {
    if ([self.delegate respondsToSelector:@selector(draggableObject:willAskToEnterLocation:withEntryMethod:)])
      [self.delegate draggableObject:self willAskToEnterLocation:location withEntryMethod:entryMethod];
    
    return [location draggableObject:self wantsToEnterLocationWithEntryMethod:entryMethod animated:animated];
  }
  return NO;
}

#pragma mark -- Convenience methods

- (void) askToDropIntoLocation:(SEDraggableLocation *)location animated:(BOOL)animated {
  [self askToEnterLocation:location entryMethod:SEDraggableLocationEntryMethodWasDropped animated:animated];
}

- (void) askToSnapBackToLocation:(SEDraggableLocation *)location animated:(BOOL)animated {
  [self askToEnterLocation:location entryMethod:SEDraggableLocationEntryMethodWantsToSnapBack animated:animated];  
}

@end
