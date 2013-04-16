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
        [self.loginViewController setFacebookPermissions:[NSArray arrayWithObjects:@"user_about_me", nil]];
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
    NSString *restaurantName = [object objectForKey:@"locationName"];
    NSString *foodName = [object objectForKey:@"meal"];
    
    // We add it to the cell
    [cell.textLabel setText:[NSString stringWithFormat:@"You were at %@", restaurantName]];
    [cell.textLabel setFont:[UIFont systemFontOfSize:14.0f]];
    [cell.textLabel setTextColor:[UIColor colorWithRed:71.0f/255.0f green:78.0f/255.0f blue:91.0f/255.0f alpha:255.0f/255.0f]];
    if (![[fromUser objectId] isEqualToString:[[PFUser currentUser] objectId]]) {
        [cell.detailTextLabel setText:[NSString stringWithFormat:@"eating %@ with %@",foodName,fromName]];
    } else {
        [cell.detailTextLabel setText:[NSString stringWithFormat:@"eating %@ with friends", foodName]];
    }
    
    return cell;
}


#pragma mark - PFTableViewController

- (PFQuery *)queryForTable {
    // If the user is not logged in we simply return nil
    if (![PFUser currentUser]) {
        return nil;
    }
    
    // Query to get all posts by current user
    PFQuery *postsFromCurrentUser = [PFQuery queryWithClassName:@"Post"];
    [postsFromCurrentUser whereKey:@"fromUser" equalTo:[PFUser currentUser]];

    // Query to get all posts from current user's friends
    PFQuery *innerFriendsQuery = [PFUser query];
    [innerFriendsQuery whereKey:@"facebookId" containedIn:[[PFUser currentUser] objectForKey:@"facebookFriends"]];
    [innerFriendsQuery setLimit:1000];
    PFQuery *postsFromFriends = [PFQuery queryWithClassName:@"Post"];
    [postsFromFriends whereKey:@"fromUser" matchesQuery:innerFriendsQuery];
    [postsFromFriends whereKey:@"toUser" equalTo:[[PFUser currentUser] objectForKey:@"facebookId"]];
    
    // Create compound query
    PFQuery *query = [PFQuery orQueryWithSubqueries:@[ postsFromCurrentUser, postsFromFriends ]];
    [query orderByDescending:@"createdAt"];
    [query includeKey:@"fromUser"];
    
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
    
    // Get user's personal information
    [FBRequestConnection startForMeWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if (!error) {
            // Set user's information
            NSString *facebookId = [result objectForKey:@"id"];
            NSString *facebookName = [result objectForKey:@"name"];
                            
            if (facebookName && facebookName.length != 0) {
                [[PFUser currentUser] setObject:facebookName forKey:@"displayName"];
            }
            if (facebookId && facebookId.length != 0) {
                [[PFUser currentUser] setObject:facebookId forKey:@"facebookId"];
            }
                
            [[PFUser currentUser] saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                // Get user's friend information
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


#pragma mark - ()

- (void)showErrorAlert {
    [[[UIAlertView alloc] initWithTitle:@"Something went wrong"
                                message:@"We were not able to create your profile. Please try again."
                               delegate:nil
                      cancelButtonTitle:@"OK"
                      otherButtonTitles:nil] show];
}

@end
