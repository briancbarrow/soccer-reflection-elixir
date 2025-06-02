defmodule SoccerReflectionCoachWeb.TranscriptionController do
  use SoccerReflectionCoachWeb, :controller

  @api_url "https://api.deepgram.com/v1/listen?model=nova-2&diarize=true&punctuate=true"

  def create(conn, %{"audio" => audio}) do
    temp_path = audio.path

    case transcribe_audio(temp_path) do
      {:ok, text} ->
        File.rm(temp_path)

        json(conn, %{text: text})

      {:error, reason} ->
        File.rm(temp_path)

        conn
        |> put_status(500)
        |> json(%{error: reason})
    end
  end

  defp transcribe_audio(file_path) do
    headers = [
      {"Authorization", "Token #{System.get_env("DEEPGRAM_KEY")}"},
      {"Content-Type", "audio/webm"}
    ]

    options = [
      recv_timeout: 300_000,
      timeout: 300_000
    ]

    case File.read(file_path) do
      {:ok, audio_data} ->
        response = HTTPoison.post(@api_url, audio_data, headers, options)

        parse_if_successful(response)

      {:error, reason} ->
        IO.puts("Failed to read audio file: #{reason}")
    end
  end

  defp parse_if_successful(response) do
    case response do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        parse_transcription(body)

      {:ok, %HTTPoison.Response{status_code: status_code, body: _body}} ->
        IO.puts("Failed to get transcription ok. Status code: #{status_code}")
        {:error, "Failed to get transcription. Status code: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("HTTP request failed: #{reason}")
        {:error, "Failed to get transcription. Status code: #{reason}"}
    end
  end

  defp parse_transcription(body) do
    decoded_body =
      case is_binary(body) do
        true -> Jason.decode!(body)
        false -> body
      end

    %{
      "results" => %{
        "channels" => [
          %{"alternatives" => [%{"transcript" => transcript} | _rest]}
          | _rest_channels
        ]
      }
    } = decoded_body

    {:ok, transcript}
  end
end
