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

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
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

- (void)updateTextViewData {
    //倒过来显示，最新的放在数组最后面，显示则是第一个
    if (self.tableView.selectedRow != -1 && self.document.list.count > 0) {
        self.textView.string = [self.document.list objectAtIndex:self.document.list.count-self.tableView.selectedRow-1];
    } else {
        self.textView.string = @"";
    }
}

@end
