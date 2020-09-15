# honeydipper-client

This repo contains a few helper client-side scripts and programs for interacting with Honeydipper through API.

## bin/hdclient.sh

This script makes it easy to send a webhook request to Honeydipper, or wait for Honeydipper to complete a triggered workflow.

### Install

Just download the script and place it somewhere in your `PATH`. The script requires `curl` and `jq`, make sure you have them installed.

### Config

Create a file named `honeydipper` under the directory `~/.config`, and put the url and tokens in the config files like below.

```bash
HD_WEBHOOK_URLPREFIX="https://dipper-webhook.myhoneydipper.com"
HD_API_URLPREFIX="https://dipper-api.myhoneydipper.com/api"
HD_API_TOKEN="xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxxx"
HD_WEBHOOK_TOKEN="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

You can also skip this step if you have other means to inject environment variables to your shell.

### Send a webhook request

Frist source in the script.

```bash
$ . hdclient.sh
$
```

Then run command like below, and you will see the event identifier printed out. It is also stored in `HD_EVENT_ID` environment variable.

```bash
$ hdwebhook path/to/my/hook
xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
$
```

### Wait for an event to complete

Assuming you have sourced in the script, run the command like below.

```bash
$ HD_EVENT_ID=xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx hdwait

```
If the `HD_EVENT_ID` is populated by your previous commands such as `hdwebhook`, you can just run `hdwait`.

### List running events

Again, source in the script, before you run the below command.

```bash
$ hdget events
{
  "XXXXXX": {
    ...
  }
}
$
```
