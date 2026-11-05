//
//  MultiFactorModel.h
//  MultiFactorFacade
//
//  Created by wangsizhe on 2022/6/1.
//  Copyright © 2022 DTF. All rights reserved.
//

#import "MultiFactorBaseModel.h"

NS_ASSUME_NONNULL_BEGIN
@interface MultiFactorTaskContent :MultiFactorBaseModel
@property (nonatomic, copy) NSString *answerTitle;
@property (nonatomic, copy) NSString *question;
@property (nonatomic, assign) int time;
@property (nonatomic, copy) NSString *answerType;
@end

@interface MultiFactorTaskModel : MultiFactorBaseModel
@property (nonatomic, copy) NSArray<MultiFactorTaskContent *> *content;
@property (nonatomic, copy) NSString *recognizeType;
@property (nonatomic, copy) NSString *recognizeTypeName;
+ (instancetype)itemWithDic:(NSDictionary *)dic;
@end

NS_ASSUME_NONNULL_END
