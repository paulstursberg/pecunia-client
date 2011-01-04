//
//  StandingOrderTabController.m
//  Pecunia
//
//  Created by Frank Emminghaus on 26.11.10.
//  Copyright 2010 Frank Emminghaus. All rights reserved.
//

#import "StandingOrderTabController.h"
#import "MOAssistant.h"
#import "StandingOrder.h"
#import "HBCIClient.h"
#import "BankAccount.h"
#import "TransactionLimits.h"
#import "BankQueryResult.h"

@implementation StandingOrderTabController

@synthesize oldMonthCycle;
@synthesize oldMonthDay;
@synthesize oldWeekCycle;
@synthesize oldWeekDay;
@synthesize currentLimits;
@synthesize currentOrder;

-(id)init
{
	self = [super init ];
	if (self == nil) return nil;
	
	managedObjectContext = [[MOAssistant assistant ] context ];
	weekDays = [NSArray arrayWithObjects:@"Montag",@"Dienstag",@"Mittwoch",@"Donnerstag",@"Freitag",@"Samstag",@"Sonntag",nil ];
	[weekDays retain ];
	accounts = [[NSMutableArray alloc ] initWithCapacity:10 ];
	return self;
}

-(void)awakeFromNib
{
	NSError *error = nil;
	NSManagedObjectModel *model = [[MOAssistant assistant ] model ];
	NSFetchRequest *request = [model fetchRequestTemplateForName:@"allBankAccounts"];
	NSArray *selectedAccounts = [managedObjectContext executeFetchRequest:request error:&error];
	if(error == nil) {
		for(BankAccount *account in selectedAccounts) {
			if ([[HBCIClient hbciClient ] isStandingOrderSupportedForAccount:account]) {
				[accounts addObject:account ];
			}
		}
	}
	[accountsController setContent:accounts ];
}

-(void)prepare
{
	
}

-(void)terminate
{
	
}

-(NSString*)monthDayToString:(int)day
{
	if (day == 97) return @"Ultimo-2";
	else if (day == 98) return @"Ultimo-1";
	else if (day == 99) return @"Ultimo";
	else return [NSString stringWithFormat:@"%d." , day ];
}

-(NSString*)weekDayToString:(int)day
{
	if (day > 0 && day < 8) {
		return [weekDays objectAtIndex:day-1 ];
	}
	return [weekDays objectAtIndex:1 ];;
}

-(int)stringToMonthDay:(NSString*)s
{
	if ([s isEqualToString:@"Ultimo-2" ]) return 97;
	else if ([s isEqualToString:@"Ultimo-1" ]) return 98;
	else if ([s isEqualToString:@"Ultimo" ]) return 99;
	else return [[s substringToIndex:[s length ] - 1 ] intValue ];
}

-(void)initCycles
{
	currentOrder.cycle = [NSNumber numberWithInt:1];
	currentOrder.executionDay = [NSNumber numberWithInt:1];
}

-(int)stringToWeekDay:(NSString*)s
{
	return [weekDays indexOfObject:s ] + 1;
}

-(void)enableWeekly:(BOOL)weekly
{
	if (weekly) {
		[execDaysMonthPopup setTitle:@"" ];
		[monthCyclesPopup setTitle:@"" ];
	} else {
		[execDaysWeekPopup setTitle:@"" ];
		[weekCyclesPopup setTitle:@"" ];
	} 
	[execDaysMonthPopup setEnabled:!weekly ];
	[monthCyclesPopup setEnabled:!weekly ];
	[execDaysWeekPopup setEnabled:weekly ];
	[weekCyclesPopup setEnabled:weekly ];
}

-(void)updateWeekCycles
{
	int i;
	
	NSMutableArray *weekCycles = [NSMutableArray arrayWithCapacity:52 ];
	if (currentLimits.weekCycles == nil || [currentLimits.weekCycles count] == 0 || [[currentLimits.weekCycles lastObject ] intValue ] == 0) {
		for(i=1;i<=52;i++) [weekCycles addObject:[NSString stringWithFormat:@"%d",i ] ];
	} else {
		for(NSString *s in currentLimits.weekCycles) [weekCycles addObject:[NSString stringWithFormat:@"%d", [s intValue ] ]];
	}
	[weekCyclesController setContent:weekCycles ];
	[weekCyclesPopup selectItemWithTitle:[NSString stringWithFormat:@"%d",[currentOrder.cycle intValue ] ]];
	
	NSMutableArray *execDays = [NSMutableArray arrayWithCapacity:7 ];
	if (currentLimits.execDaysWeek == nil || [currentLimits.execDaysWeek count] == 0 || [[currentLimits.execDaysWeek lastObject ] intValue ] == 0) {
		for(i=1;i<=7;i++) [execDays addObject:[self weekDayToString: i ] ];
	} else {
		for(NSString *s in currentLimits.execDaysWeek) [execDays addObject:[self weekDayToString:[s intValue ] ] ];
	}
	
	[execDaysWeekController setContent:execDays ];
	[execDaysWeekPopup selectItemWithTitle:[self weekDayToString: [currentOrder.executionDay intValue ] ]];
}

