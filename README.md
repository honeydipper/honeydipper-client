# honeydipper-client

This repo contains a few helper client-side scripts and programs for interacting with Honeydipper through API.

## bin/hdclient.sh

This script makes it easy to send a webhook request to Honeydipper, or wait for Honeydipper to complete a triggered workflow.

### Install

Just download the script and place it somewhere in your `PATH`. The script requires `curl` and `jq`, make sure you have them installed.

```bash
curl -s https://raw.githubusercontent.com/honeydipper/honeydipper-client/v0.0.2/bin/hdclient.sh > hdclient.sh
```

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

Once the workflow is complete, you can evaluate the environment variable `HD_SESSION_FAILURE_ERROR`. If it is a zero, then the workflow
has completed successfully. If it is not zero, check the output of the command for more detailed information about the failure. The output is also saved
in a file, whose name is in environment variable `HD_RETURN`.

Optionally, you can suppress the verbose output by setting `HD_SILENT=1`, and you can still access the payload in the file pointed to by `$HD_RETURN`.

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
