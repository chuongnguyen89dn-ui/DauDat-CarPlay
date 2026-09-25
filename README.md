# Đầu Đất CarPlay

Clean-room CarPlay project for rootless iOS 15/16.

## Goals
- Independent package and runtime namespace: `com.chuong.daudat`
- No SenseTechLab/DuoDash branding or runtime identifiers
- Full 427×240 CarPlay canvas on an 854×480 head unit
- Reversible sidebar fullscreen mode; CarPlay Home remains untouched
- Split-pane foundation for two bridged app surfaces

## Build
GitHub Actions builds a rootless `.deb` with Theos.

## Status
Initial clean-room scaffold. Geometry/fullscreen behavior will be validated on-device before bridge features are ported.
