//
//  AccountRepWindowController.m
//  Pecunia
//
//  Created by Frank Emminghaus on 03.09.08.
//  Copyright 2008 Frank Emminghaus. All rights reserved.
//

#include <math.h>

#import "AccountRepWindowController.h"
#import "Category.h"
#import "MCEMOutlineViewLayout.h"
#import "ShortDate.h"
#import "TimeSliceManager.h"
#import "MOAssistant.h"
#import "ImageAndTextCell.h"
#import "BankAccount.h"

#import "NumberExtensions.h"

static NSTimeInterval oneDay = 24 * 60 * 60;

static NSString* const PecuniaGraphLayoutChangeNotification = @"PecuniaGraphLayoutChange";
static NSString* const PecuniaGraphMouseExitedNotification = @"PecuniaGraphMouseExited";

@implementation PecuinaGraphHost

- (void)updateTrackingArea
{
    if (trackingArea != nil)
    {
        [self removeTrackingArea: trackingArea];
        [trackingArea release];
    }

    CPTXYPlotSpace* plotSpace = (id)[self hostedGraph].defaultPlotSpace;
    if (plotSpace.allowsUserInteraction) {
        trackingArea = [[[NSTrackingArea alloc] initWithRect: NSRectFromCGRect(self.hostedGraph.plotAreaFrame.frame)
                                                     options: NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInActiveApp
                                                       owner: self
                                                    userInfo: nil]
                        retain];
        [self addTrackingArea: trackingArea];
    }
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame: frameRect];
    [self updateTrackingArea];
    return self;
}

- (void)dealloc
{
    [self removeTrackingArea: trackingArea];
    [trackingArea release];
    [super dealloc];
}

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];
    
    [self updateTrackingArea];
}

- (BOOL) acceptsFirstResponder
{
  return YES;
}

-(void)scrollWheel: (NSEvent*)theEvent
{
    CPTXYPlotSpace* plotSpace = (id)[self hostedGraph].defaultPlotSpace;
    if (!plotSpace.allowsUserInteraction) {
        [super scrollWheel: theEvent];
        return;
    }
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionary];
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    
    short subtype = [theEvent subtype];
    if (subtype == NSTabletPointEventSubtype)
    {
        // A trackpad gesture (usually two-finger swipe).
        [parameters setObject: @"plotMoveSwipe" forKey: @"type"];

        CGFloat distance = [theEvent deltaX];

        NSNumber* location = [NSNumber numberWithDouble: plotSpace.xRange.locationDouble - plotSpace.xRange.lengthDouble * distance / 100];
        [parameters setObject: location forKey: @"plotXLocation"];
        
        NSNumber* range = [NSNumber numberWithDouble: CPTDecimalDoubleValue(plotSpace.xRange.length)];
        [parameters setObject: range forKey: @"plotXRange"];
    }
    else 
    {
        [parameters setObject: @"plotScale" forKey: @"type"];
        
        CGFloat distance = [theEvent deltaY];
        
        // Range location and size.
        NSNumber* location = [NSNumber numberWithDouble: plotSpace.xRange.locationDouble];
        [parameters setObject: location forKey: @"plotXLocation"];

        NSNumber* range = [NSNumber numberWithDouble: plotSpace.xRange.lengthDouble * (1 + distance / 100)];
        [parameters setObject: range forKey: @"plotXRange"];
    }
    
    // Current mouse position.
    CGPoint mouseLocation = NSPointToCGPoint([self convertPoint: [theEvent locationInWindow] fromView: nil]);
    CGPoint pointInHostedGraph = [self.layer convertPoint: mouseLocation toLayer: self.hostedGraph.plotAreaFrame.plotArea];
    [parameters setObject: [NSNumber numberWithFloat: pointInHostedGraph.x] forKey: @"mousePosition"];
    
    [center postNotificationName: PecuniaGraphLayoutChangeNotification object: plotSpace userInfo: parameters];
}

/**
 * Allow zooming the graph with a pinch gesture on a trackpad.
 */
-(void)magnifyWithEvent: (NSEvent*)theEvent
{
    CPTXYPlotSpace* plotSpace = (id)[self hostedGraph].defaultPlotSpace;
    if (!plotSpace.allowsUserInteraction) {
        [super magnifyWithEvent: theEvent];
        return;
    }
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionary];
   [parameters setObject: @"plotScale" forKey: @"type"];

    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    
    CGFloat relativeScale = [theEvent magnification];
    
    NSNumber* location = [NSNumber numberWithDouble: plotSpace.xRange.locationDouble];
    [parameters setObject: location forKey: @"plotXLocation"];

    NSNumber* range = [NSNumber numberWithDouble: plotSpace.xRange.lengthDouble * (1 - relativeScale)];
    [parameters setObject: range forKey: @"plotXRange"];

    CGPoint mouseLocation = NSPointToCGPoint([self convertPoint: [theEvent locationInWindow] fromView: nil]);
    CGPoint pointInHostedGraph = [self.layer convertPoint: mouseLocation toLayer: self.hostedGraph.plotAreaFrame.plotArea];
    [parameters setObject: [NSNumber numberWithFloat: pointInHostedGraph.x] forKey: @"mousePosition"];
    
    [center postNotificationName: PecuniaGraphLayoutChangeNotification object: plotSpace userInfo: parameters];
}

- (void)mouseMoved: (NSEvent*)theEvent
{
    [super mouseMoved: theEvent];
    
    CPTXYPlotSpace* plotSpace = (id)[self hostedGraph].defaultPlotSpace;
    if (!plotSpace.allowsUserInteraction) {
        return;
    }
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionary];
    [parameters setObject: @"trackLineMove" forKey: @"type"];
    
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    
    NSPoint location = [self convertPoint: [theEvent locationInWindow] fromView: nil];
    CGPoint mouseLocation = NSPointToCGPoint(location);
    CGPoint pointInHostedGraph = [self.layer convertPoint: mouseLocation toLayer: self.hostedGraph.plotAreaFrame.plotArea];
    [parameters setObject: [NSNumber numberWithFloat: pointInHostedGraph.x] forKey: @"location"];
    [center postNotificationName: PecuniaGraphLayoutChangeNotification object: plotSpace userInfo: parameters];
}

- (void)mouseDragged: (NSEvent*)theEvent
{
    CPTXYPlotSpace* plotSpace = (id)[self hostedGraph].defaultPlotSpace;
    if (!plotSpace.allowsUserInteraction) {
        [super mouseDragged: theEvent];
        return;
    }
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionary];
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    
    [parameters setObject: @"plotMoveDrag" forKey: @"type"];
    
    CGFloat distance = [theEvent deltaX];
    
    NSNumber* location = [NSNumber numberWithDouble: plotSpace.xRange.locationDouble - plotSpace.xRange.lengthDouble * distance / 1000];
    [parameters setObject: location forKey: @"plotXLocation"];
    
    NSNumber* range = [NSNumber numberWithDouble: CPTDecimalDoubleValue(plotSpace.xRange.length)];
    [parameters setObject: range forKey: @"plotXRange"];
    [center postNotificationName: PecuniaGraphLayoutChangeNotification object: plotSpace userInfo: parameters];
}

- (void)mouseExited: (NSEvent*)theEvent
{
    [super mouseExited: theEvent];
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center postNotificationName: PecuniaGraphMouseExitedNotification object: nil userInfo: nil];
}

@end;

@implementation PecuinaSelectionGraphHost

@synthesize selector;

-(void)scrollWheel: (NSEvent*)theEvent
{
    CPTXYPlotSpace* plotSpace = (id)[self hostedGraph].defaultPlotSpace;
    if (!plotSpace.allowsUserInteraction) {
        [super scrollWheel: theEvent];
        return;
    }
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionary];
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    
    short subtype = [theEvent subtype];
    if (subtype == NSTabletPointEventSubtype)
    {
        // A trackpad gesture (usually two-finger swipe).
        [parameters setObject: @"plotMoveSwipe" forKey: @"type"];

        CGFloat distance = [theEvent deltaX];

        NSNumber* location = [NSNumber numberWithDouble: selector.range.locationDouble + plotSpace.xRange.lengthDouble * distance / 100];
        [parameters setObject: location forKey: @"plotXLocation"];
        
        NSNumber* range = [NSNumber numberWithDouble: CPTDecimalDoubleValue(selector.range.length)];
        [parameters setObject: range forKey: @"plotXRange"];
    }
    else 
    {
        [parameters setObject: @"plotScale" forKey: @"type"];
        
        CGFloat distance = [theEvent deltaY];
        
        // Range location and size.
        NSNumber* location = [NSNumber numberWithDouble: selector.range.locationDouble];
        [parameters setObject: location forKey: @"plotXLocation"];

        NSNumber* range = [NSNumber numberWithDouble: selector.range.lengthDouble * (1 + distance / 100)];
        [parameters setObject: range forKey: @"plotXRange"];
    }
    
    // Current mouse position.
    CGPoint mouseLocation = NSPointToCGPoint([self convertPoint: [theEvent locationInWindow] fromView: nil]);
    CGPoint pointInHostedGraph = [self.layer convertPoint: mouseLocation toLayer: self.hostedGraph.plotAreaFrame.plotArea];
    [parameters setObject: [NSNumber numberWithFloat: pointInHostedGraph.x] forKey: @"mousePosition"];
    
    [center postNotificationName: PecuniaGraphLayoutChangeNotification object: plotSpace userInfo: parameters];
}

