//
//  WIIPairViewController.m
//  WiiPair
//
//  Created by Jason Fetters on 2/8/14.
//  Copyright (c) 2014 WiiPair. All rights reserved.
//

#import "WIIPairDS4.h"
#include "btstack.h"

uint16_t channels[2];
enum { WIIWaiting, WIIConnecting, WIIOpening, WIIPaired };
static unsigned pairingState = WIIWaiting;

@implementation WIIPairDS4
{
    bd_addr_t _inquiryAddress;
    uint16_t _handle;
}

- (id)initWithDevice:(BTstackDevice*)aDevice
{
    if ((self = [super init]))
    {
        self.navigationItem.hidesBackButton = YES;
        self.title = @"Pairing DualShock 4";
        
        _device = aDevice;
        bt_flip_addr(_inquiryAddress, _device.data.address);
    }
    
    return self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    WIIAppDelegate* delegate = [[UIApplication sharedApplication] delegate];
    delegate.btListener = self;
    btpad_queue_hci_set_event_mask(0xFFFFFFFF, 0x1DFFFFFF);
}

//

- (void)hciEventCommandStatus:(uint8_t *)aData size:(uint16_t)aSize
{
    if (COMMAND_STATUS_EVENT(aData, hci_create_connection))
    {
        [self addMessage:@"Connecting to device."];
    }
    else
    {
        uint16_t cmd = READ_BT_16(aData, 4);
        [self addMessage:[NSString stringWithFormat:@"Got unknown 'Command Status' event: %02X %02X", cmd >> 10, cmd & 0x3FF]];
    }
    return;
}

- (void)hciEventCommandComplete:(uint8_t *)aData size:(uint16_t)aSize
{
    if (COMMAND_COMPLETE_EVENT(aData, hci_set_event_mask))
    {
        [self addMessage:@"HCI Event mask set."];
        btpad_queue_hci_write_simple_pairing_mode(1);
    }
    else if (COMMAND_COMPLETE_EVENT(aData, hci_write_simple_pairing_mode))
    {
        [self addMessage:@"Simple Pairing Mode enabled."];
     
        pairingState = WIIConnecting;
        btpad_queue_hci_create_connection(_inquiryAddress, 0x18, self.device.data.page_scan_rep_mode,
                                          self.device.data.page_scan_mode, 0x8000 | self.device.data.clock_offset, 0);
    }
    else if (COMMAND_COMPLETE_EVENT(aData, hci_link_key_request_reply))
    {
        [self addMessage:@"Got 'Link Key Request Reply Complete' event."];
    }
    else
    {
        uint16_t cmd = READ_BT_16(aData, 3);
        [self addMessage:[NSString stringWithFormat:@"Got unknown 'Command Complete' event: %02X %02X", cmd >> 10, cmd & 0x3FF]];
    }
    
    return;
}

- (void)hciEventConnectionComplete:(uint8_t *)aData size:(uint16_t)aSize
{
    if (pairingState != WIIConnecting || BD_ADDR_CMP(self.device.data.address, &aData[5]))
    {
        // Don't print this if state is paired: BTstack will call this once for each l2cap_channel_create command.
        if (pairingState != WIIOpening)
        {
            [self addMessage:@"Got 'Connection Complete' event for untracked device; ignoring."];
        }
        return;
    }
    
    if (aData[2])
    {
        [self addMessage:[NSString stringWithFormat:@"Got failed 'Connection Complete' event (Status: %02X)", aData[2]]];
        return;
    }
    
    //
    
    pairingState = WIIOpening;
    
    _handle = READ_BT_16(aData, 3);
    bt_send_cmd(&l2cap_create_channel, _inquiryAddress, PSM_HID_CONTROL);
    
    return;
}

- (void)l2capEventChannelOpened:(uint8_t *)aData size:(uint16_t)aSize
{
    const uint16_t psm = READ_BT_16(aData, 11);
    const uint16_t channel_id = READ_BT_16(aData, 13);
    
    if (pairingState != WIIOpening || BD_ADDR_CMP(self.device.data.address, &aData[3]))
    {
        [self addMessage:@"Got L2CAP 'Channel Opened' event for untracted device; ignoring."];
        return;
    }
    
    if (psm != PSM_HID_CONTROL && psm != PSM_HID_INTERRUPT)
    {
        [self addMessage:[NSString stringWithFormat:@"Get L2CAP 'Channel Opened' event for unrecogized PSM (%02X); ignoring.", psm]];
        return;
    }
    
    if (aData[2])
    {
        [self addMessage:[NSString stringWithFormat:@"Got failed L2CAP 'Channel Opened' event (Status: %02X).", aData[2]]];
        return;
    }
    
    [self addMessage:[NSString stringWithFormat:@"L2CAP channel opened: (PSM: %02X)\n", psm]];
    channels[(psm == PSM_HID_CONTROL) ? 0 : 1] = channel_id;
    
    if (channels[0])
    {
        pairingState = WIIPaired;
        [self addMessage:@"Pairing Complete!"];
    }
    
    return;
}

@end
