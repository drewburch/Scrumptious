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

#import "SCViewController.h"
#import "SCAppDelegate.h"
#import "SCProtocols.h"
#import <AddressBook/AddressBook.h>
#import "TargetConditionals.h"
#import <Parse/Parse.h>

enum {
    GroupFieldTag = 0,
    StatusFieldTag = 1
};

@interface SCViewController() < UITableViewDataSource, 
                                FBFriendPickerDelegate,
                                UINavigationControllerDelegate,
                                FBPlacePickerDelegate,
                                CLLocationManagerDelegate,
                                UITextFieldDelegate>

@property (strong, nonatomic) IBOutlet UITableView *menuTableView;
@property (strong, nonatomic) IBOutlet FBProfilePictureView *userProfileImage;
@property (strong, nonatomic) IBOutlet UILabel *userNameLabel;
@property (strong, nonatomic) IBOutlet UIButton *announceButton;


@property (strong, nonatomic) NSString *status;
@property (strong, nonatomic) NSString *groupName;
@property (strong, nonatomic) NSArray *selectedFriends;
@property (strong, nonatomic) CLLocationManager *locationManager;

@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) CLLocation *currentLocation;

@property (strong, nonatomic) FBCacheDescriptor *placeCacheDescriptor;

@end

@implementation SCViewController
@synthesize menuTableView = _menuTableView;
@synthesize userNameLabel = _userNameLabel;
@synthesize userProfileImage = _userProfileImage;
@synthesize status = _status;
@synthesize groupName = _groupName;
@synthesize selectedFriends = _selectedFriends;
@synthesize currentLocation = _currentLocation;
@synthesize announceButton = _announceButton;
@synthesize locationManager = _locationManager;
@synthesize activityIndicator = _activityIndicator;

@synthesize placeCacheDescriptor = _placeCacheDescriptor;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


// Creates the Open Graph Action.
- (void)postOpenGraphAction {
    
    
    static int retryCount = 0;
    self.announceButton.enabled = false;
    // save the new post to parse
    [self saveParseObject];
    
    // start over
    self.status = nil;
    self.groupName = nil;
    self.selectedFriends = nil;
    retryCount = 0;
    [self updateSelections];
    self.announceButton.enabled = YES;
    [self.view setUserInteractionEnabled:YES];
    // dismiss view controller
    [self dismissViewControllerAnimated:YES completion:NULL];
}

// Save the post object to Parse
- (void)saveParseObject {
    // We create a new Parse object and set the data we want to store
    PFObject *newGroup = [[PFObject alloc] initWithClassName:@"Group"];
    
    // Add fielded data
    [newGroup setObject:self.status forKey:@"status"];
    [newGroup setObject:self.groupName forKey:@"groupName"];

    // Add location geopoint
    PFGeoPoint *location = [[PFGeoPoint alloc] init];
    [location setLatitude:self.currentLocation.coordinate.latitude];
    [location setLongitude:self.currentLocation.coordinate.longitude];
    [newGroup setObject:location forKey:@"location"];
        
    // Create 1-1 relationship between the current user and the post
    [newGroup setObject:[PFUser currentUser] forKey:@"createdBy"];

    // Add the IDs of the associated friends
    NSMutableArray *friendsIDs = [[NSMutableArray alloc] initWithCapacity:self.selectedFriends.count];
    NSMutableArray *friendsDisplay = [[NSMutableArray alloc] initWithCapacity:self.selectedFriends.count];
    for (NSDictionary *friend in self.selectedFriends) {
        [friendsIDs addObject:[friend objectForKey:@"id"]];
        [friendsDisplay addObject:friend];
    }
    // add the current user to the friends array
    [friendsIDs addObject:[[PFUser currentUser] objectForKey:@"fbid"]];
    // add the current user to the friendsDisplay array
    NSDictionary *displayObj = @{
                                 @"id" : [[PFUser currentUser] objectForKey:@"fbid"],
                                 @"name" : [[PFUser currentUser] objectForKey:@"name"]
                                };
    
    [friendsDisplay addObject:displayObj];
    
    // set the properties on the group class    
    [newGroup setObject:friendsIDs forKey:@"friends"];
    [newGroup setObject:friendsDisplay forKey:@"friendsDisplay"];
    [newGroup setObject:@"active" forKey:@"status"];
    
    // check to see if the user has a current group that has status set to active
    // if so we want to set that status to inactive
    
    
    // We save the object! If there's no internet connection, Parse
    // will automatically queue the operation and retry when possible
    [newGroup saveEventually:^(BOOL succeeded, NSError *error) {
        NSLog(@"Object saved to Parse! :)");
    }];
}

