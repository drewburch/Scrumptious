//
//  PFTimelineViewController.h
//  Scrumptious
//
//  Created by Matt GA on 2/26/13.
//
//

#import <UIKit/UIKit.h>
#import <FacebookSDK/FacebookSDK.h>
#import <Parse/Parse.h>

@interface SCTimelineViewController : PFQueryTableViewController <PFLogInViewControllerDelegate>

@property (nonatomic, strong) IBOutlet UIImageView *blankTimelineView;

@end