/**
 * Zooming with pinch, very similar to the normal host handling.
 */
-(void)magnifyWithEvent: (NSEvent*)theEvent
{
    CPTXYPlotSpace* plotSpace = (id)[self hostedGraph].defaultPlotSpace;
    if (!plotSpace.allowsUserInteraction) {
        [super magnifyWithEvent: theEvent];
        return;
    }
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionary];
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    
   [parameters setObject: @"plotScale" forKey: @"type"];

    CGFloat relativeScale = [theEvent magnification];
    
    NSNumber* location = [NSNumber numberWithDouble: selector.range.locationDouble];
    [parameters setObject: location forKey: @"plotXLocation"];

    NSNumber* range = [NSNumber numberWithDouble: selector.range.lengthDouble * (1 - relativeScale)];
    [parameters setObject: range forKey: @"plotXRange"];

    CGPoint mouseLocation = NSPointToCGPoint([self convertPoint: [theEvent locationInWindow] fromView: nil]);
    CGPoint pointInHostedGraph = [self.layer convertPoint: mouseLocation toLayer: self.hostedGraph.plotAreaFrame.plotArea];
    [parameters setObject: [NSNumber numberWithFloat: pointInHostedGraph.x] forKey: @"mousePosition"];
    
    [center postNotificationName: PecuniaGraphLayoutChangeNotification object: plotSpace userInfo: parameters];
}

- (void)mouseMoved: (NSEvent*)theEvent
{
}

- (void)sendPlotMoveNotification: (NSEvent*)theEvent
{
    CPTXYPlotSpace* plotSpace = (id)[self hostedGraph].defaultPlotSpace;
    if (!plotSpace.allowsUserInteraction) {
        [super mouseDragged: theEvent];
        return;
    }
    
    NSMutableDictionary* parameters = [NSMutableDictionary dictionary];
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    
    [parameters setObject: @"plotMoveCenter" forKey: @"type"];
    
    NSNumber* range = [NSNumber numberWithDouble: selector.range.lengthDouble];
    [parameters setObject: range forKey: @"plotXRange"];

    // Current mouse position as new center.
    CGPoint mouseLocation = NSPointToCGPoint([self convertPoint: [theEvent locationInWindow] fromView: nil]);
    CGPoint pointInHostedGraph = [self.layer convertPoint: mouseLocation toLayer: self.hostedGraph.plotAreaFrame.plotArea];
    [parameters setObject: [NSNumber numberWithFloat: pointInHostedGraph.x] forKey: @"location"];
    
    [center postNotificationName: PecuniaGraphLayoutChangeNotification object: plotSpace userInfo: parameters];
}

/**
 * When the user clicks on the selection graph then we move the selection directly to the mouse
 * position, such that the center of the selection is where the mouse pointer is.
 */
- (void)mouseDown: (NSEvent*)theEvent
{
    [self sendPlotMoveNotification: theEvent];
}

- (void)mouseDragged: (NSEvent*)theEvent
{
    [self sendPlotMoveNotification: theEvent];
}

@end;

//--------------------------------------------------------------------------------------------------

@implementation AccountRepWindowController

@synthesize fromDate;
@synthesize toDate;

@synthesize barWidth; // The width of all bars in either the main or the turnovers bar.

-(id)init
{
    self = [super init];
    if (self != nil) {
        barWidth = 15;
        managedObjectContext = [[MOAssistant assistant] context];
    }
    return self;
}

-(void)dealloc 
{
    [fromDate release], fromDate = nil;
    [toDate release], toDate = nil;
    
    [mainGraph release];
    [dates release];
    [balances release];
    [balanceCounts release];
    
    [mainIndicatorLine release];
    [turnoversIndicatorLine release];
    
    [infoLayer release];
    [infoTextFormatter release];
    [lastInfoDate release];
    [infoAnnotation release];
    [selectionBand release];
    
    [super dealloc];
}

-(void)awakeFromNib
{
    NSError *error;
    
    [self setupMainGraph];
    [self setupTurnoversGraph];
    [self setupSelectionGraph];
    
    [accountsController fetchWithRequest: nil merge: NO error: &error];
    
    // sort descriptor for accounts view
    NSSortDescriptor *sd = [[[NSSortDescriptor alloc] initWithKey: @"name" ascending: YES] autorelease];
    NSArray	*sds = [NSArray arrayWithObject: sd];
    [accountsController setSortDescriptors: sds];
    
    [self performSelector: @selector(restoreAccountsView) withObject: nil afterDelay: 0.0];
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(graphLayoutChanged:)
                                                 name: PecuniaGraphLayoutChangeNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(mouseLeftGraph:)
                                                 name: PecuniaGraphMouseExitedNotification
                                               object: nil];
}

#pragma mark -
#pragma mark Graph setup

- (void)setBarWidth: (CGFloat)value
{
    self.barWidth = value;
    
    for (CPTPlot* plot in mainGraph.allPlots) {
        if ([plot isKindOfClass: [CPTBarPlot class]]) {
            ((CPTBarPlot*)plot).barWidth = CPTDecimalFromFloat(value);
        }
    }
    for (CPTPlot* plot in turnoversGraph.allPlots) {
        if ([plot isKindOfClass: [CPTBarPlot class]]) {
            ((CPTBarPlot*)plot).barWidth = CPTDecimalFromFloat(value);
        }
    }
}

/**
 * Returns the first (earliest) date in the data, which serves as the reference date to which
 * all other dates are compared (to create a time distance in seconds).
 * If we have no data then the current date is used instead.
 */
-(ShortDate*)referenceDate
{
    if ([dates count] > 0)
        return [dates objectAtIndex: 0];
    return [ShortDate dateWithDate: [NSDate date]];
}

-(void)setupShadowForPlot: (CPTPlot*) plot
{
    plot.shadowColor = CGColorCreateGenericGray(0, 1);
    plot.shadowRadius = 2.0;
    plot.shadowOffset = CGSizeMake(1, -1);
    plot.shadowOpacity = 0.75;
}

-(void)setupMainGraph
{
    mainGraph = [(CPTXYGraph *)[CPTXYGraph alloc] initWithFrame: NSRectToCGRect(mainHostView.bounds)];
    CPTTheme *theme = [CPTTheme themeNamed: kCPTPlainWhiteTheme];
    [mainGraph applyTheme: theme];
    mainHostView.hostedGraph = mainGraph;
    
    // Setup scatter plot space
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)mainGraph.defaultPlotSpace;
    plotSpace.allowsUserInteraction = YES;
    plotSpace.delegate = self;
    
    // Grid line styles
    CPTMutableLineStyle* frameStyle = [CPTMutableLineStyle lineStyle];
    frameStyle.lineWidth = 1;
    frameStyle.lineColor = [[CPTColor colorWithGenericGray: 0] colorWithAlphaComponent: 0.5];
    
    // Graph padding
    mainGraph.paddingLeft = 10.0;
    mainGraph.paddingTop = 10.0;
    mainGraph.paddingRight = 10.0;
    mainGraph.paddingBottom = 10.0;
    mainGraph.fill = nil;
    
    CPTPlotAreaFrame* frame = mainGraph.plotAreaFrame;
    frame.paddingLeft = 90;
    frame.paddingRight = 30;
    frame.paddingTop = 30;
    frame.paddingBottom = 30;
    
    frame.cornerRadius = 10;
    frame.borderLineStyle = frameStyle;

    frame.shadowColor = CGColorCreateGenericGray(0, 1);
    frame.shadowRadius = 2.0;
    frame.shadowOffset = CGSizeMake(1, -1);
    frame.shadowOpacity = 0.1;
    
    CPTFill* fill = [CPTFill fillWithColor: [CPTColor colorWithComponentRed: 1 green: 1 blue: 1 alpha: 0.8]];
    frame.fill = fill;
    
    // Axes.
    CPTXYAxisSet* axisSet = (id)mainGraph.axisSet;
    CPTXYAxis* x = axisSet.xAxis;
    x.minorTicksPerInterval = 0;
    x.labelingPolicy = CPTAxisLabelingPolicyEqualDivisions;
    x.preferredNumberOfMajorTicks = 15;
    
    NSDateFormatter* dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    dateFormatter.dateStyle = kCFDateFormatterShortStyle;
    CPTTimeFormatter* timeFormatter = [[[CPTTimeFormatter alloc] initWithDateFormatter: dateFormatter] autorelease];
    
    timeFormatter.referenceDate = [[self referenceDate] lowDate];
    x.labelFormatter = timeFormatter;
    
    CPTMutableTextStyle* textStyle = [CPTMutableTextStyle textStyle];
    textStyle.color = [CPTColor colorWithComponentRed: 88 / 255.0 green: 86 / 255.0 blue: 77 / 255.0 alpha: 1];
    textStyle.fontName = @"LucidaGrande";
    textStyle.fontSize = 10.0;
    x.labelTextStyle = textStyle;
    
    CPTXYAxis* y = axisSet.yAxis;
    y.labelTextStyle = textStyle;
    y.axisConstraints = [CPTConstraints constraintWithLowerOffset: 0];
    y.separateLayers = NO;
    
    CPTMutableLineStyle* lineStyle = [CPTMutableLineStyle lineStyle];
    lineStyle.lineWidth = 0.5;
    lineStyle.lineColor = [CPTColor blackColor];
    y.majorGridLineStyle = lineStyle;
    
    lineStyle.lineColor = [[CPTColor blackColor] colorWithAlphaComponent: 0.25];
    y.minorGridLineStyle = lineStyle;
    y.majorTickLineStyle = nil;
    y.minorTickLineStyle = nil;
    y.axisLineStyle = nil;
    
    // Graph title, use y axis label for this.
    textStyle.textAlignment = CPTTextAlignmentCenter;
    textStyle.fontSize = 14.0;
    y.titleTextStyle = textStyle;
    y.title = @"Salden und Umsätze";
    y.titleOffset = 60;

    // The second y axis is used as the current location identifier.
    mainIndicatorLine = [[[CPTXYAxis alloc] init] autorelease];
    mainIndicatorLine.hidden = YES;
    mainIndicatorLine.coordinate = CPTCoordinateY;
    mainIndicatorLine.plotSpace = plotSpace;
    mainIndicatorLine.axisConstraints = [CPTConstraints constraintWithLowerOffset: 0];
    mainIndicatorLine.labelingPolicy = CPTAxisLabelingPolicyNone;
    mainIndicatorLine.separateLayers = NO;
    mainIndicatorLine.preferredNumberOfMajorTicks = 6;
    mainIndicatorLine.minorTicksPerInterval = 0;

    lineStyle = [CPTMutableLineStyle lineStyle];
    lineStyle.lineWidth = 1;
    lineStyle.lineColor = [CPTColor colorWithGenericGray: 64 / 255.0];
    lineStyle.lineCap = kCGLineCapRound;
    lineStyle.dashPattern = lineStyle.dashPattern = [NSArray arrayWithObjects:
                                                     [NSNumber numberWithFloat: 10.0f],
                                                     [NSNumber numberWithFloat: 5.0f],
                                                     nil];
    mainIndicatorLine.axisLineStyle = lineStyle;
    mainIndicatorLine.majorTickLineStyle = nil;
    
    // Add the y2 axis to the axis set
    axisSet.axes = [NSArray arrayWithObjects: x, y, mainIndicatorLine, nil];
    
}

