#import "WMFSyntaxHighlightTextStorage.h"


@interface WMFSyntaxHighlightTextStorage ()

@property (nonatomic, strong) NSMutableAttributedString *backingStore;

@end

@implementation WMFSyntaxHighlightTextStorage

- (instancetype) init {
    if (self = [super init]) {
        self.backingStore = [[NSMutableAttributedString alloc] init];
    }
    return self;
}

- (NSString *)string {
    return self.backingStore.string;
}

- (NSDictionary<NSAttributedStringKey,id> *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range {
    return [self.backingStore attributesAtIndex:location effectiveRange:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str {
    [self beginEditing];
    [self.backingStore replaceCharactersInRange:range withString:str];
    [self edited:NSTextStorageEditedCharacters range:range changeInLength:str.length - range.length];
    [self endEditing];
}

- (void)setAttributes:(NSDictionary<NSAttributedStringKey,id> *)attrs range:(NSRange)range {
    [self beginEditing];
    [self.backingStore setAttributes:attrs range:range];
    [self edited:NSTextStorageEditedAttributes range:range changeInLength:0];
    [self endEditing];
}

- (void)applyStylesToRange:(NSRange)searchRange {
    
    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleBody];
    UIFontDescriptor *boldFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    UIFontDescriptor *italicFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];
    UIFontDescriptor *boldItalicFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic|UIFontDescriptorTraitBold];
    UIFont *boldFont = [UIFont fontWithDescriptor:boldFontDescriptor size:0];
    UIFont *italicFont = [UIFont fontWithDescriptor:italicFontDescriptor size:0];
    UIFont *boldItalicFont = [UIFont fontWithDescriptor:boldItalicFontDescriptor size:0];
    UIFont *normalFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    
    NSString *boldItalicRegexStr = @"('{5})[^']*(?:'(?!'''')[^']*)*('{5})";
    NSString *boldRegexStr = @"('{3})[^']*(?:'(?!'')[^']*)*('{3})";
    NSString *italicRegexStr = @"('{2})[^']*(?:'(?!')[^']*)*('{2})";
    NSString *linkRegexStr = @"(\\[\\[.*\\]\\])";
    
    NSRegularExpression *boldItalicRegex = [NSRegularExpression regularExpressionWithPattern:boldItalicRegexStr options:0 error:nil];
    NSRegularExpression *boldRegex = [NSRegularExpression regularExpressionWithPattern:boldRegexStr options:0 error:nil];
    NSRegularExpression *italicRegex = [NSRegularExpression regularExpressionWithPattern:italicRegexStr options:0 error:nil];
    NSRegularExpression *linkRegex = [NSRegularExpression regularExpressionWithPattern:linkRegexStr options:0 error:nil];

    NSDictionary *boldAttributes = @{
        NSFontAttributeName:boldFont,
    };
    
    NSDictionary *italicAttributes = @{
        NSFontAttributeName:italicFont,
    };
    
    NSDictionary *boldItalicAttributes = @{
        NSFontAttributeName:boldItalicFont,
    };

    NSDictionary *linkAttributes = @{
        NSForegroundColorAttributeName:self.theme.colors.link
    };
    
    NSDictionary *orangeFontAttributes = @{
        NSForegroundColorAttributeName:self.theme.colors.warning
    };
    
    NSDictionary *normalAttributes = @{
        NSFontAttributeName:normalFont,
        NSForegroundColorAttributeName:self.theme.colors.primaryText
    };
    
    [self removeAttribute:NSFontAttributeName range:searchRange];
    [self removeAttribute:NSForegroundColorAttributeName range:searchRange];
    [self addAttributes:normalAttributes range:searchRange];
    
    [italicRegex enumerateMatchesInString:self.backingStore.string options:0 range:searchRange usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        
        NSRange matchRange = [result rangeAtIndex:0];
        NSRange openingRange = [result rangeAtIndex:1];
        NSRange closingRange = [result rangeAtIndex:2];
        
        if (matchRange.location != NSNotFound) {
            [self addAttributes:italicAttributes range:matchRange];
        }
        
        if (openingRange.location != NSNotFound) {
            [self addAttributes:orangeFontAttributes range:openingRange];
        }
        
        if (closingRange.location != NSNotFound) {
            [self addAttributes:orangeFontAttributes range:closingRange];
        }
    }];
    
    [boldRegex enumerateMatchesInString:self.backingStore.string options:0 range:searchRange usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        
        NSRange matchRange = [result rangeAtIndex:0];
        NSRange openingRange = [result rangeAtIndex:1];
        NSRange closingRange = [result rangeAtIndex:2];
        
        if (matchRange.location != NSNotFound) {
            [self addAttributes:boldAttributes range:matchRange];
        }
        
        if (openingRange.location != NSNotFound) {
            [self addAttributes:orangeFontAttributes range:openingRange];
        }
        
        if (closingRange.location != NSNotFound) {
            [self addAttributes:orangeFontAttributes range:closingRange];
        }
    }];

    [boldItalicRegex enumerateMatchesInString:self.backingStore.string options:0 range:searchRange usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {

        NSRange matchRange = [result rangeAtIndex:0];
        NSRange openingRange = [result rangeAtIndex:1];
        NSRange closingRange = [result rangeAtIndex:2];

        if (matchRange.location != NSNotFound) {
            [self addAttributes:boldItalicAttributes range:matchRange];
        }

        if (openingRange.location != NSNotFound) {
            [self addAttributes:orangeFontAttributes range:openingRange];
        }

        if (closingRange.location != NSNotFound) {
            [self addAttributes:orangeFontAttributes range:closingRange];
        }
    }];

    [linkRegex enumerateMatchesInString:self.backingStore.string options:0 range:searchRange usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {

        NSRange matchRange = [result rangeAtIndex:0];

        if (matchRange.location != NSNotFound) {
            [self addAttributes:linkAttributes range:matchRange];
        }
    }];
}

- (void)performReplacementsForRange:(NSRange)changedRange {
    NSRange extendedRange = NSUnionRange(changedRange, [self.backingStore.string lineRangeForRange:NSMakeRange(changedRange.location, 0)]);
    extendedRange = NSUnionRange(changedRange, [self.backingStore.string lineRangeForRange:NSMakeRange(NSMaxRange(changedRange), 0)]);
    [self applyStylesToRange: extendedRange];
}

- (void)processEditing {
    [self performReplacementsForRange:self.editedRange];
    [super processEditing];
}

- (void)applyTheme:(WMFTheme *)theme {
    self.theme = theme;
    NSRange allRange = NSMakeRange(0, self.backingStore.length);
    [self applyStylesToRange:allRange];
}

@end
