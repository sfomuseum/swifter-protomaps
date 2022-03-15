# SwifterProtomaps

Work in progress.

## Example

```
import Swifter
import SwifterProtomaps

do {
            
	let root = URL(string: "/path/to/pmtiles")
	let port: in_port_t  = 9000
	            
    let opts = ServeProtomapsOptions()
    opts.Root = root
    opts.AllowOrigins = "*"
    opts.AllowHeaders = "*"
    
    let server = HttpServer()

	server["/pmtiles/:path"] = ServeProtomapsTiles(root)
	try server.start(port)
	
} catch {
	print("Server start error: \(error)")
}
```

## See also

* https://github.com/httpswift/swifter
* https://github.com/protomaps/
