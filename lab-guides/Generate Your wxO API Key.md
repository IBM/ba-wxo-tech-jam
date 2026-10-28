# Generate Your wxO API Key

Version 1.0 / Authors: Olaf Hahnl, Juergen Lukas / Duration: ~5 min

---

## Notices

This information was developed for products and services offered in the USA. IBM may not offer the products, services, or features discussed in this document in other countries. Consult your local IBM representative for information on the products and services currently available in your area.

INTERNATIONAL BUSINESS MACHINES CORPORATION PROVIDES THIS PUBLICATION "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.

This information could include technical inaccuracies or typographical errors. Changes are periodically made to the information herein; these changes will be incorporated in new editions of the publication.

This information contains examples of data and reports used in daily business operations. To illustrate them as completely as possible, the examples include the names of individuals, companies, brands, and products. All of these names are fictitious and any similarity to the names and addresses used by an actual business enterprise is entirely coincidental.

Trademarks: IBM, the IBM logo, and ibm.com are trademarks or registered trademarks of International Business Machines Corp., registered in many jurisdictions worldwide. Other product and service names might be trademarks of IBM or other companies. A current list of IBM trademarks is available at [www.ibm.com/legal/copytrade.shtml](https://www.ibm.com/legal/copytrade.shtml).

© Copyright International Business Machines Corporation 2026. This document may not be reproduced in whole or in part without the prior written permission of IBM. US Government Users Restricted Rights — Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.

---

You open this guide from the setup script (`setup-adk-event.sh` / `setup-adk-event.ps1`). The script has just retrieved your SOR user ID and shown it to you, and it is now waiting for your wxO API key. Generate the key below, then return to the terminal and paste it into the script.

> **Before you start:** Have your **SOR user ID** at hand (for example `usr001`). The script showed it when it retrieved your credentials. You use it as the **API key name** in step 10. Keep the script window open.

## Generate the API key

   1. Open the following link in your browser and log in using your **IBM ID**:
      ```
      https://ap-southeast-1.dl.watson-orchestrate.ibm.com
      ```

      ![IBM ID login page with the Email Address field highlighted](Setup-Event-Credentials-screenshots/ibm-id-login.png)

      *Figure 1. IBM ID login page*

   2. If you have access to multiple wxO tenants, you will see an account selection page — select **TechJam(EMEA|APAC|Americas)**. If you have access to only one tenant, you will land directly in TechJam(EMEA|APAC|Americas) without a selection page.

      ![Account selection page with TechJam(EMEA|APAC|Americas) highlighted](Setup-Event-Credentials-screenshots/tenant-selection.png)

      *Figure 2. Account selection page — select TechJam(EMEA|APAC|Americas) if prompted*

   3. Click your user profile icon (top-right), then click **Settings**.

      ![User profile icon menu open, showing the account name, Account (TechJam), Region, Plan, Appearance options, and Settings highlighted](Setup-Event-Credentials-screenshots/profile-settings-menu.png)

      *Figure 3. User profile icon menu with Settings highlighted*

   4. Click the **API details** tab.

      ![Settings page with the Data Retention tab active and the API details tab highlighted](Setup-Event-Credentials-screenshots/api-details-tab.png)

      *Figure 4. Settings page — click the API details tab*

   5. Click **Generate API key**. The IBM SaaS Console opens in a new browser tab.

      ![API details tab with the Generate API key button highlighted](Setup-Event-Credentials-screenshots/generate-api-key-button.png)

      *Figure 5. API details tab — click Generate API key*

   6. If the IBM SaaS Console asks you to sign in, sign in.
   7. Confirm that the page shows **Access management** and that **TechJam(EMEA|APAC|Americas)** is selected as the **Instance**. If not, select it and click **Apply**.

      ![IBM SaaS Console Access management page with the Instance field set to TechJam(EMEA|APAC|Americas)](Setup-Event-Credentials-screenshots/access-management-instance.png)

      *Figure 6. IBM SaaS Console — Access management page with the correct Instance selected*

   8. Click the **API keys** tab.

      ![IBM SaaS Console Access management page with the Users / User groups / Service IDs / API keys tab bar, and the API keys tab highlighted](Setup-Event-Credentials-screenshots/api-keys-tab.png)

      *Figure 7. IBM SaaS Console — click the API keys tab*

   9. Click **Generate key +**.

       ![IBM SaaS Console API keys tab with the Generate key button highlighted](Setup-Event-Credentials-screenshots/generate-key-button.png)

       *Figure 8. IBM SaaS Console — click the Generate key button*

   10. Enter your SOR user ID (for example `usr001`), as shown by the setup script, as the **API key name**. Do not use any other name.
   11. Enter a date after the end of the event as the **Expiration date**, in `MM/DD/YYYY` format.
   12. Click **Generate key**.

       ![Generate API key dialog with API key name filled in, and Expiration date filled with a date after the event](Setup-Event-Credentials-screenshots/generate-key-dialog-filled.png)

       *Figure 9. Generate API key dialog — with API key name and Expiration date filled in*

   13. Click **Copy to clipboard**. Keep the key in your clipboard: you paste it into the setup script next. The script saves it for you in `labs/event.env`. **The API key is shown only once** — if you close this dialog before you have used it, you will need to generate a new key.

       ![IBM SaaS Console showing the generated API key with the Copy to clipboard button highlighted](Setup-Event-Credentials-screenshots/api-key-copy-to-clipboard.png)

       *Figure 10. IBM SaaS Console — generated API key with Copy to clipboard button*

   14. Close the IBM SaaS Console tab.

   > **Note:**
   > - The API key is shown only once, for about 5 minutes. You cannot retrieve it later. If you lose it, generate a new key.
   > - The API key has the same access as your user. In the **Generate API key** dialog, **Roles** shows **Builder** and **Service user**. The key is for the instance selected in step 7, so it does not work for other instances. **This is why it is critical to ensure that TechJam(EMEA|APAC|Americas) is selected in step 7 — this is the instance all labs except Lab 0 use.**
   > - If you see the message `API key not created, try to create it again`, or a page that lists accounts but no instance, ask a facilitator to check your role assignment.

## Return to the setup script

Go back to the terminal where the setup script is waiting and paste the API key at the prompt. The input is hidden, so nothing appears as you paste. Press **Enter** to continue the ADK setup. The full flow is described in [Setup & Event Credentials, section 1.1](Setup%20%26%20Event%20Credentials.md#11-on-event-day--retrieve-credentials--configure).
