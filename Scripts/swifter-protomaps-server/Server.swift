import ArgumentParser
import Swifter
import SwifterProtomaps
import Logging
import Foundation

@available(macOS 14.0, iOS 17.0, tvOS 17.0, *)
@main
struct ImageEmbossServer: AsyncParsableCommand {
    
    @Option(help: "The host name to listen for new connections")
    var host: String = "localhost"
    
    @Option(help: "...")
    var root: String = ""
    
    @Option(help: "The port to listen on for new connections")
    var port: UInt16 = 8080
    
    @Option(help: "Enable verbose logging")
    var verbose: Bool = false
    
    func run() async throws {
                
        let log_label = "org.sfomuseum.swift-protomaps"
        let logger = Logger(label: log_label)
        
        let server = HttpServer()
        let root_url = URL(fileURLWithPath: root)
        
        var opts = ServeProtomapsOptions(root: root_url)
        opts.AllowOrigins = "*"
        opts.AllowHeaders = "*"
        opts.Logger = logger
    
        opts.StripPrefix = "/pmtiles"
        
        server["/pmtiles/:path"] = ServeProtomapsTiles(opts)
        
        server["/"] = { request in
            return HttpResponse.ok(.text("Hello world."))
        }
        
        try server.start(port)
        
    }
}
