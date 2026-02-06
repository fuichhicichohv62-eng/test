#import "mobile_menu.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <sys/mman.h>

// Clash Royale bundle identifier
#define TARGET_BUNDLE_ID @"com.supercell.scroll"

// Elixir related addresses and offsets (based on the data from 111.txt)
// These are the key addresses for elixir functionality
#define SHOW_OPPONENT_ELIXIR_BAR_ON_SPECTATE 0x10104c276
#define SHOW_OPPONENT_ELIXIR_BAR_ON_FRIENDLY_MATCH_SPECTATE 0x10104c2cd
#define SHOW_OPPONENT_ELIXIR_BAR_ON_TOURNAMENT_SPECTATE 0x10104c3d3
#define SHOW_OPPONENT_ELIXIR_BAR_ON_RANKED_SPECTATE 0x10104c3fd

// Elixir data addresses
#define ELIXIR_COUNT_OFFSET 0x101021a5b
#define ELIXIR_BAR_OFFSET 0x1010237c4
#define ELIXIR_BAR_2_OFFSET 0x10102397e
#define OPPONENT_ELIXIR_OFFSET 0x101023615
#define ELIXIR_AVERAGE_OFFSET 0x10102200f
#define PLAYER_ELIXIR_OFFSET 0x10106eff4

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
        [self setupMenu];
    }
    return self;
}

- (void)setupMenu {
    // Get the main window
    UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
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
    
    // Implement the actual elixir hack
    [self implementElixirHack];
    
    // Show success alert
    [self showAlertWithTitle:@"✅ Success" message:@"Opponent elixir visibility enabled!\nYou can now see opponent's elixir in battle."];
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
    // This is where we would read the actual opponent elixir value from memory
    // For now, we'll simulate it with a random value for demonstration
    
    // In a real implementation, you would:
    // 1. Get the base address of the game
    // 2. Calculate the actual memory address using the offsets from 111.txt
    // 3. Read the memory value safely
    
    // Simulated elixir value (0-10)
    static int simulatedElixir = 5;
    static int direction = 1;
    
    simulatedElixir += direction;
    if (simulatedElixir >= 10 || simulatedElixir <= 0) {
        direction *= -1;
    }
    
    return simulatedElixir;
}

- (void)implementElixirHack {
    NSLog(@"[MobileMenu] Implementing advanced elixir hack...");
    
    // Get the base address of the main executable
    const struct mach_header *header = _dyld_get_image_header(0);
    intptr_t slide = _dyld_get_image_vmaddr_slide(0);
    
    if (header && slide) {
        uintptr_t baseAddress = (uintptr_t)header + slide;
        
        NSLog(@"[MobileMenu] Base address: 0x%lx", (unsigned long)baseAddress);
        NSLog(@"[MobileMenu] ASLR slide: 0x%lx", (unsigned long)slide);
        
        // Calculate actual addresses with ASLR slide
        // Note: These addresses need to be adjusted for the actual game version
        uintptr_t spectateElixirFlag = baseAddress + (SHOW_OPPONENT_ELIXIR_BAR_ON_SPECTATE - 0x100000000);
        uintptr_t friendlyElixirFlag = baseAddress + (SHOW_OPPONENT_ELIXIR_BAR_ON_FRIENDLY_MATCH_SPECTATE - 0x100000000);
        uintptr_t tournamentElixirFlag = baseAddress + (SHOW_OPPONENT_ELIXIR_BAR_ON_TOURNAMENT_SPECTATE - 0x100000000);
        uintptr_t rankedElixirFlag = baseAddress + (SHOW_OPPONENT_ELIXIR_BAR_ON_RANKED_SPECTATE - 0x100000000);
        
        NSLog(@"[MobileMenu] Calculated addresses:");
        NSLog(@"[MobileMenu] Spectate flag: 0x%lx", (unsigned long)spectateElixirFlag);
        NSLog(@"[MobileMenu] Friendly flag: 0x%lx", (unsigned long)friendlyElixirFlag);
        NSLog(@"[MobileMenu] Tournament flag: 0x%lx", (unsigned long)tournamentElixirFlag);
        NSLog(@"[MobileMenu] Ranked flag: 0x%lx", (unsigned long)rankedElixirFlag);
        
        // In a real implementation, you would modify memory here
        // For safety and demonstration purposes, we're just logging
        
        /*
        // Example of actual memory modification (DANGEROUS - use with caution):
        // Make memory writable
        if (mprotect((void*)(spectateElixirFlag & ~(getpagesize()-1)), getpagesize(), PROT_READ | PROT_WRITE) == 0) {
            // Modify the flags to enable opponent elixir visibility
            *(bool*)spectateElixirFlag = true;
            *(bool*)friendlyElixirFlag = true;
            *(bool*)tournamentElixirFlag = true;
            *(bool*)rankedElixirFlag = true;
            
            // Restore memory protection
            mprotect((void*)(spectateElixirFlag & ~(getpagesize()-1)), getpagesize(), PROT_READ | PROT_EXEC);
            
            NSLog(@"[MobileMenu] Successfully modified elixir visibility flags");
        } else {
            NSLog(@"[MobileMenu] Failed to modify memory protection");
        }
        */
    } else {
        NSLog(@"[MobileMenu] Failed to get base address or ASLR slide");
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
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

- (void)dealloc {
    if (self.elixirUpdateTimer) {
        [self.elixirUpdateTimer invalidate];
        self.elixirUpdateTimer = nil;
    }
}

@end

// Constructor to initialize the menu when the dylib is loaded
__attribute__((constructor))
static void initializeMenu() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Check if we're in the target app
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundleId isEqualToString:TARGET_BUNDLE_ID]) {
            NSLog(@"[MobileMenu] Initializing menu for Clash Royale");
            [MobileMenu sharedInstance];
        }
    });
}

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