- (void) presentAlertForError:(NSError *)error {
    // Facebook SDK * error handling *
    // Error handling is an important part of providing a good user experience.
    // When fberrorShouldNotifyUser is YES, a fberrorUserMessage can be
    // presented as a user-ready message
    if (error.fberrorShouldNotifyUser) {
        // The SDK has a message for the user, surface it.
        [[[UIAlertView alloc] initWithTitle:@"Something Went Wrong"
                                    message:error.fberrorUserMessage
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
}

#pragma mark - UI Behavior

// Handles the user clicking the Announce button by creating an Open Graph Action
- (IBAction)announce:(id)sender {
    [self postOpenGraphAction];
}

- (void)centerAndShowActivityIndicator {
    CGRect frame = self.view.frame;
    CGPoint center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    self.activityIndicator.center = center;
    [self.activityIndicator startAnimating];
}

// Displays the user's name and profile picture so they are aware of the Facebook
// identity they are logged in as.
- (void)populateUserDetails {
    if ([PFFacebookUtils.session isOpen]) {
        [[FBRequest requestForMe] startWithCompletionHandler:
         ^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *user, NSError *error) {
             if (!error) {
                 self.userNameLabel.text = user.name;
                 self.userProfileImage.profileID = [user objectForKey:@"id"];
             }
         }];
    }
}

- (void)closeButtonWasPressed:(id)sender {
    [self dismissModalViewControllerAnimated:YES];
}


#pragma mark - Overrides

- (void)dealloc {
    _locationManager.delegate = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Scrumptious";
    
    [self.locationManager startUpdatingLocation];
    
    // Get the CLLocationManager going.
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    // We don't want to be notified of small changes in location, preferring to use our
    // last cached results, if any.
    self.locationManager.distanceFilter = 50;
    
    FBCacheDescriptor *cacheDescriptor = [FBFriendPickerViewController cacheDescriptor];
    [cacheDescriptor prefetchAndCacheForSession:PFFacebookUtils.session];
    
    // This avoids a gray background in the table view on iPad.
    if ([self.menuTableView respondsToSelector:@selector(backgroundView)]) {
        self.menuTableView.backgroundView = nil;
    }
    
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc]initWithTitle:@"Close"
                                        style:UIBarButtonItemStyleBordered
                                       target:self
                                       action:@selector(closeButtonWasPressed:)];
    
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.tabBarController.navigationItem.hidesBackButton = YES;

    
    if ([PFFacebookUtils.session isOpen]) {
        [self populateUserDetails];
    }
}

- (void) viewDidAppear:(BOOL)animated {
    if ([PFFacebookUtils.session isOpen]) {
        [self.locationManager startUpdatingLocation];
    }
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - UITableViewDataSource methods and related helpers

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = (UITableViewCell*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.textLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
        cell.textLabel.lineBreakMode = UILineBreakModeTailTruncation;
        cell.textLabel.clipsToBounds = YES;

        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.4 green:0.6 blue:0.8 alpha:1];
        cell.detailTextLabel.lineBreakMode = UILineBreakModeTailTruncation;
        cell.detailTextLabel.clipsToBounds = YES;
    }
    
    switch (indexPath.row) {
        case 0:
        {
            
            // Add a UITextField
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(110, 10, 185, 30)];
            
            textField.placeholder = @"Group Name";
            textField.tag = GroupFieldTag;
            textField.keyboardType = UIKeyboardTypeDefault;
            textField.returnKeyType = UIReturnKeyDone;
            textField.delegate = self;
            
            [cell.contentView addSubview:textField];
            [cell.contentView bringSubviewToFront:textField];
            break;
        }
        case 1:
        {
            cell.textLabel.text = @"With whom?";
            cell.detailTextLabel.text = @"Select friends";
            cell.imageView.image = [UIImage imageNamed:@"action-people.png"];
            break;
        }
        case 2:
        {
            // Add a UITextField
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(110, 10, 185, 30)];
            
            textField.placeholder = @"Status";
            textField.tag = StatusFieldTag;
            textField.keyboardType = UIKeyboardTypeDefault;
            textField.returnKeyType = UIReturnKeyDone;
            textField.delegate = self;

            
            [cell.contentView addSubview:textField];
            [cell.contentView bringSubviewToFront:textField];
            break;
        }
        default:
            break;
    }

    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 1: {
            FBFriendPickerViewController *friendPicker = [[FBFriendPickerViewController alloc] init];
            
            // Set up the friend picker to sort and display names the same way as the
            // iOS Address Book does.
            
            // Need to call ABAddressBookCreate in order for the next two calls to do anything.
            ABAddressBookRef addressBook = ABAddressBookCreate();
            ABPersonSortOrdering sortOrdering = ABPersonGetSortOrdering();
            ABPersonCompositeNameFormat nameFormat = ABPersonGetCompositeNameFormat();
            
            friendPicker.sortOrdering = (sortOrdering == kABPersonSortByFirstName) ? FBFriendSortByFirstName : FBFriendSortByLastName;
            friendPicker.displayOrdering = (nameFormat == kABPersonCompositeNameFormatFirstNameFirst) ? FBFriendDisplayByFirstName : FBFriendDisplayByLastName;
            
            [friendPicker loadData];
            [friendPicker presentModallyFromViewController:self
                                                  animated:YES
                                                   handler:^(FBViewController *sender, BOOL donePressed) {
                                                       if (donePressed) {
                                                           self.selectedFriends = friendPicker.selection;
                                                           [self updateSelections];
                                                       }
                                                   }];
            CFRelease(addressBook);
            return;
        }
    }
}

