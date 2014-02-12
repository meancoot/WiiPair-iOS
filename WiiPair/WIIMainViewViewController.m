//
//  WIIMainViewViewController.m
//  WiiPair
//
//  Created by Jason Fetters on 2/7/14.
//  Copyright (c) 2014 WiiPair. All rights reserved.
//

#import "WIIMainViewViewController.h"
#import "WIILogViewController.h"
#import "WIIPairDS4.h"
#import "WIIPairWiiMote.h"

#include "btstack.h"

@implementation WIIMainViewViewController
{
    NSMutableDictionary* _devices;
    uint32_t _namesWaiting;
}

- (id)init
{
    if (self = [super initWithStyle:UITableViewStyleGrouped])
    {
        self.title = @"BTstack WiiMote/DualShock 4 Pairer";
        _devices = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    WIIAppDelegate* delegate = [[UIApplication sharedApplication] delegate];
    delegate.btListener = self;
    [self startNewInquiryIfNeeded];
}

- (void)startNewInquiryIfNeeded
{
    if (_namesWaiting == 0)
    {
        btpad_queue_hci_inquiry(HCI_INQUIRY_LAP, 4, 0);
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_devices count];
}

- (NSString*)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return @"Press the red sync button on any Wii Remote, or hold the "
            "Share and PlayStations buttons on any DualShock 4 you would like to pair.";
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BTstackDevice* device = [_devices objectForKey:_devices.allKeys[indexPath.row]];
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TblItem"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = device.name ? device.name : @"{ Waiting for name }";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BTstackDevice* device = [_devices objectForKey:_devices.allKeys[indexPath.row]];

    if (strstr(device.name.UTF8String, "Nintendo RVL-CNT-01"))
    {
        [self.navigationController pushViewController:[[WIIPairWiiMote alloc] initWithDevice:device] animated:YES];
    }
    else if (strstr(device.name.UTF8String, "Wireless Controller"))
    {
        [self.navigationController pushViewController:[[WIIPairDS4 alloc] initWithDevice:device] animated:YES];
    }
}

//

- (void)hciEventInquiryResult:(uint8_t *)aData size:(uint16_t)aSize
{
    for (uint8_t i = 0; i < aData[2]; i ++)
    {
        BTstackDevice* device = [[BTstackDevice alloc] initWithData:aData + 3 stride:aData[2]];
        
        if (![_devices objectForKey:device.hash])
        {
            [_devices setObject:device forKey:device.hash];
        }
    }

    [self.tableView reloadData];
    return;
}

- (void)hciEventInquiryComplete:(uint8_t *)aData size:(uint16_t)aSize
{
    for (BTstackDevice* device in _devices.objectEnumerator)
    {
        if (device.name == nil)
        {
            bd_addr_t address;
            bt_flip_addr(address, device.data.address);
            btpad_queue_hci_remote_name_request(address, device.data.page_scan_rep_mode, 0, 0x8000 | device.data.clock_offset);
            _namesWaiting ++;
        }
    }
    
    [self startNewInquiryIfNeeded];
}

- (void)hciEventRemoteNameRequestComplete:(uint8_t *)aData size:(uint16_t)aSize
{
    if (aData[2])
    {
        NSLog(@"Got failed 'Remote Name Request Complete' event.");
        return;
    }
    
    NSNumber* hash = [NSNumber numberWithUnsignedLongLong:bd_addr_to_uint(&aData[3])];
    BTstackDevice* device = _devices[hash];
    
    if (device)
    {
        device.name = [NSString stringWithFormat:@"%.200s", &aData[9]];
        _namesWaiting --;
        
        [self.tableView reloadData];
    }
    
    [self startNewInquiryIfNeeded];
}


@end

