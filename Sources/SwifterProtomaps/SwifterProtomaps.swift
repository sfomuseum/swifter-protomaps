import Swifter
import Foundation
import Logging
import PMTiles

/// ServeProtomapsOptions defines runtime options for serving Protomaps tiles
public struct ServeProtomapsOptions {
    /// Root is the root directory to serve Protomaps tiles from
    public var Root: URL
    /// AllowOrigin is a string containing zero or more allowed origins for CORs requests and responses.
    public var AllowOrigins: String
    /// AllowOrigin is a string containing zero or more allowed headers for CORs requests and responses.
    public var AllowHeaders: String
    /// Logger is an option swift-logging instance for recording errors and warning.
    public var Logger: Logger?
    /// Optional string to strip from URL paths before processing
    public var StripPrefix: String
    /// Optional value to use System.FileDescriptor rather than Foundation.FileHandle to read data. This is necessary when reading from very large Protomaps databases. This should still be considered experimental as in "It works, but if you find a bug I won't be shocked or anything."
    public var UseFileDescriptor: Bool
    
    public init(root: URL) {
        Root = root
        AllowOrigins = ""
        AllowHeaders = ""
        StripPrefix = ""
        UseFileDescriptor = false
    }
}

/// ServeProtomapsTiles will serve HTTP range requests for zero or more Protomaps tile databases in a directory.
public func ServeProtomapsTiles(_ opts: ServeProtomapsOptions) -> ((HttpRequest) -> HttpResponse) {
    
    return { r in
        
        var rsp_headers = [String: String]()
        
        guard let req_path = r.params.first else {
            return .raw(404, "Not found", rsp_headers, {_ in })
        }
        
        var rel_path = req_path.value
        
        if opts.StripPrefix != "" {
            rel_path = rel_path.replacingOccurrences(of: opts.StripPrefix, with: "")
        }
                
        guard var range_h = r.headers["range"] else {
            rsp_headers["Access-Control-Allow-Origin"] = opts.AllowOrigins
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
        
        guard let stop = UInt64(positions[1]) else {
            rsp_headers["X-Error"] = "Invalid stopping range"
            return .raw(400, "Bad Request", rsp_headers, {_ in })
        }
        
        if start > stop {
            rsp_headers["X-Error"] = "Invalid range: Start value greater than stop value"
            return .raw(400, "Bad Request", rsp_headers, {_ in })
        }
        
        let next = stop + 1
        
        // Fetch data
        
        let db_url = opts.Root.appendingPathComponent(rel_path)
    
        var pmtiles_reader: PMTilesReader
        
        do {
            
            var reader_opts = PMTilesReaderOptions(db_url, use_file_descriptor: opts.UseFileDescriptor)
            reader_opts.Logger = opts.Logger
            
            pmtiles_reader = try PMTilesReader(reader_opts)
            
        } catch {
            opts.Logger?.error("Failed to instantiate PMTiles reader \(error)")
            rsp_headers["X-Error"] = "Failed to instantiate PMTiles reader"
            return .raw(500, "Internal Server Error", rsp_headers, {_ in })
        }
        
        defer {
            if case .failure(let error) = pmtiles_reader.Close() {
                opts.Logger?.error("Failed to close PMTiles reader \(error)")
            }
        }
        
        opts.Logger?.debug("Read data from \(db_url.absoluteString) start: \(start) stop: \(stop)")
        
        let body: Data!
        
        let read_rsp = pmtiles_reader.Read(from: start, to: stop)
        
        switch read_rsp {
        case .success(let data):
            body = data
        case .failure(let error):
            opts.Logger?.error("Failed to read data from PMTiles reader, \(error)")
            rsp_headers["X-Error"] = "Failed to read from Protomaps tile"
            return .raw(500, "Internal Server Error", rsp_headers, {_ in })
        }
        
        // https://httpwg.org/specs/rfc7233.html#header.accept-ranges
        
        var filesize = "*"
        
        let size_rsp = pmtiles_reader.Size()
        
        switch size_rsp {
        case .success(let sz):
            filesize = String(sz)
        case .failure(let error):
            opts.Logger?.warning("Failed to determine size from PMTiles reader \(error)")
        }
        
        let length = UInt64(next) - start
        
        let content_length = String(length)
        let content_range = "bytes \(start)-\(next)/\(filesize)"
        
        rsp_headers["Access-Control-Allow-Origin"] = opts.AllowOrigins
        rsp_headers["Access-Control-Allow-Headers"] = opts.AllowHeaders
        rsp_headers["Content-Length"] = content_length
        rsp_headers["Content-Range"] = content_range
        rsp_headers["Accept-Ranges"] = "bytes"
        
        opts.Logger?.debug("Return 206 \(content_range)")
        
        return .raw(206, "Partial Content", rsp_headers, { writer in
            
            do {
                try writer.write(body)
            } catch (let error) {
                opts.Logger?.error("Failed to write body, \(error)")
            }
        })
    }
}
