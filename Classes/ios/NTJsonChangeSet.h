//
//  NTJsonChangeSet.h
//  NTJsonStore
//
//  Created by  Ethan Nagel on 6/24/17.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, NTJsonChangeSetAction)
{
    NTJsonChangeSetActionDelete,
    NTJsonChangeSetActionUpdate,
    NTJsonChangeSetActionMove,
    NTJsonChangeSetActionInsert,
};


@interface NTJsonChangeSetChange: NSObject

@property(nonatomic, readonly) NTJsonChangeSetAction action;
@property(nonatomic, readonly) NSInteger oldIndex;
@property(nonatomic, readonly) NSInteger newIndex;
@property(nonatomic, readonly) NSDictionary *item;
@property(nonatomic, readonly) NSInteger itemId;

- (BOOL)isEqualToChange:(NTJsonChangeSetChange *)other;
- (BOOL)isEqual:(id)object;
- (NSUInteger)hash;
- (NSString *)description;

@end

@interface NTJsonChangeSet: NSObject

@property(nonatomic, readonly) NSArray<NSDictionary *> *oldItems;
@property(nonatomic, readonly) NSArray<NSDictionary *> *items;
@property(nonatomic, readonly) NSArray<NTJsonChangeSetChange *> *changes;
@property(nonatomic, readonly) BOOL hasChanges;

- (instancetype)initWithOldItems:(NSArray<NSDictionary *> *)oldItems newItems:(NSArray<NSDictionary *> *)newItems;

- (BOOL)validateChanges;

@end

@interface NTJsonChangeSetChange(Private)

-(instancetype)initWithAction:(NTJsonChangeSetAction)action oldIndex:(NSInteger)oldIndex newIndex:(NSInteger)newIndex item:(NSDictionary *)item;

+(instancetype)deleteWithOldIndex:(NSInteger)oldIndex item:(NSDictionary *)item;
+(instancetype)updateWithOldIndex:(NSInteger)oldIndex newIndex:(NSInteger)newIndex item:(NSDictionary *)item;
+(instancetype)insertWithNewIndex:(NSInteger)newIndex item:(NSDictionary *)item;
+(instancetype)moveWithOldIndex:(NSInteger)oldIndex newIndex:(NSInteger)newIndex item:(NSDictionary *)item;

@end