-(void)updateMonthCycles
{
	int i;
	
	NSMutableArray *monthCycles = [NSMutableArray arrayWithCapacity:12 ];
	if (currentLimits.monthCycles == nil || [currentLimits.monthCycles count] == 0 || [[currentLimits.monthCycles lastObject ] intValue ] == 0) {
		for(i=1;i<=12;i++) [monthCycles addObject:[NSString stringWithFormat:@"%d",i ] ];
	} else {
		for(NSString *s in currentLimits.monthCycles) [monthCycles addObject:[NSString stringWithFormat:@"%d", [s intValue ] ]];
	}
	
	[monthCyclesController setContent:monthCycles ];
	[monthCyclesPopup selectItemWithTitle:[NSString stringWithFormat:@"%d",[currentOrder.cycle intValue ] ]];
	
	NSMutableArray *execDays = [NSMutableArray arrayWithCapacity:31 ];
	if (currentLimits.execDaysMonth == nil || [currentLimits.execDaysMonth count] == 0 || [[currentLimits.execDaysMonth lastObject ] intValue ] == 0) {
		for(i=1;i<=28;i++) [execDays addObject:[NSString stringWithFormat:@"%d.",i ] ];
		[execDays addObject:@"Ultimo-2" ];
		[execDays addObject:@"Ultimo-1" ];
		[execDays addObject:@"Ultimo" ];
	} else {
		for(NSString *s in currentLimits.execDaysMonth) {
			[execDays addObject:[self monthDayToString: [s intValue ] ] ];
		}
	}
	
	[execDaysMonthController setContent:execDays ];
	[execDaysMonthPopup selectItemWithTitle:[self monthDayToString: [currentOrder.executionDay intValue ] ]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSArray *sel = [orderController selectedObjects ];
	if (sel == nil || [sel count ] == 0) return;
	self.currentOrder = [sel objectAtIndex:0 ];
	
	oldWeekDay = nil; oldWeekCycle = nil; oldMonthDay =  nil; oldMonthCycle = nil;
	if (currentOrder.orderKey == nil) {
		self.currentLimits = [[HBCIClient hbciClient ] standingOrderLimitsForAccount:currentOrder.account action:stord_create ];
	} else {
		self.currentLimits = [[HBCIClient hbciClient ] standingOrderLimitsForAccount:currentOrder.account action:stord_change ];
	}

	StandingOrderPeriod period = [currentOrder.period intValue ];
	if (period == stord_weekly) {
		[self enableWeekly:YES ];
		[weekCell setState:NSOnState ];
		[monthCell setState:NSOffState ];
		[self updateWeekCycles ];
		[weekCyclesPopup setEnabled:currentLimits.allowChangeCycle ];
		[execDaysWeekPopup setEnabled:currentLimits.allowChangeExecDay ];
	} else {
		[self enableWeekly:NO ];
		[weekCell setState:NSOffState ];
		[monthCell setState:NSOnState ];
		[self updateMonthCycles ];
		[monthCyclesPopup setEnabled:currentLimits.allowChangeCycle ];
		[execDaysMonthPopup setEnabled:currentLimits.allowChangeExecDay ];
	}		
	
	[weekCell setEnabled: currentLimits.allowWeekly];
	[monthCell setEnabled: currentLimits.allowMonthly];	
}

-(IBAction)monthCycle:(id)sender
{
	StandingOrderPeriod period = [currentOrder.period intValue ];
	if (period == stord_weekly) {
		self.oldWeekDay = currentOrder.executionDay;
		self.oldWeekCycle = currentOrder.cycle;
		if(oldMonthDay) currentOrder.executionDay = oldMonthDay; else currentOrder.executionDay = [NSNumber numberWithInt:1 ];
		if(oldMonthCycle) currentOrder.cycle = oldMonthCycle; else currentOrder.cycle = [NSNumber numberWithInt:1 ];
	}
	[self enableWeekly:NO ];
	currentOrder.period = [NSNumber numberWithInt:stord_monthly ];
	currentOrder.isChanged = [NSNumber numberWithBool:YES ];
	[self updateMonthCycles ];
}

-(IBAction)weekCycle:(id)sender
{
	StandingOrderPeriod period = [currentOrder.period intValue ];
	if (period == stord_monthly) {
		self.oldMonthDay = currentOrder.executionDay;
		self.oldMonthCycle = currentOrder.cycle;
		if(oldWeekDay) currentOrder.executionDay = oldWeekDay; else currentOrder.executionDay = [NSNumber numberWithInt:1 ];
		if(oldWeekCycle) currentOrder.cycle = oldWeekCycle; else currentOrder.cycle = [NSNumber numberWithInt:1 ];
	}
	[self enableWeekly:YES ];
	currentOrder.period = [NSNumber numberWithInt:stord_weekly ];
	currentOrder.isChanged = [NSNumber numberWithBool:YES ];
	[self updateWeekCycles ];
	
}

-(IBAction)monthCycleChanged:(id)sender
{
	currentOrder.cycle = [NSNumber numberWithInt:[[monthCyclesPopup titleOfSelectedItem ] intValue ] ];
	currentOrder.isChanged = [NSNumber numberWithBool:YES ];
}

-(IBAction)monthDayChanged:(id)sender
{
	currentOrder.executionDay = [NSNumber numberWithInt:[self stringToMonthDay:[execDaysMonthPopup titleOfSelectedItem ] ]];
	currentOrder.isChanged = [NSNumber numberWithBool:YES ];
}

-(IBAction)weekCycleChanged:(id)sender
{
	currentOrder.cycle = [NSNumber numberWithInt:[[weekCyclesPopup titleOfSelectedItem ] intValue ] ];
	currentOrder.isChanged = [NSNumber numberWithBool:YES ];
}

-(IBAction)weekDayChanged:(id)sender
{
	currentOrder.executionDay = [NSNumber numberWithInt: [self stringToWeekDay:[execDaysWeekPopup titleOfSelectedItem ] ]];
	currentOrder.isChanged = [NSNumber numberWithBool:YES ];
}

-(void)add
{
	int res = [NSApp runModalForWindow:selectAccountWindow ];
	if (res) {
		NSArray *sel = [accountsController selectedObjects ];
		if (sel == nil || [sel count ] != 1) return;
		BankAccount *account = [sel lastObject ];
		
		StandingOrder *stord = [NSEntityDescription insertNewObjectForEntityForName:@"StandingOrder"
															 inManagedObjectContext:managedObjectContext];
		stord.account = account;
		stord.period = [NSNumber numberWithInt:stord_monthly ];
		stord.cycle = [NSNumber numberWithInt:1 ];
		stord.executionDay = [NSNumber numberWithInt:1 ];
		stord.isChanged = [NSNumber numberWithBool:YES ];
		stord.currency = account.currency;
		
		[orderController addObject:stord ];
		[orderController setSelectedObjects:[NSArray arrayWithObject:stord ] ];
	}
}

-(void)delete
{
	NSArray *sel = [orderController selectedObjects ];
	if (sel == nil || [sel count ] != 1) return;
	StandingOrder *order = [sel lastObject ];
	if (order.orderKey == nil) [managedObjectContext deleteObject:order ];
	else order.isDeleted = [NSNumber numberWithBool:YES ];
}

-(IBAction)accountsOk:(id)sender
{
	[selectAccountWindow close ];
	[NSApp stopModalWithCode:1 ];
}

-(IBAction)accountsCancel:(id)sender
{
	[selectAccountWindow close ];
	[NSApp stopModalWithCode:0 ];
}

-(IBAction)firstExecDateChanged:(id)sender
{
	currentOrder.isChanged = [NSNumber numberWithBool:YES ];
}

-(IBAction)lastExecDateChanged:(id)sender
{
	currentOrder.isChanged = [NSNumber numberWithBool:YES ];
}

-(void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	NSTextField	*te = [aNotification object ];
	NSString	*bankName;
	
	if([te tag ] == 100) {
		bankName = [[HBCIClient hbciClient  ] bankNameForCode: [te stringValue ] inCountry: currentOrder.account.country ];
		if(bankName) currentOrder.remoteBankName = bankName;
	}
	currentOrder.isChanged = [NSNumber numberWithBool:YES ];
}


-(IBAction)segButtonPressed:(id)sender
{
	int clickedSegment = [sender selectedSegment];
    int clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
	switch(clickedSegmentTag) {
		case 0: [self add ]; break;
		case 1: [self delete ]; break;
//		case 2: [self edit: sender ]; break;
		default: return;
	}
}

- (void)dealloc
{
	[currentLimits release], currentLimits = nil;
	[currentOrder release], currentOrder = nil;
	[weekDays release ];
	[accounts release ];
	
	[oldMonthCycle release], oldMonthCycle = nil;
	[oldMonthDay release], oldMonthDay = nil;
	[oldWeekCycle release], oldWeekCycle = nil;
	[oldWeekDay release], oldWeekDay = nil;

	[super dealloc];
}

-(IBAction)update:(id)sender
{
	[[HBCIClient hbciClient ] updateStandingOrders: [orderController arrangedObjects ]];
}

-(IBAction)getOrders:(id)sender
{
	BankAccount *account;
	
	NSMutableArray *resultList = [[NSMutableArray arrayWithCapacity: [accounts count ] ] retain ];
	for(account in accounts) {
		if (account.userId) {
			BankQueryResult *result = [[BankQueryResult alloc ] init ];
			result.accountNumber = account.accountNumber;
			result.bankCode = account.bankCode;
			result.userId = account.userId;
			result.account = account;
			[resultList addObject: [result autorelease] ];
		}
	}
	
	[[HBCIClient hbciClient ] getStandingOrders: resultList ];
}


-(NSView*)mainView
{
	return mainView;
}
	

@end


