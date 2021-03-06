/**
 * Copyright (c) 2008, 2015, Pecunia Project. All rights reserved.
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

#import "CategoryMaintenanceController.h"
#import "BankingCategory.h"
#import "MOAssistant.h"
#import "NSDictionary+PecuniaAdditions.h"
#import "MessageLog.h"
#import "BWGradientBox.h"

extern NSString *const CategoryColorNotification;
extern NSString *const CategoryKey;

// A simple descentant to store our image name (NSImage.name doesn't accept our "names").
@interface LibraryImage : NSImage
@property (copy) NSString *privatePath;
@end

@implementation LibraryImage
@end

// A simple descendant to send mouse click actions and accept dragged image files.
@interface DoubleClickImageView : NSImageView
{
}

@property (assign) id controller;

@end

@implementation DoubleClickImageView

@synthesize controller;

- (void)mouseDown: (NSEvent *)theEvent {
    // Eat this event to prevent the image view from doing so which would result in no
    // mouseUp event.
}

- (void)mouseUp: (NSEvent *)theEvent {
    NSPoint point = [self convertPoint: theEvent.locationInWindow fromView: nil];
    if (NSPointInRect(point, self.bounds) && [[self target] respondsToSelector: [self action]]) {
        [NSApp sendAction: [self action] to: [self target] from: self];
    }
}

- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect: [self bounds] cursor: [NSCursor pointingHandCursor]];
}

- (void)concludeDragOperation: (id <NSDraggingInfo>)sender {
    // Read image path for later processing.
    // Temporarily remove the associated action to prevent NSImageView to trigger it.
    SEL action = self.action;
    self.action = nil;

    // Convert image to a LibraryImage.
    NSString *path = [[sender draggingPasteboard] propertyListForType: @"NSFilenamesPboardType"][0];
    [super concludeDragOperation: sender];
    LibraryImage *newImage = [[LibraryImage alloc] initWithContentsOfFile: path];
    newImage.privatePath = path;
    self.action = action;
    self.image = newImage;
}

@end

#pragma mark -

@interface LibraryIconView : NSBox
{
}
@end

@implementation LibraryIconView

- (id)initWithFrame: (NSRect)frameRect {
    self = [super initWithFrame: frameRect];
    if (self != nil) {
    }
    return self;
}

- (NSView *)hitTest: (NSPoint)aPoint {
    // Don't allow any mouse clicks for subviews in this NSBox (necessary for making this box selectable).
    if (NSPointInRect(aPoint, [self convertRect: [self bounds] toView: [self superview]])) {
        return self;
    } else {
        return nil;
    }
}

- (void)mouseDown: (NSEvent *)theEvent {
    [super mouseDown: theEvent];

    if ([theEvent clickCount] > 1) {
        [NSApp sendAction: @selector(acceptImage:) to: nil from: self];
    }
}

@end

#pragma mark -

@interface ImageLibraryPopup : NSView
@end

@implementation ImageLibraryPopup

- (void)cancelOperation: (id)sender {
    [NSApp sendAction: @selector(cancelImage:) to: nil from: self];
}

@end

#pragma mark -

@interface CategoryMaintenanceController ()
{
    IBOutlet NSObjectController *categoryController;
    IBOutlet BWGradientBox      *topGradient;
    IBOutlet BWGradientBox      *backgroundGradient;
    IBOutlet NSPopover          *imageLibraryPopover;

    BankingCategory *category;
    BankingCategory *changedCategory;
    NSMutableArray  *iconCollection;

    NSManagedObjectContext *moc;
}

@property (strong) IBOutlet DoubleClickImageView *categoryIcon;
@property (strong) IBOutlet NSImageView          *smallCategoryIcon;
@property (strong) IBOutlet NSView               *imageLibraryPopup;
@property (strong) IBOutlet NSArrayController    *iconCollectionController;
@property (strong) NSArray                       *iconCollection;

@property (assign) NSUInteger currentCollection;

@end

@implementation CategoryMaintenanceController

@synthesize categoryIcon;
@synthesize smallCategoryIcon;
@synthesize imageLibraryPopup;
@synthesize iconCollectionController;
@synthesize iconCollection;
@synthesize currentCollection;

- (id)initWithCategory: (BankingCategory *)aCategory {
    self = [super initWithWindowNibName: @"CategoryMaintenance"];
    if (self != nil) {
        moc = MOAssistant.sharedAssistant.memContext; // Referenced by the xib.
        category = [NSEntityDescription insertNewObjectForEntityForName: @"Category"
                                                 inManagedObjectContext: moc];

        changedCategory = aCategory;
        category.name = aCategory.name;
        category.currency = aCategory.currency;
        category.categoryColor = aCategory.categoryColor;
        category.iconName = aCategory.iconName;
        category.isHidden = aCategory.isHidden;
        category.noCatRep = aCategory.noCatRep;

        currentCollection = 1;
    }
    return self;
}

- (void)awakeFromNib {
    // Manually set up properties which cannot be set via user defined runtime attributes
    // (Color type is not available pre 10.7).
    topGradient.fillStartingColor = [NSColor colorWithCalibratedWhite: 59 / 255.0 alpha: 1];
    topGradient.fillEndingColor = [NSColor colorWithCalibratedWhite: 99 / 255.0 alpha: 1];
    backgroundGradient.fillColor = [NSColor whiteColor];

    iconCollection = [NSMutableArray arrayWithCapacity: 100];
    [categoryIcon addObserver: self forKeyPath: @"image" options: 0 context: nil];
    categoryIcon.controller = self;

    if (category.iconName.length > 0) {
        NSString *path;
        if ([category.iconName isAbsolutePath]) { // Shouldn't happen, but just in case.
            path = category.iconName;
        } else {
            NSURL *url = [NSURL URLWithString: category.iconName];
            if (url.scheme == nil) { // Old style collection item.
                NSString *subfolder = [category.iconName stringByDeletingLastPathComponent];
                path = [[NSBundle mainBundle] pathForResource: [category.iconName lastPathComponent]
                                                       ofType: @"icns"
                                                  inDirectory: subfolder];
            } else {
                if ([url.scheme isEqualToString: @"collection"]) { // An image from one of our collections.
                    NSDictionary *parameters = [NSDictionary dictForUrlParameters: url];
                    NSString     *subfolder = [@"Collections/" stringByAppendingString : parameters[@"c"]];
                    path = [[NSBundle mainBundle] pathForResource: [url.host stringByDeletingPathExtension]
                                                           ofType: url.host.pathExtension
                                                      inDirectory: subfolder];

                } else {
                    if ([url.scheme isEqualToString: @"image"]) { // An image from our data bundle.
                        NSString *targetFolder = [MOAssistant.sharedAssistant.pecuniaFileURL.path stringByAppendingString: @"/Images/"];
                        path = [targetFolder stringByAppendingString: url.host];
                    }
                }
            }
        }

        // Might leave the image at nil if the path is wrong or the image could not be loaded.
        LibraryImage *image = [[LibraryImage alloc] initWithContentsOfFile: path];
        image.privatePath = category.iconName;
        categoryIcon.image = image;
    }

    // Set up the icon collection with all icons in our (first) internal collection.
    // TODO: handle multiple collectons.
    NSArray *paths = [NSBundle.mainBundle pathsForResourcesOfType: @"icns" inDirectory: @"Collections/1"];

    for (NSString *path in paths) {
        LibraryImage *image = [[LibraryImage alloc] initByReferencingFile: path];
        if (image != nil) {
            image.privatePath = [path lastPathComponent];
            [iconCollectionController addObject: @{@"icon": image}];
        }
    }

    if ([iconCollectionController.arrangedObjects count] > 0) {
        iconCollectionController.selectionIndex = 0;
    }
}

#pragma mark - KVO handling

- (void)observeValueForKeyPath: (NSString *)keyPath
                      ofObject: (id)object
                        change: (NSDictionary *)change
                       context: (void *)context {
    if ([keyPath isEqualToString: @"image"]) {
        smallCategoryIcon.image = categoryIcon.image;
        return;
    }
    [super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
}

- (void)openImageLibrary {
    if (!imageLibraryPopover.shown) {
        [imageLibraryPopover showRelativeToRect: categoryIcon.bounds ofView: categoryIcon preferredEdge: NSMinYEdge];
    }
}

#pragma mark - Event handling

- (IBAction)selectImage: (id)sender {
    [self openImageLibrary];
}

- (IBAction)acceptImage: (id)sender {
    [imageLibraryPopover performClose: sender];

    NSArray *selection = iconCollectionController.selectedObjects;
    if ([selection count] > 0) {
        categoryIcon.image = selection[0][@"icon"];
    }
}

- (IBAction)cancelImage: (id)sender {
    [imageLibraryPopover performClose: sender];
}

- (IBAction)cancel: (id)sender {
    if ([NSColorPanel sharedColorPanelExists]) {
        [[NSColorPanel sharedColorPanel] close];
    }

    [categoryIcon removeObserver: self forKeyPath: @"image"];


    [self close];
    [moc reset];
    [NSApp stopModalWithCode: 0];
}

- (IBAction)ok: (id)sender {
    if ([NSColorPanel sharedColorPanelExists]) {
        [[NSColorPanel sharedColorPanel] close];
    }

    [categoryIcon removeObserver: self forKeyPath: @"image"];

    [categoryController commitEditing];
    NSManagedObjectContext *context = MOAssistant.sharedAssistant.context;

    // Take changes over.
    changedCategory.localName = category.localName;
    changedCategory.currency = category.currency;
    changedCategory.categoryColor = category.categoryColor;
    changedCategory.isHidden = category.isHidden;
    changedCategory.noCatRep = category.noCatRep;

    LibraryImage *image = (LibraryImage*)categoryIcon.image;

    // Path to the data bundle image folder.
    NSString *targetFolder = [MOAssistant.sharedAssistant.pecuniaFileURL.path stringByAppendingString: @"/Images/"];
    if (image != nil && image.privatePath != nil) {
        if (![image.privatePath isEqualToString: category.iconName]) {
            // Remove a previously copied image if there's one referenced.
            NSURL *oldUrl = [NSURL URLWithString: category.iconName];
            if (oldUrl != nil) {
                if ([oldUrl.scheme isEqual: @"image"]) {
                    NSString *targetFileName = [NSString stringWithFormat: @"%@%@", targetFolder, oldUrl.host];

                    // Remove the file but don't show a message in case of an error. The message is
                    // meaningless anyway (since it contains the internal filename).
                    [NSFileManager.defaultManager removeItemAtPath: targetFileName error: nil];
                }
            }

            if ([image.privatePath isAbsolutePath]) {
                // An icon located somewhere else in the file system. In order to avoid the need for
                // security bookmarks and other trouble (like unavailable network drives etc.) we copy
                // the icon to our data bundle (like we do for attachments).
                NSString *guid = [[NSProcessInfo processInfo] globallyUniqueString];
                NSString *uniqueFilenName = [NSString stringWithFormat: @"%@.%@", guid, image.privatePath.pathExtension];
                NSString *targetFileName = [targetFolder stringByAppendingString: uniqueFilenName];

                NSError *error = nil;
                if (![NSFileManager.defaultManager createDirectoryAtPath: targetFolder withIntermediateDirectories: YES attributes: nil error: &error]) {
                    NSAlert *alert = [NSAlert alertWithError: error];
                    [alert runModal];
                }
                if (error == nil && ![NSFileManager.defaultManager copyItemAtPath: image.privatePath
                                                                           toPath: targetFileName
                                                                            error: &error]) {
                    NSAlert *alert = [NSAlert alertWithError: error];
                    [alert runModal];
                }

                changedCategory.iconName = [@"image://" stringByAppendingString : uniqueFilenName];
            } else {
                // A library icon was selected. Construct the relative path. Parameter c refers to the
                // collection number.
                changedCategory.iconName = [NSString stringWithFormat: @"collection://%@?c=%lu", image.privatePath, currentCollection];
            }
        }
    } else {
        NSURL *oldUrl = [NSURL URLWithString: category.iconName];
        if (oldUrl != nil) {
            if ([oldUrl.scheme isEqual: @"image"]) {
                NSString *targetFileName = [NSString stringWithFormat: @"%@%@", targetFolder, oldUrl.host];
                [NSFileManager.defaultManager removeItemAtPath: targetFileName error: nil];
            }
        }
        changedCategory.iconName = @""; // An empty string denotes a category without icon.
    }

    [NSNotificationCenter.defaultCenter postNotificationName: CategoryColorNotification
                                                      object: self
                                                    userInfo: @{CategoryKey: changedCategory}];
    [self close];

    NSError *error = nil;
    if (![context save: &error]) {
        NSAlert *alert = [NSAlert alertWithError: error];
        [alert runModal];
    }

    [moc reset];
    [NSApp stopModalWithCode: 1];
}

- (IBAction)removeIcon: (id)sender {
    categoryIcon.image = nil;
    smallCategoryIcon.image = nil;
}

@end
