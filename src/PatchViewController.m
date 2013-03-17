/*
 * Copyright (c) 2013 Dan Wilcox <danomatika@gmail.com>
 *
 * BSD Simplified License.
 * For information on usage and redistribution, and for a DISCLAIMER OF ALL
 * WARRANTIES, see the file, "LICENSE.txt," in this distribution.
 *
 * See https://github.com/danomatika/PdParty for documentation
 *
 */
#import "PatchViewController.h"

#import "Log.h"
#import "Gui.h"
#import "PdParser.h"
#import "PdFile.h"
#import "KeyGrabber.h"
#import "AppDelegate.h"

#define ACCEL_UPDATE_HZ	60.0

@interface PatchViewController () {

	NSMutableDictionary *activeTouches; // for persistent ids
	CMMotionManager *motionManager; // for accel data
	Osc *osc; // to send osc

	BOOL hasReshaped; // has the gui been reshaped?
}
@property (nonatomic, strong) UIPopoverController *masterPopoverController;
@end

@implementation PatchViewController

- (void)awakeFromNib {
	self.sceneType = SceneTypeEmpty;
	activeTouches = [[NSMutableDictionary alloc] init];
	hasReshaped = NO;
	[super awakeFromNib];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	KeyGrabberView *grabber = [[KeyGrabberView alloc] init];
	grabber.active = YES;
	grabber.delegate = self;
	[self.view addSubview:grabber];
	
	// set motionManager pointer for accel updates
	AppDelegate *app = (AppDelegate*)[[UIApplication sharedApplication] delegate];
	motionManager = app.motionManager;
	self.enableAccelerometer = YES;
	
	// set osc
	osc = app.osc;
}

- (void)viewDidLayoutSubviews {
	
	self.gui.bounds = self.view.bounds;
	
	// do animations if gui has already been setup once
	// http://www.techotopia.com/index.php/Basic_iOS_4_iPhone_Animation_using_Core_Animation
	if(hasReshaped) {
		[UIView beginAnimations:nil context:nil];
	}
	[self.gui reshapeWidgets];
	if(hasReshaped) {
		[UIView commitAnimations];
	}
	else {
		hasReshaped = YES;
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	
	int rotate = [PatchViewController orientationInDegrees:fromInterfaceOrientation] -
			     [PatchViewController orientationInDegrees:self.interfaceOrientation];
	
	NSString *orient;
	switch(self.interfaceOrientation) {
		case UIInterfaceOrientationPortrait:
			orient = PARTY_ORIENT_PORTRAIT;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			orient = PARTY_ORIENT_PORTRAIT_UPSIDEDOWN;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			orient = PARTY_ORIENT_LANDSCAPE_LEFT;
			break;
		case UIInterfaceOrientationLandscapeRight:
			orient = PARTY_ORIENT_LANDSCAPE_RIGHT;
			break;
	}

//	DDLogVerbose(@"rotate: %d %@", rotate, orient);
	[PureData sendRotate:rotate newOrientation:orient];
	if(osc.isListening) {
		[osc sendRotate:rotate newOrientation:orient];
	}
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Overridden Getters / Setters

- (void)setPatch:(NSString*)newPatch {
    
	if(_patch != newPatch) {
        _patch = newPatch;
		
		// create gui here as iPhone dosen't load view until *after* this is called
		if(!self.gui) {
			self.gui = [[Gui alloc] init];
			self.gui.bounds = self.view.bounds;
		}
		
		// close open patch
		if(self.gui.patch) {
			[self.gui.patch closeFile];
			for(Widget *widget in self.gui.widgets) {
				[widget removeFromSuperview];
			}
			[self.gui.widgets removeAllObjects];
			self.gui.patch = nil;
		}
		
		// open new patch
		if(self.patch) {
			
			NSString *fileName = [self.patch lastPathComponent];
			NSString *dirPath = [self.patch stringByDeletingLastPathComponent];
			
			DDLogVerbose(@"Opening %@ %@", fileName, dirPath);
			self.navigationItem.title = [fileName stringByDeletingPathExtension]; // set view title
			
			// load gui
			[self.gui addWidgetsFromPatch:self.patch];
			self.gui.patch = [PdFile openFileNamed:fileName path:dirPath];
			DDLogVerbose(@"Adding %d widgets", self.gui.widgets.count);
			for(Widget *widget in self.gui.widgets) {
				[widget replaceDollarZerosForGui:self.gui];
				[self.view addSubview:widget];
			}
			hasReshaped = NO;
		}
		else {
			self.sceneType = SceneTypeEmpty;
		}
    }

    if(self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }        
}

#pragma mark Util

+ (int)orientationInDegrees:(UIInterfaceOrientation)orientation {
	switch(orientation) {
		case UIInterfaceOrientationPortrait:
			return 0;
		case UIInterfaceOrientationPortraitUpsideDown:
			return 180;
		case UIInterfaceOrientationLandscapeLeft:
			return 90;
		case UIInterfaceOrientationLandscapeRight:
			return -90;
	}
}

#pragma mark Overridden Getters / Setters

- (void)setEnableAccelerometer:(BOOL)enableAccelerometer {
	if(self.enableAccelerometer == enableAccelerometer) {
		return;
	}
	_enableAccelerometer = enableAccelerometer;
	
	// start
	if(enableAccelerometer) {
		if([motionManager isAccelerometerAvailable]) {
			NSTimeInterval updateInterval = 1.0/ACCEL_UPDATE_HZ;
			[motionManager setAccelerometerUpdateInterval:updateInterval];
			
			// accel data callback block
			[motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue]
				withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
//					DDLogVerbose(@"accel %f %f %f", accelerometerData.acceleration.x,
//													accelerometerData.acceleration.y,
//													accelerometerData.acceleration.z);
					[PureData sendAccel:accelerometerData.acceleration.x
									  y:accelerometerData.acceleration.y
									  z:accelerometerData.acceleration.z];
					if(osc.isListening) {
						[osc sendAccel:accelerometerData.acceleration.x
										  y:accelerometerData.acceleration.y
										  z:accelerometerData.acceleration.z];
					}
				}];
		}
	}
	else { // stop
		if([motionManager isAccelerometerActive]) {
          [motionManager stopAccelerometerUpdates];
		}
	}
}

