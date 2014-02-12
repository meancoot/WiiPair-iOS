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

uint64_t bd_addr_to_uint(bd_addr_t address)
{
    uint64_t result = 0;
    
    for (uint64_t i = 0; i != 6; i ++)
        result |= address[i] << (i * 8);
    return result;
}

@implementation BTstackDevice

- (id)initWithData:(uint8_t*)data stride:(uint32_t)stride
{
    if ((self = [super init]))
    {
        #define ADDRESS_OFF             0
        #define PAGE_SCAN_REP_OFF       (ADDRESS_OFF            + stride * 6)
        #define PAGE_SCAN_PER_OFF       (PAGE_SCAN_REP_OFF      + stride * 1)
        #define PAGE_SCAN_MODE_OFF      (PAGE_SCAN_PER_OFF      + stride * 1)
        #define CLASS_OF_DEVICE_OFF     (PAGE_SCAN_MODE_OFF     + stride * 1)
        #define CLOCK_OFFSET_OFF        (CLASS_OF_DEVICE_OFF    + stride * 3)
        memcpy(_data.address, &data[0], sizeof(bd_addr_t));
        _data.page_scan_rep_mode = data[PAGE_SCAN_REP_OFF];
        _data.page_scan_per_mode = data[PAGE_SCAN_PER_OFF];
        _data.page_scan_mode     = data[PAGE_SCAN_MODE_OFF];
        _data.class_of_device    = READ_BT_24(data, CLASS_OF_DEVICE_OFF);
        _data.clock_offset       = READ_BT_16(data, CLOCK_OFFSET_OFF);
        
        self.name = nil;
        self.hash = [NSNumber numberWithUnsignedLongLong:bd_addr_to_uint(_data.address)];        
    }
    
    return self;
}

@end

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
    
    WIIAppDelegate* delegate = [[UIApplication sharedApplication] delegate];
    NSObject<BTstackListener>* listener = (NSObject<BTstackListener>*)delegate.btListener;
    
#define PumpTo(X) if ([listener respondsToSelector:@selector(X:size:)]) [listener X:aData size:aSize]
    
    switch (aData[0])
    {
        case BTSTACK_EVENT_STATE:                       PumpTo(btstackEventState);                  return;
        case HCI_EVENT_COMMAND_STATUS:                  PumpTo(hciEventCommandStatus);              return;
        case HCI_EVENT_COMMAND_COMPLETE:                PumpTo(hciEventCommandComplete);            return;
        case HCI_EVENT_INQUIRY_RESULT:                  PumpTo(hciEventInquiryResult);              return;
        case HCI_EVENT_INQUIRY_COMPLETE:                PumpTo(hciEventInquiryComplete);            return;
        case HCI_EVENT_CONNECTION_COMPLETE:             PumpTo(hciEventConnectionComplete);         return;
        case HCI_EVENT_REMOTE_NAME_REQUEST_COMPLETE:    PumpTo(hciEventRemoteNameRequestComplete);  return;
        case HCI_EVENT_AUTHENTICATION_COMPLETE_EVENT:   PumpTo(hciEventAuthenticationComplete);     return;
        case HCI_EVENT_PIN_CODE_REQUEST:                PumpTo(hciEventPinCodeRequest);             return;            
        case L2CAP_EVENT_CHANNEL_OPENED:                PumpTo(l2capEventChannelOpened);            return;
        default:                                        NSLog(@"Unhandle packet: %02X\n", aData[0]);return;
    }
}


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
    bt_register_packet_handler(BTstackPacketHandler);
    bt_open();
    btpad_queue_reset();
    btpad_queue_btstack_set_power_mode(1);
    
    _navigationController = [[UINavigationController alloc] initWithRootViewController:[WIIMainViewViewController new]];
    self.window.rootViewController = _navigationController;
    
    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

@end
