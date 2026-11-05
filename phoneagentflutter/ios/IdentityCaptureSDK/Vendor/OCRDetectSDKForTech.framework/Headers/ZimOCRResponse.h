//
//  ZimOCRResponse.h
//  DTFIdentityManager
//
//  Created by 053508 on 2020/6/22.
//  Copyright © 2020 DTF. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZimOCRResponse : NSObject
@property (nonatomic,strong) NSString* RetCode;//SInt32 productRetCode ;
@property (nonatomic,strong) NSDictionary* OcrInfo;//extParams ;
@property (nonatomic,strong) NSString* RetCodeSub;//retCodeSub ;
@property (nonatomic,strong) NSString* RetMessageSub;//retMessageSub ;


+ (Class)OcrInfoElementClass;
@end

NS_ASSUME_NONNULL_END
