# Zero-dependency TCP-socket based Static HTTP Server for Windows
$port = 8000
$basePath = "C:\Users\aqbr5\.gemini\antigravity\scratch\ultimate-birthday-microsite"

# Bind to 0.0.0.0 (listen on all local network interfaces)
$ip = [System.Net.IPAddress]::Any
$server = New-Object System.Net.Sockets.TcpListener($ip, $port)

# Get the Wi-Fi/Ethernet IPv4 address
$localIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress

try {
    $server.Start()
    Write-Host "Server successfully started on all interfaces!"
    Write-Host "Local URL: http://localhost:${port}/"
    if ($localIp) {
        Write-Host "Mobile / Local Network URL: http://${localIp}:${port}/"
    }
    Write-Host "Press Ctrl+C in terminal or kill background task to stop."
} catch {
    Write-Error "Failed to start TCP listener: $_"
    exit 1
}

# Keep listening until stopped
while ($true) {
    try {
        $client = $server.AcceptTcpClient()
        $stream = $client.GetStream()
        
        # Read HTTP request header
        $buffer = New-Object Byte[] 4096
        $readBytes = $stream.Read($buffer, 0, $buffer.Length)
        if ($readBytes -le 0) {
            $client.Close()
            continue
        }
        $requestStr = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $readBytes)
        
        # Simple HTTP Parser
        $firstLine = ($requestStr -split "`r`n")[0]
        $parts = $firstLine -split " "
        if ($parts.Length -lt 2) {
            $client.Close()
            continue
        }
        
        $urlPath = $parts[1]
        # Remove query parameters if present
        $urlPath = ($urlPath -split "\?")[0]
        if ($urlPath -eq "/") {
            $urlPath = "/index.html"
        }
        
        # Resolve local file path
        $filePath = [System.IO.Path]::Combine($basePath, $urlPath.TrimStart('/'))
        
        if (Test-Path $filePath -PathType Leaf) {
            $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
            
            # Simple content type mapping
            $contentType = "application/octet-stream"
            if ($urlPath.EndsWith(".html")) {
                $contentType = "text/html; charset=utf-8"
            } elseif ($urlPath.EndsWith(".css")) {
                $contentType = "text/css"
            } elseif ($urlPath.EndsWith(".js")) {
                $contentType = "application/javascript"
            } elseif ($urlPath.EndsWith(".png")) {
                $contentType = "image/png"
            } elseif ($urlPath.EndsWith(".jpg") -or $urlPath.EndsWith(".jpeg")) {
                $contentType = "image/jpeg"
            } elseif ($urlPath.EndsWith(".mp3")) {
                $contentType = "audio/mpeg"
            } elseif ($urlPath.EndsWith(".gif")) {
                $contentType = "image/gif"
            }
            
            # HTTP Response Header
            $headers = "HTTP/1.1 200 OK`r`n" +
                       "Content-Type: ${contentType}`r`n" +
                       "Content-Length: $($fileBytes.Length)`r`n" +
                       "Connection: close`r`n`r`n"
            $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($headers)
            
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $stream.Write($fileBytes, 0, $fileBytes.Length)
        } else {
            # HTTP 404 Response
            $headers = "HTTP/1.1 404 Not Found`r`n" +
                       "Content-Type: text/plain`r`n" +
                       "Content-Length: 18`r`n" +
                       "Connection: close`r`n`r`n" +
                       "404 File Not Found"
            $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($headers)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
        }
        $stream.Close()
        $client.Close()
    } catch {
        if ($client) { $client.Close() }
    }
}
