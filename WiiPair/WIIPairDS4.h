//
//  WIIPairViewController.h
//  WiiPair
//
//  Created by Jason Fetters on 2/8/14.
//  Copyright (c) 2014 WiiPair. All rights reserved.
//

#import "WIIAppDelegate.h"
#import "WIILogViewController.h"

@interface WIIPairDS4 : WIILogViewController<BTstackListener>
@property (nonatomic, retain) BTstackDevice* device;

- (id)initWithDevice:(BTstackDevice*)device;

@end
