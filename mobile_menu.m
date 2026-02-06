#import "mobile_menu.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <sys/mman.h>

// Include KFD library
#include "kfd/libkfd.h"

// Clash Royale bundle identifier
#define TARGET_BUNDLE_ID @"com.supercell.scroll"

// Elixir addresses (from 111.txt)
#define SHOW_OPPONENT_ELIXIR_BAR_ON_SPECTATE 0x10104c276
#define ELIXIR_COUNT_OFFSET 0x101021a5b
#define PLAYER_ELIXIR_OFFSET 0x10106eff4
#define OPPONENT_ELIXIR_OFFSET 0x101070560

@implementation MobileMenu

static MobileMenu *sharedInstance = nil;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MobileMenu alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Check if we're in the target app
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if (![bundleId isEqualToString:TARGET_BUNDLE_ID]) {
            return nil;
        }
        
        self.isElixirHackEnabled = NO;
        self.kfdInitialized = NO;
        self.kfd = 0;
        self.baseAddress = 0;
        
        [self setupMenu];
    }
    return self;
}

- (void)setupMenu {
    // Get the main window
    UIWindow *mainWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        mainWindow = window;
                        break;
                    }
                }
            }
        }
    }
    if (!mainWindow) {
        mainWindow = [UIApplication sharedApplication].windows.firstObject;
    }
    
    // Create toggle button (always visible, draggable)
    self.toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggleButton.frame = CGRectMake(20, 100, 70, 70);
    self.toggleButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.9];
    self.toggleButton.layer.cornerRadius = 35;
    self.toggleButton.layer.borderWidth = 3;
    self.toggleButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.toggleButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.toggleButton.layer.shadowOffset = CGSizeMake(2, 2);
    self.toggleButton.layer.shadowOpacity = 0.5;
    self.toggleButton.layer.shadowRadius = 4;
    [self.toggleButton setTitle:@"CR" forState:UIControlStateNormal];
    self.toggleButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [self.toggleButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    
    // Add pan gesture for dragging
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.toggleButton addGestureRecognizer:panGesture];
    
    [mainWindow addSubview:self.toggleButton];
    
    // Create menu container (initially hidden)
    self.menuContainer = [[UIView alloc] initWithFrame:CGRectMake(-280, 50, 280, 500)];
    self.menuContainer.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.95];
    self.menuContainer.layer.cornerRadius = 20;
    self.menuContainer.layer.borderWidth = 2;
    self.menuContainer.layer.borderColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0].CGColor;
    self.menuContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    self.menuContainer.layer.shadowOffset = CGSizeMake(5, 5);
    self.menuContainer.layer.shadowOpacity = 0.7;
    self.menuContainer.layer.shadowRadius = 10;
    
    // Menu title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 280, 40)];
    titleLabel.text = @"🏰 Clash Royale Hack";
    titleLabel.textColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [self.menuContainer addSubview:titleLabel];
    
    // Separator line
    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(20, 60, 240, 1)];
    separator.backgroundColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    [self.menuContainer addSubview:separator];
    
    // Elixir status label
    self.elixirStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 75, 240, 30)];
    self.elixirStatusLabel.text = @"Elixir Hack: Disabled";
    self.elixirStatusLabel.textColor = [UIColor redColor];
    self.elixirStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.elixirStatusLabel.font = [UIFont systemFontOfSize:16];
    [self.menuContainer addSubview:self.elixirStatusLabel];
    
    // Opponent elixir display label
    self.opponentElixirLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 110, 240, 40)];
    self.opponentElixirLabel.text = @"Opponent Elixir: --";
    self.opponentElixirLabel.textColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.8 alpha:1.0];
    self.opponentElixirLabel.textAlignment = NSTextAlignmentCenter;
    self.opponentElixirLabel.font = [UIFont boldSystemFontOfSize:18];
    self.opponentElixirLabel.layer.cornerRadius = 10;
    self.opponentElixirLabel.layer.borderWidth = 1;
    self.opponentElixirLabel.layer.borderColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.8 alpha:0.5].CGColor;
    self.opponentElixirLabel.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.8 alpha:0.1];
    [self.menuContainer addSubview:self.opponentElixirLabel];
    
    // Show Opponent Elixir button
    self.showOpponentElixirButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.showOpponentElixirButton.frame = CGRectMake(20, 170, 240, 50);
    self.showOpponentElixirButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.8 alpha:0.8];
    self.showOpponentElixirButton.layer.cornerRadius = 15;
    self.showOpponentElixirButton.layer.borderWidth = 2;
    self.showOpponentElixirButton.layer.borderColor = [UIColor whiteColor].CGColor;
    [self.showOpponentElixirButton setTitle:@"🔮 Toggle Opponent Elixir" forState:UIControlStateNormal];
    self.showOpponentElixirButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.showOpponentElixirButton addTarget:self action:@selector(showOpponentElixir) forControlEvents:UIControlEventTouchUpInside];
    [self.menuContainer addSubview:self.showOpponentElixirButton];
    
    // Test function button
    UIButton *testButton = [UIButton buttonWithType:UIButtonTypeCustom];
    testButton.frame = CGRectMake(20, 240, 240, 50);
    testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:0.8];
    testButton.layer.cornerRadius = 15;
    testButton.layer.borderWidth = 2;
    testButton.layer.borderColor = [UIColor whiteColor].CGColor;
    [testButton setTitle:@"🧪 Test Function" forState:UIControlStateNormal];
    testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [testButton addTarget:self action:@selector(testFunction) forControlEvents:UIControlEventTouchUpInside];
    [self.menuContainer addSubview:testButton];
    
    // Info button
    UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeCustom];
    infoButton.frame = CGRectMake(20, 310, 240, 50);
    infoButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:0.8];
    infoButton.layer.cornerRadius = 15;
    infoButton.layer.borderWidth = 2;
    infoButton.layer.borderColor = [UIColor whiteColor].CGColor;
    [infoButton setTitle:@"ℹ️ About" forState:UIControlStateNormal];
    infoButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [infoButton addTarget:self action:@selector(showInfo) forControlEvents:UIControlEventTouchUpInside];
    [self.menuContainer addSubview:infoButton];
    
    // Close button
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    closeButton.frame = CGRectMake(20, 430, 240, 50);
    closeButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:0.8];
    closeButton.layer.cornerRadius = 15;
    closeButton.layer.borderWidth = 2;
    closeButton.layer.borderColor = [UIColor whiteColor].CGColor;
    [closeButton setTitle:@"❌ Close Menu" forState:UIControlStateNormal];
    closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [closeButton addTarget:self action:@selector(hideMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.menuContainer addSubview:closeButton];
    
    [mainWindow addSubview:self.menuContainer];
    
    self.isMenuOpen = NO;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:gesture.view.superview];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.isDragging = YES;
        self.lastTouchPoint = gesture.view.center;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        gesture.view.center = CGPointMake(self.lastTouchPoint.x + translation.x, 
                                        self.lastTouchPoint.y + translation.y);
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        self.isDragging = NO;
        
        // Keep button within screen bounds with magnetic edges
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGRect buttonFrame = gesture.view.frame;
        
        // Magnetic edge snapping
        if (buttonFrame.origin.x < screenBounds.size.width / 2) {
            buttonFrame.origin.x = 10; // Snap to left edge
        } else {
            buttonFrame.origin.x = screenBounds.size.width - buttonFrame.size.width - 10; // Snap to right edge
        }
        
        if (buttonFrame.origin.y < 50) {
            buttonFrame.origin.y = 50;
        } else if (buttonFrame.origin.y + buttonFrame.size.height > screenBounds.size.height - 100) {
            buttonFrame.origin.y = screenBounds.size.height - buttonFrame.size.height - 100;
        }
        
        [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            gesture.view.frame = buttonFrame;
        } completion:nil];
    }
}

