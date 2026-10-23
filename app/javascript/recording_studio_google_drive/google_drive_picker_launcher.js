import {
  loadScript,
  createBootstrapCache,
  providerNeedsAuth,
  openProviderAuth,
  csrfToken,
  hideProviderContinueButton,
  showProviderContinueButton,
  registerUploadProviderLauncher
} from "recording_studio_attachable/provider_launchers"

let googlePickerPromise
const sessions = createBootstrapCache()
const ACCESS_TOKEN_REFRESH_SKEW_SECONDS = 30

async function ensureGooglePickerLoaded() {
  if (!googlePickerPromise) {
    googlePickerPromise = loadScript("https://apis.google.com/js/api.js").then(() => new Promise((resolve, reject) => {
      if (!window.gapi) {
        reject(new Error("Google API client did not load."))
        return
      }

      window.gapi.load("picker", {
        callback: resolve,
        onerror: () => reject(new Error("Google Picker failed to load."))
      })
    }))
  }

  return googlePickerPromise
}

function openPicker(bootstrap) {
  return new Promise((resolve, reject) => {
    if (!window.google?.picker) {
      reject(new Error("Google Picker is not available."))
      return
    }

    const docsView = new window.google.picker.DocsView()
      .setIncludeFolders(false)
      .setSelectFolderEnabled(false)
      .setMode(window.google.picker.DocsViewMode.LIST)

    const picker = new window.google.picker.PickerBuilder()
      .setAppId(String(bootstrap.app_id))
      .setDeveloperKey(bootstrap.api_key)
      .setOAuthToken(bootstrap.access_token)
      .setOrigin(window.location.origin)
      .enableFeature(window.google.picker.Feature.MULTISELECT_ENABLED)
      .addView(docsView)
      .setCallback((data) => {
        if (data.action === window.google.picker.Action.PICKED) {
          resolve(
            data.docs
              .filter((doc) => doc?.id)
              .map((doc) => ({ id: doc.id, resource_key: doc.resourceKey }))
          )
          return
        }

        if (data.action === window.google.picker.Action.CANCEL) {
          resolve([])
        }
      })
      .build()

    picker.setVisible(true)
  })
}

function accessTokenNearExpiry(bootstrap) {
  if (!bootstrap?.access_token) return false

  const expiresAt = Number(bootstrap.expires_at)
  if (!Number.isFinite(expiresAt) || expiresAt <= 0) return false

  return expiresAt <= (Date.now() / 1000) + ACCESS_TOKEN_REFRESH_SKEW_SECONDS
}

function driveNeedsAuth(bootstrap) {
  return providerNeedsAuth(bootstrap)
}

function startBootstrap(controller, bootstrapUrl, start) {
  if (typeof start === "function") return start

  return async () => controller.fetchProviderBootstrap(bootstrapUrl)
}

function sessionFor(controller, bootstrapUrl, start) {
  const existing = sessions.get(bootstrapUrl)
  if (existing?.error || accessTokenNearExpiry(existing?.bootstrap)) {
    sessions.forget(bootstrapUrl)
  }

  return sessions.sessionFor(bootstrapUrl, startBootstrap(controller, bootstrapUrl, start))
}

async function applySelections(controller, providerKey, selections) {
  if (selections.length === 0) {
    controller.clearProviderStatus()
    return
  }

  controller.clearProviderStatus()
  controller.addProviderSelections(providerKey, selections)
}

function openPickerNow(controller, providerKey, bootstrap) {
  hideProviderContinueButton(controller)
  controller.setProviderStatus("Opening Google Drive picker…")
  return ensureGooglePickerLoaded()
    .then(() => openPicker(bootstrap))
    .then((selections) => applySelections(controller, providerKey, selections))
}

registerUploadProviderLauncher("google_drive", {
  forget(bootstrapUrl) {
    sessions.forget(bootstrapUrl)
  },

  prefetch({ controller, bootstrapUrl, button, start }) {
    if (!controller || !bootstrapUrl) return Promise.resolve()

    return sessionFor(controller, bootstrapUrl, start).promise.catch((error) => {
      sessions.forget(bootstrapUrl)
      controller.handleProviderBootstrapError?.(error, button, { announce: false })
    })
  },

  async launch({ controller, providerKey, bootstrapUrl, button, gesture = false, start }) {
    hideProviderContinueButton(controller)
    const session = sessionFor(controller, bootstrapUrl, start)
    try {
      await session.promise
    } catch (error) {
      sessions.forget(bootstrapUrl)
      controller.handleProviderBootstrapError?.(error, button)
      throw error
    }

    const bootstrap = session.bootstrap
    csrfToken(controller, bootstrap)

    if (driveNeedsAuth(bootstrap)) {
      if (gesture) openProviderAuth(controller, bootstrap, providerKey)
      return
    }

    if (!gesture) {
      showProviderContinueButton(controller, button, "Open Google Drive picker", () => {
        openPickerNow(controller, providerKey, bootstrap)
      })
      return
    }

    return openPickerNow(controller, providerKey, bootstrap)
  }
})
