//
//  KFChatTableView.m
//  Pods
//
//  Created by admin on 16/10/20.
//
//

#import "KFChatTableView.h"
#import "KFCategory.h"

static NSString *kChatMessageVoiceCellID = @"chatMessageVoiceCellID";
static NSString *kChatMessageTextCellID = @"chatMessageTextCellID";
static NSString *kChatMessageImageCellID = @"chatMessageImageCellID";
static NSString *kChatMessageSystemCellID = @"chatMessageSystemCellID";
static NSString *kChatMessageCardCellID = @"chatMessageCardCellID";
static NSString *kChatMessageQueueCellID = @"chatMessageQueueCellID";

#define KFContentInsetTop  KF5Helper.KF5VerticalSpacing

@interface KFChatTableView()<UITableViewDataSource,UITableViewDelegate>

@property (nonatomic, assign) BOOL isScrollBottomed;

@end

@implementation KFChatTableView

- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style{
    self = [super initWithFrame:frame style:style];
    if (self) {
        
        self.delaysContentTouches = NO;
        self.canCancelContentTouches = YES;
        
        // Remove touch delay (since iOS 8)
        UIView *wrapView = self.subviews.firstObject;
        // UITableViewWrapperView
        if (wrapView && [NSStringFromClass(wrapView.class) hasSuffix:@"WrapperView"]) {
            for (UIGestureRecognizer *gesture in wrapView.gestureRecognizers) {
                // UIScrollViewDelayedTouchesBeganGestureRecognizer
                if ([NSStringFromClass(gesture.class) containsString:@"DelayedTouchesBegan"] ) {
                    gesture.enabled = NO;
                    break;
                }
            }
        }
        
        [self registerClass:[KFTextMessageCell class] forCellReuseIdentifier:kChatMessageTextCellID];
        [self registerClass:[KFImageMessageCell class] forCellReuseIdentifier:kChatMessageImageCellID];
        [self registerClass:[KFVoiceMessageCell class] forCellReuseIdentifier:kChatMessageVoiceCellID];
        [self registerClass:[KFSystemMessageCell class] forCellReuseIdentifier:kChatMessageSystemCellID];
        [self registerClass:[KFCardMessageCell class] forCellReuseIdentifier:kChatMessageCardCellID];
        
        [self setContentInset:UIEdgeInsetsMake(KFContentInsetTop, 0, 0, 0)];
        self.delegate = self;
        self.dataSource = self;
        
        self.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    return self;
}

- (void)setCanRefresh:(BOOL)canRefresh {
    if (canRefresh != _canRefresh) {
        if (canRefresh) {
            UIActivityIndicatorView *view = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            [view startAnimating];
            self.tableHeaderView = view;
        }else{
            self.tableHeaderView = nil;
        }
        CGPoint offset = self.contentOffset;
        offset.y = offset.y + (canRefresh ? 20 : -20);
        self.contentOffset = offset;
    }
    _canRefresh = canRefresh;
}

#pragma mark - tableView代理
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    KFMessageModel *messageModel = self.messageModels[indexPath.row];
    return messageModel.cellHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    // 第一次显示时,滚动到最底部
    if (self.isScrollBottomed == false) {
        self.isScrollBottomed = true;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (self.messageModels.count > 0) {
                [tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.messageModels.count-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
            }
        });
    }
    return self.messageModels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    KFMessageModel *messageModel = self.messageModels[indexPath.row];
    
    NSString *identifier = nil;
    
    switch (messageModel.message.messageType) {
        case KFMessageTypeText:
        case KFMessageTypeCustom:{
            identifier = kChatMessageTextCellID;
        }
            break;
        case KFMessageTypeImage:{
            identifier = kChatMessageImageCellID;
        }
            break;
        case KFMessageTypeVoice:{
            identifier = kChatMessageVoiceCellID;
        }
            break;
        case KFMessageTypeSystem:{
            identifier = kChatMessageSystemCellID;
        }
            break;
        case KFMessageTypeCard:{
            identifier = kChatMessageCardCellID;
        }
            break;
        default:{
            identifier = kChatMessageTextCellID;
        }
            break;
    }
    
    if (messageModel.message.recalled) {
        identifier = kChatMessageSystemCellID;
    }
    
    KFChatViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    cell.cellDelegate = self.tableDelegate;
    cell.messageModel = messageModel;
    
    return cell;
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    if (self.superview)[self.superview endEditing:NO];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    [[UIMenuController sharedMenuController] setMenuVisible:NO];
    if (self.canRefresh && scrollView.isDragging && !self.refreshing) {
        if (scrollView.contentOffset.y <= -scrollView.contentInset.top) {
            self.refreshing = YES;
            self.contentOffset = CGPointZero;
            if ([self.tableDelegate respondsToSelector:@selector(tableViewWithRefreshData:)]) {
                [self.tableDelegate tableViewWithRefreshData:self];
            }
        }
    }
}

#pragma mark 向下滚动
- (void)scrollViewBottomWithAnimated:(BOOL)animated{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger rowCount = [self numberOfRowsInSection:0];
        if (rowCount > 1) {
            NSIndexPath* indexPath = [NSIndexPath indexPathForRow:rowCount-1 inSection:0];
            [self layoutIfNeeded];
            [self scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:animated];
        }
    });
}

- (void)scrollViewBottomWithAfterTime:(int16_t)afterTime{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(afterTime * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self scrollViewBottomWithAnimated:YES];
    });
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if ( [view isKindOfClass:[UIControl class]]) {
        return YES;
    }
    return [super touchesShouldCancelInContentView:view];
}

- (void)drawRect:(CGRect)rect{
    [super drawRect:rect];
    
    [self.messageModels makeObjectsPerformSelector:@selector(updateFrame)];

    [self reloadData];
    [self scrollViewBottomWithAnimated:YES];
}

@end
