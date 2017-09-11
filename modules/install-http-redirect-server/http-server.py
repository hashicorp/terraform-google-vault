# This simple Python HTTP server redirects all inbound HTTP requests on port 8000 to an HTTPS endpoint for the Vault
# health check. We set this up because, per https://github.com/terraform-providers/terraform-provider-google/issues/18,
# GCE only supports associating HTTP Health Checks with Target Pools (not HTTPS or TCP Health Checks).

import SimpleHTTPServer
import SocketServer

class myHandler(SimpleHTTPServer.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(301)
        self.send_header('Location', 'https://127.0.0.1:8200/v1/sys/health?standbyok=true')
        self.end_headers()

port = 8000
handler = SocketServer.TCPServer(("", port), myHandler)
print "Listening for HTTP requests on port", port
handler.serve_forever()