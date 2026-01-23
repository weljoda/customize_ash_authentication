# Ash Authentication - Customize Magic Link Strategy

Welcome! This repository demonstrates how to intercept and customize the **Magic Link** strategy in [Ash Authentication](https://ash-hq.org/) using Phoenix LiveView.

Instead of the default "click link -> logged in" behavior, this project implements a **"Just-in-Time" registration flow**. This ensures that users are only persisted to the database after they have provided necessary profile details and legally agreed to your terms.

## Tutorial Series

The code for this series is organized into separate branches, representing the state of the project at each stage of the tutorial.

### [Part 1: Profile Enforcement](https://github.com/weljoda/customize_ash_authentication/tree/part-1)
**Branch:** [`part-1`](https://github.com/weljoda/customize_ash_authentication/tree/part-1)

Focuses on the basics of intercepting the Magic Link to collect user data before session creation.
* **Goal:** Force new users to enter their **First Name** and **Last Name**.
* **Key Concepts:** Customizing the `sign_in_with_magic_link` action, creating a custom `MagicSignIn` LiveView, and handling Profile relationships.

### [Part 2: Legal Compliance (GDPR)](https://github.com/weljoda/customize_ash_authentication/tree/part-2)
**Branch:** [`part-2`](https://github.com/weljoda/customize_ash_authentication/tree/part-2)

Expands on Part 1 to add a robust legal compliance system.
* **Goal:** Require users to accept the latest **Privacy Policy** or **Terms of Service**.
* **Key Concepts:**
    * **Versioning:** Managing document versions (e.g., Privacy Policy v1, v2).
    * **Audit Trail:** Capturing metadata (IP Address & User Agent) securely.
    * **Validation:** Preventing login until specific documents are acknowledged.

## How to use this repo

Since `main` acts as a directory, please switch to the specific branch to run the code or view the implementation details:

```bash
# To view Part 1
git checkout part-1

# To view Part 2
git checkout part-2
