//
//  PFTimelineViewController.m
//  Scrumptious
//
//  Created by Matt GA on 2/26/13.
//
//

#import "SCTimelineViewController.h"
#import "SCViewController.h"
#import "MBProgressHUD.h"
#import <Parse/Parse.h>

@interface SCTimelineViewController ()

@property (strong, nonatomic) PFLogInViewController *loginViewController;
@property (strong, nonatomic) MBProgressHUD *progressHud;
@property (strong, nonatomic) PFGeoPoint *userLocation;
@property (strong, nonatomic) NSMutableDictionary *settings;

@end

@implementation SCTimelineViewController

#pragma mark - Initialization

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.title = @"Scrumptious";
        
        // Create login view controller
        self.loginViewController = [[PFLogInViewController alloc] init];
        [self.loginViewController setDelegate:self];
        [self.loginViewController setFields:PFLogInFieldsFacebook];
        [self.loginViewController setFacebookPermissions:[NSArray arrayWithObjects:@"email,user_birthday,user_education_history,user_hometown,user_likes,user_location,user_interests,user_relationships,user_photos,friends_birthday,friends_education_history,friends_hometown,friends_likes,friends_location,friends_interests,friends_relationships,friends_photos", nil]];
    }
    return self;
}

- (void)dealloc {
    _loginViewController.delegate = nil;
}


#pragma mark - UIViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Show the login view controller if necessary
    if (![PFUser currentUser]) {
        [self presentViewController:self.loginViewController animated:NO completion:NULL];
    }    
}

- (void)viewDidAppear:(BOOL)animated {
    // Reload the table when the timeline is shown
    [self loadObjects];
    
    // load the current user's location
    [PFGeoPoint geoPointForCurrentLocationInBackground:^(PFGeoPoint *geoPoint, NSError *error) {
        if (!error) {
            self.userLocation = geoPoint;
            [self loadObjects];
        }
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.navigationItem.hidesBackButton = YES;

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc]initWithTitle:@"Logout"
                                        style:UIBarButtonItemStyleBordered
                                       target:self
                                       action:@selector(logoutButtonWasPressed:)];
    
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                     target:self
                                                     action:@selector(addButtonWasPressed:)];
}


#pragma mark - UITableViewController

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PFObject *object = [self objectAtIndexPath:indexPath];
    static NSString *CellIdentifier = @"Cell";
    PFTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[PFTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    // This is the data we want to display
    PFUser *fromUser = (PFUser *)[object objectForKey:@"fromUser"];
    NSString *fromName = [fromUser objectForKey:@"displayName"];
    NSString *groupName = [object objectForKey:@"groupName"];
    NSString *status = [object objectForKey:@"status"];
    
    // We add it to the cell
    [cell.textLabel setText:groupName];
    [cell.textLabel setFont:[UIFont systemFontOfSize:14.0f]];
    [cell.textLabel setTextColor:[UIColor colorWithRed:71.0f/255.0f green:78.0f/255.0f blue:91.0f/255.0f alpha:255.0f/255.0f]];
    [cell.detailTextLabel setText:status];
    return cell;
}


#pragma mark - PFTableViewController

- (PFQuery *)queryForTable {
    // If the user is not logged in we simply return nil
    if (![PFUser currentUser]) {
        return nil;
    }
    
    // If we dont have the current user's location simply return nil
    if (!self.userLocation) {
        return nil;
    }
    
    
    
    // Query to get all groups
    PFQuery *groupsQuery = [PFQuery queryWithClassName:@"Group"];
    // To exlude the current user's group
    // if the current user's fbid is in the friends array
    NSString *currentFBID = [[PFUser currentUser] objectForKey:@"fbid"];
    [groupsQuery whereKey:@"friends" notEqualTo:currentFBID];
    // Note, apparently parse is doing some introspection into the key
    // treating the array as if it was a string or something. Need to mess around
    // testing further but this is how you do it
    
    // create the geopoint query
    // whereKey:nearGeoPoint:withinMiles
    [self.settings setObject:@1000 forKey:@"withinMiles"];
    [groupsQuery whereKey:@"location" nearGeoPoint:self.userLocation withinMiles: 10];
    
    // Create compound query
    PFQuery *query = groupsQuery;
    
    // Don't check the cache if we already have items displayed
    query.cachePolicy = kPFCachePolicyNetworkOnly;
    if (self.objects.count == 0) {
        query.cachePolicy = kPFCachePolicyCacheThenNetwork;
    }
    
    return query;
}



- (void)objectsDidLoad:(NSError *)error {
    [super objectsDidLoad:error];
    
    // We show an image instead of an empty table if there are no results
    if (self.objects.count == 0 && ![[self queryForTable] hasCachedResult]) {
        [self.view addSubview:self.blankTimelineView];
    } else {
        [self.blankTimelineView removeFromSuperview];
    }
}


#pragma mark - PFTimelineViewController

- (void)logoutButtonWasPressed:(id)sender {
    [PFUser logOut];
    [self presentViewController:self.loginViewController animated:YES completion:NULL];
}

-(void)addButtonWasPressed:(id)sender {
    SCViewController *viewController = [[SCViewController alloc] initWithNibName:@"SCViewController" bundle:nil];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [self presentViewController:navigationController animated:YES completion:NULL];
}