- (void)updateCellIndex:(int)index withSubtitle:(NSString *)subtitle {
    UITableViewCell *cell = (UITableViewCell *)[self.menuTableView cellForRowAtIndexPath:
                                                [NSIndexPath indexPathForRow:index inSection:0]];
    cell.detailTextLabel.text = subtitle;
}

- (void)updateSelections {
    
    
    NSString *friendsSubtitle = @"Select friends";
    int friendCount = self.selectedFriends.count;
    if (friendCount > 2) {
        // Just to mix things up, don't always show the first friend.
        id<FBGraphUser> randomFriend = [self.selectedFriends objectAtIndex:arc4random() % friendCount];
        friendsSubtitle = [NSString stringWithFormat:@"%@ and %d others",
                           randomFriend.name,
                           friendCount - 1];
    } else if (friendCount == 2) {
        id<FBGraphUser> friend1 = [self.selectedFriends objectAtIndex:0];
        id<FBGraphUser> friend2 = [self.selectedFriends objectAtIndex:1];
        friendsSubtitle = [NSString stringWithFormat:@"%@ and %@",
                           friend1.name,
                           friend2.name];
    } else if (friendCount == 1) {
        id<FBGraphUser> friend = [self.selectedFriends objectAtIndex:0];
        friendsSubtitle = friend.name;
    }
    [self updateCellIndex:1 withSubtitle:friendsSubtitle];
    
    self.announceButton.enabled = (self.groupName != nil);
}


- (void)textFieldDidEndEditing:(UITextField *)textField {
    if ([textField.text isEqualToString:@""])
        return;
    
    switch (textField.tag) {
        case GroupFieldTag:
            self.groupName = textField.text;
            break;
        case StatusFieldTag:
            self.status = textField.text;
            break;
        default:
            break;
    }
}

#pragma mark - CLLocationManagerDelegate methods and related

- (void)locationManager:(CLLocationManager *)manager 
    didUpdateToLocation:(CLLocation *)newLocation 
           fromLocation:(CLLocation *)oldLocation {
    if (!oldLocation ||
        (oldLocation.coordinate.latitude != newLocation.coordinate.latitude && 
         oldLocation.coordinate.longitude != newLocation.coordinate.longitude &&
         newLocation.horizontalAccuracy <= 100.0)) {
            // Fetch data at this new location, and remember the cache descriptor.
            self.currentLocation = newLocation;
            
            // turn the current location into a geopoint
            PFGeoPoint *location = [[PFGeoPoint alloc] init];
            [location setLatitude:self.currentLocation.coordinate.latitude];
            [location setLongitude:self.currentLocation.coordinate.longitude];
            // set the currentLocation on the current user
            [[PFUser currentUser] setObject:location forKey:@"currentLocation"];
            // save the current user object
            [[PFUser currentUser] saveEventually:^(BOOL succeeded, NSError *error) {
                if (succeeded) {
                    NSLog(@"new location updated");
                }
            }];
    }
}

- (void)locationManager:(CLLocationManager *)manager 
       didFailWithError:(NSError *)error {
	NSLog(@"%@", error);
}

/**
 Return a location manager -- create one if necessary.
 */
- (CLLocationManager *)locationManager {
    
    if (_locationManager != nil) {
		return _locationManager;
	}
    
	_locationManager = [[CLLocationManager alloc] init];
    _locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
    _locationManager.delegate = self;
    _locationManager.purpose = @"Your current location is used to demonstrate PFGeoPoint and Geo Queries.";
    
	return _locationManager;
}



- (void)setPlaceCacheDescriptorForCoordinates:(CLLocationCoordinate2D)coordinates {
    self.placeCacheDescriptor =
    [FBPlacePickerViewController cacheDescriptorWithLocationCoordinate:coordinates
                                                        radiusInMeters:1000
                                                            searchText:@"restaurant"
                                                          resultsLimit:50
                                                      fieldsForRequest:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

#pragma mark -

@end
