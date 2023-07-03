# honeydipper-client

This repo contains a few helper client-side scripts and programs for interacting with Honeydipper through API.

## bin/hdclient.sh

This script makes it easy to send a webhook request to Honeydipper, or wait for Honeydipper to complete a triggered workflow.

### Install

Just download the script and place it somewhere in your `PATH`. The script
requires `curl` and `jq`, make sure you have them installed. If you use Google
IAP to secure your API, you will also need to have `gcloud` installed.

```bash
curl -s https://raw.githubusercontent.com/honeydipper/honeydipper-client/v0.0.2/bin/hdclient.sh > hdclient.sh
```

### Config

The script supports switching back and forth between multiple
environments. To easily configure the access to your Honeydipper
daemons, place a file for each of your environment under `~/.config/honeydipper/envs`.
Each file should set a few environment variables.

Below are required
```bash
HD_WEBHOOK_URLPREFIX="https://dipper-webhook.myhoneydipper.com"
HD_API_URLPREFIX="https://dipper-api.myhoneydipper.com/api"
```

If you are given an API token, you can specify it here.
```bash
HD_API_TOKEN="< api token >"
```

Alternatively, you can use `HD_USER_NAME` and `HD_USER_PASS` instead of
`HD_API_TOKEN` to access the APIs, if you are given a username/password
credential.

If your deamon is protected by Google IAP. You can skip the tokens or
username/password, and set below environment variables.
```bash
HD_USE_GCLOUD_IAP=true
HD_GCLOUD_IAP_AUDIENCE=<client_id credential for your backend>.apps.googleusercontent.com
```

To properly authenticate with IAP, You will need to have another desktop app
client id credential in the same GCP project where you daemon is running, and
download the client ID json file to your local and store it as
```
~/.config/honeydipper/creds/gcp.<backend client_id_credential without the .app.googleusercontent.com>
```

Be careful, use the backend client ID credential name, not the desktop app
client ID credential name in the file name.

If you are granted a webhook token, you can specify it this way.
```bash
HD_WEBHOOK_TOKEN="< webhook token >"
```


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

### Removing all cached oauth tokens

Run below command after source in the script.

```bash
hdwipe
```
