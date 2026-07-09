# Xuanji Liuyao Installer

This is the custom Flutter-based Windows installer GUI for the main app.

The final single-file installer is built by `build_installer.ps1`:

1. Build the main Windows release as the install payload.
2. Build this Flutter installer app.
3. Stage both under one folder.
4. Wrap the staged folder with the 7-Zip SFX module.

The installer reads/writes the app install state under
`HKCU\Software\XuanjiLiuyao` and uses the matching uninstall registry key to
detect updates, rollbacks, and reinstalls.
