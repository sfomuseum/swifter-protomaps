import Swifter
import Foundation
import Logging

/// ServeProtomapsOptions defines runtime options for serving Protomaps tiles
public struct ServeProtomapsOptions {
    /// Root is the root directory to serve Protomaps tiles from
    public var Root: URL
    /// AllowOrigin is a string containing zero or more allowed origins for CORs requests and responses.
    public var AllowOrigin: String
    /// AllowOrigin is a string containing zero or more allowed headers for CORs requests and responses.
    public var AllowHeaders: String
    /// Logger is an option swift-logging instance for recording errors and warning.
    public var Logger: Logger?
}

@available(macOS 10.15.4, *)
/// ServeProtomapsTiles will serve HTTP range requests for zero or more Protomaps tile databases in a directory.
public func ServeProtomapsTiles(_ opts: ServeProtomapsOptions) -> ((HttpRequest) -> HttpResponse) {
        return { r in
                   
            var rsp_headers = [String: String]()
            
            guard let rel_path = r.params.first else {
                        return .notFound
            }
                            
            let uri = opts.Root.appendingPathComponent(rel_path.value)
            let path = uri.absoluteString
            
            // https://developer.apple.com/documentation/foundation/filehandle
            
            guard let file =  FileHandle(forReadingAtPath: path) else {
                return .notFound
            }
                                    
            guard var range_h = r.headers["range"] else {
                rsp_headers["Access-Control-Allow-Origin"] = opts.AllowOrigin
                rsp_headers["Access-Control-Allow-Headers"] = opts.AllowHeaders
                return .raw(200, "OK", rsp_headers, {_ in })
            }
            
            let pat = "bytes=(\\d+)-(\\d+)"
            
            guard let _ = range_h.range(of: pat, options: .regularExpression) else {
                rsp_headers["X-Error"] = "Invalid or unsupported range request"
                return .raw(400, "Bad Request", rsp_headers, {_ in })
            }
            
            range_h = range_h.replacingOccurrences(of: "bytes=", with: "")
            let positions = range_h.split(separator: "-")
            
            if positions.count != 2 {
                rsp_headers["X-Error"] = "Invalid count for range request"
                return .raw(400, "Bad Request", rsp_headers, {_ in })
            }
            
            guard let start = UInt64(positions[0]) else {
                rsp_headers["X-Error"] = "Invalid starting range"
                return .raw(400, "Bad Request", rsp_headers, {_ in })
            }
            
            guard let stop = Int(positions[1]) else {
                rsp_headers["X-Error"] = "Invalid stopping range"
                return .raw(400, "Bad Request", rsp_headers, {_ in })
            }
            
            if start > stop {
                rsp_headers["X-Error"] = "Invalid range: Start value greater than stop value"
                return .raw(400, "Bad Request", rsp_headers, {_ in })
            }
            
            let next = stop + 1
            
            let body: Data!
        
            file.seek(toFileOffset: start)
            
            do {
                body = try file.read(upToCount: next)
            } catch (let error){
                opts.Logger?.error("Failed to read to \(next) for \(path), \(error)")
                rsp_headers["X-Error"] = "Failed to read from Protomaps tile"
                return .raw(500, "Internal Server Error", rsp_headers, {_ in })
            }

            // https://httpwg.org/specs/rfc7233.html#header.accept-ranges

            var filesize = "*"
            
            do {
                let size = try file.seekToEnd()
                filesize = String(size)
            } catch (let error){
                opts.Logger?.warning("Failed to determine filesize for \(path), \(error)")
            }
            
            let length = UInt64(next) - start
            
            let content_length = String(length)
            let content_range = "bytes \(start)-\(next)/\(filesize)"
                        
            rsp_headers["Access-Control-Allow-Origin"] = opts.AllowOrigin
            rsp_headers["Access-Control-Allow-Headers"] = opts.AllowHeaders
            rsp_headers["Content-Length"] = content_length
            rsp_headers["Content-Range"] = content_range
            rsp_headers["Accept-Ranges"] = "bytes"
                        
            return .raw(206, "Partial Content", rsp_headers, { writer in
                try? writer.write(body)
                try? file.close()
            })
        }
    }
