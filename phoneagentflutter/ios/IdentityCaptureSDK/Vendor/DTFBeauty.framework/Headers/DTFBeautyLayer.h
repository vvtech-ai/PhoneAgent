//
//  ZolozBeautyLayer.h
//  ZolozSensorServices
//
//  Created by 晗羽 on 2019/5/6.
//  Copyright © 2019 Alipay. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTFBeautyLayer : CAEAGLLayer

@property(nonatomic, assign)BOOL isMirrored;

- (void)setFrame:(CGRect)frame;

- (void)displayframePixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
