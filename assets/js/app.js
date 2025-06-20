// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

let Hooks = {};

Hooks.ScrollToBottom = {
  mounted() {
    this.scrollToBottom();
  },
  updated() {
    this.scrollToBottom();
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight;
  },
};

Hooks.SubmitOnEnter = {
  mounted() {
    this.el.addEventListener("keydown", (e) => {
      // Submit on Cmd+Enter or Ctrl+Enter
      if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        this.submitForm();
      }

      // Optional: Submit on plain Enter (without Shift for new line)
      // Uncomment this if you want plain Enter to submit
      // if (e.key === "Enter" && !e.shiftKey) {
      //   e.preventDefault()
      //   this.submitForm()
      // }
    });
  },

  submitForm() {
    // Find the closest form and submit it
    const form = this.el.closest("form");
    if (form) {
      // Only submit if there's content
      if (this.el.value.trim() !== "") {
        form.dispatchEvent(
          new Event("submit", { bubbles: true, cancelable: true })
        );
      }
    }
  },
};

Hooks.VoiceRecorder = {
  mounted() {
    this.recording = false;
    this.mediaRecorder = null;
    this.audioChunks = [];

    this.el.addEventListener("click", () => {
      if (this.recording) {
        this.stopRecording();
      } else {
        this.startRecording();
      }
    });
  },

  async startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      this.mediaRecorder = new MediaRecorder(stream, {
        mimeType: "audio/webm;codecs=opus",
      });
      this.audioChunks = [];

      this.mediaRecorder.addEventListener("dataavailable", (event) => {
        if (event.data.size > 0) {
          this.audioChunks.push(event.data);
        }
      });

      this.mediaRecorder.addEventListener("stop", () => {
        this.processAudio();
      });

      this.mediaRecorder.start();
      this.recording = true;

      // Push event to LiveView to update UI state
      this.pushEvent("recording_started", {});
    } catch (err) {
      console.error("Error accessing microphone:", err);
      alert("Could not access your microphone. Please check permissions.");
    }
  },

  stopRecording() {
    if (this.mediaRecorder && this.recording) {
      this.mediaRecorder.stop();
      this.mediaRecorder.stream.getTracks().forEach((track) => track.stop());
      this.recording = false;

      // Push event to LiveView to update UI state
      this.pushEvent("recording_stopped", {});
    }
  },

  async processAudio() {
    const audioBlob = new Blob(this.audioChunks, {
      type: "audio/webm;codecs=opus",
    });

    this.lastRecordedAudio = audioBlob;

    // Add a debug download (optional - remove in production)
    // this.downloadAudio();

    // Show loading state
    this.pushEvent("transcription_loading", {});

    try {
      // Create FormData to send to server
      const formData = new FormData();
      formData.append("audio", audioBlob, "recording.webm");

      // Send to server for Deepgram processing
      const response = await fetch("/api/transcribe", {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        throw new Error("Transcription failed");
      }

      const result = await response.json();

      // Update the textarea with transcription
      this.pushEvent("transcription_result", { text: result.text });
    } catch (err) {
      console.error("Error transcribing audio:", err);
      this.pushEvent("transcription_error", { error: err.message });
    }
  },

  //   downloadAudio() {
  //     if (!this.lastRecordedAudio) {
  //       console.warn("No audio recording available to download");
  //       return;
  //     }

  //     // Create a URL for the blob
  //     const audioUrl = URL.createObjectURL(this.lastRecordedAudio);

  //     // Create a timestamp for the filename
  //     const timestamp = new Date().toISOString().replace(/[:.]/g, "-");

  //     // Create a download link
  //     const downloadLink = document.createElement("a");
  //     downloadLink.href = audioUrl;
  //     downloadLink.download = `recording-${timestamp}.webm`;

  //     // Append to the document, click it, and remove it
  //     document.body.appendChild(downloadLink);
  //     downloadLink.click();
  //     document.body.removeChild(downloadLink);

  //     // Clean up the URL object
  //     setTimeout(() => URL.revokeObjectURL(audioUrl), 100);
  //   },
};

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true
      );

      window.liveReloader = reloader;
    }
  );
}
