//
//  TSTextShineView.m
//  TextShine
//
//  Created by Genki on 5/7/14.
//  Copyright (c) 2014 Reteq. All rights reserved.
//

#import "RQShineLabel.h"
#import "GifHelper.h"
@interface RQShineLabel()

@property (strong, nonatomic) NSMutableAttributedString *attributedString;
@property (nonatomic, strong) NSMutableArray *characterAnimationDurations;
@property (nonatomic, strong) NSMutableArray *characterAnimationDelays;
@property (strong, nonatomic) CADisplayLink *displaylink;
@property (assign, nonatomic) CFTimeInterval beginTime;
@property (assign, nonatomic) CFTimeInterval endTime;
@property (assign, nonatomic, getter = isFadedOut) BOOL fadedOut;
@property (nonatomic, copy) void (^completion)(void);

@end

@implementation RQShineLabel

- (instancetype)init
{
  self = [super init];
  if (!self) {
    return nil;
  }
  
  [self commonInit];
  
  return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (!self) {
    return nil;
  }
  
  [self commonInit];
  
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super initWithCoder:aDecoder];
  if (!self) {
    return nil;
  }
  
  [self commonInit];
  
  [self setText:self.text];
  
  return self;
}

- (void)commonInit
{
  // Defaults
  _shineDuration   = DEFAULT_DURATION;
  _fadeoutDuration = DEFAULT_DURATION;
  _autoStart       = NO;
  _fadedOut        = YES;
  self.textColor  = [UIColor whiteColor];
  
  _characterAnimationDurations = [NSMutableArray array];
  _characterAnimationDelays    = [NSMutableArray array];
  
}

- (CADisplayLink *)displaylink {
    if (_displaylink == nil) {
        _displaylink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateAttributedString)];
        _displaylink.paused = YES;
        [_displaylink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
    return _displaylink;
}

- (void)didMoveToWindow
{
  if (nil != self.window && self.autoStart) {
    [self shine];
  }
}

- (void)setText:(NSString *)text
{
  self.attributedText = [[NSAttributedString alloc] initWithString:text];
}

-(void)setAttributedText:(NSAttributedString *)attributedText
{
    self.attributedString = [self initialAttributedStringFromAttributedString:attributedText];
	[super setAttributedText:self.attributedString];
	for (NSUInteger i = 0; i < attributedText.length; i++) {
        self.characterAnimationDelays[i] = @(arc4random_uniform(self.shineDuration / 2 * 100) / 100.0);
//        self.characterAnimationDelays[i] = @(self.shineDuration/2+0.01*i);
		CGFloat remain = self.shineDuration - [self.characterAnimationDelays[i] floatValue];
		self.characterAnimationDurations[i] = @(arc4random_uniform(remain * 100) / 100.0);
	}
}
- (void)setFrameInterval:(NSInteger)frameInterval {
    _frameInterval = frameInterval;
    self.displaylink.frameInterval = frameInterval;
}
- (void)shine
{
  [self shineWithCompletion:NULL];
}

- (void)shineWithCompletion:(void(^)(void))completion
{
  
  if (!self.isShining && self.isFadedOut) {
    self.completion = completion;
    self.fadedOut = NO;
    [self startAnimationWithDuration:self.shineDuration];
  }
}

- (void)fadeOut
{
  [self fadeOutWithCompletion:NULL];
}

- (void)fadeOutWithCompletion:(void(^)(void))completion
{
  if (!self.isShining && !self.isFadedOut) {
    self.completion = completion;
    self.fadedOut = YES;
    [self startAnimationWithDuration:self.fadeoutDuration];
  }
}

- (BOOL)isShining
{
  return !self.displaylink.isPaused;
}

- (BOOL)isVisible
{
  return (!self.isFadedOut) && (!self.isShining);
}


#pragma mark - Private methods

- (void)startAnimationWithDuration:(CFTimeInterval)duration
{
  self.beginTime = CACurrentMediaTime();
  self.endTime = self.beginTime + duration;
  self.displaylink.paused = NO;
}

- (void)updateAttributedString
{
    CFTimeInterval now = CACurrentMediaTime();
    for (NSUInteger i = 0; i < self.attributedString.length; i ++) {
        if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[self.attributedString.string characterAtIndex:i]]) { //跳过空格和换行
            continue;
        }
        [self.attributedString enumerateAttribute:NSForegroundColorAttributeName
                                      inRange:NSMakeRange(i, 1) //当前字（location,length）
                                      options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                                   usingBlock:^(id value, NSRange range, BOOL *stop) { //枚举属性字符串中的属性，针对各个子属性字符串调用usingBlock
                                     
//                                     CGFloat currentAlpha = CGColorGetAlpha([(UIColor *)value CGColor]);
                                     BOOL shouldUpdateAlpha = //((self.isFadedOut && currentAlpha > 0) //正在消失
                                                              //|| (!self.isFadedOut && currentAlpha < 1)） //正在显现
                                                              (now - self.beginTime) >= [self.characterAnimationDelays[i] floatValue]; //到达了delayTime
                                     
                                     if (!shouldUpdateAlpha) {
                                       return;
                                     }
                                     
                                     CGFloat percentage = (now - self.beginTime - [self.characterAnimationDelays[i] floatValue]) / ( [self.characterAnimationDurations[i] floatValue]);
                                     if (self.isFadedOut) {
                                       percentage = 1 - percentage;
                                     }
                                     UIColor *color = [self.textColor colorWithAlphaComponent:percentage];
                                     [self.attributedString addAttribute:NSForegroundColorAttributeName value:color range:range];
                                   }];
    }
    [super setAttributedText:self.attributedString];

    if ([_delegate respondsToSelector:@selector(onShine:)]) {
        [_delegate onShine:self];
    }
    
    if (now > self.endTime) {
        self.displaylink.paused = YES;
        [_displaylink invalidate];
        _displaylink = nil;
        if (self.completion) {
            self.completion();
        }
    }
}

- (NSMutableAttributedString *)initialAttributedStringFromAttributedString:(NSAttributedString *)attributedString
{ //初始化时全部透明化
  NSMutableAttributedString *mutableAttributedString = [attributedString mutableCopy];
  UIColor *color = [self.textColor colorWithAlphaComponent:0];
  [mutableAttributedString addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, mutableAttributedString.length)];
  return mutableAttributedString;
}

@end
