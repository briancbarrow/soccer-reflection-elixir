defmodule SoccerReflectionCoachWeb.CoachLive do
  use SoccerReflectionCoachWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, messages: [], current_message: "", is_loading: false)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    handle_send_message(socket, message)
  end

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, current_message: message)}
  end

  def handle_send_message(socket, message) do
    messages = socket.assigns.messages ++ [%{role: :user, content: message}]

    ai_response = "This is a placeholder response from the AI. The player said: #{message}"

    updated_messages = messages ++ [%{role: :ai_coach, content: ai_response}]

    {:noreply, assign(socket, messages: updated_messages, current_message: "")}
  end
end
