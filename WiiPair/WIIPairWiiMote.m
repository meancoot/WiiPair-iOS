//
//  WIIPairViewController.m
//  WiiPair
//
//  Created by Jason Fetters on 2/8/14.
//  Copyright (c) 2014 WiiPair. All rights reserved.
//

#import "WIIPairWiiMote.h"
#include "btstack.h"

#pragma pack(push, 1)
static bd_addr_t localMAC;
static uint16_t handle;
static uint16_t channels[2];

enum { WIIWaiting, WIIConnecting, WIIAuthenticating, WIIPaired };
static unsigned pairingState = WIIWaiting;

@implementation WIIPairWiiMote
{
    bd_addr_t _inquiryAddress;
}

- (id)initWithDevice:(BTstackDevice*)aDevice
{
    if ((self = [super init]))
    {
        self.navigationItem.hidesBackButton = YES;
        self.title = @"Pairing Wii Remote";

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
    btpad_queue_hci_read_bd_addr();
}

- (void)hciEventCommandStatus:(uint8_t *)aData size:(uint16_t)aSize
{
    if (COMMAND_STATUS_EVENT(aData, hci_create_connection))
    {
        if (pairingState != WIIPaired)
            [self addMessage:@"Connecting to device."];
    }
    else if (COMMAND_STATUS_EVENT(aData, hci_authentication_requested))
    {
        [self addMessage:@"Requesting Authentication."];
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
    if (COMMAND_COMPLETE_EVENT(aData, hci_read_bd_addr))
    {
        if (pairingState != WIIWaiting)
            return;
 
        memcpy(localMAC, &aData[6], sizeof(bd_addr_t));

        bd_addr_t address;
        bt_flip_addr(address, &aData[6]);
        [self addMessage:[NSString stringWithFormat:@"Local BT MAC address is %s", bd_addr_to_str(address)]];
        
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
        if (pairingState != WIIPaired)
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
    
    pairingState = WIIAuthenticating;
    
    handle = READ_BT_16(aData, 3);
    btpad_queue_hci_authentication_requested(handle);
    
    return;
}

- (void)hciEventPinCodeRequest:(uint8_t*)aData size:(uint16_t)aSize
{
    if (pairingState != WIIAuthenticating || BD_ADDR_CMP(self.device.data.address, &aData[2]))
    {
        [self addMessage:@"Got 'Pin Code Request' event for untracked device; ignoring."];
        return;
    }
    
    //

    
    [self addMessage:@"Sending PIN code."];
    btpad_queue_hci_pin_code_request_reply(_inquiryAddress, localMAC);
    
    return;
}

- (void)hciEventAuthenticationComplete:(uint8_t *)aData size:(uint16_t)aSize
{
    if (handle != READ_BT_16(aData, 3))
    {
        [self addMessage:@"Got 'Authentication Complete' event for untracked device; ignoring."];
        return;
    }
    
    if (aData[2])
    {
        [self addMessage:[NSString stringWithFormat:@"Got failed 'Authentication Complete' event (Status: %02X)", aData[2]]];
        return;
    }
    
    //
    
    pairingState = WIIPaired;
    
    [self addMessage:@"Got authentication."];
    
    bt_send_cmd(&l2cap_create_channel, _inquiryAddress, PSM_HID_CONTROL);
    bt_send_cmd(&l2cap_create_channel, _inquiryAddress, PSM_HID_INTERRUPT);
    
    return;
}

- (void)l2capEventChannelOpened:(uint8_t *)aData size:(uint16_t)aSize
{
    const uint16_t psm = READ_BT_16(aData, 11);
    const uint16_t channel_id = READ_BT_16(aData, 13);
    
    if (pairingState != WIIPaired || BD_ADDR_CMP(self.device.data.address, &aData[3]))
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
    
    if (channels[0] && channels[1])
    {
        [self addMessage:@"Pairing Complete!"];
    }
    
    return;
}


@end
