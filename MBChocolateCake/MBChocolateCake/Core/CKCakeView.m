//
//  CKCakeCalendarView.m
//  MBChocolateCake
//
//  Created by Moshe Berman on 4/10/13.
//  Copyright (c) 2013 Moshe Berman. All rights reserved.
//

#import "CKCakeView.h"

//  Categories
#import "NSCalendar+DateManipulation.h"
#import "NSCalendar+Ranges.h"
#import "NSCalendar+Weekend.h"
#import "NSCalendar+Components.h"
#import "NSCalendar+DateComparison.h"

//  Cells
#import "CKCakeMonthCell.h"
//Cell for hourly events

@interface CKCakeView ()

@property (nonatomic, strong) NSMutableSet* spareCells;
@property (nonatomic, strong) NSMutableSet* usedCells;

@property (nonatomic, strong) NSDateFormatter *formatter;

@property (nonatomic, strong) UIView *titleView;

@property (nonatomic, assign) NSUInteger selectedIndex;

@end

@implementation CKCakeView

#pragma mark - Initializer

- (id)init
{
    self = [super init];
    
    if (self) {
        _locale = [NSLocale currentLocale];
        _calendar = [NSCalendar currentCalendar];
        [_calendar setLocale:_locale];
        _timeZone = nil;
        _date = [NSDate date];
        _displayMode = CKCakeViewModeMonth;
        _spareCells = [NSMutableSet new];
        _usedCells = [NSMutableSet new];
        _selectedIndex = 0;
    }
    return self;
}

- (id)initWithMode:(CKCakeDisplayMode)cakeDisplayMode
{
    self = [self init];
    if (self) {
        _displayMode = cakeDisplayMode;
    }
    return self;
}

#pragma mark - View Hierarchy

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [self layoutSubviews];
}

-(void)removeFromSuperview
{
    for (CKCakeMonthCell *cell in [self usedCells]) {
        [cell removeFromSuperview];
    }
    
    [super removeFromSuperview];
}

#pragma mark - Size

//  Ensure that the calendar always has the correct size.
- (void)setFrame:(CGRect)frame
{
    frame.size = [self _rectForDisplayMode:[self displayMode]].size;
    
    [super setFrame:frame];
}

- (CGRect)_rectForDisplayMode:(CKCakeDisplayMode)displayMode
{
    CGSize cellSize = [self cellSize];
    
    CGRect rect = CGRectZero;
    
    //  Attempt to use the superview bounds as the default frame
    if ([self superview]) {
        rect = [[self superview] bounds];
    }
    
    //  Otherwise, the default is the bounds of the key window
    else
    {
        rect = [[[UIApplication sharedApplication] keyWindow] bounds];
    }
    
    //  Show one row of days for week mode
    if (displayMode == CKCakeViewModeWeek) {
        NSUInteger daysPerWeek = [[self calendar] daysPerWeekUsingReferenceDate:[self date]];
        rect = CGRectMake(0, 0, (CGFloat)daysPerWeek*cellSize.width, cellSize.height);
        rect.size.height += [[self titleView] frame].size.height;
    }
    
    //  Show enough for all the visible weeks
    else if(displayMode == CKCakeViewModeMonth)
    {
        CGFloat width = (CGFloat)[self _columnCountForDisplayMode:CKCakeViewModeMonth] * cellSize.width;
        CGFloat height = (CGFloat)[self _rowCountForDisplayMode:CKCakeViewModeMonth] * cellSize.height;
        height += [[self titleView] frame].size.height;
        
        rect = CGRectMake(0, 0, width, height);
    }
    
    return rect;
}

#pragma mark - Layout

- (void)layoutSubviews
{
    CGRect frame = [self _rectForDisplayMode:[self displayMode]];
    CGPoint origin = [self frame].origin;
    frame.origin = origin;
    [self setFrame:frame];
    
    [self _layoutCellsAnimated:NO];
}

- (void)_layoutCellsAnimated:(BOOL)animated
{
    if (animated) {
        [UIView animateWithDuration:0.4 animations:^{
            [self _layoutCells];
        }];
    }
    else
    {
        [self _layoutCells];
    }
}

