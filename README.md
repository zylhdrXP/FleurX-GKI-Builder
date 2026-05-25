# Automated GKI Kernel Builder

A robust, fully automated CI/CD pipeline for building Android GKI (Generic Kernel Image) kernels, powered by GitHub Actions. This builder supports automated patching for KernelSU-Next and SUSFS, AnyKernel3 packaging, Telegram notifications, and dynamic GitHub Release versioning.

## Features

*   **Automated Builds:** Trigger builds manually via GitHub Actions.
*   **Variant Support:** Choose between `Vanilla` (no root) and `KSUN_SUSFS` (KernelSU-Next + SUSFS) during execution.
*   **Auto-Versioning:** Automatically increments minor versions (e.g., v1.0 -> v1.1) for official releases, or uses date stamps for CI testing.
*   **Dynamic Configuration:** Easily switch kernel sources, toolchains, and release targets via a single configuration file without modifying the core build logic.
*   **Telegram Integration:** Sends build status and the final compiled zip directly to a Telegram chat.

## Configuration

All non-sensitive variables are located in `config.sh`. Before running your first build, verify the following parameters:

*   **Project Config:** `KERNEL_NAME`, `KERNEL_SOURCE`, `KERNEL_BRANCH`, `KBUILD_USER`, `KBUILD_HOST`
*   **Toolchain:** `CLANG_URL` (Direct link to the prebuilt clang tarball)
*   **Packaging:** `ANYKERNEL_REPO`, `ANYKERNEL_BRANCH`
*   **Releases:** `RELEASE_REPO` (The repository where official releases will be uploaded, e.g., `username/repo`)

## Secrets Setup

To enable Telegram notifications and GitHub Releases, you must configure the following secrets in your repository settings (**Settings > Secrets and variables > Actions**):

*   `TG_BOT_TOKEN`: Your Telegram Bot Token (obtained from @BotFather).
*   `TG_CHAT_ID`: The ID of the Telegram chat or channel where notifications should be sent.
*   `GH_TOKEN`: A Personal Access Token (PAT) required to upload files to the `RELEASE_REPO`.

### How to Generate a GitHub Token
If you are releasing to a different repository, the default GitHub Actions token will not have permission. You must generate a custom Personal Access Token:
1. Go to your GitHub Profile Settings -> **Developer settings** -> **Personal access tokens** -> **Tokens (classic)**.
2. Click **Generate new token (classic)**.
3. Give it a descriptive note (e.g., "GKI Builder Release").
4. Under **Scopes**, check the box for `repo` (Full control of private repositories).
5. Generate the token, copy it, and add it as a new repository secret named `GH_TOKEN` in your builder repository.

## How to Build

1. Navigate to the **Actions** tab in your GitHub repository.
2. Select the **Build GKI Kernel** workflow from the left sidebar.
3. Click the **Run workflow** dropdown on the right.
4. Select your desired parameters:
    *   **Kernel Variant:** `Vanilla` or `KSUN_SUSFS`
    *   **Build Type:** `CI` (Testing, no GitHub release) or `Release` (Auto-versioned and published to GitHub Releases)
5. Click **Run workflow**.

## Local Build (Optional)

If you prefer to run the script locally on a Linux machine with the necessary dependencies installed (`build-essential`, `clang`, etc.), simply execute:

```bash
chmod +x build.sh
./build.sh <VARIANT> <RELEASE_TYPE>
# Example: ./build.sh KSUN_SUSFS CI
```
