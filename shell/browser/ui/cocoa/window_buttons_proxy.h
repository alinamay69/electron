// Copyright (c) 2021 Microsoft, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#ifndef ELECTRON_SHELL_BROWSER_UI_COCOA_WINDOW_BUTTONS_PROXY_H_
#define ELECTRON_SHELL_BROWSER_UI_COCOA_WINDOW_BUTTONS_PROXY_H_

#import <Cocoa/Cocoa.h>

#include <optional>

#include "ui/gfx/geometry/point.h"

@class WindowButtonsProxy;

// A helper view that floats above the window buttons.
@interface ButtonsAreaHoverView : NSView {
 @private
  WindowButtonsProxy* proxy_;
}
- (id)initWithProxy:(WindowButtonsProxy*)proxy;
@end

// Manipulating the window buttons.
@interface WindowButtonsProxy : NSObject {
 @private
  NSWindow* window_;

  // Current left-top margin of buttons.
  gfx::Point margin_;
  // The default left-top margin.
  gfx::Point default_margin_;
  // Current height of the title bar container.
  float height_;

  // The native titlebar stays in AppKit's fullscreen window. Only its origin
  // changes while controls slide into the app's custom row.
  BOOL fullscreen_overlay_;
  std::optional<double> fullscreen_reveal_;
  NSView* __weak fullscreen_titlebar_view_;
  NSPoint fullscreen_titlebar_origin_;

  // Track mouse moves above window buttons.
  BOOL show_on_hover_;
  BOOL mouse_inside_;
  NSTrackingArea* __strong tracking_area_;
  ButtonsAreaHoverView* __strong hover_view_;
}

- (id)initWithWindow:(NSWindow*)window;

- (void)setVisible:(BOOL)visible;
- (BOOL)isVisible;

// Only show window buttons when mouse moves above them.
- (void)setShowOnHover:(BOOL)yes;

// Set left-top margin of the window buttons..
- (void)setMargin:(const std::optional<gfx::Point>&)margin;

// Set height of button container
- (void)setHeight:(const float)height;
- (BOOL)useCustomHeight;
// A missing reveal amount keeps the system titlebar's layout.
- (void)setFullscreenOverlay:(BOOL)enabled reveal:(std::optional<double>)reveal;

// Return the bounds of all 3 buttons, with margin on all sides.
- (NSRect)getButtonsContainerBounds;

- (void)redraw;
- (void)updateTrackingAreas;
@end

#endif  // ELECTRON_SHELL_BROWSER_UI_COCOA_WINDOW_BUTTONS_PROXY_H_
