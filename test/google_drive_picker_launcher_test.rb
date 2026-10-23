# frozen_string_literal: true

require "json"
require "open3"
require "tmpdir"
require "test_helper"

class GoogleDrivePickerLauncherTest < Minitest::Test
  def test_picker_opens_once_after_the_uploader_that_started_connect
    skip "node is not available" unless node_available?
    skip "recording_studio_attachable is not bundled" unless attachable_launchers_path

    stdout, stderr, status = run_node_launcher_harness
    assert status.success?, "#{stderr}\n#{stdout}"
    result = JSON.parse(stdout)
    assert_equal true, result.fetch("continueWithoutPriorAuth")
    assert_equal true, result.fetch("pickerOpensOnceAfterAuth")
    assert_equal true, result.fetch("secondRelaunchOpensNoPicker")
  end

  private

  def launcher_path
    File.expand_path("../app/javascript/recording_studio_google_drive/google_drive_picker_launcher.js", __dir__)
  end

  def attachable_launchers_path
    spec = Gem.loaded_specs["recording_studio_attachable"]
    return unless spec

    File.join(spec.full_gem_path, "app/javascript/controllers/recording_studio_attachable/provider_launchers.js")
  end

  def node_available?
    system("node", "-v", out: File::NULL, err: File::NULL)
  end

  def run_node_launcher_harness
    Dir.mktmpdir("google-drive-launcher-test") do |dir|
      File.write(
        File.join(dir, "provider_launchers.js"),
        browser_globals_prefix + File.read(attachable_launchers_path)
      )
      File.write(
        File.join(dir, "google_drive_picker_launcher.js"),
        browser_globals_prefix + File.read(launcher_path).sub(
          'from "recording_studio_attachable/provider_launchers"',
          'from "./provider_launchers.js"'
        )
      )
      File.write(File.join(dir, "harness.mjs"), node_harness_source)
      Open3.capture3("node", File.join(dir, "harness.mjs"))
    end
  end

  def browser_globals_prefix
    "const window = globalThis;\n"
  end

  def node_harness_source
    <<~JS
      const pickerCalls = []
      const authCalls = []
      const continueLabels = []
      let documentClicks = []
      globalThis.window = globalThis
      globalThis.window.location = { origin: "https://dummy.test" }

      globalThis.document = {
        querySelector(selector) {
          if (String(selector).includes("apis.google.com")) {
            return { dataset: { loaded: "true" }, readyState: "complete" }
          }
          return null
        },
        head: {
          appendChild(node) {
            node.addEventListener?.("load")
            node._load?.()
          }
        },
        body: { appendChild() {}, removeChild() {} },
        createElement(tag) {
          const node = {
            tagName: tag,
            type: "",
            dataset: {},
            children: [],
            addEventListener(type, fn) {
              if (type === "click") documentClicks.push(fn)
              if (type === "load") node._load = fn
            },
            appendChild(child) {
              node.children.push(child)
              if (child?.type === "button" && child.textContent) continueLabels.push(child.textContent)
              return child
            },
            replaceChildren() { node.children = [] },
            submit() {},
            remove() {}
          }
          return node
        }
      }

      globalThis.window.gapi = { load(_name, opts) { opts.callback() } }
      globalThis.window.google = {
        picker: {
          DocsView: class { setIncludeFolders() { return this } setSelectFolderEnabled() { return this } setMode() { return this } },
          PickerBuilder: class {
            setAppId() { return this }
            setDeveloperKey() { return this }
            setOAuthToken() { return this }
            setOrigin() { return this }
            enableFeature() { return this }
            addView() { return this }
            setCallback(cb) { this._cb = cb; return this }
            build() {
              const cb = this._cb
              return {
                setVisible() { pickerCalls.push(true); cb?.({ action: "cancel" }) }
              }
            }
          },
          DocsViewMode: { LIST: "LIST" },
          Feature: { MULTISELECT_ENABLED: "MULTISELECT_ENABLED" },
          Action: { PICKED: "picked", CANCEL: "cancel" }
        }
      }

      await import("./google_drive_picker_launcher.js")
      const launcher = globalThis.RecordingStudioAttachableUploadProviders.get("google_drive")

      const connected = {
        needs_auth: false,
        access_token: "token",
        api_key: "k",
        app_id: "1",
        connect: { url: "/oauth", method: "post", fields: { authenticity_token: "from-connect" } }
      }
      const needsAuth = {
        needs_auth: true,
        connect: { url: "/oauth", method: "post", fields: { authenticity_token: "from-connect" } }
      }

      function controller(bootstrap) {
        let current = bootstrap
        return {
          element: { querySelector() { return null }, appendChild() {} },
          fetchProviderBootstrap() { return Promise.resolve(current) },
          handleProviderBootstrapError() {},
          clearProviderStatus() {},
          setProviderStatus() {},
          addProviderSelections() {},
          openPopup() { authCalls.push(true); return {} },
          useBootstrap(next) { current = next }
        }
      }

      const bystander = controller(connected)
      await launcher.launch({ controller: bystander, providerKey: "google_drive", bootstrapUrl: "/other", button: {}, gesture: false })
      const continueWithoutPriorAuth = pickerCalls.length === 0 && continueLabels.includes("Open Google Drive picker")

      const opener = controller(needsAuth)
      await launcher.launch({ controller: opener, providerKey: "google_drive", bootstrapUrl: "/drive", button: {}, gesture: true })
      opener.useBootstrap(connected)
      launcher.forget("/drive")
      await launcher.launch({ controller: opener, providerKey: "google_drive", bootstrapUrl: "/drive", button: {}, gesture: false })
      const pickerOpensOnceAfterAuth = pickerCalls.length === 1

      await launcher.launch({ controller: opener, providerKey: "google_drive", bootstrapUrl: "/drive", button: {}, gesture: false })
      const secondRelaunchOpensNoPicker = pickerCalls.length === 1

      console.log(JSON.stringify({
        continueWithoutPriorAuth,
        pickerOpensOnceAfterAuth,
        secondRelaunchOpensNoPicker
      }))
    JS
  end
end
