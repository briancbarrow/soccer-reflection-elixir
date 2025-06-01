defmodule SoccerReflectionCoach.Anthropic do
  @moduledoc """
  Module for interacting with the Anthropic API.
  """
  alias SoccerReflectionCoach.Message

  @api_base "https://api.anthropic.com/v1"

  @doc """
  Sends a message to the Anthropic API and returns the response.
  """
  def call_messages_api(messages) do
    formatted_messages =
      messages
      |> Enum.reverse()
      |> Enum.map(fn %{role: role, content: content} ->
        %{role: role, content: content}
      end)

    system_prompt = """
    You are a thoughtful youth soccer coach who uses Socratic questioning to help players reflect on their performance.
    Ask open-ended questions, encourage self-analysis, and guide players to discover insights about their play rather than just telling them what they did wrong or right.
    Keep responses concise and age-appropriate for youth soccer players. Don't sound too rigid in your responses. Talk to them on their level. In your questions, make sure to
    ask them if there have been any recent trainings their coach has worked with them on, or if there is a specific drill or video they could go through to get better. If they don't know of any,
    encourage them to talk with their coach for advice on where to look for things they can work on. If they mention something about defense, make the questions about the 3 'P's. Pressure, Position, Patience.
    If they mention offense, make the questions about the 3 'S's. Shape, Shielding, Space (moving into space to be passed to and draw defenders).
    Keep the follow up questions minimal per message. Only one for each message.
    """

    system_prompt =
      system_prompt <>
        if length(formatted_messages) >= 6 do
          """
          IMPORTANT: Do NOT ask any follow-up questions in your response. Instead, provide a thoughtful summary of the discussion and end with an encourging conclusion.
          Offer one or two clear and actionable takeaways the player can apply in their upcoming games and practices
          """
        else
          ""
        end

    headers = [
      {"anthropic-version", "2023-06-01"},
      {"x-api-key", System.get_env("ANTHROPIC_API_KEY")},
      {"Content-Type", "application/json"}
    ]

    body =
      %{
        "model" => "claude-3-7-sonnet-20250219",
        "system" => system_prompt,
        "messages" => formatted_messages,
        "max_tokens" => 1024
      }
      |> Jason.encode!()

    options = [
      recv_timeout: 100_000,
      timeout: 100_000
    ]

    url = "#{@api_base}/messages"

    response = HTTPoison.post(url, body, headers, options)

    case response do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        parsed_response = parse_response(body)

        case parsed_response do
          {:ok, response_message} ->
            {:ok, response_message}

          {:error, reason} ->
            {:error, reason}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        IO.puts("Failed to complete message. Status code: #{status_code}")
        {:error, "Failed to complete ERROR BUT OKAY message. Status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("HTTP request failed: #{reason}")
        {:error, "Failed to complete THE message. Reason: #{reason}"}
    end
  end

  defp parse_response(body) do
    case Jason.decode(body) do
      {:ok, decoded_body} ->
        %{
          "content" => [
            %{
              "type" => "text",
              "text" => response_message
            }
          ],
          "role" => role
        } = decoded_body

        {:ok,
         %Message{
           content: response_message,
           role: role,
           created_at: DateTime.utc_now()
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
