//
//  WIIAppDelegate.m
//  WiiPair
//
//  Created by Jason Fetters on 2/7/14.
//  Copyright (c) 2014 WiiPair. All rights reserved.
//

#import "WIIAppDelegate.h"
#import "WIIMainViewViewController.h"
#import "WIILogViewController.h"
#include "btstack.h"

@implementation WIIAppDelegate
{
    UINavigationController* _navigationController;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
   
    run_loop_init(RUN_LOOP_COCOA);
    
    _navigationController = [[UINavigationController alloc] initWithRootViewController:[WIIMainViewViewController new]];
    self.window.rootViewController = _navigationController;
    
    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

@end
