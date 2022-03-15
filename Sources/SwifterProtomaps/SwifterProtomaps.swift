import Swifter
import Foundation

@available(macOS 10.15.4, *)
public func ServeTiles(_ root: String) -> ((HttpRequest) -> HttpResponse) {
        return { r in
                        
            guard let rel_path = r.params.first else {
                        return .notFound
            }
                            
            let path = root + rel_path.value
            
            // https://developer.apple.com/documentation/foundation/filehandle
            
            guard let file =  FileHandle(forReadingAtPath: path) else {
                return .notFound
            }
                                    
            guard var range_h = r.headers["range"] else {
                return .raw(200, "OK", ["Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "*"], {_ in })
            }
            
            let pat = "bytes=(\\d+)-(\\d+)"
            
            guard let _ = range_h.range(of: pat, options: .regularExpression) else {
                print("NO MATCH")
                return .raw(400, "Bad Request", ["": ""], {_ in })
            }
            
            range_h = range_h.replacingOccurrences(of: "bytes=", with: "")
            let positions = range_h.split(separator: "-")
            
            if positions.count != 2 {
                print("POSTIONS \(positions)")
                return .raw(400, "Bad Request", ["": ""], {_ in })
            }
            
            guard let start = UInt64(positions[0]) else {
                print("OMG \(positions[0])")
                return .raw(400, "Bad Request", ["": ""], {_ in })
            }
            
            guard let stop = Int(positions[1]) else {
                return .raw(400, "Bad Request", ["": ""], {_ in })
            }
            
            if start > stop {
                return .raw(400, "Bad Request", ["": ""], {_ in })
            }
            
            let next = stop + 1
            
            let body: Data!
        
            file.seek(toFileOffset: start)
            
            do {
                body = try file.read(upToCount: next)
            } catch (let error){
                print("WOMP WOMP \(error)")
                return .raw(500, "Internal Server Error", ["": ""], {_ in })
            }

            // https://httpwg.org/specs/rfc7233.html#header.accept-ranges

            var filesize = "*"
            
            do {
                let size = try file.seekToEnd()
                filesize = String(size)
            } catch {
                //
            }
            
            let length = UInt64(next) - start
            
            let content_length = String(length)
            let content_range = "bytes \(start)-\(next)/\(filesize)"
            
            var rsp_headers = [String: String]()
            rsp_headers["Access-Control-Allow-Origin"] = "*"
            rsp_headers["Access-Control-Allow-Headers"] = "*"
            rsp_headers["Content-Length"] = content_length
            rsp_headers["Content-Range"] = content_range
            rsp_headers["Accept-Ranges"] = "bytes"
                        
            return .raw(206, "Partial Content", rsp_headers, { writer in
                try? writer.write(body)
                try? file.close()
            })
        }
    }