-(void)setupTurnoversGraph
{
    turnoversGraph = [(CPTXYGraph *)[CPTXYGraph alloc] initWithFrame: NSRectToCGRect(turnoversHostView.bounds)];
    CPTTheme *theme = [CPTTheme themeNamed: kCPTPlainWhiteTheme];
    [turnoversGraph applyTheme: theme];
    turnoversHostView.hostedGraph = turnoversGraph;
    
    // Setup scatter plot space
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)turnoversGraph.defaultPlotSpace;
    plotSpace.allowsUserInteraction = YES;
    plotSpace.delegate = self;
    
    // Grid line styles
    CPTMutableLineStyle* frameStyle = [CPTMutableLineStyle lineStyle];
    frameStyle.lineWidth = 1;
    frameStyle.lineColor = [[CPTColor colorWithGenericGray: 0] colorWithAlphaComponent: 0.5];
    
    // Graph padding
    turnoversGraph.paddingLeft = 10.0;
    turnoversGraph.paddingTop = 10;
    turnoversGraph.paddingRight = 10.0;
    turnoversGraph.paddingBottom = 10;
    
    CPTPlotAreaFrame* frame = turnoversGraph.plotAreaFrame;
    frame.paddingLeft = 90;
    frame.paddingRight = 30;
    frame.paddingTop = 15;
    frame.paddingBottom = 15;
    
    frame.cornerRadius = 10;
    frame.borderLineStyle = frameStyle;
    
    frame.shadowColor = CGColorCreateGenericGray(0, 1);
    frame.shadowRadius = 2.0;
    frame.shadowOffset = CGSizeMake(1, -1);
    frame.shadowOpacity = 0.1;
    
    // Axes.
    CPTXYAxisSet* axisSet = (id)turnoversGraph.axisSet;
    CPTXYAxis* x = axisSet.xAxis;
    x.axisLineStyle = nil;
    x.majorTickLineStyle = nil;
    x.minorTickLineStyle = nil;
    x.labelTextStyle = nil;
    x.labelingPolicy = CPTAxisLabelingPolicyNone;
    
    CPTMutableTextStyle* textStyle = [CPTMutableTextStyle textStyle];
    textStyle.color = [CPTColor colorWithComponentRed: 88 / 255.0 green: 86 / 255.0 blue: 77 / 255.0 alpha: 1];
    textStyle.fontName = @"LucidaGrande";
    textStyle.fontSize = 10.0;
    
    CPTXYAxis* y = axisSet.yAxis;
    y.labelTextStyle = textStyle;
    y.axisConstraints = [CPTConstraints constraintWithLowerOffset: 0];
    
    CPTMutableLineStyle* lineStyle = [CPTMutableLineStyle lineStyle];
    lineStyle.lineWidth = 0.25;
    lineStyle.lineColor = [CPTColor blackColor];
    y.majorGridLineStyle = lineStyle;
    
    lineStyle.lineColor = [[CPTColor blackColor] colorWithAlphaComponent: 0];
    y.majorTickLineStyle = nil;
    
    lineStyle.lineColor = [[CPTColor blackColor] colorWithAlphaComponent: 0.25];
    y.minorGridLineStyle = lineStyle;
    y.axisLineStyle = lineStyle;
    y.minorTickLineStyle = nil;
    
    NSNumberFormatter* formatter = [[[NSNumberFormatter alloc] init] autorelease];
    formatter.usesSignificantDigits = YES;
    formatter.minimumFractionDigits = 0;
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.zeroSymbol = @"0";
    y.labelFormatter = formatter;
    
    // Graph title, use y axis label for this.
    textStyle.textAlignment = CPTTextAlignmentCenter;
    textStyle.fontSize = 12.0;
    y.titleTextStyle = textStyle;
    y.title = @"Überweisungen";
    y.titleOffset = 60;

    // The second y axis is used as the current location identifier.
    turnoversIndicatorLine = [[[CPTXYAxis alloc] init] autorelease];
    turnoversIndicatorLine.hidden = YES;
    turnoversIndicatorLine.coordinate = CPTCoordinateY;
    turnoversIndicatorLine.plotSpace = plotSpace;
    turnoversIndicatorLine.axisConstraints = [CPTConstraints constraintWithLowerOffset: 0];
    turnoversIndicatorLine.labelingPolicy = CPTAxisLabelingPolicyNone;
    turnoversIndicatorLine.separateLayers = NO;
    turnoversIndicatorLine.preferredNumberOfMajorTicks = 6;
    turnoversIndicatorLine.minorTicksPerInterval = 0;

    lineStyle = [CPTMutableLineStyle lineStyle];
    lineStyle.lineWidth = 1;
    lineStyle.lineColor = [CPTColor colorWithGenericGray: 64 / 255.0];
    lineStyle.dashPattern = lineStyle.dashPattern = [NSArray arrayWithObjects:
                                                     [NSNumber numberWithFloat: 10.0f],
                                                     [NSNumber numberWithFloat: 5.0f],
                                                     nil];
    turnoversIndicatorLine.axisLineStyle = lineStyle;
    turnoversIndicatorLine.majorTickLineStyle = nil;
    
    // Add the second y axis to the axis set.
    axisSet.axes = [NSArray arrayWithObjects: x, y, turnoversIndicatorLine, nil];
}

-(void)setupSelectionGraph
{
    selectionGraph = [(CPTXYGraph *)[CPTXYGraph alloc] initWithFrame: NSRectToCGRect(selectionHostView.bounds)];
    CPTTheme *theme = [CPTTheme themeNamed: kCPTPlainWhiteTheme];
    [selectionGraph applyTheme: theme];
    selectionHostView.hostedGraph = selectionGraph;
    selectionGraph.fill = nil;
    
    // Setup scatter plot space
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)selectionGraph.defaultPlotSpace;
    plotSpace.allowsUserInteraction = YES;
    plotSpace.delegate = self;
    
    // Grid line styles
    CPTMutableLineStyle* frameStyle = [CPTMutableLineStyle lineStyle];
    frameStyle.lineWidth = 2;
    frameStyle.lineColor = [CPTColor colorWithComponentRed: 18 / 255.0
                                                     green: 97 / 255.0
                                                      blue: 185 / 255.0
                                                     alpha: 1];
    
    // Graph padding
    selectionGraph.paddingLeft = 10.0;
    selectionGraph.paddingTop = 10;
    selectionGraph.paddingRight = 10.0;
    selectionGraph.paddingBottom = 10.0;
    
    CPTPlotAreaFrame* frame = selectionGraph.plotAreaFrame;
    frame.paddingLeft = 30;
    frame.paddingRight = 10;
    frame.paddingTop = 10;
    frame.paddingBottom = 10;
    
    frame.cornerRadius = 5;
    frame.borderLineStyle = nil; //frameStyle;
    
    CPTGradient* gradient = [CPTGradient gradientWithBeginningColor: [CPTColor colorWithGenericGray: 80 / 255.0]
                                                        endingColor: [CPTColor colorWithGenericGray: 30 / 255.0]
                             ];
    gradient.angle = -87.0;
    CPTFill* gradientFill = [CPTFill fillWithGradient: gradient];

    frame.fill = gradientFill;
    
    frame.shadowColor = CGColorCreateGenericGray(0, 1);
    frame.shadowRadius = 3.0;
    frame.shadowOffset = CGSizeMake(2, -2);
    frame.shadowOpacity = 0.7;
    
    // Axes.
    CPTMutableLineStyle* lineStyle = [CPTMutableLineStyle lineStyle];
    lineStyle.lineWidth = 1;
    lineStyle.lineColor = [[CPTColor whiteColor] colorWithAlphaComponent: 0.2];

    CPTXYAxisSet* axisSet = (id)selectionGraph.axisSet;
    CPTXYAxis* x = axisSet.xAxis;
    x.minorTicksPerInterval = 0;
    x.labelingPolicy = CPTAxisLabelingPolicyEqualDivisions;
    x.preferredNumberOfMajorTicks = 60;

    x.majorGridLineStyle = lineStyle;
    x.labelTextStyle = nil;
    x.separateLayers = NO;
    x.minorGridLineStyle = nil;
    x.majorTickLineStyle = nil;
    x.minorTickLineStyle = nil;
    x.axisLineStyle = nil;

    CPTXYAxis* y = axisSet.yAxis;
    y.minorTicksPerInterval = 0;
    y.labelingPolicy = CPTAxisLabelingPolicyEqualDivisions;
    y.preferredNumberOfMajorTicks = 8;
    y.majorGridLineStyle = lineStyle;
    y.labelTextStyle = nil;
    y.separateLayers = NO;
    y.minorGridLineStyle = nil;
    y.majorTickLineStyle = nil;
    y.minorTickLineStyle = nil;
    y.axisLineStyle = nil;

    // Graph title, use y axis label for this.
    CPTMutableTextStyle* textStyle = [CPTMutableTextStyle textStyle];
    textStyle.color = [CPTColor whiteColor];
    textStyle.fontName = @"LucidaGrande";
    textStyle.fontSize = 10.0;
    textStyle.textAlignment = CPTTextAlignmentCenter;
    y.titleTextStyle = textStyle;
    y.title = @"Übersicht";
    y.titleOffset = 8;
}

