<p align="center">
  <img src="docs/icon.svg" width="100">
</p>
<h1 align="center">Stop Origin migration</h1>
<p align="center">
  A comprehensive guide on how to configure and install Origin without being forced to migrate to the new EA app
</p>


## Language

- [Български][readme-bg]
- [English][readme-en]

> **Note**: If you would like to help translate this guide in other languages, go to [contributing](#contributing).


## Table of contents

- [About](#about)
- [Preparation](#preparation)
- [Automatic setup (recommended)](#automatic-setup-recommended)
- [Manual setup](#manual-setup)
- [Additional configuration](#additional-configuration)
  - [Disable background processes](#disable-background-processes)
  - [Disable data collection](#disable-data-collection)
  - [Opt out of targeted advertising](#opt-out-of-targeted-advertising)
- [What's wrong with the EA app](#whats-wrong-with-the-ea-app)
  - [Forced migration](#forced-migration)
  - [Broken features](#broken-features)
  - [Missing features](#missing-features)
  - [Mandatory background processes](#mandatory-background-processes)
  - [Concerning network traffic](#concerning-network-traffic)
  - [Conclusion](#conclusion)
- [Contributing](#contributing)
- [License](#license)


## About

Users of the Origin app are forced to migrate to the EA app - the successor of Origin. It's broken beyond usability and
it forces you to migrate no matter what. Origin is not flawless either, but it was light years better than what we have
now. Read about [what's wrong with the EA app](#whats-wrong-with-the-ea-app).

This guide focuses on providing clear and user-friendly instructions on how to install Origin again and prevent it from
migrating. It is not affiliated with EA in any way.

Migration workaround by [p0358][p0358].


## Preparation

1. Uninstall the EA app with all of its files and settings

    Skipping this step is strongly discouraged, but if you absolutely have a reason to keep the EA app installed without
    using it often, you should set the `EABackgroundService` service startup type to "Manual" to avoid having it running
    in the background all the time.

2. Ensure Origin is fully stopped if it's currently running


## Automatic setup (recommended)

A script is available to help you easily configure and install the last known stable version of Origin.

If you don't want or are unable to download and run a PowerShell script, feel free to follow the
[manual setup](#manual-setup) instead.

1. [Download the script stop-origin-migration.ps1 by right-clicking this link][stop-origin-migration.ps1] and clicking
  "Save link as"
2. Save the script to an easily accessible location, such as your Desktop
3. Right-click the script and click "Run with PowerShell"
4. Click "Yes" if an administrator prompt pops up
5. Follow the prompts given by the script to choose what you want to do

If you are unsure wether to choose to install Origin again and replace the currently installed version, there shouldn't
be any issues as your games and settings won't be deleted. The default choices should work well for everybody.


## Manual setup

If you're having difficulty following the manual setup, you can follow the [automatic
setup](#automatic-setup-recommended) instead.

1. Press `Ctrl + R`, type `%ProgramData%` and hit enter

2. Go into the `Origin` directory

    If it doesn't exist, simply create a new folder with the name `Origin`.

2. Open the file `local.xml` using Notepad or any text editor by right-clicking it and clicking "Edit" or "Open with"

    If the file doesn't exist, enable file name extensions from the ribbon menu on top in File Explorer, create a new
    text file and rename it to `local.xml`, noting the `xml` file extension.

3. Modify the settings to disable automatic updates and migration

    If the file exists and is not empty:

    1. Scroll down to the end of the file

    2. Right before the closing tag (`</Settings>`) insert the following lines:
        ```xml
        <Setting key="AutoPatchGlobal" value="false" type="1"/>
        <Setting key="AutoUpdate" value="false" type="1"/>
        <Setting key="MigrationDisabled" value="true" type="1"/>
        <Setting key="UpdateURL" value="" type="10"/>
        ```

    3. The end of file should now look like this:
        ```xml
          <Setting key="AutoPatchGlobal" value="false" type="1"/>
          <Setting key="AutoUpdate" value="false" type="1"/>
          <Setting key="MigrationDisabled" value="true" type="1"/>
          <Setting key="UpdateURL" value="" type="10"/>
        </Settings>
        ```

    If the file is empty:

    1. Copy and paste the following content into the file:
        ```xml
        <?xml version="1.0"?>
        <Settings>
          <Setting key="AutoPatchGlobal" value="false" type="1"/>
          <Setting key="AutoUpdate" value="false" type="1"/>
          <Setting key="MigrationDisabled" value="true" type="1"/>
          <Setting key="UpdateURL" value="" type="10"/>
        </Settings>
        ```

4. Save and close the file

5. Download the last known stable version 10.5.119.52718 of Origin from [here][origin-download-external] or
  [here][origin-download-local]

    Make sure you download `OriginSetup`, also known as "full", instead of `OriginSetupThin`. The "full" setup is an
    offline installer that contains the whole application, while the "thin" setup is an online installer that downloads
    the application directly from EA during installation, which might result in installing newer, undesired version.

    For advanced users - the file `OriginSetup-10.5.119.52718.exe` should have the following SHA-256 hash:
    `ED6EE5174F697744AC7C5783FF9021DA603BBAC42AE9836CD468D432CADC9779`

6. Install Origin as normal


## Additional configuration

After disabling migration and installing Origin, you might want to disable potentially unwanted features, such as data
collection, and opt out of targeted advertising.

### Disable background processes

1. In the Origin app, go to "Origin > Application Settings"
2. Go to the "Applications" tab
3. Go to "Start-up options"
4. Disable "Origin Helper service"

### Disable data collection

1. In the Origin app, go to "Origin > Application Settings"
2. Go to the "Diagnostics" tab
3. Go to "Help improve Origin"
4. Disable "Share system interaction data", set "Origin crash reporting" to "Ask before sending" or "Never send", and
  optionally disable "Share hardware info" (note that this info might be useful to game developers)
5. Go to "Troubleshooting"
6. Disable "Origin In-Game logging"

### Opt out of targeted advertising

1. In the Origin app, go to "Origin > EA Account and Billing..."
2. On the account settings page, go to "Privacy Settings"
3. Under "Preferred Data Usage", uncheck "EA In-Game Targeted Advertising" and "EA Targeted Advertising on Third Party
  Websites and Platforms"


## What's wrong with the EA app

### Forced migration

First of all, a big issue is how the migration is handled in hand with the automatic update process. When launching
Origin or an EA game, the migration begins automatically without notice, Origin is uninstalled (though for some people
strangely it isn't) and the EA app is installed in its place. It is unreasonable to expect an application to silently
delete itself upon launching one day and get replaced by another (*cough* Windows Updates *cough*).

### Broken features

Then we get to the new EA app. For many, core features simply don't work at all. Ever since the first few months when
the migration had started rolling out, numerous critical problems with the app and its web infrastructure have arisen,
such as being unable to log in, add or invite friends, see chat messages, open or use the in-game overlay, launch games,
launch the app itself, or the whole installation failing with unspecified errors upon migration.

### Missing features

The EA app is also missing the important feature to locate already installed games, which was possible with Origin, and
is a deal-breaker for a game launcher.

### Mandatory background processes

But the issues don't end with usability, or lack there of, and the terrible user experience. The EA app installs a
background service required for it to function called "EABackgroundService", which starts automatically on system
startup and continues to run in the background all time time, even when not using the app.

### Concerning network traffic

This EABackgroundService service also appears to have an issue where in some cases it can generate [tens or hundreds of
gigabytes of traffic per month][eabs-traffic]. This may be caused due to automatic updates in the background or broken
data collection and sending mechanism, but in any case this shouldn't happen without the user's permission. It's also
worth noting that EA's customer support [silently closed a ticket][eabs-ticket] about reporting and requesting
information for this issue, effectively giving users even less reasons to trust the company and its software. This issue
was discovered [back in 2021][eabs-reddit-1], but it's [still not fixed][eabs-reddit-2].

### Conclusion

At best, the EA app is an unfinished product and all of its users are beta testers, and at worst, it's a horribly borked
piece of software that limits your ability to play games, constantly uses system resources, and might be collecting and
sending your data in the background.

That's why it is strongly recommended to purge the EA app and all of its settings, files and cache from your system
completely, and instead use Origin while it still works.


## Contributing

You are welcome to contribute and make this project better. Make sure to follow the existing code style, keep your code
well-formatted and consistent, and test your changes. If you have any questions or proposals, feel free to ask for
feedback at any time.

The current priority is to make this guide available in more languages. If you're able and would like to translate the
README page:

1. Fork the repository

2. Create a copy of `README.md` with the name `README.<lang>.md`, where `<lang>` is the language code, e.g. `README.bg.md`

3. Translate the page and commit your changes

    Tips:

    - Don't translate code or raw text surrounded by backticks
    - Don't translate blockquote prefixes like `**Note**`
    - You don't need to translate user interface text of applications that don't support the language
    - For clarity, please keep user interface and technical terms untranslated in parentheses after the translated
      version like this: "\<translated>" (\<original>)
    - Keep the language list at the top alphabetically sorted by the language code

4. Open a pull request to this repository


## License

MIT license. See [LICENSE][license] for more information.

The icon uses modified assets from [Ionicons][ionicons].


[readme-bg]: README.bg.md
[readme-en]: README.md
[p0358]: https://twitter.com/p0358
[stop-origin-migration.ps1]: https://raw.githubusercontent.com/alexitx/stop-origin-migration/master/stop-origin-migration.ps1
[origin-download-external]: https://taskinoz.com/origin
[origin-download-local]: setup
[eabs-traffic]: docs/eabackgroundservice-traffic.png
[eabs-ticket]: docs/eabackgroundservice-ticket.png
[eabs-reddit-1]: https://redd.it/mcssru
[eabs-reddit-2]: https://redd.it/11cvrvn
[license]: LICENSE
[ionicons]: https://github.com/ionic-team/ionicons
