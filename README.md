# AzureADAppsSecretExpiration

Friendly reminder through Teams MessageCard for secret expiration on your Azure AD *App Registrations*.

![Result of the MessageCard](/capture.png)

## Parameters

There is two parameters available on the script:

1. `-Webhooks` to provide the URI of the Teams incoming webhooks. Multiple URIs are accepted.
2. `-Days` to filter secret that will expire in X days or less. By default, the value of this parameter is 30.

## Message card

Each section contains an expiring/expired secret, so you can have multiple section for one app (since an application can contains multiple secrets).

## Useful resources

- [MessageCard Playground V2](https://messagecardplayground.azurewebsites.net/) to see the result without having to create an incoming webhook
- [Create an Incoming Webhook - Teams \| Microsoft Learn](https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook)
