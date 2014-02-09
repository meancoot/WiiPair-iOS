//
//  WIIMainViewViewController.m
//  WiiPair
//
//  Created by Jason Fetters on 2/7/14.
//  Copyright (c) 2014 WiiPair. All rights reserved.
//

#import "WIIMainViewViewController.h"
#import "WIILogViewController.h"
#import "WIIPairViewController.h"

@interface WIIMainViewViewController ()

@end

@implementation WIIMainViewViewController

- (id)init
{
    if (self = [super initWithStyle:UITableViewStyleGrouped])
    {
        self.title = @"WiiPair";
    }
    
    return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (NSString*)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @"Use this to pair a new Wii Remote to the device.\n"
            "When asked press the red sync button found under the battery cover.\n"
            "Before running, close all other apps which use BTstack, set the active "
            "bluetooth stack to none, and make sure there are no other discoverable "
            "bluetooth devices nearby.\n\nNote: This does not pair the Wii Remote with "
            "the native bluetooth stack, only BTstack.";
}


- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TblItem"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = @"Pair Wii Remote";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.navigationController pushViewController:[WIIPairViewController new] animated:YES];
}

@end

