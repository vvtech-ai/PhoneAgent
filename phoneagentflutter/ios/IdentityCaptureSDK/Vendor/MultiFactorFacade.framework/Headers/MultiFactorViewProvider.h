//
//  AuthViewProvider.h
//  DTFIdentityManager
//
//  Created by mengbingchuan on 2022/6/1.
//  Copyright © 2022 DTF. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <BioAuthEngine/DTFViewProviderProtocol.h>
#import <BioAuthEngine/DTFFaceViewProtocol.h>
#import <ToygerService/ToygerService.h>

#import "MultiFactorTaskModel.h"

@protocol MultiFactorTaskViewDelegate;

@interface MultiFactorAlertModel : NSObject

@property (nonatomic, copy) NSString *type;

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *message;

@property (nonatomic, copy) NSString *confirmTitle;
@property (nonatomic, copy) void (^confirmBlock)(NSString *type);

@property (nonatomic, copy) NSString *cancelTitle;
@property (nonatomic, copy) void (^cancelBlock)(NSString *type);

@end

@protocol MultiFactorTaskViewProtocol <NSObject>

@property (nonatomic, weak) id<MultiFactorTaskViewDelegate> delegate;
@property (nonatomic, strong) MultiFactorTaskModel *model;

- (void)alertWithModel:(MultiFactorAlertModel *)model onController:(UIViewController *)controller;

- (void)handleFaceStateChange:(ToygerMessage)state
                    stateTips:(NSString *)tips
                  actionGuide:(NSString *)guide
                     progress:(CGFloat)progress;

- (void)countDown:(int)left;

- (void)nextAction:(int)index;

- (void)reset;

- (UIView *)view;

@end

@protocol MultiFactorTaskViewDelegate <NSObject>

- (void)viewExit:(id<MultiFactorTaskViewProtocol>)view;

- (void)viewStartRecord:(id<MultiFactorTaskViewProtocol>)view;

- (void)viewStopRecord:(id<MultiFactorTaskViewProtocol>)view;

@end

@protocol MultiFactorViewProviderProtocol <DTFViewProviderProtocol>

- (id<MultiFactorTaskViewProtocol>)viewForRead:(MultiFactorTaskModel *)model;

- (id<MultiFactorTaskViewProtocol>)viewForQuestion:(MultiFactorTaskModel *)model;

- (id<MultiFactorTaskViewProtocol>)viewForRegister:(MultiFactorTaskModel *)model;

@end

