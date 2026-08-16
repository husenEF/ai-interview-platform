# frozen_string_literal: true

# Mount WebSocket middlewares at the Rack level.
# These must be inserted BEFORE TenantResolverMiddleware so they can handle
# WebSocket upgrades before Rails routing runs.
#
# Path mapping:
#   /ws/sessions/:id/audio    → AudioWebSocketMiddleware  (binary audio proxy)
#   /ws/sessions/:id/coverage → CoverageWebSocketMiddleware (assessor live monitor)

# The filenames spell "web_socket", not "websocket", because Zeitwerk derives
# the constant from the path: audio_websocket_middleware.rb would have to
# define AudioWebsocketMiddleware, and these classes are named
# AudioWebSocketMiddleware. Nothing noticed for as long as eager loading was
# off — which is every environment except production and CI, where the boot
# raised NameError before the first request.
require_relative '../../app/channels/audio_web_socket_middleware'
require_relative '../../app/channels/coverage_web_socket_middleware'

Rails.application.config.middleware.insert_before TenantResolverMiddleware, AudioWebSocketMiddleware
Rails.application.config.middleware.insert_before TenantResolverMiddleware, CoverageWebSocketMiddleware