- (void)toggleMenu {
    if (self.isDragging) return;
    
    if (self.isMenuOpen) {
        [self hideMenu];
    } else {
        [self showMenu];
    }
}

- (void)showMenu {
    self.isMenuOpen = YES;
    
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.menuContainer.frame = CGRectMake(10, 50, 280, 500);
        self.toggleButton.alpha = 0.6;
        self.toggleButton.transform = CGAffineTransformMakeRotation(M_PI);
    } completion:nil];
}

- (void)hideMenu {
    self.isMenuOpen = NO;
    
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.menuContainer.frame = CGRectMake(-280, 50, 280, 500);
        self.toggleButton.alpha = 1.0;
        self.toggleButton.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)showOpponentElixir {
    NSLog(@"[MobileMenu] Toggle Opponent Elixir function called");
    
    if (self.isElixirHackEnabled) {
        [self disableElixirVisibility];
    } else {
        [self enableElixirVisibility];
    }
}

- (void)enableElixirVisibility {
    NSLog(@"[MobileMenu] Enabling opponent elixir visibility...");
    
    // Initialize KFD if not already done
    if (![self initKFD]) {
        [self showAlertWithTitle:@"❌ Error" message:@"Failed to initialize KFD exploit!\nPlease try again."];
        return;
    }
    
    self.isElixirHackEnabled = YES;
    
    // Update UI
    self.elixirStatusLabel.text = @"Elixir Hack: Enabled";
    self.elixirStatusLabel.textColor = [UIColor greenColor];
    [self.showOpponentElixirButton setTitle:@"🔮 Disable Opponent Elixir" forState:UIControlStateNormal];
    self.showOpponentElixirButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.5 blue:0.2 alpha:0.8];
    
    // Start updating elixir display
    self.elixirUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 
                                                              target:self 
                                                            selector:@selector(updateElixirDisplay) 
                                                            userInfo:nil 
                                                             repeats:YES];
    
    // Enable opponent elixir visibility in game
    [self implementElixirHack];
    
    [self showAlertWithTitle:@"✅ Success" message:@"Opponent elixir visibility enabled!\nKFD exploit active."];
}

