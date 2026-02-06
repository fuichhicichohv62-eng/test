#ifndef MOBILE_MENU_H
#define MOBILE_MENU_H

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// KFD structures
typedef uint64_t u64;

@interface MobileMenu : UIView

@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIButton *showOpponentElixirButton;
@property (nonatomic, strong) UILabel *elixirStatusLabel;
@property (nonatomic, strong) UILabel *opponentElixirLabel;
@property (nonatomic, strong) NSTimer *elixirUpdateTimer;
@property (nonatomic, assign) BOOL isMenuOpen;
@property (nonatomic, assign) BOOL isDragging;
@property (nonatomic, assign) BOOL isElixirHackEnabled;
@property (nonatomic, assign) CGPoint lastTouchPoint;
@property (nonatomic, assign) u64 kfd;
@property (nonatomic, assign) u64 baseAddress;
@property (nonatomic, assign) BOOL kfdInitialized;

+ (instancetype)sharedInstance;
- (void)setupMenu;
- (void)showMenu;
- (void)hideMenu;
- (void)toggleMenu;
- (void)showOpponentElixir;
- (void)testFunction;
- (void)updateElixirDisplay;
- (int)getOpponentElixirValue;
- (void)enableElixirVisibility;
- (void)disableElixirVisibility;
- (BOOL)initKFD;
- (void)closeKFD;
- (u64)kread64:(u64)addr;
- (void)kwrite64:(u64)addr value:(u64)value;

@end

#endif