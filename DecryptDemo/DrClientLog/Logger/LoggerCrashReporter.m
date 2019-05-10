//
//  LoggerCrashReporter.m
//  DrClientLog
//
//  Created by Ge on 2019/5/10.
//  Copyright © 2019 Ge. All rights reserved.
//

#import "LoggerCrashReporter.h"
#import "PLCrashReporter.h"
#import "PLCrashReportTextFormatter.h"
#import "Logger.h"

@implementation LoggerCrashReporter

+ (void)initCrashReporter {
    static LoggerCrashReporter *reporter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        reporter = [[LoggerCrashReporter alloc] init];
        [reporter initCrashReporter];
    });
}

- (void)initCrashReporter {
    PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
    NSError *error;
    // Check if we previously crashed
    if ([crashReporter hasPendingCrashReport]) {
        [self handleCrashReport];
    }
    // Enable the Crash Reporter
    if (![crashReporter enableCrashReporterAndReturnError: &error]) {
        [Logger warn:@"Could not enable crash reporter: %@", error];
    }
}

- (void)handleCrashReport {
    PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
    NSData *crashData;
    NSError *error;
    
    // Try loading the crash report
    crashData = [crashReporter loadPendingCrashReportDataAndReturnError:&error];
    if (crashData == nil) {
        [Logger error:@"Could not load crash report: %@", error];
        [crashReporter purgePendingCrashReport];
        return;
    }
    
    // We could send the report from here, but we'll just print out some debugging info instead
    PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
    if (report == nil) {
        [Logger error:@"Could not parse crash report"];
        [crashReporter purgePendingCrashReport];
        return;
    }
    
    //TODO:send the report
    [Logger error:@"Crashed: %@", report.systemInfo.timestamp];
    [Logger error:@"Crashed with signal %@ (code %@, address=0x%" PRIx64 ")", report.signalInfo.name, report.signalInfo.code, report.signalInfo.address];
    NSString *humanReadText = [PLCrashReportTextFormatter stringValueForCrashReport:report withTextFormat:PLCrashReportTextFormatiOS];
    [Logger error:@"Crashed detail: %@", humanReadText];
    
    [crashReporter purgePendingCrashReport];
}

@end
