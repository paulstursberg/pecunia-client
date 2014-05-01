/**
 * Copyright (c) 2011, 2014, Pecunia Project. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; version 2 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301  USA
 */

#import <Cocoa/Cocoa.h>

#import "PecuniaListViewCell.h"

@protocol StatementsListViewNotificationProtocol
- (void)cellActivationChanged: (BOOL)state forIndex: (NSUInteger)index;
@end

@interface StatementsListViewCell : PecuniaListViewCell
{
    IBOutlet NSTextField *dateLabel;
    IBOutlet NSTextField *turnoversLabel;
    IBOutlet NSTextField *remoteNameLabel;
    IBOutlet NSTextField *purposeLabel;
    IBOutlet NSTextField *noteLabel;
    IBOutlet NSTextField *categoriesLabel;
    IBOutlet NSTextField *valueLabel;
    IBOutlet NSImageView *newImage;
    IBOutlet NSTextField *currencyLabel;
    IBOutlet NSTextField *saldoLabel;
    IBOutlet NSTextField *saldoCurrencyLabel;
    IBOutlet NSTextField *transactionTypeLabel;
    IBOutlet NSButton    *checkbox;
    IBOutlet NSTextField *dayLabel;
    IBOutlet NSTextField *monthLabel;
}

@property (nonatomic, strong) id   delegate;
@property (nonatomic, assign) BOOL hasUnassignedValue;

- (IBAction)activationChanged: (id)sender;

- (void)setHeaderHeight: (int)aHeaderHeight;
- (void)setDetails: (NSDictionary *)details;
- (void)setIsNew: (BOOL)flag;
- (void)showActivator: (BOOL)flag markActive: (BOOL)active;
- (void)showBalance: (BOOL)flag;

@end