-(CPTScatterPlot*)createScatterPlotWithFill: (CPTFill*)fill
{
    CPTScatterPlot* linePlot = [[[CPTScatterPlot alloc] init] autorelease];
    linePlot.cachePrecision = CPTPlotCachePrecisionDecimal;
    linePlot.alignsPointsToPixels = NO;
    linePlot.dataLineStyle = nil;
    linePlot.interpolation = CPTScatterPlotInterpolationStepped;
    linePlot.areaFill = fill;
    linePlot.areaBaseValue = CPTDecimalFromInt(0);
    
    linePlot.delegate = self;
    linePlot.dataSource = self;
    
    return linePlot;
}

-(CPTBarPlot*)createBarPlotWithFill: (CPTFill*)fill withBorder: (BOOL)withBorder
{
    CPTBarPlot *barPlot = [[[CPTBarPlot alloc] init] autorelease];
    barPlot.barBasesVary = NO;
    barPlot.barWidthsAreInViewCoordinates = YES;
    barPlot.barWidth = CPTDecimalFromFloat(barWidth);
    barPlot.barCornerRadius = 3.0f;
    barPlot.barsAreHorizontal = NO;
    barPlot.baseValue = CPTDecimalFromInt(0);
    barPlot.alignsPointsToPixels = NO;
    barPlot.cachePrecision = CPTPlotCachePrecisionDouble;
    
    if (withBorder) {
        CPTMutableLineStyle* lineStyle = [[[CPTMutableLineStyle alloc] init] autorelease];
        lineStyle.lineColor = [CPTColor whiteColor];
        lineStyle.lineWidth = 1;
        barPlot.lineStyle = lineStyle;
    } else {
        barPlot.lineStyle = nil;
    }
    barPlot.fill = fill;
    
    barPlot.delegate = self;
    barPlot.dataSource = self;
    
    return barPlot;
}

-(void)setupMainPlots
{
    [mainGraph removePlotWithIdentifier: @"positivePlot"];
    [mainGraph removePlotWithIdentifier: @"negativePlot"];

    // The main graph contains two plots, one for the positive values (with a gray fill)
    // and the other one for negative values (with a red fill).
    // Depending on whether we view a bank account or a normal category either line or bar plots are used.
    Category* category = [self currentSelection];
    if (category == nil)
        return;
    
    CPTGradient* positiveGradient = [CPTGradient gradientWithBeginningColor: [CPTColor colorWithComponentRed: 100 / 255.0
                                                                                                       green: 100 / 255.0
                                                                                                        blue: 100 / 255.0
                                                                                                       alpha: 0.75]
                                                                endingColor: [CPTColor colorWithComponentRed: 60 / 255.0
                                                                                                       green: 60 / 255.0
                                                                                                        blue: 60 / 255.0
                                                                                                       alpha: 0.75]
                                     ];
    positiveGradient.angle = -90.0;
    CPTFill* positiveGradientFill = [CPTFill fillWithGradient: positiveGradient];
    CPTGradient* negativeGradient = [CPTGradient gradientWithBeginningColor: [CPTColor colorWithComponentRed: 255 / 255.0
                                                                                                       green: 50 / 255.0
                                                                                                        blue: 50 / 255.0
                                                                                                       alpha: 0.75]
                                                                endingColor: [CPTColor colorWithComponentRed: 255 / 255.0
                                                                                                       green: 50 / 255.0
                                                                                                        blue: 50 / 255.0
                                                                                                       alpha: 0.75]
                                     ];
    
    negativeGradient.angle = -90.0;
    CPTFill* negativeGradientFill = [CPTFill fillWithGradient: negativeGradient];
    
    CPTPlot* plot;
    if (category.isBankAccount)
    {
        plot = [self createScatterPlotWithFill: positiveGradientFill];
    }
    else
    {
        plot = [self createBarPlotWithFill: positiveGradientFill withBorder: YES];
    }
    
    CPTMutableTextStyle* labelTextStyle = [CPTMutableTextStyle textStyle];
    labelTextStyle.color = [CPTColor blackColor];
    plot.labelTextStyle = labelTextStyle;
    
    plot.identifier = @"positivePlot";
    [self setupShadowForPlot: plot];
    
    [mainGraph addPlot: plot];
    
    // The negative plot.
    if (category.isBankAccount)
    {
        plot = [self createScatterPlotWithFill: negativeGradientFill];
    }
    else
    {
        plot = [self createBarPlotWithFill: negativeGradientFill withBorder: YES];
    }
    
    plot.identifier = @"negativePlot";
    [self setupShadowForPlot: plot];
    
    [mainGraph addPlot: plot];
    
    [self updateMainGraph];
}

-(void)setupTurnoversPlot
{
    [turnoversGraph removePlotWithIdentifier: @"turnoversPlot"];

    CPTGradient* areaGradient = [CPTGradient gradientWithBeginningColor: [CPTColor colorWithComponentRed: 23 / 255.0
                                                                                                   green: 124 / 255.0
                                                                                                    blue: 236 / 255.0
                                                                                                   alpha: 0.75]
                                                            endingColor: [CPTColor colorWithComponentRed: 18 / 255.0
                                                                                                   green: 97 / 255.0
                                                                                                    blue: 185 / 255.0
                                                                                                   alpha: 0.75]
                                 ];
    areaGradient.angle = -90.0;
    CPTFill* areaGradientFill = [CPTFill fillWithGradient: areaGradient];
    CPTBarPlot* barPlot = [self createBarPlotWithFill: areaGradientFill withBorder: YES];
    
    barPlot.identifier = @"turnoversPlot";
    [self setupShadowForPlot: barPlot];
    
    [turnoversGraph addPlot: barPlot];
    
    [self updateTurnoversGraph];
}

-(void)setupSelectionPlot
{
    [selectionGraph removePlotWithIdentifier: @"selectionPlot"];

    // The selection plot always contains the full range of values as it is used to select a subrange
    // for main and turnovers graphs.
    Category* category = [self currentSelection];
    if (category == nil)
        return;
    
    CPTGradient* gradient = [CPTGradient gradientWithBeginningColor: [CPTColor colorWithComponentRed: 255 / 255.0
                                                                                               green: 255 / 255.0
                                                                                                blue: 255 / 255.0
                                                                                               alpha: 0.80]
                                                        endingColor: [CPTColor colorWithComponentRed: 255 / 255.0
                                                                                               green: 255 / 255.0
                                                                                                blue: 255 / 255.0
                                                                                               alpha: 0.9]
                             ];
    gradient.angle = 90.0;
    CPTFill* gradientFill = [CPTFill fillWithGradient: gradient];
    
    CPTPlot* plot = [self createScatterPlotWithFill: gradientFill];
    
    plot.identifier = @"selectionPlot";
    [self setupShadowForPlot: plot];
    
    [selectionGraph addPlot: plot];
    
    [self updateSelectionGraph];
}

/**
 * Determines the optimal length of a major interval length for a plot depending on the
 * overall size of the range. This is a bit tricky as we want sharp and easy intervals
 * for optimal perceptibility. The given range is already rounded up to two most significant digits.
 */
- (float)intervalFromRange: (NSDecimalNumber*) range
{
    int digitCount = [range numberOfDigits];
    NSDecimal value = [range decimalValue];
    NSDecimal hundred = [[NSNumber numberWithInt: 100] decimalValue];
    if (NSDecimalCompare(&value, &hundred) == NSOrderedDescending)
    {
        // The range is > 100 so scale it down so it falls into that range.
        NSDecimalMultiplyByPowerOf10(&value, &value, -digitCount + 2, NSRoundDown);
    }
    double convertedValue = [[NSDecimalNumber decimalNumberWithDecimal: value] doubleValue];
    if (convertedValue < 10) {
        return pow(10, digitCount - 1);
    }
    if (convertedValue == 10) {
        return 2 * pow(10, digitCount - 2);
    }
    if (convertedValue <= 15) {
        return 3 * pow(10, digitCount - 2);
    }
    if (convertedValue <= 45) {
        return 5 * pow(10, digitCount - 2);
    }

    return pow(10, digitCount - 1);
}

