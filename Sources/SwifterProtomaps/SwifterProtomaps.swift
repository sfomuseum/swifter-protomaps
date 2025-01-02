import Swifter
import Foundation
import Logging
import System

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
    
    public init(root: URL) {
                Root = root
                AllowOrigins = ""
                AllowHeaders = ""
                StripPrefix = ""
    }
}

/// ServeProtomapsTiles will serve HTTP range requests for zero or more Protomaps tile databases in a directory.
@available(iOS 13.4, *)
@available(macOS 11.0, *)
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
        
        let uri = opts.Root.appendingPathComponent(rel_path)
        let path = uri.absoluteString
        
        // https://developer.apple.com/documentation/foundation/filehandle
        
        // var file: FileHandle
        var file: FileDescriptor
        
        do {
            // file = try FileHandle(forReadingFrom: uri)
            let fp = FilePath(uri.absoluteString)
            file = try FileDescriptor.open(fp, .readOnly)
        } catch {
            opts.Logger?.error("Failed to open path (\(path)) for reading \(error)")
            return .raw(404, "Not found", rsp_headers, {_ in })
        }
        
        defer {
            do {
                try file.close()
            } catch (let error) {
                opts.Logger?.warning("Failed to close \(path), \(error)")
            }
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
        
        guard let stop = Int(positions[1]) else {
            rsp_headers["X-Error"] = "Invalid stopping range"
            return .raw(400, "Bad Request", rsp_headers, {_ in })
        }
        
        if start > stop {
            rsp_headers["X-Error"] = "Invalid range: Start value greater than stop value"
            return .raw(400, "Bad Request", rsp_headers, {_ in })
        }
        
        let next = stop + 1
        
        // let body: Data!
        // file.seek(toFileOffset: start)
        
        do {
            try file.seek(offset: Int64(start), from: FileDescriptor.SeekOrigin.start)
        } catch {
            opts.Logger?.error("Failed to seek to \(start) for \(path), \(error)")
            rsp_headers["X-Error"] = "Failed to read from Protomaps tile"
            return .raw(500, "Internal Server Error", rsp_headers, {_ in })
        }
        
        guard let body = readData(from: file.rawValue, length: next) else {
            opts.Logger?.error("Failed to read to \(next) for \(path)")
            rsp_headers["X-Error"] = "Failed to read from Protomaps tile"
            return .raw(500, "Internal Server Error", rsp_headers, {_ in })
        }
            
        /*
        do {
            // body = try file.read(upToCount: next)
            body = try file.read(upToCount: next)
        } catch (let error){
            opts.Logger?.error("Failed to read to \(next) for \(path), \(error)")
            rsp_headers["X-Error"] = "Failed to read from Protomaps tile"
            return .raw(500, "Internal Server Error", rsp_headers, {_ in })
        }
        */
        
        // https://httpwg.org/specs/rfc7233.html#header.accept-ranges
                
        let filesize = "*"
        
        /*
        do {
            let size = try file.seekToEnd()
            filesize = String(size)
        } catch (let error){
            opts.Logger?.warning("Failed to determine filesize for \(path), \(error)")
        }
        */
        
        let length = UInt64(next) - start
        
        let content_length = String(length)
        let content_range = "bytes \(start)-\(next)/\(filesize)"
        
        rsp_headers["Access-Control-Allow-Origin"] = opts.AllowOrigins
        rsp_headers["Access-Control-Allow-Headers"] = opts.AllowHeaders
        rsp_headers["Content-Length"] = content_length
        rsp_headers["Content-Range"] = content_range
        rsp_headers["Accept-Ranges"] = "bytes"
        
        return .raw(206, "Partial Content", rsp_headers, { writer in
            
            do {
                try writer.write(body)
            } catch (let error) {
                opts.Logger?.error("Failed to write body, \(error)")
            }
        })
    }
}

internal func readData(from fileDescriptor: Int32, length: Int) -> Data? {
    // Create a Data buffer of the desired length
    var data = Data(count: length)
    
    // Read the data into the Data buffer
    let bytesRead = data.withUnsafeMutableBytes { buffer -> Int in
        guard let baseAddress = buffer.baseAddress else { return -1 }
        return read(fileDescriptor, baseAddress, length)
    }
    
    // Handle errors or end-of-file
    guard bytesRead > 0 else {
        return nil // Return nil if no bytes were read
    }
    
    // Resize the Data object to the actual number of bytes read
    data.removeSubrange(bytesRead..<data.count)
    return data
}
