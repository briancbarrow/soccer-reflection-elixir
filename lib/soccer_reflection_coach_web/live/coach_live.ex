defmodule SoccerReflectionCoachWeb.CoachLive do
  alias SoccerReflectionCoach.Anthropic
  alias SoccerReflectionCoach.Message
  use SoccerReflectionCoachWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       messages: [],
       current_message: "",
       is_loading: false,
       error: "",
       recording: false,
       transcribing: false
     )}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    user_message = %Message{
      role: :user,
      content: message,
      created_at: DateTime.utc_now()
    }

    updated_messages = [user_message | socket.assigns.messages]

    send(self(), {:get_ai_response, updated_messages})

    {:noreply,
     socket
     |> assign(:messages, updated_messages)
     |> assign(:current_message, "")
     |> assign(:is_loading, true)}
  end

  @impl true
  def handle_event("start_conversation", _params, socket) do
    first_message = %Message{
      role: :user,
      content: "I am ready to talk about the game today",
      created_at: DateTime.utc_now()
    }

    send(self(), {:get_ai_response, [first_message]})

    {:noreply,
     socket
     |> assign(:messages, [])
     |> assign(:current_message, "")
     |> assign(:is_loading, true)}
  end

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, current_message: message)}
  end

  @impl true
  def handle_event("recording_started", _parms, socket) do
    {:noreply, assign(socket, recording: true)}
  end

  @impl true
  def handle_event("recording_stopped", _params, socket) do
    {:noreply, assign(socket, recording: false, transcribing: true)}
  end

  @impl true
  def handle_event("transcription_loading", _params, socket) do
    {:noreply, assign(socket, transcribing: true)}
  end

  @impl true
  def handle_event("transcription_result", %{"text" => text}, socket) do
    IO.inspect(text, label: "TRANS RESULTS")
    {:noreply, assign(socket, current_message: text, transcribing: false)}
  end

  @impl true
  def handle_event("transcription_error", _params, socket) do
    {:noreply, assign(socket, transcribing: false)}
  end

  @impl true
  def handle_info({:get_ai_response, messages}, socket) do
    ai_response = Anthropic.call_messages_api(messages)

    case ai_response do
      {:ok, response_message} ->
        {:noreply,
         socket
         |> assign(:messages, [response_message | socket.assigns.messages])
         |> assign(:is_loading, false)}

      {:error, error_message} ->
        {:noreply,
         socket
         |> assign(:error, error_message)
         |> assign(:is_loading, false)}
    end
  end

  defp get_placeholder(recording, transcribing, message_length) do
    cond do
      recording -> "Recording... Speak clearly"
      transcribing -> "Transcribing your message..."
      message_length == 0 -> "Click the button above to start"
      true -> "Type your reflection here..."
    end
  end
end
