defmodule JellyfishWeb.Component.FileComponentTest do
  use JellyfishWeb.ConnCase
  use JellyfishWeb.ComponentCase

  alias JellyfishWeb.WS

  alias Jellyfish.ServerMessage.{
    Authenticated,
    Track,
    TrackAdded,
    TrackRemoved
  }

  @file_component_directory "file_component_sources"
  @fixtures_directory "test/fixtures"
  @video_source "video.h264"
  @video_source_short "video_short.h264"
  @audio_source "audio.ogg"

  @ws_url "ws://127.0.0.1:4002/socket/server/websocket"
  @auth_response %Authenticated{}

  setup_all _tags do
    media_sources_directory =
      Application.fetch_env!(:jellyfish, :media_files_path)
      |> Path.join(@file_component_directory)
      |> Path.expand()

    File.mkdir_p!(media_sources_directory)

    File.cp_r!(@fixtures_directory, media_sources_directory)

    on_exit(fn -> :file.del_dir_r(media_sources_directory) end)

    {:ok, %{media_sources_directory: media_sources_directory}}
  end

  describe "Create File Component" do
    test "renders component with video as source", %{conn: conn, room_id: room_id} do
      start_notifier()

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: @video_source}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "file",
                 "properties" => %{
                   "filePath" => @video_source
                 }
               }
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "file")

      assert_receive %TrackAdded{
        room_id: ^room_id,
        endpoint_info: {:component_id, ^id},
        track: %Track{type: :TRACK_TYPE_VIDEO, metadata: "null"} = track
      }

      conn = delete(conn, ~p"/room/#{room_id}/component/#{id}")
      assert response(conn, :no_content)

      assert_receive %TrackRemoved{
        room_id: ^room_id,
        endpoint_info: {:component_id, ^id},
        track: ^track
      }
    end

    test "renders component with video as source with framerate set", %{
      conn: conn,
      room_id: room_id
    } do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: @video_source, framerate: 60}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "file",
                 "properties" => %{
                   "filePath" => @video_source,
                   "framerate" => 60
                 }
               }
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "file")
    end

    test "renders component with audio as source", %{conn: conn, room_id: room_id} do
      start_notifier()

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: @audio_source}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "file",
                 "properties" => %{
                   "filePath" => @audio_source
                 }
               }
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "file")

      assert_receive %TrackAdded{
        room_id: ^room_id,
        endpoint_info: {:component_id, ^id},
        track:
          %{
            type: :TRACK_TYPE_AUDIO,
            metadata: "null"
          } = track
      }

      conn = delete(conn, ~p"/room/#{room_id}/component/#{id}")
      assert response(conn, :no_content)

      assert_receive %TrackRemoved{
        room_id: ^room_id,
        endpoint_info: {:component_id, ^id},
        track: ^track
      }
    end

    test "file component removed after stream finishes", %{conn: conn, room_id: room_id} do
      start_notifier()

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: @video_source_short}
        )

      assert %{
               "data" => %{"id" => id, "properties" => %{"filePath" => @video_source_short}}
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "file")

      assert_receive %TrackAdded{}

      assert_receive %TrackRemoved{}, 1500

      conn = get(conn, ~p"/room/#{room_id}")
      response = json_response(conn, :ok)
      assert Enum.empty?(response["data"]["components"])
    end

    test "file in subdirectory", %{
      conn: conn,
      room_id: room_id,
      media_sources_directory: media_sources_directory
    } do
      subdir_name = "subdirectory"
      video_relative_path = Path.join(subdir_name, @video_source)
      [media_sources_directory, subdir_name] |> Path.join() |> File.mkdir_p!()
      media_sources_directory |> Path.join(video_relative_path) |> File.touch!()

      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: video_relative_path}
        )

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "file",
                 "properties" => %{
                   "filePath" => ^video_relative_path
                 }
               }
             } = model_response(conn, :created, "ComponentDetailsResponse")

      assert_component_created(conn, room_id, id, "file")
    end

    test "renders error when required options are missing", %{
      conn: conn,
      room_id: room_id
    } do
      conn = post(conn, ~p"/room/#{room_id}/component", type: "file")

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Required field \"filePath\" missing"
    end

    test "renders error when filePath is invalid", %{
      conn: conn,
      room_id: room_id
    } do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: "some/fake/path.h264"}
        )

      assert model_response(conn, :not_found, "Error")["errors"] ==
               "File not found"
    end

    test "renders error when framerate is invalid (not a number)", %{
      conn: conn,
      room_id: room_id
    } do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: @video_source, framerate: "abc"}
        )

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Invalid framerate passed"
    end

    test "renders error when framerate is invalid (negative integer)", %{
      conn: conn,
      room_id: room_id
    } do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: @video_source, framerate: -123}
        )

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Invalid framerate passed"
    end

    test "renders error when framerate is set for audio", %{
      conn: conn,
      room_id: room_id
    } do
      conn =
        post(conn, ~p"/room/#{room_id}/component",
          type: "file",
          options: %{filePath: @audio_source, framerate: 30}
        )

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Attempted to set framerate for audio component which is not supported."
    end

    test "renders error when file path is outside of media files directory", %{
      conn: conn,
      room_id: room_id
    } do
      filepath = "../restricted_audio.opus"

      conn =
        post(conn, ~p"/room/#{room_id}/component", type: "file", options: %{filePath: filepath})

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Invalid file path"
    end

    test "renders error when file has no extension", %{
      conn: conn,
      room_id: room_id,
      media_sources_directory: media_sources_directory
    } do
      filepath = "h264"
      media_sources_directory |> Path.join(filepath) |> File.touch!()

      conn =
        post(conn, ~p"/room/#{room_id}/component", type: "file", options: %{filePath: filepath})

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Unsupported file type"
    end

    test "renders error when file has invalid extension", %{
      conn: conn,
      room_id: room_id,
      media_sources_directory: media_sources_directory
    } do
      filepath = "sounds.aac"
      media_sources_directory |> Path.join(filepath) |> File.touch!()

      conn =
        post(conn, ~p"/room/#{room_id}/component", type: "file", options: %{filePath: filepath})

      assert model_response(conn, :bad_request, "Error")["errors"] ==
               "Unsupported file type"
    end
  end

  defp start_notifier() do
    token = Application.fetch_env!(:jellyfish, :server_api_token)

    {:ok, ws} = WS.start_link(@ws_url, :server)
    WS.send_auth_request(ws, token)
    assert_receive @auth_response, 1000
    WS.subscribe(ws, :server_notification)

    ws
  end
end