#pragma mark - PFLoginViewControllerDelegate

- (void)logInViewController:(PFLogInViewController *)logInController didLogInUser:(PFUser *)user {
    // user has logged in - we need to fetch all of their Facebook data before we let them in
    if (![user isNew]) {
        [self dismissViewControllerAnimated:YES completion:NULL];
        [self loadObjects];
    } else {
        self.progressHud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        [self.progressHud setLabelText:@"Loading..."];
        [self.progressHud setDimBackground:YES];
    }
    
    [FBRequestConnection startWithGraphPath:@"me?fields=id,name,first_name,last_name,birthday,relationship_status,interested_in,location,bio,hometown,education,likes" completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if (!error) {
            
            [self addFBAttributesToUserObject:result userToUpdate:[PFUser currentUser]];
            
            [[PFUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                // Get user's friend information
                // Do a quick, optimized query, just to get the users fbFriends ids
                // We're going to get as much profile information about the friends as possible
                // with another graph query in the background.                
                [FBRequestConnection startForMyFriendsWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                    if (!error) {
                        NSArray *data = [result objectForKey:@"data"];
                        NSMutableArray *facebookIds = [[NSMutableArray alloc] initWithCapacity:data.count];
                        for (NSDictionary *friendData in data) {
                            [facebookIds addObject:[friendData objectForKey:@"id"]];
                        }
                        
                        [[PFUser currentUser] setObject:facebookIds forKey:@"facebookFriends"];
                        [[PFUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                            // We're in!
                            [MBProgressHUD hideHUDForView:self.view animated:YES];
                            [self dismissViewControllerAnimated:YES completion:NULL];
                        }];
                    } else {
                        [self showErrorAlert];
                    }
                }];
            }];
        } else {
            [self showErrorAlert];
        }
    }];
}

- (void) setFullFBFriendsData {
    // make a fb request to get all of the users detailed friends data
    // this request is pretty slow so we are going to do it in the background
    [FBRequestConnection startWithGraphPath:@"me/friends?fields=id,name,first_name,last_name,birthday,relationship_status,interested_in,location,bio,hometown,education" completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if (!error) {
            NSArray *data = [result objectForKey:@"data"];
            NSLog(@"fb friends data");
            NSLog(@"%@",data);
            // Loop through all the friends
            NSMutableArray *friendsProfiles;
            for (NSDictionary *friendData in data) {
                // create a new "Profile" PFObject for every fbid
                PFObject *profile = [PFObject objectWithClassName:@"Profile"];
                profile = [self addFBAttributesToUserObject:friendData userToUpdate:profile];
                [friendsProfiles addObject:profile];
            }
            // save all the profiles in a batch to parse
            [PFObject saveAll:friendsProfiles];
            
        } else {
            [self showErrorAlert];
        }
    }];

}

- (PFUser *)addFBAttributesToUserObject:(NSDictionary *)fbUserData userToUpdate:(PFUser *)user {
    NSLog(@"fb user data");
    NSLog(@"%@",fbUserData);
    // Set user's information
    NSString *facebookId = [fbUserData objectForKey:@"id"];
    NSString *name = [fbUserData objectForKey:@"name"];
    NSString *first_name = [fbUserData objectForKey:@"first_name"];
    NSString *last_name = [fbUserData objectForKey:@"last_name"];
    NSString *birthday = [fbUserData objectForKey:@"birthday"];
    NSString *relationship_status = [fbUserData objectForKey:@"relationship_status"];
    // Arrays
    NSArray *education = [fbUserData objectForKey:@"education"];
    NSDictionary *likesObj = [fbUserData objectForKey:@"likes"];
    NSArray *likes;
    if (likesObj && likesObj.count){
        likes = [likesObj objectForKey:@"data"];
    }
    // Objects
    NSDictionary *location = [fbUserData objectForKey:@"location"];
    NSDictionary *hometown = [fbUserData objectForKey:@"hometown"];
    
    if (facebookId && facebookId.length != 0) {
        [user setObject:facebookId forKey:@"fbid"];
    }
    if (name && name.length != 0) {
        [user setObject:name forKey:@"name"];
    }
    if (first_name && first_name.length != 0) {
        [user setObject:first_name forKey:@"first_name"];
    }
    if (last_name && last_name.length != 0) {
        [user setObject:last_name forKey:@"last_name"];
    }
    // TODO
    // Do some parsing on the Birthday to get age?
    //(current format = 11/17/1987)
    if (birthday && birthday.length != 0) {
        [user setObject:birthday forKey:@"birthday"];
    }
    if (relationship_status && relationship_status.length != 0) {
        [user setObject:relationship_status forKey:@"relationship_status"];
    }
    if (education && education.count != 0) {
        [user setObject:education forKey:@"education"];
    }
    if (likes && likes.count != 0) {
        [user setObject:likes forKey:@"likes"];
    }
    if (location && location.count != 0) {
        [user setObject:location forKey:@"location"];
    }
    if (hometown && hometown.count != 0) {
        [user setObject:hometown forKey:@"hometown"];
    }
    return user;
}

#pragma mark - ()

- (void)showErrorAlert {
    [[[UIAlertView alloc] initWithTitle:@"Something went wrong"
                                message:@"We were not able to create your profile. Please try again."
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

@end
