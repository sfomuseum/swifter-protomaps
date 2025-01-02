import ArgumentParser
import Swifter
import SwifterProtomaps
import Logging
import Foundation

@available(macOS 14.0, iOS 17.0, tvOS 17.0, *)
@main
struct SwifterProtomapsServer: ParsableCommand {
    
    // @Option(help: "The host name to listen for new connections")
    // var host: String = "localhost"
    
    @Option(help: "The parent directory where PMTiles databases should be served from.")
    var root: String = ""
    
    @Option(help: "The port to listen on for new connections")
    var port: UInt16 = 8080
    
    @Option(help: "Enable verbose logging")
    var verbose: Bool = false
    
    @Option(help: "Use System.FileDescriptor rather than Foundation.FileHandle to read data. This is necessary when reading from very large Protomaps databases. This should still be considered experimental")
    var filedescriptors: Bool = false
    
    func run() throws {
                
        let log_label = "org.sfomuseum.swift-protomaps"
        var logger = Logger(label: log_label)
        
        if verbose {
            logger.logLevel = .debug
            logger.debug("Verbose (debug) logging enabled")
        }
        
        let server = HttpServer()
        let root_url = URL(fileURLWithPath: root)
        
        var opts = ServeProtomapsOptions(root: root_url)
        opts.AllowOrigins = "*"
        opts.AllowHeaders = "*"
        opts.Logger = logger
        opts.UseFileDescriptor = filedescriptors
        
        opts.StripPrefix = "/pmtiles"
        
        server["/pmtiles/:path"] = ServeProtomapsTiles(opts)
        
        server["/"] = { request in
            return HttpResponse.ok(.text("Hello world."))
        }
                
        let semaphore = DispatchSemaphore(value: 0)
        
        do {
          try server.start(port)
          logger.info("Server has started on \(port). Try to connect now...")
          semaphore.wait()
        } catch {
            logger.error("Server start error: \(error)")
          semaphore.signal()
        }

    }
}
