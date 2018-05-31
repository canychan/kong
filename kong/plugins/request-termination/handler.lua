local BasePlugin = require "kong.plugins.base_plugin"
local responses = require "kong.tools.responses"
local meta = require "kong.meta"


local coroutine = coroutine
local ngx = ngx


local SERVER_HEADER = meta._NAME .. "/" .. meta._VERSION


local RequestTerminationHandler = BasePlugin:extend()


RequestTerminationHandler.PRIORITY = 2
RequestTerminationHandler.VERSION = "0.1.0"


local function flush(ctx)
  ctx = ctx or ngx.ctx

  local response = ctx.delayed_response

  local status       = response.status_code
  local content      = response.content
  local content_type = response.content_tyoe
  if not content_type then
    content_type = "application/json; charset=utf-8";
  end

  ngx.status = status
  ngx.header["Server"] = SERVER_HEADER
  ngx.header["Content-Type"] = content_type
  ngx.header["Content-Length"] = #content
  ngx.print(content)

  return ngx.exit(status)
end


function RequestTerminationHandler:new()
  RequestTerminationHandler.super.new(self, "request-termination")
end


function RequestTerminationHandler:access(conf)
  RequestTerminationHandler.super.access(self)

  local status = conf.status_code
  local body   = conf.body

  if body then
    local ctx = ngx.ctx
    if ctx.delay_response and not ctx.delayed_response then
      ctx.delayed_response = {
        status_code               = status,
        content                   = body,
        content_type              = conf.content_type,
      }

      ctx.delayed_response_callback = flush

      coroutine.yield()
      return
    end
  end

  return responses.send(status, conf.message)
end


return RequestTerminationHandler