/**
 * Determines a good number of subticks depending on the size of the interval. The returned value
 * should be so that it is easy to sum up subinterval steps to find a value from the graph easily.
 */
- (float)minorTicksFromInterval: (float)interval
{
    NSDecimal value = CPTDecimalFromFloat(interval);
    int digitCount = [[NSDecimalNumber decimalNumberWithDecimal: value] numberOfDigits];
    NSDecimal hundred = [[NSNumber numberWithInt: 100] decimalValue];
    if (NSDecimalCompare(&value, &hundred) == NSOrderedDescending)
    {
        // The range is > 100 so scale it down so it falls into that range.
        NSDecimalMultiplyByPowerOf10(&value, &value, -digitCount + 2, NSRoundDown);
    }
    double convertedValue = [[NSDecimalNumber decimalNumberWithDecimal: value] doubleValue];
    if (convertedValue < 10) {
        return 0;
    }
    if (convertedValue == 10) {
        return 4;
    }
    if (convertedValue <= 15) {
        return 4;
    }
    if (convertedValue <= 45) {
        return convertedValue / 5 - 1;
    }

    return 4;
}

/**
 * Computes the distance between the given and the reference date in seconds.
 */
- (NSDecimal)secondsFromDate: (ShortDate*)date
{
    return CPTDecimalFromInt(oneDay * [[self referenceDate] daysToDate: date]);
}

- (void)updateMainGraph
{
    Category* category = [self currentSelection];
    
    NSUInteger count = [dates count];
    
    // Time intervals are specified in number of seconds on the x axis.
    ShortDate* startDate = [self referenceDate];
    int totalDays = (count > 0) ? [startDate daysToDate: [dates lastObject]] + 1 : 0;
    if (totalDays < 14) {
        totalDays = 14;
    }
    
    // Set the available plot space depending on the min, max and day values we found. Extend both range by a few precent for more appeal.
    CPTXYPlotSpace* plotSpace = (id)mainGraph.defaultPlotSpace;
    
    // Horizontal range.
    CPTPlotRange* plotRange = [CPTPlotRange plotRangeWithLocation: CPTDecimalFromDouble(0)
                                                           length: CPTDecimalFromDouble(oneDay * totalDays)];
    plotSpace.globalXRange = plotRange;
    
    NSDecimal fromPoint = [self secondsFromDate: fromDate];
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation: fromPoint
                                                    length: CPTDecimalSubtract([self secondsFromDate: toDate], fromPoint)];
    
//    NSLog(@"From: %@, To: %@", fromDate, toDate);
    
    CPTXYAxisSet* axisSet = (id)mainGraph.axisSet;
    CPTXYAxis* x = axisSet.xAxis;

    // Recreate the time formatter to apply the now reference date. Just setting the date on the existing
    // formatter is not enough.
    NSDateFormatter* dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    dateFormatter.dateStyle = kCFDateFormatterShortStyle;
    CPTTimeFormatter* timeFormatter = [[[CPTTimeFormatter alloc] initWithDateFormatter: dateFormatter] autorelease];
    
    timeFormatter.referenceDate = [[self referenceDate] lowDate];
    x.labelFormatter = timeFormatter;
    
    // Vertical range.
    NSDecimalNumber* roundedMinValue = [minValue roundToUpperOuter];
    NSDecimalNumber* roundedMaxValue = [maxValue roundToUpperOuter];
    
    plotRange = [CPTPlotRange plotRangeWithLocation: [roundedMinValue decimalValue]
                                             length: [[roundedMaxValue decimalNumberBySubtracting: roundedMinValue] decimalValue]];
    plotSpace.globalYRange = plotRange;
    plotSpace.yRange = plotRange;
    
    // Set the y axis ticks depending on the maximum value.
    CPTXYAxis* y = axisSet.yAxis;
    y.visibleRange = plotRange;
    
    // Let the larger area (negative or positive) determine the size of the major tick range.
    NSDecimalNumber* minAbsolute = [roundedMinValue abs];
    NSDecimalNumber* maxAbsolute = [roundedMaxValue abs];
    float interval;
    if ([minAbsolute compare: maxAbsolute] == NSOrderedDescending) {
        interval = [self intervalFromRange: minAbsolute];
    } else {
        interval = [self intervalFromRange: maxAbsolute];
    }
    y.majorIntervalLength = CPTDecimalFromFloat(interval);
    y.minorTicksPerInterval = [self minorTicksFromInterval: interval];
    
    NSString* currency = (category == nil) ? @"EUR" : [category currency];
    NSNumberFormatter* currencyFormatter = [[[NSNumberFormatter alloc] init] autorelease];
    currencyFormatter.usesSignificantDigits = YES;
    currencyFormatter.minimumFractionDigits = 0;
    currencyFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
    currencyFormatter.currencyCode = currency;
    currencyFormatter.zeroSymbol = [NSString stringWithFormat: @"0 %@", currencyFormatter.currencySymbol];
    y.labelFormatter = currencyFormatter;
    
    [mainGraph reloadData];
}

- (void)updateTurnoversGraph
{
    NSUInteger count = [dates count];
    
    int maxTurnoversCount = 0;
    
    // Time intervals are specified in number of seconds on the x axis.
    for (NSUInteger i = 0; i < count; i++)
    {
        id y = [balanceCounts objectAtIndex: i];
        
        if ([y intValue] > maxTurnoversCount)
            maxTurnoversCount = [y floatValue];
    }
    
    ShortDate* startDate = [self referenceDate];
    int totalDays = (count > 0) ? [startDate daysToDate: [dates lastObject]] + 1: 0;
    if (totalDays < 14) {
        totalDays = 14;
    };
    
    // Set the available plot space depending on the min, max and day values we found.
    CPTXYPlotSpace* plotSpace = (id)turnoversGraph.defaultPlotSpace;
    
    // Horizontal range.
    CPTPlotRange* plotRange = [CPTPlotRange plotRangeWithLocation: CPTDecimalFromDouble(0)
                                                           length: CPTDecimalFromDouble(oneDay * totalDays)];
    plotSpace.globalXRange = plotRange;
    
    NSDecimal fromPoint = [self secondsFromDate: fromDate];
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation: fromPoint
                                                    length: CPTDecimalSubtract([self secondsFromDate: toDate], fromPoint)];
    
    CPTXYAxisSet* axisSet = (id)turnoversGraph.axisSet;
    
    // Vertical range.
    NSDecimalNumber* roundedMax = [[NSDecimalNumber decimalNumberWithDecimal: CPTDecimalFromInt(maxTurnoversCount)] roundToUpperOuter];
    plotRange = [CPTPlotRange plotRangeWithLocation: CPTDecimalFromFloat(0) length: [roundedMax decimalValue]];
    plotSpace.globalYRange = plotRange;
    plotSpace.yRange = plotRange;
    
    // Set the y axis ticks depending on the maximum value.
    CPTXYAxis* y = axisSet.yAxis;
    y.visibleRange = plotRange;
    
    float interval = [self intervalFromRange: roundedMax];
    y.majorIntervalLength = CPTDecimalFromFloat(interval);
    y.minorTicksPerInterval = [self minorTicksFromInterval: interval];
    
    [turnoversGraph reloadData];
}

-(void)updateSelectionGraph
{
    // Time intervals are specified in number of seconds on the x axis.
    ShortDate* startDate = [self referenceDate];
    int totalDays = ([dates count] > 0) ? [startDate daysToDate: [dates lastObject]] : 0;
    if (totalDays < 14)
        totalDays = 14;
    
    // Set the available plot space depending on the min, max and day values we found. Extend both range by a few precent for more appeal.
    CPTXYPlotSpace* plotSpace = (id)selectionGraph.defaultPlotSpace;
    
    // Horizontal range.
    CPTPlotRange* plotRange = [CPTPlotRange plotRangeWithLocation: CPTDecimalFromDouble(0)
                                                           length: CPTDecimalFromDouble(oneDay * totalDays)];
    plotSpace.globalXRange = plotRange;
    plotSpace.xRange = plotRange;
    
    CPTXYAxisSet* axisSet = (id)selectionGraph.axisSet;

    // Vertical range.
    NSDecimalNumber* roundedMinValue = [minValue roundToUpperOuter];
    NSDecimalNumber* roundedMaxValue = [maxValue roundToUpperOuter];
    
    plotRange = [CPTPlotRange plotRangeWithLocation: [roundedMinValue decimalValue]
                                             length: [[roundedMaxValue decimalNumberBySubtracting: roundedMinValue] decimalValue]];
    plotSpace.globalYRange = plotRange;
    plotSpace.yRange = plotRange;
    
    // Set the y axis lines depending on the maximum value.
    CPTXYAxis* y = axisSet.yAxis;
    y.visibleRange = plotRange;
    
    [selectionGraph reloadData];
}

#pragma mark -
#pragma mark User interaction

- (void)applyRangeLocationToPlotSpace: (CPTXYPlotSpace*)space location: (NSNumber*)location range: (NSNumber*)range
{
    CPTPlotRange* plotRange = [CPTPlotRange plotRangeWithLocation: CPTDecimalFromDouble([location doubleValue])
                                                           length: CPTDecimalFromDouble([range doubleValue])];
    space.xRange = plotRange;
}

