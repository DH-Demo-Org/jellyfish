defmodule JellyfishWeb.ApiSpec.Peer do
  @moduledoc false

  require OpenApiSpex
  alias OpenApiSpex.Schema

  alias JellyfishWeb.ApiSpec.Peer.WebRTC

  defmodule Type do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PeerType",
      description: "Peer type",
      type: :string,
      example: "webrtc"
    })
  end

  defmodule Options do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PeerOptions",
      description: "Peer-specific options",
      type: :object,
      oneOf: [
        WebRTC
      ]
    })
  end

  defmodule Status do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PeerStatus",
      description: "Informs about the peer status",
      type: :string,
      enum: ["connected", "disconnected"],
      example: "disconnected"
    })
  end

  defmodule Token do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AuthToken",
      description: "Token for authorizing websocket connection",
      type: :string,
      example: "5cdac726-57a3-4ecb-b1d5-72a3d62ec242"
    })
  end

  defmodule WebSocketUrl do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WebsocketURL",
      description: "Websocket URL to which peer has to connect",
      type: :string,
      example: "www.jellyfish.org/socket/peer"
    })
  end

  defmodule PeerMetadata do
    @moduledoc false

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PeerMetadata",
      description: "Custom metadata set by the peer",
      example: %{name: "JellyfishUser"},
      nullable: true
    })
  end

  OpenApiSpex.schema(%{
    title: "Peer",
    description: "Describes peer status",
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Assigned peer id", example: "peer-1"},
      type: Type,
      status: Status,
      tracks: %Schema{
        type: :array,
        items: JellyfishWeb.ApiSpec.Track,
        description: "List of all peer's tracks"
      },
      metadata: PeerMetadata
    },
    required: [:id, :type, :status, :tracks, :metadata]
  })
end
