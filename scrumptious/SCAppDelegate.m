/*
 * Copyright 2012 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "SCAppDelegate.h"
#import "SCViewController.h"
#import "SCTimelineViewController.h"
#import <FacebookSDK/FBSessionTokenCachingStrategy.h>
#import <Parse/Parse.h>

@implementation SCAppDelegate

@synthesize window = _window,
            navigationController = _navigationController,
            mainViewController = _mainViewController,
            timelineViewController = _timelineViewController,
            isNavigating = _isNavigating;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // ****************************************************************************
    // Add your Parse credentials here
    //
    // [Parse setApplicationId:YOUR_APPLICATION_ID clientKey:YOUR_CLIENT_KEY];
    //
    // ****************************************************************************
    
    [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
    [PFFacebookUtils initializeFacebook];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Create timeline view controller
    self.timelineViewController = [[SCTimelineViewController alloc]
                                   initWithNibName:@"SCTimelineViewController" bundle:nil];
    
    // Create our navigation controller
    self.navigationController = [[UINavigationController alloc]
                                 initWithRootViewController:self.timelineViewController];
    self.navigationController.delegate = self;
    
    // Set root view controller
    self.window.rootViewController = self.navigationController;
    
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [PFFacebookUtils handleOpenURL:url];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Facebook SDK * pro-tip *
    // if the app is going away, we close the session object; this is a good idea because
    // things may be hanging off the session, that need releasing (completion block, etc.) and
    // other components in the app may be awaiting close notification in order to do cleanup
    [FBSession.activeSession close];
}

- (void)applicationDidBecomeActive:(UIApplication *)application	{
    // Facebook SDK * login flow *
    // We need to properly handle activation of the application with regards to SSO
    //  (e.g., returning from iOS 6.0 authorization dialog or from fast app switching).
    [FBSession.activeSession handleDidBecomeActive];
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
    self.isNavigating = NO;
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    self.isNavigating = YES;
}

@end