/**
 * Updates the info annotation with the given values.
 */
- (void)updateMainInfoForDate: (ShortDate*)date balance: (NSDecimalNumber*)balance turnovers: (int)turnovers
{
    if (infoTextFormatter == nil)
    {
        Category* category = [self currentSelection];
        
        NSString* currency = (category == nil) ? @"EUR" : [category currency];
        infoTextFormatter = [[[NSNumberFormatter alloc] init] retain];
        infoTextFormatter.usesSignificantDigits = NO;
        infoTextFormatter.minimumFractionDigits = 2;
        infoTextFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
        infoTextFormatter.currencyCode = currency;
        infoTextFormatter.zeroSymbol = [NSString stringWithFormat: @"0 %@", infoTextFormatter.currencySymbol];
    }
    
    // Prepare the info layer if not yet done.
    if (infoLayer == nil)
    {
        CGRect frame = CGRectMake(0.5, 0.5, 120, 50);
        infoLayer = [[(ColumnLayoutCorePlotLayer*)[ColumnLayoutCorePlotLayer alloc] initWithFrame: frame] autorelease];
        infoLayer.hidden = YES;
        infoLayer.paddingTop = 10;
        infoLayer.paddingBottom = 10;
        infoLayer.paddingLeft = 15;
        infoLayer.paddingRight = 15;
        infoLayer.spacing = 5;

        infoLayer.shadowColor = CGColorCreateGenericGray(0, 1);
        infoLayer.shadowRadius = 5.0;
        infoLayer.shadowOffset = CGSizeMake(2, -2);
        infoLayer.shadowOpacity = 0.75;
        
        CPTMutableLineStyle* lineStyle = [CPTMutableLineStyle lineStyle];
        lineStyle.lineWidth = 2;
        lineStyle.lineColor = [CPTColor whiteColor];
        CPTFill* fill = [CPTFill fillWithColor: [CPTColor colorWithComponentRed: 0.1 green: 0.1 blue: 0.1 alpha: 0.75]];
        infoLayer.borderLineStyle = lineStyle;
        infoLayer.fill = fill;
        infoLayer.cornerRadius = 10;
        
        CPTMutableTextStyle* textStyle = [CPTMutableTextStyle textStyle];
        textStyle.fontName = @"Lucida Grande";
        textStyle.fontSize = 12;
        textStyle.color = [CPTColor whiteColor];
        textStyle.textAlignment = CPTTextAlignmentCenter;
        
        dateInfoLayer = [[[CPTTextLayer alloc] initWithText: @"" style: textStyle] autorelease];
        [infoLayer addSublayer: dateInfoLayer];
        
        textStyle = [CPTMutableTextStyle textStyle];
        textStyle.fontName = @"Lucida Grande Bold";
        textStyle.fontSize = 16;
        textStyle.color = [CPTColor whiteColor];
        textStyle.textAlignment = CPTTextAlignmentCenter;
        
        valueInfoLayer = [[[CPTTextLayer alloc] initWithText: @"" style: textStyle] autorelease];
        [infoLayer addSublayer: valueInfoLayer];

        // We can also prepare the annotation which hosts the info layer but don't add it to the plot area yet.
        // When we switch the plots it won't show up otherwise unless we add it on demand.
        infoAnnotation = [[[CPTAnnotation alloc] init] retain];
        infoAnnotation.contentLayer = infoLayer;
    }
    if (![mainGraph.plotAreaFrame.plotArea.annotations containsObject: infoAnnotation])
        [mainGraph.plotAreaFrame.plotArea addAnnotation: infoAnnotation]; 

    if (balance != nil) {
        valueInfoLayer.text = [infoTextFormatter stringFromNumber: balance];
    } else {
        valueInfoLayer.text = @"--";
    }

    
    NSString* infoText;
    if (turnovers == 1) {
        infoText = [NSString stringWithFormat: @"%@\n%@", date.description, NSLocalizedString(@"AP132", @"")];
    } else {
        infoText = [NSString stringWithFormat: @"%@\n%@", date.description, [NSString stringWithFormat: NSLocalizedString(@"AP133", @""), turnovers]];
    }
    dateInfoLayer.text = infoText;
    
    // Resize the info layer so that it fits its contents.
    CGRect infoBounds;
    infoBounds.size = [dateInfoLayer sizeThatFits];
    CGSize size = valueInfoLayer.hidden ? CGSizeMake(0, 0) : [valueInfoLayer sizeThatFits];
    if (size.width > infoBounds.size.width)
        infoBounds.size.width = size.width;
    infoBounds.size.width += infoLayer.paddingLeft + infoLayer.paddingRight + infoLayer.borderLineStyle.lineWidth;
    infoBounds.size.height += infoLayer.paddingTop + infoLayer.paddingBottom + infoLayer.spacing + size.height + infoLayer.borderLineStyle.lineWidth;
    infoLayer.bounds = infoBounds;
}

- (void)animatedMoveOfLayer: (CPTLayer*)layer toPosition: (CGPoint)newPosition
{
    if (layer.hidden) {
        return;
    }
    
    NSArray* keys = layer.animationKeys;
    for (NSString* key in keys)
        if ([key isEqualToString: @"animatePosition"]) {
            return;
        }
    
    CGMutablePathRef animationPath = CGPathCreateMutable();
    CGPathMoveToPoint(animationPath, NULL, layer.position.x, layer.position.y);
    CGPathAddLineToPoint(animationPath, NULL, newPosition.x, newPosition.y);
    
    layer.position = newPosition;
    
    CAKeyframeAnimation* animation = [CAKeyframeAnimation animationWithKeyPath: @"position"];
    animation.path = animationPath;
    animation.duration = 0.5;
    animation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
    
    [layer addAnimation: animation forKey: @"animatePosition"];
}

- (void)animatedShowOfLayer: (CPTLayer*)layer
{
    if (layer.hidden || layer.opacity < 1) {
        layer.hidden = NO;
        layer.opacity = 1;
        
        CABasicAnimation* animation = [CABasicAnimation animationWithKeyPath: @"opacity"];
        animation.fromValue = [NSNumber numberWithFloat: 0];
        animation.toValue = [NSNumber numberWithFloat: 1];
        animation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
        animation.delegate = self;
        
        [layer addAnimation: animation forKey: @"animateOpacity"];
    }
}

- (void)animatedHideOfLayer: (CPTLayer*)layer
{
    if (layer.opacity > 0) {
        layer.opacity = 0;
        
        CABasicAnimation* animation = [CABasicAnimation animationWithKeyPath: @"opacity"];
        animation.fromValue = [NSNumber numberWithFloat: 1];
        animation.toValue = [NSNumber numberWithFloat: 0];
        animation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
        animation.delegate = self;
        
        [layer addAnimation: animation forKey: @"animateOpacity"];
    }
}

- (void)animationDidStop: (CAAnimation*)anim finished: (BOOL)flag
{
    if (flag) {
        CABasicAnimation* animation = (CABasicAnimation*)anim;
        
        if ([animation.keyPath isEqualToString: @"opacity"]) {
            if (infoLayer.opacity < 1) {
                infoLayer.hidden = YES;
            }
        } 
    }
}

- (void)updateInfoLayerPosition
{
    // Place the info layer so in the graph that it doesn't get "in the way" but is still close enough
    // to the focus center (which is usually the mouse pointer). This is done by dividing
    // the graph into 4 rectangles (top-left, top-right, bottom-left, bottom-rigth). Use the same horizontal
    // quadrant in which is also the mouse but the opposite vertical one.
    CGRect frame = mainGraph.plotAreaFrame.plotArea.frame;
    CGFloat horizontalCenter = frame.size.width / 2;
    CGFloat verticalCenter = frame.size.height / 2;
    
    NSPoint mousePosition = [mainHostView.window convertScreenToBase: [NSEvent mouseLocation]];
    mousePosition = [mainHostView convertPoint: mousePosition fromView: nil];
    
    CPTPlot* plot = [mainGraph plotAtIndex: 0];
    CGPoint mouseLocation = NSPointToCGPoint(mousePosition);
    CGPoint pointInHostedGraph = [mainHostView.layer convertPoint: mouseLocation toLayer: [plot plotArea]];
    
    CGPoint infoLayerLocation;
    if (pointInHostedGraph.x > horizontalCenter) {
        // Position in right half.
        infoLayerLocation.x = frame.origin.x + horizontalCenter + (horizontalCenter - infoLayer.bounds.size.width) / 2;
    } else {
        // Position in left half.
        infoLayerLocation.x = frame.origin.x + (horizontalCenter - infoLayer.bounds.size.width) / 2;
    }
    if (pointInHostedGraph.y < verticalCenter) {
        // Position in top half.
        infoLayerLocation.y = frame.origin.y + verticalCenter + (verticalCenter - infoLayer.bounds.size.height) / 2;
    } else {
        // Position in bottom half.
        infoLayerLocation.y = frame.origin.y + (verticalCenter - infoLayer.bounds.size.height) / 2;
    }
    
    if (infoLayer.position.x != infoLayerLocation.x || infoLayer.position.y != infoLayerLocation.y)
        [self animatedMoveOfLayer: infoLayer toPosition: infoLayerLocation];
}

/**
 * Searches the date array for the closest value to the given date.
 * The search is left-affine, that is, if the date to search is between two existing dates the 
 * lower date will always be returned.
 */
