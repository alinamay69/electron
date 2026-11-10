// Copyright (c) 2021 Microsoft, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#include "shell/browser/ui/cocoa/window_buttons_proxy.h"

#include "base/i18n/rtl.h"

@implementation ButtonsAreaHoverView : NSView

- (id)initWithProxy:(WindowButtonsProxy*)proxy {
  if ((self = [super init])) {
    proxy_ = proxy;
  }
  return self;
}

// Ignore all mouse events.
- (NSView*)hitTest:(NSPoint)aPoint {
  return nil;
}

- (void)updateTrackingAreas {
  [proxy_ updateTrackingAreas];
}

@end

@implementation WindowButtonsProxy

- (id)initWithWindow:(NSWindow*)window {
  window_ = window;
  show_on_hover_ = NO;
  mouse_inside_ = NO;

  // Remember the default margin.
  margin_ = default_margin_ = [self getCurrentMargin];
  // Custom height will be used if set larger than default
  height_ = 0;

  return self;
}

- (void)dealloc {
  if (hover_view_)
    [hover_view_ removeFromSuperview];
}

- (void)setVisible:(BOOL)visible {
  if (fullscreen_overlay_) {
    [self titleBarContainer].hidden = NO;
    for (NSWindowButton kind :
         {NSWindowCloseButton, NSWindowMiniaturizeButton, NSWindowZoomButton}) {
      NSButton* button = [window_ standardWindowButton:kind];
      if (button.hidden == visible)
        button.hidden = !visible;
    }
    return;
  }
  NSView* titleBarContainer = [self titleBarContainer];
  if (!titleBarContainer)
    return;
  [titleBarContainer setHidden:!visible];
}

- (BOOL)isVisible {
  NSView* titleBarContainer = [self titleBarContainer];
  if (!titleBarContainer)
    return YES;
  return ![titleBarContainer isHidden];
}

- (void)setShowOnHover:(BOOL)yes {
  NSView* titleBarContainer = [self titleBarContainer];
  if (!titleBarContainer)
    return;
  show_on_hover_ = yes;
  // Put a transparent view above the window buttons so we can track mouse
  // events when mouse enter/leave the window buttons.
  if (show_on_hover_) {
    hover_view_ = [[ButtonsAreaHoverView alloc] initWithProxy:self];
    [hover_view_ setFrame:[self getButtonsBounds]];
    [titleBarContainer addSubview:hover_view_];
  } else {
    [hover_view_ removeFromSuperview];
    hover_view_ = nil;
  }
  [self updateButtonsVisibility];
}

- (void)setMargin:(const std::optional<gfx::Point>&)margin {
  margin_ = margin.value_or(default_margin_);
  [self redraw];
}

- (void)setHeight:(const float)height {
  height_ = height;
  [self redraw];
}

- (BOOL)useCustomHeight {
  NSView* left = [self leftButton];
  float button_height = NSHeight(left.frame);
  return height_ > button_height + 2 * default_margin_.y();
}

- (void)restoreFullscreenTitlebar {
  NSView* parent = fullscreen_titlebar_view_;
  if (!parent)
    return;
  NSRect frame = parent.frame;
  frame.origin.x = fullscreen_titlebar_origin_.x;
  frame.origin.y = parent.superview.flipped
                       ? fullscreen_titlebar_origin_.y
                       : NSHeight(parent.superview.bounds) - NSHeight(frame) -
                             fullscreen_titlebar_origin_.y;
  parent.frame = frame;
}

- (void)setFullscreenOverlay:(BOOL)enabled
                      reveal:(std::optional<double>)reveal {
  fullscreen_overlay_ = enabled;
  fullscreen_reveal_ = reveal;
  if (!reveal) {
    [self restoreFullscreenTitlebar];
    fullscreen_titlebar_view_ = nil;
  }
  if (enabled)
    [self redraw];
}

- (NSRect)getButtonsContainerBounds {
  return NSInsetRect([self getButtonsBounds], -margin_.x(), -margin_.y());
}

