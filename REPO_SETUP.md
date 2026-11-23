# Repository setup

The Flutter plugin lives in `packages/nosmai_tencent_live`. The app at the repository root can build and run its tests from a clean checkout. [Bridge integration guide](README.md)

## Local credentials

For a live session, supply the Tencent application ID, user ID and matching server-issued UserSig through Flutter build definitions. Each device needs its own user ID and UserSig. The host also needs `NOSMAI_ANDROID_LICENSE_KEY` or `NOSMAI_IOS_LICENSE_KEY` for its application ID or bundle ID.

The optional launch helpers read a local JSON profile via `--dart-define-from-file`. Copy `config/host.example.json` or `config/viewer.example.json` to `config/host.json` or `config/viewer.json`, fill in that participant’s credentials and add the host license to the host profile. Keep these files local. Use `bash run.sh host DEVICE_ID` or `bash run.sh viewer DEVICE_ID` to launch with that profile.

## Tests

Run `flutter test` from the repository root for the example app and from `packages/nosmai_tencent_live` for the bridge.
