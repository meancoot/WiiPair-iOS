//
//  WIIMainViewViewController.m
//  WiiPair
//
//  Created by Jason Fetters on 2/7/14.
//  Copyright (c) 2014 WiiPair. All rights reserved.
//

#import "WIILogViewController.h"

@interface WIILogViewController ()

@end

@implementation WIILogViewController
{
    NSMutableArray* _messages;
}

- (id)init
{
    if (self = [super initWithStyle:UITableViewStyleGrouped])
    {
        self.title = @"WiiPair";
        _messages = [NSMutableArray array];
    }
    
    return self;
}

- (void)addMessage:(NSString *)message
{
    [_messages addObject:message];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _messages.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"TblItem"];
    
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TblItem"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    cell.textLabel.text = _messages[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
}

@end
