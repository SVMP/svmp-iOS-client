//
//  iMASAppDelegate.h
//  APSampleApp
//
//  Created by Ganley, Gregg on 8/22/13.
//  Copyright (c) 2013 MITRE Corp. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface iMASAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIApplication *app;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)callNewDelegate;
- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