- (void)_layoutCells
{
    
    for (CKCakeMonthCell *cell in [self usedCells]) {
        [[self spareCells] addObject:cell];
        [cell removeFromSuperview];
    }
    
    for (CKCakeMonthCell *cell in [self spareCells]) {
        [[self usedCells] removeObject:cell];
    }
    
    //  Count the rows and columns that we'll need
    NSUInteger rowCount = [self _rowCountForDisplayMode:[self displayMode]];
    NSUInteger columnCount = [self _columnCountForDisplayMode:[self displayMode]];
    
    //  Cache the cell values for easier readability below
    CGFloat width = [self cellSize].width;
    CGFloat height = [self cellSize].height;
    
    //  Cache the start date
    NSDate *workingDate = [self _firstVisibleDateForDisplayMode:[self displayMode]];
    NSUInteger cellIndex = 0;
    
    for (NSUInteger row = 0; row < rowCount; row++) {
        for (NSUInteger column = 0; column < columnCount; column++) {


            /* STEP 1: create and position the cell */
            
            CKCakeMonthCell *cell = [self dequeueCell];
            
            CGRect frame = CGRectMake(column*width, row*height, width, height);
            [cell setFrame:frame];
            
            /* STEP 2:  We need to know some information about the cells - namely, if they're in
                        the same month as the selected date and if any of them represent the system's
                        value representing "today".
             */
            
            BOOL cellRepresentsToday = [[self calendar] date:workingDate isSameDayAs:[NSDate date]];
            BOOL isThisMonth = [[self calendar] date:workingDate isSameMonthAs:[self date]];
            
            /* STEP 3:  Here we style the cells accordingly.
             
                        If the cell represents "today" then select it, and set
                        the selectedIndex.
             
                        If the cell is part of another month, gray it out.
             */
            
            if (cellRepresentsToday) {
                [cell setState:CKCakeMonthCellStateTodaySelected];
                [self setSelectedIndex:cellIndex];
            }
            else if (!isThisMonth) {
                [cell setState:CKCakeMonthCellStateInactive];
            }
            else{
                [cell setState:CKCakeMonthCellStateNormal];
            }
            
            /* STEP 4: Show the day of the month in the cell. */
            
            NSUInteger day = [[self calendar] daysInDate:workingDate];
            [cell setNumber:@(day)];
            
            /* STEP 5: Set the index */
            [cell setIndex:cellIndex];
            
            /* STEP 6: Install the cell in the view hierarchy. */
            [self addSubview:cell];
            
            /* STEP 7: Move to the next date before we continue iterating. */
            
            workingDate = [[self calendar] dateByAddingDays:1 toDate:workingDate];
            cellIndex++;
        }
    }
    
}

- (CKCakeMonthCell *)dequeueCell
{
    CKCakeMonthCell *cell = [[self spareCells] anyObject];
    
    if (!cell) {
        cell = [[CKCakeMonthCell alloc] initWithSize:[self cellSize]];
    }
    
    
    
    //  Move the used cells to the appropriate set
    [[self usedCells] addObject:cell];
    
    if ([[self spareCells] containsObject:cell]) {
        [[self spareCells] removeObject:cell];
    }
    
    [cell prepareForReuse];
    
    return cell;
}


#pragma mark - Setters
- (void)setCalendar:(NSCalendar *)calendar
{
    if (calendar == nil) {
        calendar = [NSCalendar currentCalendar];
    }
    
    _calendar = calendar;
    [_calendar setLocale:_locale];

    [self layoutSubviews];
}

- (void)setLocale:(NSLocale *)locale
{
    if (locale == nil) {
        locale = [NSLocale currentLocale];
    }
    
    _locale = locale;
    [[self calendar] setLocale:locale];
    
    [self layoutSubviews];
}

- (void)setTimeZone:(NSTimeZone *)timeZone
{
    [self setTimeZone:timeZone animated:NO];
}

- (void)setTimeZone:(NSTimeZone *)timeZone animated:(BOOL)animated
{
    if (!timeZone) {
        timeZone = [NSTimeZone localTimeZone];
    }
    
    [[self calendar] setTimeZone:timeZone];
    
    [self _layoutCellsAnimated:animated];
}

- (void)setDisplayMode:(CKCakeDisplayMode)displayMode
{
    [self setDisplayMode:displayMode animated:NO];
}

