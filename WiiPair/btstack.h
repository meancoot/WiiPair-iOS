/*  MFiWrapper
 *  Copyright (C) 2014 - Jason Fetters
 * 
 *  MFiWrapper is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  MFiWrapper is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with MFiWrapper.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "btstack/btstack.h"
#include "btstack/utils.h"
#include "btstack/btstack.h"

void btpad_queue_reset();
void btpad_queue_run(uint32_t count);
void btpad_queue_process();

void btpad_queue_btstack_set_power_mode(uint8_t on);
void btpad_queue_hci_read_bd_addr();
void btpad_queue_hci_create_connection(bd_addr_t bd_addr, uint16_t packet_type,
                        uint8_t page_scan_repetition_mode, uint8_t page_scan_mode,
                        uint16_t clock_offset, uint8_t allow_role_switch);
void btpad_queue_hci_disconnect(uint16_t handle, uint8_t reason);
void btpad_queue_hci_inquiry(uint32_t lap, uint8_t length, uint8_t num_responses);
void btpad_queue_hci_remote_name_request(bd_addr_t bd_addr, uint8_t page_scan_repetition_mode, uint8_t reserved, uint16_t clock_offset);
void btpad_queue_hci_pin_code_request_reply(bd_addr_t bd_addr, bd_addr_t pin);
void btpad_queue_hci_authentication_requested(uint16_t handle);
void btpad_queue_hci_set_event_mask(uint32_t a, uint32_t b);
void btpad_queue_hci_write_simple_pairing_mode(uint8_t aMode);
