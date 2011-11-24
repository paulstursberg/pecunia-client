//
//  AccountRepWindowController.h
//  Pecunia
//
//  Created by Frank Emminghaus on 03.09.08.
//  Copyright 2008 Frank Emminghaus. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CorePlot/CorePlot.h>

#import "MainTabViewItem.h"
#import "ColumnLayoutCorePlotLayer.h"

@class SM2DGraphView;
@class Category;
@class ShortDate;
@class TimeSliceManager;

@interface PecuinaGraphHost : CPTGraphHostingView
{
    NSTrackingArea* trackingArea; // To get mouse events, regardless of responder or key window state.
}

@end

@interface PecuinaSelectionGraphHost : PecuinaGraphHost
{
    CPTLimitBand* selector;
}

@property (nonatomic, retain) CPTLimitBand* selector;

@end

@interface AccountRepWindowController : NSObject <MainTabViewItem, CPTScatterPlotDataSource, CPTPlotSpaceDelegate, CPTPlotDataSource, CPTBarPlotDelegate>
{
    IBOutlet NSTreeController	*accountsController;
	IBOutlet NSOutlineView      *accountsView;
	IBOutlet NSSplitView		*splitView;
	IBOutlet NSView				*mainView;
	IBOutlet NSView				*printView;

	NSManagedObjectContext		*managedObjectContext;
	
    // New graph
    IBOutlet PecuinaGraphHost *mainHostView;
    IBOutlet PecuinaGraphHost *turnoversHostView;
    IBOutlet PecuinaSelectionGraphHost *selectionHostView;
    
    @private
	CPTXYGraph* mainGraph;
    CPTXYGraph* turnoversGraph;
    CPTXYGraph* selectionGraph;
    CPTXYAxis* mainIndicatorLine;
    CPTXYAxis* turnoversIndicatorLine;
    ColumnLayoutCorePlotLayer* infoLayer; // Content layer of the info annotation.
    CPTAnnotation* infoAnnotation;        // The host of the info layer placed in the plot area.
    CPTTextLayer* dateInfoLayer;
    CPTTextLayer* valueInfoLayer;
    CPTLimitBand* selectionBand;
    
	NSArray* dates;
    NSArray* balances;
    NSArray* balanceCounts;               // Number of balances per day.
    NSNumberFormatter* infoTextFormatter;

	ShortDate* fromDate;
	ShortDate* toDate;
    ShortDate* lastInfoDate;              // The date for which the info text was last updated.
    
    CGFloat barWidth;
    NSDecimalNumber* minValue;            // The minimum value of the currently selected category.
    NSDecimalNumber* maxValue;            // Ditto for maximum.
}

@property (nonatomic, retain) ShortDate *fromDate;
@property (nonatomic, retain) ShortDate *toDate;

@property (nonatomic, readwrite) CGFloat barWidth;

//- (void)prepare;
//- (void)terminate;

- (void)updateValues;
- (void)clearGraphs;
- (NSView*)mainView;

- (Category*)currentSelection;

- (void)setupMainGraph;
- (void)setupTurnoversGraph;
- (void)setupSelectionGraph;

- (void)setupMainPlots;
- (void)setupTurnoversPlot;
- (void)setupSelectionPlot;

- (void)updateMainGraph;
- (void)updateTurnoversGraph;
- (void)updateSelectionGraph;
- (void)updateSelectionDisplay;

@end
