//
//  WIIAppDelegate.h
//  WiiPair
//
//  Created by Jason Fetters on 2/7/14.
//  Copyright (c) 2014 WiiPair. All rights reserved.
//

#include <stdint.h>
#import <UIKit/UIKit.h>
#include "btstack.h"

uint64_t bd_addr_to_uint(bd_addr_t address);

@protocol BTstackListener
@optional

- (void)btstackEventState:(uint8_t*)aData size:(uint16_t)aSize;
- (void)hciEventCommandStatus:(uint8_t*)aData size:(uint16_t)aSize;
- (void)hciEventCommandComplete:(uint8_t*)aData size:(uint16_t)aSize;
- (void)hciEventInquiryResult:(uint8_t*)aData size:(uint16_t)aSize;
- (void)hciEventInquiryComplete:(uint8_t*)aData size:(uint16_t)aSize;
- (void)hciEventConnectionComplete:(uint8_t*)aData size:(uint16_t)aSize;
- (void)hciEventRemoteNameRequestComplete:(uint8_t*)aData size:(uint16_t)aSize;
- (void)hciEventAuthenticationComplete:(uint8_t*)aData size:(uint16_t)aSize;
- (void)hciEventPinCodeRequest:(uint8_t*)aData size:(uint16_t)aSize;
- (void)l2capEventChannelOpened:(uint8_t*)aData size:(uint16_t)aSize;

@end

#pragma pack(push, 1)
struct InquiryResult
{
    bd_addr_t address;
    uint8_t page_scan_rep_mode;
    uint8_t page_scan_per_mode;
    uint8_t page_scan_mode;
    uint32_t class_of_device;
    uint16_t clock_offset;
};
#pragma(pop)

@interface BTstackDevice : NSObject
@property (copy) NSString* name;
@property struct InquiryResult data;
@property (retain) NSNumber* hash;

- (id)initWithData:(uint8_t*)data stride:(uint32_t)stride;
@end


@interface WIIAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) id<BTstackListener> btListener;

@end
