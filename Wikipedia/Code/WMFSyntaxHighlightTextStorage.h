@import UIKit;
@import WMF.Swift;

@interface WMFSyntaxHighlightTextStorage: NSTextStorage <WMFThemeable>

@property (nonatomic, strong) WMFTheme *theme;
@property (nonatomic, strong) UITraitCollection *fontSizeTraitCollection;
- (void)applyTheme:(WMFTheme *)theme;
- (void)applyFontSizeTraitCollection:(UITraitCollection *)fontSizeTraitCollection;

@end
