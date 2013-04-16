# Scrumptious sample

## What is Scrumptious

Scrumptious demonstrates a "real-world" (albeit very limited) application that integrates with Parse and Facebook. It allows a user to select from a small pre-defined list of cuisine types that they are eating, then tag friends who they are with, and tag the restaurant they are in. Scrumptious then allows them to post an Open Graph Action and save the post in a Parse app. Users can later see this post and the posts they where they were tagged in a timeline.

### Parse Features
  - Using the Facebook integration
  - Creating a login flow with PFLogInViewController
  - Creating and storing objects on Parse
  - Creating relationships between Parse objects
  - Querying Parse object
  - Using the PFQueryTableViewController

### Facebook Features
  - Using the FBFriendPickerViewController to present a UI to pick friends.
  - Using the FBPlacePickerViewController to present a UI to pick a location.
  - Creating an Open Graph action
  - Making Open Graph queryies for a user's information and friends.

If you are using Scrumptious as the basis for another application, please note that all of the Open Graph namespaces will need
to be updated, and a hosted service must be provided in order to serve up Open Graph Objects. In addition, the logged-in
user will need to be a Developer or a Tester on the application until it is approved for posting Open Graph Actions.

## Usage
1. Sign up for Parse at [www.parse.com](www.parse.com).
2. Add your Parse Client Key and App ID in the Parse initialize funcion in the application delegate.
3. Change the Facebook key for those of your Facebook app.

## Requirements
  - iOS 6.0 SDK
  - iPhone OS 4.3 or later
  - Parse account
