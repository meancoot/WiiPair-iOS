//
//  WIIPairViewController.m
//  WiiPair
//
//  Created by Jason Fetters on 2/8/14.
//  Copyright (c) 2014 WiiPair. All rights reserved.
//

#import "WIIPairViewController.h"
#include "btstack.h"

static WIIPairViewController* vc;

#pragma pack(push, 1)
static struct
{
    bd_addr_t address;
    uint8_t page_scan_rep_mode;
    uint8_t page_scan_per_mode;
    uint8_t page_scan_mode;
    uint8_t class_of_device[3];
    uint16_t clock_offset;
}   inquiryResult;
static bd_addr_t localMAC;
static bd_addr_t inquiryAddress;
static uint16_t handle;
static uint16_t channels[2];
static uint16_t hciState;

enum { WIIWaiting, WIIGotInquiry, WIIConnecting, WIIAuthenticating, WIIPaired };
static unsigned pairingState = WIIWaiting;

#pragma pack(pop)


static void BTstackPacketHandler(uint8_t packet_type, uint16_t channel, uint8_t *aData, uint16_t aSize)
{
    if (packet_type != HCI_EVENT_PACKET)
    {
        printf("L2CAP with size %02X\n", aSize);
        return;
    }
    
    // Run the hci queue as needed
    if (aData[0] == HCI_EVENT_COMMAND_STATUS)
    {
        btpad_queue_run(aData[3]);
    }
    else if (aData[0] == HCI_EVENT_COMMAND_COMPLETE)
    {
        btpad_queue_run(aData[2]);
    }
    
    // We only process while status is HCI_STATE_WORKING
    if (hciState != HCI_STATE_WORKING && aData[0] != BTSTACK_EVENT_STATE)
    {
        return;
    }
        
    switch (aData[0])
    {
        case BTSTACK_EVENT_STATE:
        {
            hciState = aData[2];
            
            if (aData[2] == HCI_STATE_WORKING)
            {
                [vc addMessage:@"Starting BTstack"];
                btpad_queue_hci_read_bd_addr();
                btpad_queue_run(1);
            }
            
            return;
        }
        
        case HCI_EVENT_COMMAND_STATUS:
        {
            if (COMMAND_STATUS_EVENT(aData, hci_inquiry))
            {
                [vc addMessage:@"Inquiry has started."];
                [vc addMessage:@"Press the RED SYNC button on the Wii Remote."];
            }
            else if (COMMAND_STATUS_EVENT(aData, hci_create_connection))
            {
                [vc addMessage:@"Connecting to device."];
            }
            else if (COMMAND_STATUS_EVENT(aData, hci_authentication_requested))
            {
                [vc addMessage:@"Requesting Authentication."];
            }
            else if (COMMAND_STATUS_EVENT(aData, hci_remote_name_request))
            {
                [vc addMessage:@"Requesting Device Name."];
            }
            else
            {
                uint16_t cmd = READ_BT_16(aData, 4);
                [vc addMessage:[NSString stringWithFormat:@"Got unknown 'Command Status' event: %02X %02X", cmd >> 10, cmd & 0x3FF]];
            }
            return;
        }
            
        case HCI_EVENT_COMMAND_COMPLETE:
        {
            if (COMMAND_COMPLETE_EVENT(aData, hci_read_bd_addr))
            {
                memcpy(localMAC, &aData[6], sizeof(bd_addr_t));
                [vc addMessage:[NSString stringWithFormat:@"Local BT MAC address is %s", bd_addr_to_str(localMAC)]];
                
                btpad_queue_hci_inquiry(HCI_INQUIRY_LAP, 48, 1);
            }
            else if (COMMAND_COMPLETE_EVENT(aData, hci_link_key_request_reply))
            {
                [vc addMessage:@"Got 'Link Key Request Reply Complete' event."];
            }
            else
            {
                uint16_t cmd = READ_BT_16(aData, 3);
                [vc addMessage:[NSString stringWithFormat:@"Got unknown 'Command Complete' event: %02X %02X", cmd >> 10, cmd & 0x3FF]];
            }
            
            return;
        }
            
        case HCI_EVENT_INQUIRY_RESULT:
        {
            if (pairingState > WIIWaiting)
            {
                [vc addMessage:@"Got unexpected 'Iquiry Result' event; ignoring."];
                return;
            }
            
            if (aData[2] != 1)
            {
                [vc addMessage:@"'Inquiry Result' event does not specify exactly one result."];
                return;
            }
            
            //

            pairingState = WIIGotInquiry;
            
            [vc addMessage:@"Found device."];
            
            memcpy(&inquiryResult, &aData[3], sizeof(inquiryResult));
            bt_flip_addr(inquiryAddress, &aData[3]);
            
            return;
        }
            
        case HCI_EVENT_INQUIRY_COMPLETE:
        {
            if (aData[2])
            {
                [vc addMessage:@"Got failed 'Inquiry Complete' event."];
                return;
            }
            
            if (pairingState < WIIGotInquiry)
            {
                [vc addMessage:@"Have not found device; will keep looking."];
                btpad_queue_hci_inquiry(HCI_INQUIRY_LAP, 48, 1);
                return;
            }
            else if(pairingState > WIIGotInquiry)
            {
                [vc addMessage:@"Got unexpected 'Inquiry Complete' event; ignoring."];
                return;
            }

            //
            
            pairingState = WIIConnecting;
            
            bt_send_cmd(&hci_create_connection,
                        inquiryAddress,
                        0x18,
                        inquiryResult.page_scan_rep_mode,
                        inquiryResult.page_scan_mode,
                        0x8000 | inquiryResult.clock_offset, 0);

            return;
        }
            
        case HCI_EVENT_CONNECTION_COMPLETE:
        {
            if (pairingState != WIIConnecting || BD_ADDR_CMP(inquiryResult.address, &aData[5]))
            {
                // Don't print this if state is paired: BTstack will call this once for each l2cap_channel_create command.
                if (pairingState != WIIPaired)
                {
                    [vc addMessage:@"Got 'Connection Complete' event for untracked device; ignoring."];
                }
                return;
            }
            
            if (aData[2])
            {
                [vc addMessage:[NSString stringWithFormat:@"Got failed 'Connection Complete' event (Status: %02X)", aData[2]]];
                return;
            }

            //
            
            pairingState = WIIAuthenticating;
            
            [vc addMessage:@"Got connection."];
            
            handle = READ_BT_16(aData, 3);
            btpad_queue_hci_authentication_requested(handle);
            
            return;
        }
            
        case HCI_EVENT_PIN_CODE_REQUEST:
        {
            if (pairingState != WIIAuthenticating || BD_ADDR_CMP(inquiryResult.address, &aData[2]))
            {
                [vc addMessage:@"Got 'Pin Code Request' event for untracked device; ignoring."];
                return;
            }
            
            //

            [vc addMessage:@"Sending PIN code."];
            btpad_queue_hci_pin_code_request_reply(inquiryAddress, localMAC);
            
            return;
        }
            
        case HCI_EVENT_AUTHENTICATION_COMPLETE_EVENT:
        {
            if (handle != READ_BT_16(aData, 3))
            {
                [vc addMessage:@"Got 'Authentication Complete' event for untracked device; ignoring."];
                return;
            }
         
            if (aData[2])
            {
                [vc addMessage:[NSString stringWithFormat:@"Got failed 'Authentication Complete' event (Status: %02X)", aData[2]]];
                return;
            }
            
            //
            
            pairingState = WIIPaired;
            
            [vc addMessage:@"Got authentication."];

            bt_send_cmd(&l2cap_create_channel, inquiryAddress, PSM_HID_CONTROL);
            bt_send_cmd(&l2cap_create_channel, inquiryAddress, PSM_HID_INTERRUPT);
            
            return;
        }
            
        case L2CAP_EVENT_CHANNEL_OPENED:
        {
            const uint16_t psm = READ_BT_16(aData, 11);
            const uint16_t channel_id = READ_BT_16(aData, 13);
            
            if (pairingState != WIIPaired || BD_ADDR_CMP(inquiryResult.address, &aData[3]))
            {
                [vc addMessage:@"Got L2CAP 'Channel Opened' event for untracted device; ignoring."];
                return;
            }
            
            if (psm != PSM_HID_CONTROL && psm != PSM_HID_INTERRUPT)
            {
                [vc addMessage:[NSString stringWithFormat:@"Get L2CAP 'Channel Opened' event for unrecogized PSM (%02X); ignoring.", psm]];
                return;
            }
            
            if (aData[2])
            {
                [vc addMessage:[NSString stringWithFormat:@"Got failed L2CAP 'Channel Opened' event (Status: %02X).", aData[2]]];
                return;
            }
            
            [vc addMessage:[NSString stringWithFormat:@"L2CAP channel opened: (PSM: %02X)\n", psm]];
            channels[(psm == PSM_HID_CONTROL) ? 0 : 1] = channel_id;
            
            if (channels[0] && channels[1])
            {
                [vc addMessage:@"Pairing Complete!"];
            }
            
            return;
        }
    }
}

@interface WIIPairViewController ()

@end

@implementation WIIPairViewController

- (id)init
{
    if ((self = [super init]))
    {
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    vc = self;
    bt_open();
    bt_register_packet_handler(BTstackPacketHandler);
    bt_send_cmd(&btstack_set_power_mode, HCI_POWER_ON);
}

@end
