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


## DauDat Doctor (required before final release)
Đầu Đất must ship with a diagnostic/doctor layer. It records evidence before applying a fix and must never guess from injection success alone.

Diagnostic chain: device/iOS -> CarPlay display -> UIWindowScene -> windows -> root/content views -> sidebar/status-bar window -> bridge process -> hosted app surfaces -> pane/layout geometry -> touch/input -> preferences/runtime state -> crash/runtime logs.

Required geometry fields: UIScreen bounds/nativeBounds/scale, CarPlay scene coordinateSpace bounds, every CarPlay UIWindow class/frame/bounds/safeAreaInsets/windowLevel/root VC, DBStatusBarWindow frame, content/frame window dimensions, pane rectangles, layout id, split ratios, left/right/third bundle IDs, fullscreen/sidebar state.

Required health checks: SpringBoard/CarPlay/CarPlayTemplateUIHost/mediaserverd processes, DauDat injection per process, bridge state and app launch state, preferences readability, stale paths/identifiers, notification/state synchronization, remote surface creation/attachment, orientation, touch routing, crash/restart loops.

Diagnosis rule: compare the last known-good path with the failing path layer-by-layer. The first divergent layer is the primary suspect. A green build or successful injection is not proof of runtime correctness.

Repair loop: snapshot -> diagnose -> identify first divergence -> apply minimal targeted fix -> snapshot again -> compare -> only then mark the symptom fixed. Preserve working layouts and behavior while repairing another device/layout.
