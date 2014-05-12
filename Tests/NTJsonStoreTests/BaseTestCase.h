//
//  BaseTestCase.h
//  NTJsonStoreTests
//
//  Created by Ethan Nagel on 5/7/14.
//
//

#import <XCTest/XCTest.h>

@interface BaseTestCase : XCTestCase

@property (nonatomic,readonly) NTJsonStore *store;

+(NSString *)storeName;

@end