- (void)setDisplayMode:(CKCakeDisplayMode)displayMode animated:(BOOL)animated
{
    _displayMode = displayMode;
    
    [self _layoutCellsAnimated:animated];
}

- (void)setDate:(NSDate *)date
{
    [self setDate:date animated:NO];
}

- (void)setDate:(NSDate *)date animated:(BOOL)animated
{
    
    date = [NSDate date];
    
    _date = date;
    
    [self _layoutCellsAnimated:animated];
    
}

#pragma mark - Rows and Columns

- (NSUInteger)_rowCountForDisplayMode:(CKCakeDisplayMode)displayMode
{
    if (displayMode == CKCakeViewModeWeek) {
        return 1;
    }
    else if(displayMode == CKCakeViewModeMonth)
    {
        return [[self calendar] weeksPerMonthUsingReferenceDate:[self date]];
    }
    
    return 1; 
}

- (NSUInteger)_columnCountForDisplayMode:(NSUInteger)displayMode
{
    return [[self calendar] daysPerWeekUsingReferenceDate:[self date]];
}

#pragma mark - Date Calculations

- (NSDate *)_firstVisibleDateForDisplayMode:(CKCakeDisplayMode)displayMode
{
    // for the day mode, just return today
    if (displayMode == CKCakeViewModeDay) {
        return [self date];
    }
    else if(displayMode == CKCakeViewModeWeek)
    {
        return [[self calendar] firstDayOfTheWeekUsingReferenceDate:[self date]];
    }
    else if(displayMode == CKCakeViewModeMonth)
    {
        NSDate *firstOfTheMonth = [[self calendar] firstDayOfTheMonthUsingReferenceDate:[self date]];
        
        return [[self calendar] firstDayOfTheWeekUsingReferenceDate:firstOfTheMonth];
    }
    
    return [self date];
}

- (NSDate *)_lastVisibleDateForDisplayMode:(CKCakeDisplayMode)displayMode
{
    // for the day mode, just return today
    if (displayMode == CKCakeViewModeDay) {
        return [self date];
    }
    else if(displayMode == CKCakeViewModeWeek)
    {
        return [[self calendar] lastDayOfTheWeekUsingReferenceDate:[self date]];
    }
    else if(displayMode == CKCakeViewModeMonth)
    {
        NSDate *lastOfTheMonth = [[self calendar] lastDayOfTheMonthUsingReferenceDate:[self date]];
        return [[self calendar] lastDayOfTheWeekUsingReferenceDate:lastOfTheMonth];
    }
    
    return [self date];
}

- (NSUInteger)_numberOfVisibleDaysforDisplayMode:(CKCakeDisplayMode)displayMode
{
    //  If we're showing one day, well, we only one
    if (displayMode == CKCakeViewModeDay) {
        return 1;
    }
    
    //  If we're showing a week, count the days per week
    else if (displayMode == CKCakeViewModeWeek)
    {
        return [[self calendar] daysPerWeek];
    }
    
    //  If we're showing a month, we need to account for the
    //  days that complete the first and last week of the month
    else if (displayMode == CKCakeViewModeMonth)
    {
        
        NSDate *firstVisible = [self _firstVisibleDateForDisplayMode:CKCakeViewModeMonth];
        NSDate *lastVisible = [self _lastVisibleDateForDisplayMode:CKCakeViewModeMonth];
        return [[self calendar] daysFromDate:firstVisible toDate:lastVisible];
    }
    
    //  Default to 1;
    return 1;
}

#pragma mark - Cell Size

- (CGSize)cellSize
{
    return CGSizeMake(46, 44);
}

#pragma mark - Touch Handling

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *t = [touches anyObject];
    
    CGPoint p = [t locationInView:self];
    
    [self pointInside:p withEvent:event];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    
    if (!CGRectContainsPoint([self bounds], point)) {
        return NO;
    }
    
    NSUInteger index = [self selectedIndex];
    
    for (CKCakeMonthCell *cell in [self usedCells]) {
        CGRect rect = [cell frame];
        if (CGRectContainsPoint(rect, point)) {
            [cell setSelected];
            index = [cell index];
        }
        else
        {
            [cell setDeselected];
        }
    }
    
    [self setSelectedIndex:index];
    
    return [super pointInside:point withEvent:event];
}


@end