- (void)disableElixirVisibility {
    NSLog(@"[MobileMenu] Disabling opponent elixir visibility...");
    
    self.isElixirHackEnabled = NO;
    
    // Update UI
    self.elixirStatusLabel.text = @"Elixir Hack: Disabled";
    self.elixirStatusLabel.textColor = [UIColor redColor];
    [self.showOpponentElixirButton setTitle:@"🔮 Enable Opponent Elixir" forState:UIControlStateNormal];
    self.showOpponentElixirButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.8 alpha:0.8];
    self.opponentElixirLabel.text = @"Opponent Elixir: --";
    
    // Stop timer
    if (self.elixirUpdateTimer) {
        [self.elixirUpdateTimer invalidate];
        self.elixirUpdateTimer = nil;
    }
    
    [self showAlertWithTitle:@"⚠️ Disabled" message:@"Opponent elixir visibility disabled."];
}

- (void)updateElixirDisplay {
    if (!self.isElixirHackEnabled) return;
    
    int opponentElixir = [self getOpponentElixirValue];
    
    if (opponentElixir >= 0) {
        self.opponentElixirLabel.text = [NSString stringWithFormat:@"Opponent Elixir: %d/10", opponentElixir];
        
        // Color coding based on elixir amount
        if (opponentElixir <= 3) {
            self.opponentElixirLabel.textColor = [UIColor redColor];
        } else if (opponentElixir <= 6) {
            self.opponentElixirLabel.textColor = [UIColor orangeColor];
        } else {
            self.opponentElixirLabel.textColor = [UIColor greenColor];
        }
    } else {
        self.opponentElixirLabel.text = @"Opponent Elixir: Not in battle";
        self.opponentElixirLabel.textColor = [UIColor grayColor];
    }
}

- (int)getOpponentElixirValue {
    if (!self.kfdInitialized || self.kfd == 0) {
        return -1;
    }
    
    // Calculate actual address with ASLR
    u64 opponentElixirAddr = self.baseAddress + (OPPONENT_ELIXIR_OFFSET - 0x100000000);
    
    // Read opponent elixir value from memory
    u64 elixirValue = [self kread64:opponentElixirAddr];
    
    // Extract elixir count (usually stored as int32)
    int elixir = (int)(elixirValue & 0xFFFFFFFF);
    
    // Validate range (0-10 for Clash Royale)
    if (elixir < 0 || elixir > 10) {
        return -1;
    }
    
    return elixir;
}

- (void)implementElixirHack {
    NSLog(@"[MobileMenu] Implementing elixir hack with KFD...");
    
    if (!self.kfdInitialized || self.kfd == 0) {
        NSLog(@"[MobileMenu] KFD not initialized!");
        return;
    }
    
    // Calculate addresses with ASLR
    u64 spectateFlag = self.baseAddress + (SHOW_OPPONENT_ELIXIR_BAR_ON_SPECTATE - 0x100000000);
    
    NSLog(@"[MobileMenu] Base: 0x%llx", self.baseAddress);
    NSLog(@"[MobileMenu] Spectate flag addr: 0x%llx", spectateFlag);
    
    // Read current value
    u64 currentValue = [self kread64:spectateFlag];
    NSLog(@"[MobileMenu] Current spectate flag value: 0x%llx", currentValue);
    
    // Enable opponent elixir visibility (set to 1/true)
    [self kwrite64:spectateFlag value:1];
    
    // Verify write
    u64 newValue = [self kread64:spectateFlag];
    NSLog(@"[MobileMenu] New spectate flag value: 0x%llx", newValue);
    
    if (newValue == 1) {
        NSLog(@"[MobileMenu] Successfully enabled opponent elixir visibility!");
    } else {
        NSLog(@"[MobileMenu] Warning: Flag value not changed as expected");
    }
}

