//
//  ABController.h
//  MacBanking
//
//  Created by Frank Emminghaus on 03.01.07.
//  Copyright 2007 Frank Emminghaus. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <aqbanking/banking.h>
#import "ABAccount.h"
#import "Transfer.h"
#import "LogLevel.h"
#import "StandingOrder.h"

@class BankAccount;
@class Transfer;
@class ABUser;
@class TransactionLimits;
@class BankInfo;
@class ImExporter;
@class ImExporterProfile;
@class ABControllerGui;

@interface ABController : NSObject {
	AB_BANKING				*ab;
	NSMutableArray			*accounts;
	NSMutableArray			*users;
	NSMutableDictionary		*countries;
	ABControllerGui			*abGui;
	id <MessageLog>			log;
}

-(NSMutableArray*)getAccounts;
-(NSMutableArray*)accounts;
-(NSMutableArray*)getUsers;
-(NSMutableArray*)users;
-(ABAccount*)accountByNumber: (NSString*)n bankCode: (NSString*)c;
-(BOOL)checkAccount: (NSString*)accountNumber forBank: (NSString*)bankCode inCountry: (NSString*)country;
-(BOOL)addAccount: (BankAccount*)account forUser: (ABUser*)user;
-(BOOL)deleteAccount: (BankAccount*)account;
-(BOOL)sendTransfers: (NSArray*)transfers;
-(BOOL)checkIBAN: (NSString*)iban;
-(void)statementsForAccounts: (NSArray*)selAccounts;
-(void)standingOrdersForAccounts:(NSArray*)selAccounts;

-(NSString*)bankNameForCode: (NSString*)bankCode inCountry: (NSString*)country;
-(NSString*)bankNameForBic: (NSString*)bic inCountry: (NSString*)country;
-(BankInfo*)infoForBankCode: (NSString*)code inCountry: (NSString*)country;

-(NSString*)addBankUser:(ABUser*)user;
//-(BOOL)removeBankUser: (ABUser*)user;
-(NSString*)getSystemIDForUser:(ABUser*)user;

-(NSArray*)getImExporters;
-(void)importForAccounts:(NSMutableArray*)selAccounts module:(ImExporter*)ie profile:(ImExporterProfile*)iep dataFile:(NSString*)file;

-(BOOL)isTransferSupported:(TransferType)tt forAccount:(BankAccount*)account;
-(BOOL)isStandingOrderSupportedForAccount:(BankAccount*)account;

-(NSArray*)allowedCountriesForAccount:(BankAccount*)account;
-(TransactionLimits*)limitsForType:(TransferType)tt account:(BankAccount*)account country:(NSString*)ctry;
-(TransactionLimits*)standingOrderLimitsForAccount:(BankAccount*)account action:(StandingOrderAction)action;
-(BOOL)updateStandingOrders:(NSArray*)orders;

-(NSDictionary*)countries;

-(void)startLog:(id <MessageLog>)logger withLevel:(LogLevel)level withDetails:(BOOL)details;
-(void)endLog;

+(ABController*)controller;

@end
