//
//  main.m
//  SIDPLAY
//
//  Created by Andreas Varga on 15.11.07.
//  Copyright __MyCompanyName__ 2007. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <objc/message.h>

int main(int argc, char *argv[])
{
    time_t seed;
    time(&seed);
    srandom((unsigned int)seed);

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--test-engine") == 0 && i + 1 < argc) {
            NSString *tunePath = [NSString stringWithUTF8String:argv[i + 1]];
            Class cls = NSClassFromString(@"SPSwiftPlayer");
            if (!cls) {
                fprintf(stderr, "Error: SPSwiftPlayer class not found!\n");
                return 1;
            }
            SEL sel = NSSelectorFromString(@"runSmokeTestWithTunePath:");
            if (![cls respondsToSelector:sel]) {
                fprintf(stderr, "Error: SPSwiftPlayer does not respond to runSmokeTestWithTunePath:\n");
                return 1;
            }
            BOOL success = ((BOOL (*)(id, SEL, NSString *))objc_msgSend)(cls, sel, tunePath);
            return success ? 0 : 1;
        } else if (argv[i][0] != '-') {
            NSString *tunePath = [NSString stringWithUTF8String:argv[i]];
            dispatch_async(dispatch_get_main_queue(), ^{
                Class cls = NSClassFromString(@"SPSwiftModernAppController");
                if (cls) {
                    SEL sel = NSSelectorFromString(@"openFileWithPath:");
                    if ([cls respondsToSelector:sel]) {
                        ((void (*)(id, SEL, NSString *))objc_msgSend)(cls, sel, tunePath);
                    }
                }
            });
        }
    }

    return NSApplicationMain(argc,  (const char **) argv);
}
