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
#import <UIKit/UIKit.h>

#import "PureData.h"
#import "Midi.h"
#import "Osc.h"
#import "SceneManager.h"

@class PatchViewController;
@class BrowserViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

/// global access
@property (weak, nonatomic) PatchViewController *patchViewController;
@property (weak, nonatomic) BrowserViewController *browserViewController;

@property (strong, nonatomic) PureData *pureData;
@property (strong, nonatomic) Midi *midi;
@property (strong, nonatomic) Osc *osc;
@property (strong, nonatomic) SceneManager *sceneManager;

/// returns whether the patch view is currently visible
@property (readonly, nonatomic) BOOL isPatchViewVisible;

#pragma mark App Behavior

@property (assign, getter=isLockScreenDisabled, nonatomic) BOOL lockScreenDisabled;
@property (assign, nonatomic) BOOL runsInBackground;

#pragma mark Now Playing

/// create "Now Playing" nav bar button, target:self action:@selector(cNowPlayingPressed)
/// returns nil on iPad
- (UIBarButtonItem *)nowPlayingButton;

/// push patch view on sender.navigationController on iPhone, ignored on iPad
- (void)nowPlayingPressed:(id)sender;

#pragma mark URL

/// launch web view for a url, uses app scene folder for relative path
- (void)launchWebViewForURL:(NSURL *)url withTitle:(NSString *)title;

#pragma mark Util

/// recursively copy dirs and patches in the resource patches dir to the
/// Documents dir, removes/overwrites any currently existing subdirs matching
/// those within the source dir
- (void)copyLibDirectory;
- (void)copySamplesDirectory;
- (void)copyTestsDirectory;

@end
