# Robust multi-threaded .NET HttpListener Static HTTP Server for Windows
$port = 8000
$basePath = "C:\Users\aqbr5\.gemini\antigravity\scratch\ultimate-birthday-microsite"

$listener = New-Object System.Net.HttpListener
# Bind to localhost and 127.0.0.1 (does not require admin privileges on Windows)
$listener.Prefixes.Add("http://127.0.0.1:8000/")
$listener.Prefixes.Add("http://localhost:8000/")

try {
    $listener.Start()
    Write-Host "Multi-threaded .NET HttpListener started successfully!"
    Write-Host "Local URL: http://localhost:8000/"
    Write-Host "Local URL: http://127.0.0.1:8000/"
    Write-Host "Listening for requests..."
} catch {
    Write-Error "Failed to start HttpListener: $_"
    exit 1
}

# Keep handling requests
while ($listener.IsListening) {
    try {
        # Blocks until a complete HTTP request is received by the kernel
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $urlPath = $request.Url.LocalPath
        if ($urlPath -eq "/") {
            $urlPath = "/index.html"
        }
        
        # Resolve file path safely
        $filePath = [System.IO.Path]::Combine($basePath, $urlPath.TrimStart('/'))
        
        if (Test-Path $filePath -PathType Leaf) {
            $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
            
            # Match mime types
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
            
            $response.ContentType = $contentType
            $response.ContentLength64 = $fileBytes.Length
            # Allow Cross-Origin Requests if needed by tunnel
            $response.AddHeader("Access-Control-Allow-Origin", "*")
            $response.OutputStream.Write($fileBytes, 0, $fileBytes.Length)
        } else {
            $response.StatusCode = 404
            $response.ContentType = "text/plain"
            $responseBuffer = [System.Text.Encoding]::UTF8.GetBytes("404 File Not Found")
            $response.ContentLength64 = $responseBuffer.Length
            $response.OutputStream.Write($responseBuffer, 0, $responseBuffer.Length)
        }
        $response.Close()
    } catch {
        Write-Host "Error handling request: $_"
    }
}
