//
//  ViewController.m
//  DrClientLog
//
//  Created by Ge on 2019/5/7.
//  Copyright © 2019 Ge. All rights reserved.
//

#import "ViewController.h"
#import "Document.h"

@interface ViewController()

@property (strong) Document *document;
@property (strong) NSDateFormatter *formatter;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.formatter = [[NSDateFormatter alloc] init];
    [self.formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    self.document = [self.view.window.windowController document];
    [self.tableView reloadData];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

#pragma mark - NSTableViewDataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (self.document) {
        if (self.document.list.count > 0) {
            return self.document.list.count;
        }
    }
    return 1;
}

#pragma mark - NSTableViewDelegate
- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self updateTextViewData];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = @"LogListID";
    NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:nil];
    if (!cell) {
        cell = [[NSTableCellView alloc] init];
        cell.identifier = identifier;
    }
    
    cell.wantsLayer = YES;
    if (!self.document) {
        cell.textField.stringValue = @"请打开一个文件";
    } else {
        if (self.document.list.count == 0) {
            cell.textField.stringValue = @"无记录";
        } else {
            cell.textField.stringValue = [NSString stringWithFormat:@"记录%i", (int)row+1];
        }
    }
    
    return cell;
    
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    NSTableRowView *view = [tableView rowViewAtRow:row makeIfNecessary:NO];
    return view;
}

- (void)updateData {
    [self.tableView reloadData];
    [self updateTextViewData];
}

- (NSAttributedString *)attributeStringWithString:(NSString *)str {
    //原始字符串分解、上色
    NSMutableAttributedString *mAttrString = [[NSMutableAttributedString alloc] init];
    NSRange range = NSMakeRange(0, str.length);
    NSColor *color = [NSColor blackColor];
    
    while (range.location < str.length) {
        NSRange lineRange = [str rangeOfString:@"\n" options:NSCaseInsensitiveSearch range:range];
        NSInteger subLength;
        
        if (lineRange.location > str.length) {
            //搜索不到结尾符号时，可能是EOF，也可能有最后一行
            subLength = str.length-range.location;
            if (subLength <= 0) {
                break;
            }
        } else {
            subLength = lineRange.location-range.location+1;
        }
        
        //判断是否为日志记录头
        NSString *rangeStr = [str substringWithRange:NSMakeRange(range.location, subLength)];
        if (subLength > 24) {
            NSString *dateStr = [rangeStr substringWithRange:NSMakeRange(0, 23)];
            NSDate *date = [self.formatter dateFromString:dateStr];
            if (date) {
                //根据日志头标志更换颜色
                NSString *levelStr = [rangeStr substringFromIndex:24];
                if ([levelStr hasPrefix:@"INFO: "]) {
                    color = [NSColor colorWithRed:0 green:0.75 blue:0 alpha:1];
                } else if ([levelStr hasPrefix:@"DEBUG: "]) {
                    color = [NSColor blueColor];
                } else if ([levelStr hasPrefix:@"WARN: "]) {
                    color = [NSColor colorWithRed:0.75 green:0.75 blue:0 alpha:1];
                } else if ([levelStr hasPrefix:@"ERROR: "]) {
                    color = [NSColor redColor];
                }
            }
        }
        
        //合并格式
        NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithCapacity:1];
        [attrs setValue:color forKey:NSForegroundColorAttributeName];
        NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:rangeStr attributes:attrs];
        [mAttrString appendAttributedString:attrStr];
        
        //搜索范围变更
        range.location += rangeStr.length;
        range.length -= rangeStr.length;
    }
    return mAttrString;
}

- (void)updateTextViewData {
    //倒过来显示，最新的放在数组最后面，显示则是第一个
    if (self.tableView.selectedRow != -1 && self.document.list.count > 0) {
        self.textView.string = @"";
        
        NSLog(@"begin updateTextViewData");
        
        NSString *str = [self.document.list objectAtIndex:self.document.list.count-self.tableView.selectedRow-1];
        NSAttributedString *attrStr = [self attributeStringWithString:str];

        NSLog(@"end updateTextViewData");
        
        [self.textView.textStorage appendAttributedString:attrStr];
    } else {
        self.textView.string = @"";
    }
}

@end
