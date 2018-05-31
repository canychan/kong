local singletons = require "kong.singletons"
local constants = require "kong.constants"


local ngx = ngx
local find = string.find
local format = string.format


local TYPE_PLAIN = "text/plain"
local TYPE_JSON = "application/json"
local TYPE_XML = "application/xml"
local TYPE_HTML = "text/html"


local text_template = "%s"
local json_template = '{"message":"%s"}'
local xml_template = '<?xml version="1.0" encoding="UTF-8"?>\n<error><message>%s</message></error>'
local html_template = '<html><head><title>Kong Error</title></head><body><h1>Kong Error</h1><p>%s.</p></body></html>'


local STATUS_CODES = {
  [400] = "Bad request",
  [404] = "Not found",
  [408] = "Request timeout",
  [411] = "Length required",
  [412] = "Precondition failed",
  [413] = "Payload too large",
  [414] = "URI too long",
  [417] = "Expectation failed",
  [494] = "Request Header Or Cookie Too Large",
  [500] = "An unexpected error occurred",
  [502] = "An invalid response was received from the upstream server",
  [503] = "The upstream server is currently unavailable",
  [504] = "The upstream server is timing out",
}

local CONTENT_LENGTHS = {
  ["255"] = 494
}


local SERVER_HEADER = _KONG._NAME .. "/" .. _KONG._VERSION


local function header_filter()
  local accept_header = ngx.req.get_headers()["Accept"]
  if not accept_header then
    accept_header = singletons.configuration.error_default_type
  end

  local template, content_type
  if find(accept_header, TYPE_HTML, nil, true) then
    template = html_template
    content_type = TYPE_HTML

  elseif find(accept_header, TYPE_JSON, nil, true) then
    template = json_template
    content_type = TYPE_JSON

  elseif find(accept_header, TYPE_XML, nil, true) then
    template = xml_template
    content_type = TYPE_XML

  else
    template = text_template
    content_type = TYPE_PLAIN
  end

  local status = CONTENT_LENGTHS[ngx.header["Content-Length"]]
  local message = STATUS_CODES[status]
  if message then
    ngx.status = status

  else
    status = ngx.status

    message = STATUS_CODES[status]
    if not message then
      message = format("The upstream server responded with %d", status)
    end
  end

  local body = format(template, message)

  if singletons.configuration.enabled_headers[constants.HEADERS.SERVER] then
    ngx.header[constants.HEADERS.SERVER] = SERVER_HEADER
  end

  ngx.header["Content-Type"] = content_type .. "; charset=utf-8"
  ngx.header["Content-Length"] = #body

  return body
end


local _M = {
  STATUS_CODES = STATUS_CODES
}


function _M.header_filter(ctx)
  if not ctx.delayed_response and STATUS_CODES[ngx.status] then
    ctx.KONG_ERROR_MESSAGE = header_filter()
  end
end


function _M.body_filter(ctx)
  if not ctx.KONG_ERROR_MESSAGE then
    return
  end

  ngx.arg[1] = ctx.KONG_ERROR_MESSAGE
  ngx.arg[2] = true
end


return _M