- (int)findDateIndexForDate: (ShortDate*)dateToSearch
{
    if ([dates count] == 0)
        return -1;
    
    int low = 0;
    int high = [dates count] - 1;
    while (low <= high)
    {
        int mid = (low + high) / 2;
        ShortDate* date = [dates objectAtIndex: mid];
        switch ([date compare: dateToSearch])
        {
            case NSOrderedSame:
                return mid;
            case NSOrderedAscending:
                low = mid + 1;
                break;
            case NSOrderedDescending:
                high = mid - 1;
                break;
        }
    };

    return low - 1;
}

/**
 * Called when the users moved the mouse over either the main or the turnovers graph.
 * Move the indicator lines in both graphs to the current mouse position and update the info annotation.
 *
 * The location is given in plot area coordinates.
 */
- (void)updateTrackLinesAndInfoAnnotation: (NSNumber*)location snapToCloseDate: (BOOL)snap
{
    CGFloat actualLocation = [location floatValue];
    
    // Determine the content for the info layer.
    CPTXYPlotSpace* plotSpace = (id)mainGraph.defaultPlotSpace;
    CGPoint point = CGPointMake(actualLocation, 0);
    
    NSDecimal dataPoint[2];
    [plotSpace plotPoint: dataPoint forPlotAreaViewPoint: point];
    double timePoint = CPTDecimalDoubleValue(dataPoint[0]);
    
    // Check if the time point is within the visible range.
    if (timePoint < plotSpace.xRange.minLimitDouble ||
        timePoint > plotSpace.xRange.maxLimitDouble) {
        [self animatedHideOfLayer: infoLayer];
        [self animatedHideOfLayer: mainIndicatorLine];
        [self animatedHideOfLayer: turnoversIndicatorLine];
        return;
    } else {
        [self animatedShowOfLayer: infoLayer];
        [self animatedShowOfLayer: mainIndicatorLine];
        [self animatedShowOfLayer: turnoversIndicatorLine];
    }

    // Find closest date in our date points that is before the computed date value.
    int days = floor(CPTDecimalFloatValue(dataPoint[0]) / oneDay);
    ShortDate* date = [[dates objectAtIndex: 0] dateByAddingDays: days];
    int index = [self findDateIndexForDate: date];
    ShortDate* dateAtIndex = [dates objectAtIndex: index];
    BOOL dateHit = NO;
    
    // The found index might not be one matching exactly the current date. In order to ease
    // usage we snap the indicator to the closest existing data point if it is within bar width distance.
    if (snap) {
        dataPoint[0] = CPTDecimalFromFloat(oneDay * [[self referenceDate] daysToDate: dateAtIndex]);
        CGPoint targetPoint = [plotSpace plotAreaViewPointForPlotPoint: dataPoint];
        if (abs(targetPoint.x - actualLocation) <= barWidth) {
            actualLocation = targetPoint.x;
            date = dateAtIndex;
            dateHit = YES;
        } else {
            // The found index is not close enough. Try the next date point if there is one.
            if (index < [dates count] - 1) {
                dateAtIndex = [dates objectAtIndex: index + 1];
                dataPoint[0] = CPTDecimalFromFloat(oneDay * [[self referenceDate] daysToDate: dateAtIndex]);
                targetPoint = [plotSpace plotAreaViewPointForPlotPoint: dataPoint];
                if (abs(targetPoint.x - actualLocation) <= barWidth) {
                    actualLocation = targetPoint.x;
                    date = dateAtIndex;
                    dateHit = YES;
                    index++;
                }
            }
        }
    }
    
    if (!dateHit && [date compare: dateAtIndex] == NSOrderedSame) {
        dateHit = YES;
    }

    if (lastInfoDate == nil || [date compare: lastInfoDate] != NSOrderedSame)
    {
        [lastInfoDate release];
        lastInfoDate = [date retain];
        
        if (dateHit) {
            [self updateMainInfoForDate: date
                                balance: [balances objectAtIndex: index]
                              turnovers: [[balanceCounts objectAtIndex: index] intValue]];
        } else {
            [self updateMainInfoForDate: date
                                balance: [[self currentSelection] isBankAccount] ? [balances objectAtIndex: index] : nil
                              turnovers: 0];
        }
    }

    // Position the indicator line to the given location in main and turnovers graphs.
    mainIndicatorLine.axisConstraints = [CPTConstraints constraintWithLowerOffset: actualLocation];
    turnoversIndicatorLine.axisConstraints = [CPTConstraints constraintWithLowerOffset: actualLocation];
    
    [self updateInfoLayerPosition];
}

/**
 * Updates the limit band size and position depending on the currently selected time frame.
 */
- (void)updateSelectionDisplay
{
    CPTXYAxisSet* axisSet = (id)selectionGraph.axisSet;
    CPTXYAxis* x = axisSet.xAxis;
    
    [x removeBackgroundLimitBand: selectionBand];
    [selectionBand release];
    CPTFill* bandFill = [CPTFill fillWithColor: [CPTColor colorWithComponentRed: 134 / 255.0
                                                                          green: 153 / 255.0
                                                                           blue: 67 / 255.0
                                                                          alpha: 1]];
    
    NSDecimal fromPoint = [self secondsFromDate: fromDate];
    selectionBand = [[CPTLimitBand limitBandWithRange:
                      [CPTPlotRange plotRangeWithLocation: fromPoint
                                                   length: CPTDecimalSubtract([self secondsFromDate: toDate], fromPoint)]
                                                 fill: bandFill] retain];
    [x addBackgroundLimitBand: selectionBand];
    selectionHostView.selector = selectionBand;
}

- (void)updateTimeRangeVariables
{
    CPTXYPlotSpace* plotSpace = (id)mainGraph.defaultPlotSpace;
    
    NSDecimal fromPoint = plotSpace.xRange.location;
    int days = CPTDecimalIntValue(CPTDecimalDivide(fromPoint, CPTDecimalFromDouble(oneDay)));
    [fromDate release];
    fromDate = [[self.referenceDate dateByAddingDays: days] retain];
    
    NSDecimal toPoint = plotSpace.xRange.end;
    days = CPTDecimalIntValue(CPTDecimalDivide(toPoint, CPTDecimalFromDouble(oneDay)));
    [toDate release];
    toDate = [[self.referenceDate dateByAddingDays: days] retain];
}

/**
 * Handler method for notifications sent from the graph host windows if something in the graphs need
 * adjustment, mostly due to user input.
 */
- (void)graphLayoutChanged: (NSNotification*)notification
{
    if ([[notification name] isEqualToString: PecuniaGraphLayoutChangeNotification])
    {
        NSDictionary* parameters = [notification userInfo];
        NSString* type = [parameters objectForKey: @"type"];
        
        CPTXYPlotSpace* sourcePlotSpace = notification.object;
        BOOL fromSelectionGraph = (sourcePlotSpace == selectionGraph.defaultPlotSpace);
        BOOL isDragMove = [type isEqualToString: @"plotMoveDrag"];
        BOOL isScale = [type isEqualToString: @"plotScale"];
        BOOL keepInfoLayerHidden = NO;
        if ([type isEqualToString: @"plotMoveSwipe"] || isDragMove || isScale) {
            if (isDragMove || isScale) {
                keepInfoLayerHidden = YES;
                if (!infoLayer.hidden) {
                    [self animatedHideOfLayer: infoLayer];
                }
            }
            
            NSNumber* location = [parameters objectForKey: @"plotXLocation"];
            NSNumber* range = [parameters objectForKey: @"plotXRange"];
            NSNumber* lowRange = [NSNumber numberWithDouble: oneDay * 14]; // Corresponds to the number of major ticks for the x-axis.
            if ([range compare: lowRange] == NSOrderedAscending)
                range = lowRange;
            
            NSNumber* center = [parameters objectForKey: @"mousePosition"];

            // Apply new plot location and range to all relevant graphs.
            // If this is a scale event then adjust the location so that the center is at the mouse
            // location.
            if (isScale) {
                // If this event is from the selection graph then we don't use the actual mouse
                // position, but the center of the selection band.
                double timePoint;
                if (fromSelectionGraph) {
                    timePoint = selectionBand.range.locationDouble + selectionBand.range.lengthDouble / 2;
                } else {
                    // Convert scale center (given in device coordinates).
                    CGPoint point = CGPointMake([center floatValue], 0);
                    
                    NSDecimal dataPoint[2];
                    [sourcePlotSpace plotPoint: dataPoint forPlotAreaViewPoint: point];
                    timePoint = CPTDecimalDoubleValue(dataPoint[0]);
                }
                
                CGFloat oldRange = fromSelectionGraph ? selectionBand.range.lengthDouble : sourcePlotSpace.xRange.lengthDouble;
                CGFloat newRange = [range floatValue];
                CGFloat offset = (oldRange - newRange) * (timePoint - [location floatValue]) / oldRange;
                location = [NSNumber numberWithFloat: [location  floatValue] + offset];
            }
            
            [self applyRangeLocationToPlotSpace: (id)mainGraph.defaultPlotSpace location: location range: range];
            [self applyRangeLocationToPlotSpace: (id)turnoversGraph.defaultPlotSpace location: location range: range];
            
            // Adjust the time range display in the selection graph.
            [self updateTimeRangeVariables];
            [self updateSelectionDisplay];

            if (!keepInfoLayerHidden && !fromSelectionGraph) {
                [self updateTrackLinesAndInfoAnnotation: center snapToCloseDate: NO];
            }
        } else {
            if ([type isEqualToString: @"trackLineMove"]) {
                NSNumber* location = [parameters objectForKey: @"location"];
                [self updateTrackLinesAndInfoAnnotation: location snapToCloseDate: YES];
            } else {
                if ([type isEqualToString: @"plotMoveCenter"]) {
                    NSNumber* location = [parameters objectForKey: @"location"];
                    NSNumber* range = [parameters objectForKey: @"plotXRange"];

                    CGPoint point = CGPointMake([location floatValue], 0);
                    
                    NSDecimal dataPoint[2];
                    [sourcePlotSpace plotPoint: dataPoint forPlotAreaViewPoint: point];
                    double timePoint = CPTDecimalDoubleValue(dataPoint[0]);
                    location = [NSNumber numberWithDouble: timePoint - [range doubleValue] / 2];

                    [self applyRangeLocationToPlotSpace: (id)mainGraph.defaultPlotSpace location: location range: range];
                    [self applyRangeLocationToPlotSpace: (id)turnoversGraph.defaultPlotSpace location: location range: range];
                    
                    // Adjust the time range display in the selection graph.
                    [self updateTimeRangeVariables];
                    [self updateSelectionDisplay];
                    
                }
            }

        }
    }
}

