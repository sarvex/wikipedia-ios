@import UIKit;
@import WMF.Swift;

@interface WMFSyntaxHighlightTextStorage: NSTextStorage <WMFThemeable>

@property (nonatomic, strong) WMFTheme *theme;
- (void)applyTheme:(WMFTheme *)theme;


@end
