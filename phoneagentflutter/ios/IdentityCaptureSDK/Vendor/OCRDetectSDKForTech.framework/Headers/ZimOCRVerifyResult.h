//
//  ZimOCRVerifyResult.h
//  DTFIdentityManager
//
//  Created by 053508 on 2020/6/23.
//  Copyright © 2020 DTF. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZimOCRVerifyResult : NSObject

@property (nonatomic,strong) NSString* RetCode;//SInt32 productRetCode ;
@property (nonatomic,strong) NSString* nameString;
@property (nonatomic,strong) NSString* idString;
@property (nonatomic,strong) NSString* startTime;
@property (nonatomic,strong) NSString* endTime;
@property (nonatomic,strong) NSString* RetCodeSub;//retCodeSub ;
@property (nonatomic,strong) NSString* RetMessageSub;//retMessageSub ;
@property (nonatomic,assign) BOOL abnormalDismiss;
@end