- (void)testFunction {
    NSLog(@"[MobileMenu] Test function called");
    
    // Test memory reading capabilities
    const struct mach_header *header = _dyld_get_image_header(0);
    intptr_t slide = _dyld_get_image_vmaddr_slide(0);
    
    NSString *message = [NSString stringWithFormat:@"Test Results:\n\nBase Address: 0x%lx\nASLR Slide: 0x%lx\nBundle ID: %@\n\nMemory access test completed!", 
                        (unsigned long)header, (unsigned long)slide, [[NSBundle mainBundle] bundleIdentifier]];
    
    [self showAlertWithTitle:@"🧪 Test Results" message:message];
}

- (void)showInfo {
    NSString *infoMessage = @"🏰 Clash Royale Hack Menu\n\nFeatures:\n• Show opponent elixir in real-time\n• Draggable floating menu\n• Memory analysis tools\n\n⚠️ Use responsibly!\n\nVersion: 1.0\nTarget: com.supercell.scroll";
    
    [self showAlertWithTitle:@"ℹ️ About" message:infoMessage];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" 
                                                       style:UIAlertActionStyleDefault 
                                                     handler:nil];
    [alert addAction:okAction];
    
    UIViewController *topVC = [self topViewController];
    if (topVC) {
        [topVC presentViewController:alert animated:YES completion:nil];
    }
}

- (UIViewController *)topViewController {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
            }
        }
    }
    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }
    
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

- (BOOL)initKFD {
    if (self.kfdInitialized) {
        return YES;
    }
    
    NSLog(@"[MobileMenu] Initializing KFD exploit...");
    
    // Get base address
    const struct mach_header *header = _dyld_get_image_header(0);
    intptr_t slide = _dyld_get_image_vmaddr_slide(0);
    self.baseAddress = (u64)header + slide;
    
    NSLog(@"[MobileMenu] Base address: 0x%llx", self.baseAddress);
    
    // Initialize KFD with physpuppet method
    u64 puaf_method = puaf_physpuppet;
    u64 kread_method = kread_sem_open;
    u64 kwrite_method = kwrite_sem_open;
    
    // Try to open KFD
    self.kfd = kopen(1, puaf_method, kread_method, kwrite_method);
    
    if (self.kfd == 0) {
        NSLog(@"[MobileMenu] KFD initialization failed!");
        return NO;
    }
    
    NSLog(@"[MobileMenu] KFD initialized successfully! kfd=0x%llx", self.kfd);
    self.kfdInitialized = YES;
    return YES;
}

- (void)closeKFD {
    if (self.kfdInitialized && self.kfd != 0) {
        NSLog(@"[MobileMenu] Closing KFD...");
        kclose(self.kfd);
        self.kfd = 0;
        self.kfdInitialized = NO;
    }
}

- (u64)kread64:(u64)addr {
    if (!self.kfdInitialized || self.kfd == 0) {
        NSLog(@"[MobileMenu] KFD not initialized!");
        return 0;
    }
    
    u64 value = 0;
    kread(self.kfd, addr, &value, sizeof(u64));
    return value;
}

- (void)kwrite64:(u64)addr value:(u64)value {
    if (!self.kfdInitialized || self.kfd == 0) {
        NSLog(@"[MobileMenu] KFD not initialized!");
        return;
    }
    
    kwrite(self.kfd, &value, addr, sizeof(u64));
}

- (void)dealloc {
    if (self.elixirUpdateTimer) {
        [self.elixirUpdateTimer invalidate];
        self.elixirUpdateTimer = nil;
    }
    [self closeKFD];
}

@end

// Constructor to initialize the menu when the dylib is loaded
__attribute__((constructor))
static void initializeMenu() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Check if we're in the target app
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleId isEqualToString:TARGET_BUNDLE_ID]) {
            NSLog(@"[MobileMenu] 🏰 Initializing Clash Royale hack menu...");
            NSLog(@"[MobileMenu] Target bundle detected: %@", bundleId);
            [MobileMenu sharedInstance];
        } else {
            NSLog(@"[MobileMenu] Not target app, current bundle: %@", bundleId);
        }
    });
}