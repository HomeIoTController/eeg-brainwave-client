# Homer Controller - Brainwave Command Listener

This is an iOS app that connects with MindWave 2 Mobile via bluetooth in order to collect, send and present brainwave that. On that note, this application collects `eeg` data from the user, presents it in a real time graph and dispatches it directly to [graphql-api](https://github.com/PhilipsHUEController/api). Also, it shows real time classifications of users brainwaves.

## Getting Started

* Install [Cocoa Pods](https://cocoapods.org/)
* Run `cd HomeController && pod install` in order to install project dependencies
* Open `eeg-brainwave-client.xcworkspace` project file
* Select a real apple device and click `Run`.
  * This application does not work with the simulator since it uses bluetooth. Moreover, MindWave 2 Mobile library (called `libMWMSDK.a`) was only compiled for `arm7` and `arm64`. That means this only works in a real device.

## Quick description about MWM Comm SDK from NeuroSky

If this is your first time using the MWM Comm SDK for iOS, please start
by reading the "neurosky_mwm_sdk_for_ios" PDF.  It will
tell you everything you need to know to get started.

If you need further help, please visit http://developer.neurosky.com for the latest
additional information.

To contact NeuroSky for support, please visit http://support.neurosky.com, or
send email to support@neurosky.com.

For developer community support, please visit our community forum on
http://www.linkedin.com/groups/NeuroSky-Brain-Computer-Interface-Technology-3572341
