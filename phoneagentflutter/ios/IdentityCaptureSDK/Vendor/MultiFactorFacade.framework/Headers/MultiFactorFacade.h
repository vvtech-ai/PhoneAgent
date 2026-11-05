//
//  MultiFactorFacade.h
//  MultiFactorFacade
//
//  Created by mengbingchuan on 2022/5/11.
//  Copyright © 2022 DTF. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <BioAuthEngine/IBioAuthFactor.h>

NS_ASSUME_NONNULL_BEGIN

@interface MultiFactorFacade : NSObject<IBioAuthFactor>
+ (NSString*)getTokenid;
@end

NS_ASSUME_NONNULL_END