#pragma mark Touches

// persistent touch ids from ofxIPhone:
// https://github.com/openframeworks/openFrameworks/blob/master/addons/ofxiPhone/src/core/ofxiOSEAGLView.mm
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {	
	
	for(UITouch *touch in touches) {
		int touchId = 0;
		while([[activeTouches allValues] containsObject:[NSNumber numberWithInt:touchId]]){
			touchId++;
		}
		[activeTouches setObject:[NSNumber numberWithInt:touchId]
						  forKey:[NSValue valueWithPointer:(__bridge const void *)(touch)]];
		
		CGPoint pos = [touch locationInView:self.view];
		pos.x = pos.x/CGRectGetWidth(self.view.frame);
		pos.y = pos.y/CGRectGetHeight(self.view.frame);
			
		// normalize
		if(self.sceneType == SceneTypeRj) {
			pos.x = (int)(pos.x * 320);
			pos.y = (int)(pos.y * 320);
		}
		
//		DDLogVerbose(@"touch %d: down %.4f %.4f", touchId+1, pos.x, pos.y);
		[PureData sendTouch:RJ_TOUCH_DOWN forId:touchId atX:pos.x andY:pos.y];
		if(osc.isListening) {
			[osc sendTouch:RJ_TOUCH_DOWN forId:touchId atX:pos.x andY:pos.y];
		}
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	
	for(UITouch *touch in touches) {
		int touchId = [[activeTouches objectForKey:[NSValue valueWithPointer:(__bridge const void *)(touch)]] intValue];
		
		CGPoint pos = [touch locationInView:self.view];
		pos.x = pos.x/CGRectGetWidth(self.view.frame);
		pos.y = pos.y/CGRectGetHeight(self.view.frame);
			
		// normalize
		if(self.sceneType == SceneTypeRj) {
			pos.x = (int)(pos.x * 320);
			pos.y = (int)(pos.y * 320);
		}
		
//		DDLogVerbose(@"touch %d: moved %d %d", touchId+1, (int) pos.x, (int) pos.y);
		[PureData sendTouch:RJ_TOUCH_XY forId:touchId atX:pos.x andY:pos.y];
		if(osc.isListening) {
			[osc sendTouch:RJ_TOUCH_XY forId:touchId atX:pos.x andY:pos.y];
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {

	for(UITouch *touch in touches) {
		int touchId = [[activeTouches objectForKey:[NSValue valueWithPointer:(__bridge const void *)(touch)]] intValue];
		[activeTouches removeObjectForKey:[NSValue valueWithPointer:(__bridge const void *)(touch)]];
		
		CGPoint pos = [touch locationInView:self.view];
		pos.x = pos.x/CGRectGetWidth(self.view.frame);
		pos.y = pos.y/CGRectGetHeight(self.view.frame);
		
		// normalize
		if(self.sceneType == SceneTypeRj) {
			pos.x = (int)(pos.x * 320);
			pos.y = (int)(pos.y * 320);
		}
		
//		DDLogVerbose(@"touch %d: up %d %d", touchId+1, (int) pos.x, (int) pos.y);
		[PureData sendTouch:RJ_TOUCH_UP forId:touchId atX:pos.x andY:pos.y];
		if(osc.isListening) {
			[osc sendTouch:RJ_TOUCH_UP forId:touchId atX:pos.x andY:pos.y];
		}
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	[self touchesEnded:touches withEvent:event];
}

#pragma mark KeyGrabberDelegate

- (void)keyPressed:(int)key {
	[PureData sendKey:key];
}

#pragma mark UISplitViewControllerDelegate

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController {

	if([Util isDeviceATablet]) {
		barButtonItem.title = NSLocalizedString(@"Patches", @"Patches");
	}
    
	[self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem {
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

// hide master view controller by default on all orientations
- (BOOL)splitViewController:(UISplitViewController *)splitController shouldHideViewController:(UIViewController *)viewController inOrientation:(UIInterfaceOrientation)orientation {
	return YES;
}

@end