/**
 * Handler method for notifications sent from the graph host windows if the mouse pointer
 * exited from the window's tracking area.
 */
- (void)mouseLeftGraph: (NSNotification*)notification
{
    [self animatedHideOfLayer: infoLayer];
    [self animatedHideOfLayer: mainIndicatorLine];
    [self animatedHideOfLayer: turnoversIndicatorLine];
}

#pragma mark -
#pragma mark Plot Delegate Methods

#pragma mark -
#pragma mark Plot Data Source Methods

- (NSUInteger)numberOfRecordsForPlot: (CPTPlot*)plot
{
    // We add one to the total number as we have to duplicate the last value in scatter plots to
    // make it appear, due to the way coreplot works. Otherwise it is just cut off by the plot area.
    // This extra day is accompanied by duplication of the last value in our data (for scatterplots)
    // or nil (for bar plots).
    return [dates count] + 1;
}

- (NSNumber*)numberForPlot: (CPTPlot*)plot field: (NSUInteger)fieldEnum recordIndex: (NSUInteger)index
{
    BOOL endValue = index >= [dates count];
    if (fieldEnum == CPTBarPlotFieldBarLocation || fieldEnum == CPTScatterPlotFieldX)
    {
        ShortDate* date = [dates objectAtIndex: endValue ? index - 1 : index];
        ShortDate* startDate = [self referenceDate];
        int days = [startDate daysToDate: date];
        if (endValue) {
            days++;
        }
        
        return [NSDecimalNumber numberWithDouble: oneDay * days];
    }
    
    if ([plot graph] == turnoversGraph)
    {
        if (!endValue && fieldEnum == CPTBarPlotFieldBarTip)
            return [balanceCounts objectAtIndex: index];
        
        return nil;
    }
    
    if ([plot graph] == mainGraph)
    {
        if (endValue) {
            if (fieldEnum == CPTBarPlotFieldBarTip) {
                return nil;
            }
            index--;
        }
        
        NSString* identifier = (id)plot.identifier;
        NSDecimalNumber* value = [balances objectAtIndex: index];
        if ([identifier isEqualToString: @"positivePlot"])
        {
            // Only return positive values for this plot. Negative values are displayed as 0.
            if ([value compare: [NSDecimalNumber zero]] == NSOrderedAscending)
                return [NSDecimalNumber numberWithDouble: 0];
            else
                return [balances objectAtIndex: index];
        }
        else
        {
            // Similar as for the positive plot, but for negative values.
            if ([value compare: [NSDecimalNumber zero]] == NSOrderedDescending)
                return [NSDecimalNumber numberWithDouble: 0];
            else
                return [balances objectAtIndex: index];
        }
    }
    
    if ([plot graph] == selectionGraph)
    {
        if (endValue) {
            index--;
        }
        
        return [balances objectAtIndex: index];
    }
    
    return nil;
}

- (CPTLayer *)dataLabelForPlot: (CPTPlot*)plot recordIndex: (NSUInteger)index 
{
    return (id)[NSNull null]; // Don't show any label
}

- (void)updateValues
{
    maxValue = [NSDecimalNumber zero];
    minValue = [NSDecimalNumber zero];
    
    for (NSUInteger i = 0; i < [dates count]; i++) {
        id y = [balances objectAtIndex: i];
        
        if ([y compare: maxValue] == NSOrderedDescending) {
            maxValue = y;
        }
        if ([y compare: minValue] == NSOrderedAscending) {
            minValue = y;
        }
    }

    // Ensure the stored time range is not larger than our existing data.
    ShortDate* date = [dates objectAtIndex: 0];
    if (fromDate == nil || [date compare: fromDate] == NSOrderedDescending) {
        [fromDate release];
        fromDate = [date retain];
    }
    
    date = [[dates lastObject] dateByAddingDays: 1];
    if (toDate == nil || [date compare: toDate] == NSOrderedAscending) {
        [toDate release];
        toDate = [date retain];
    }

    // Ensure a minimum of 14 days for display.
    int days = [fromDate daysToDate: toDate];
    if (days < 14) {
        [toDate release];
        toDate = [[fromDate dateByAddingDays: 14] retain];
    }
}

- (void)clearGraphs
{
    [dates release];
    dates = nil;
    [balances release];
    balances = nil;
    [balanceCounts release];
    balanceCounts = nil;
    
    NSArray* plots = mainGraph.allPlots;
    for (CPTPlot* plot in plots)
        [mainGraph removePlot: plot];
    plots = turnoversGraph.allPlots;
    for (CPTPlot* plot in plots)
        [turnoversGraph removePlot: plot];
}

-(Category*)currentSelection
{
    NSArray* sel = [accountsController selectedObjects];
    if (sel == nil || [sel count] != 1) {
        return nil;
    }
    return [sel objectAtIndex: 0];
}

- (void)outlineViewSelectionDidChange: (NSNotification*)notification
{
    [self clearGraphs];
    
    Category* category = [self currentSelection];
    if (category == nil)
        return;
    
    if (category.isBankAccount)
    {
        if ([category balanceHistoryToDates: &dates balances: &balances perDayCounts: &balanceCounts] == 0)
            return;
    }
    else
    {
        if ([category categoryHistoryToDates: &dates balances: &balances perDayCounts: &balanceCounts] == 0)
            return;
    }
    
    [dates retain];
    [balances retain];
    [balanceCounts retain];
    
    [self updateValues];

    [self setupMainPlots];
    [self setupTurnoversPlot];
    [self setupSelectionPlot];
    [self updateSelectionDisplay];
    
    [[mainHostView window] makeFirstResponder: mainHostView];
}

#pragma mark -
#pragma mark Old chart code

-(void)prepare
{
}

-(void)print
{
    NSPrintInfo	*printInfo = [NSPrintInfo sharedPrintInfo];
    [printInfo setTopMargin: 45];
    [printInfo setBottomMargin: 45];
    [printInfo setHorizontalPagination:NSFitPagination];
    [printInfo setVerticalPagination:NSFitPagination];
    NSPrintOperation *printOp;
    printOp = [NSPrintOperation printOperationWithView: printView printInfo: printInfo];
    [printOp setShowsPrintPanel: YES];
    [printOp runOperation];
}

-(NSView*)mainView
{
    return mainView;
}

// workaround for strange outlineView collapsing...
-(void)restoreAccountsView
{
   [accountsView restoreAll];
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(ImageAndTextCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    Category *cat = [item representedObject];
    if(cat == nil)
        return;
    
    //	NSImage *catImage		= [NSImage imageNamed:@"catdef4_18.png"];
    NSImage *moneyImage		= [NSImage imageNamed:@"money_18.png"];
    NSImage *moneySyncImage	= [NSImage imageNamed:@"money_sync_18.png"];
    NSImage *folderImage	= [NSImage imageNamed:@"folder_18.png"];
    
    if ([cat isBankAccount] && cat.accountNumber == nil)
        [cell setImage: folderImage];
    if ([cat isBankAccount] && cat.accountNumber != nil)
    {
        BankAccount *account = (BankAccount*)cat;
        if ([account.isManual boolValue] || [account.noAutomaticQuery boolValue])
            [cell setImage: moneyImage];
        else
            [cell setImage: moneySyncImage];
    }
    
    BOOL itemIsSelected = NO;
    if ([outlineView itemAtRow:[outlineView selectedRow]] == item)	 itemIsSelected = TRUE;
    
    BOOL itemIsRoot = [cat isRoot];
    if (itemIsRoot) {
        [cell setImage: nil];
    }
    
    [cell setValues: [cat catSum] currency: cat.currency unread: 0 selected: itemIsSelected root:itemIsRoot ];
}

-(NSString*)autosaveNameForTimeSlicer: (TimeSliceManager*)tsm
{
    return @"AccRepTimeSlice";
}

-(void)timeSliceManager: (TimeSliceManager*)tsm changedIntervalFrom: (ShortDate*)from to: (ShortDate*)to
{
}


- (id)outlineView:(NSOutlineView *)outlineView persistentObjectForItem:(id)item 
{
    return [outlineView persistentObjectForItem: item ];
}

-(id)outlineView: (NSOutlineView *)outlineView itemForPersistentObject: (id)object
{
    return nil;
}

-(void)terminate
{
    [accountsView saveLayout ];
}

@end