- (void)redraw {
  NSView* titleBarContainer = [self titleBarContainer];
  if (!titleBarContainer)
    return;

  NSView* left = [self leftButton];
  NSView* middle = [self middleButton];
  NSView* right = [self rightButton];

  float button_width = NSWidth(left.frame);
  float button_height = NSHeight(left.frame);
  float padding = NSMinX(middle.frame) - NSMaxX(left.frame);
  if (fullscreen_overlay_) {
    if (!fullscreen_reveal_)
      return;
    NSView* parent = left.superview;
    if (fullscreen_titlebar_view_ != parent) {
      [self restoreFullscreenTitlebar];
      fullscreen_titlebar_view_ = parent;
      fullscreen_titlebar_origin_ = NSMakePoint(
          NSMinX(parent.frame),
          parent.superview.flipped
              ? NSMinY(parent.frame)
              : NSHeight(parent.superview.bounds) - NSMaxY(parent.frame));
    }
    const CGFloat controls_width =
        NSWidth([self getButtonsBounds]) + 2 * margin_.x();
    const CGFloat slide = controls_width * (1 - *fullscreen_reveal_);
    NSRect frame = parent.frame;
    frame.origin.x = base::i18n::IsRTL()
                         ? NSWidth(parent.superview.bounds) - margin_.x() +
                               slide - NSMaxX(right.frame)
                         : margin_.x() - slide - NSMinX(left.frame);
    const CGFloat height =
        [self useCustomHeight] ? height_ : button_height + 2 * margin_.y();
    const CGFloat button_top =
        parent.flipped ? NSMinY(left.frame)
                       : NSHeight(parent.bounds) - NSMaxY(left.frame);
    const CGFloat desired_top = margin_.y() != default_margin_.y()
                                    ? margin_.y()
                                    : (height - button_height) / 2;
    const CGFloat top = desired_top - button_top;
    frame.origin.y =
        parent.superview.flipped
            ? top
            : NSHeight(parent.superview.bounds) - NSHeight(frame) - top;
    parent.frame = frame;
    return;
  }
  float start;
  if (base::i18n::IsRTL())
    start =
        NSWidth(window_.frame) - 3 * button_width - 2 * padding - margin_.x();
  else
    start = margin_.x();

  NSRect cbounds = titleBarContainer.frame;
  cbounds.size.height = button_height + 2 * margin_.y();
  // Custom height must be larger than the button height to use
  if ([self useCustomHeight]) {
    cbounds.size.height = height_;
  }
  cbounds.origin.y = NSHeight(window_.frame) - NSHeight(cbounds);
  [titleBarContainer setFrame:cbounds];

  [left setFrameOrigin:NSMakePoint(start, [self getCurrentMargin].y())];
  start += button_width + padding;
  [middle setFrameOrigin:NSMakePoint(start, [self getCurrentMargin].y())];
  start += button_width + padding;
  [right setFrameOrigin:NSMakePoint(start, [self getCurrentMargin].y())];

  if (hover_view_)
    [hover_view_ setFrame:[self getButtonsBounds]];
}

- (void)updateTrackingAreas {
  if (tracking_area_)
    [hover_view_ removeTrackingArea:tracking_area_];
  tracking_area_ = [[NSTrackingArea alloc]
      initWithRect:NSZeroRect
           options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways |
                   NSTrackingInVisibleRect
             owner:self
          userInfo:nil];
  [hover_view_ addTrackingArea:tracking_area_];
}

- (void)mouseEntered:(NSEvent*)event {
  mouse_inside_ = YES;
  [self updateButtonsVisibility];
}

- (void)mouseExited:(NSEvent*)event {
  mouse_inside_ = NO;
  [self updateButtonsVisibility];
}

- (void)updateButtonsVisibility {
  // Show buttons when mouse hovers above them.
  BOOL hidden = show_on_hover_ && !mouse_inside_;
  // Always show buttons under fullscreen.
  if ([window_ styleMask] & NSWindowStyleMaskFullScreen)
    hidden = NO;
  for (NSWindowButton button_type :
       {NSWindowCloseButton, NSWindowMiniaturizeButton, NSWindowZoomButton}) {
    NSButton* button = [window_ standardWindowButton:button_type];
    if (!button)
      continue;
    [button setHidden:hidden];
    [button setNeedsDisplay:YES];
  }

  // On macOS 26, toggling the hidden state of the standard window buttons can
  // cause AppKit to re-layout the title bar container and reset its frame,
  // which loses the custom margin adjustments. Re-apply the calculated geometry
  // after visibility changes to keep the buttons at the specified margin
  // instead of snapping back to the default until the next manual resize.
  [self redraw];
}

// Return the bounds of all 3 buttons.
- (NSRect)getButtonsBounds {
  NSView* left = [self leftButton];
  NSView* right = [self rightButton];

  return NSMakeRect(NSMinX(left.frame), NSMinY(left.frame),
                    NSMaxX(right.frame) - NSMinX(left.frame),
                    NSHeight(left.frame));
}

// Compute margin from position of current buttons.
- (gfx::Point)getCurrentMargin {
  gfx::Point result;
  NSView* titleBarContainer = [self titleBarContainer];
  if (!titleBarContainer)
    return result;

  NSView* left = [self leftButton];
  NSView* right = [self rightButton];

  if (height_ != 0) {
    result.set_y((height_ - NSHeight(left.frame)) / 2);

    // Do not center buttons if height and button position specified
    if (margin_.y() != default_margin_.y())
      result.set_y(height_ - NSHeight(left.frame) - margin_.y());

  } else {
    result.set_y((NSHeight(titleBarContainer.frame) - NSHeight(left.frame)) /
                 2);
  }

  if (base::i18n::IsRTL())
    result.set_x(NSWidth(window_.frame) - NSMaxX(right.frame));
  else
    result.set_x(NSMinX(left.frame));
  return result;
}

// Receive the titlebar container, which might be nil if the window does not
// have the NSWindowStyleMaskTitled style.
- (NSView*)titleBarContainer {
  NSView* left = [self leftButton];
  if (!left.superview)
    return nil;
  return left.superview.superview;
}

// Receive the window buttons, note that the buttons might be removed and
// re-added on the fly so we should not cache them.
- (NSButton*)leftButton {
  if (base::i18n::IsRTL())
    return [window_ standardWindowButton:NSWindowZoomButton];
  else
    return [window_ standardWindowButton:NSWindowCloseButton];
}

- (NSButton*)middleButton {
  return [window_ standardWindowButton:NSWindowMiniaturizeButton];
}

- (NSButton*)rightButton {
  if (base::i18n::IsRTL())
    return [window_ standardWindowButton:NSWindowCloseButton];
  else
    return [window_ standardWindowButton:NSWindowZoomButton];
}

@end
