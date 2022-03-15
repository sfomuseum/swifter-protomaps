# SwifterProtomaps

Work in progress.

## Example

```
import Swifter
import SwifterProtomaps

do {
            
	let root = "/path/to/pmtiles"
	let port: in_port_t  = 9000
	
	let server = HttpServer()
            
	server["/pmtiles/:path"] = SwifterProtomaps.ServeTiles(root)
	try server.start(port)
	
} catch {
	print("Server start error: \(error)")
}
```

## See also

* https://github.com/httpswift/swifter
* https://github.com/protomaps/